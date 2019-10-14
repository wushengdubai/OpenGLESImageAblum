//
//  TPImageVideo.m
//  TPImage
//
//  Created by 张清泉 on 2019/10/10.
//  Copyright © 2019 Tapai. All rights reserved.
//

#import "TPImageVideo.h"
#import "TPImageContext.h"
#import "TPImageUtils.h"
#import "TPImageConstShaderString.h"
#import <UIKit/UIKit.h>

@interface TPImageVideo ()<AVPlayerItemOutputPullDelegate>
{
    const GLfloat *_preferredConversion; // 更合适的转换格式（矩阵）
    // YUV转RGB的着色器相关传入属性
    GLint yuvConversionPositionAttribute, yuvConversionTextureCoordinateAttribute;
    GLint yuvConversionLuminanceTextureUniform, yuvConversionChrominanceTextureUniform;
    GLint yuvConversionMatrixUniform;
}

/** video的输出 */
@property (nonatomic, strong) AVPlayerItemVideoOutput *playerItemOutput;
@property (nonatomic, assign) BOOL isFullYUVRange;
@property (nonatomic, assign) int videoBufferW;
@property (nonatomic, assign) int videoBufferH;
/** 灰度纹理 Y平面 */
@property (nonatomic, assign) GLuint luminanceTexture;
/** 色度纹理 UV平面 */
@property (nonatomic, assign) GLuint chrominanceTexture;
/** YUV转RGB着色器程序 */
@property (nonatomic, strong) TPProgram *yuvConversionProgram;

/** 视频资源读取 */
@property (nonatomic, strong) AVAssetReader *redader;

/** 视频资源是编码完毕 */
@property (nonatomic, assign) BOOL videoEncodingIsFinished;

/** 视频帧进度时间 */
@property (nonatomic, assign) CMTime processingFrameTime;

@property (nonatomic, assign) CGSize size;

@end

@implementation TPImageVideo
#pragma mark ---------初始化
- (instancetype)initWithPlayerItem:(AVPlayerItem *)playerItem size:(CGSize)size{
    if (!(self = [super init])) {
        return nil;
    }
    self.size = size;
    [self yuvConversionSetup];
    
    self.playerItem = playerItem;
    return self;
}

- (instancetype)initWithAsset:(AVAsset *)asset size:(CGSize)size {
    if (!(self = [super init])) {
        return nil;
    }
    self.size = size;
    [self yuvConversionSetup];
    
    self.asset = asset;
    return self;
}

/** YUV转换的初始化 */
- (void)yuvConversionSetup {
    runSyncOnVideoProcessingQueue(^{
        [TPImageContext useImageProcessingContext];

        self->_preferredConversion = kColorConversion709Default;
        self.isFullYUVRange = YES;

        // 创建着色器程序
        self.yuvConversionProgram = [[TPImageContext sharedImageProcessingContext] programForVertexShaderString:kTPImageVideoVertexShaderString fragmentShaderString:kTPImageYUVFullRangeConversionForLAFragmentShaderString];
        if (![self.yuvConversionProgram link]) {
            NSLog(@"link 失败");
        }

        self->yuvConversionPositionAttribute = [self.yuvConversionProgram attributeIndex:@"position"];
        self->yuvConversionTextureCoordinateAttribute = [self.yuvConversionProgram attributeIndex:@"inputTextureCoordinate"];
        self->yuvConversionLuminanceTextureUniform = [self.yuvConversionProgram uniformIndex:@"luminanceTexture"];
        self->yuvConversionChrominanceTextureUniform = [self.yuvConversionProgram uniformIndex:@"chrominanceTexture"];
        self->yuvConversionMatrixUniform = [self.yuvConversionProgram uniformIndex:@"colorConversionMatrix"];

        [TPImageContext setActiveShaderProgram:self.yuvConversionProgram];

        glEnableVertexAttribArray(self->yuvConversionPositionAttribute);
        glEnableVertexAttribArray(self->yuvConversionTextureCoordinateAttribute);
        
        if (!self.outputFrameBuffer) {
            // 创建frameBuffer
            self.outputFrameBuffer = [[TPImageFramebuffer alloc] initWithSize:self.size];
        }
    });
}

#pragma mark ---------movie 流程
- (void)startProcessing {
    if (self.playerItem) {
        [self processPlayerItem];
    }
    
    if (self.asset) {
        [self processAsset];
    }
}

- (void)processPlayerItem {
    // 指定输出取样数据格式的配置字典
    NSMutableDictionary *pixBuffAttributes = [NSMutableDictionary dictionary];
    if ([TPImageContext supportsFastTextureUpload]) {
        [pixBuffAttributes setObject:@(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    } else {
        [pixBuffAttributes setObject:@(kCVPixelFormatType_32BGRA) forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    }
    
    // 创建video的输出并添加到playerItem中
    self.playerItemOutput = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:pixBuffAttributes];
    dispatch_queue_t videoProcessingQueue = [TPImageContext sharedContextQueue];
    [self.playerItemOutput setDelegate:self queue:videoProcessingQueue];
    
    // self.playerItemOutput会被强引用
    [self.playerItem addOutput:self.playerItemOutput];
    [self.playerItemOutput requestNotificationOfMediaDataChangeWithAdvanceInterval:0.1];
}

#pragma mark ---------公开的方法
/** 获取outputItemTime帧的数据 */
- (void)processPixelBufferAtTime:(CMTime)outputItemTime {
    if ([self.playerItemOutput hasNewPixelBufferForItemTime:outputItemTime]) {
        __weak typeof(self) weakSelf = self;
        // 每帧输出的数据对象
        CVPixelBufferRef pixelBuffer = [self.playerItemOutput copyPixelBufferForItemTime:outputItemTime itemTimeForDisplay:NULL];
        if (pixelBuffer) {
            runSyncOnVideoProcessingQueue(^{
                [weakSelf processMovieFrame:pixelBuffer withSampleTime:outputItemTime];
                CFRelease(pixelBuffer);
            });
        }
    }
}

- (GLuint)videoTexture {
    return self.outputFrameBuffer.texture;
}

#pragma mark ---------处理帧数据
/** 处理playerItem输出的每帧数据 */
- (void)processMovieFrame:(CVPixelBufferRef)movieFrame withSampleTime:(CMTime)currentSampleTime {
    int bufferW = (int)CVPixelBufferGetWidth(movieFrame);
    int bufferH = (int)CVPixelBufferGetHeight(movieFrame);
    
    // 获取附加的颜色信息
    CFTypeRef colorAttachments = CVBufferGetAttachment(movieFrame, kCVImageBufferYCbCrMatrixKey, NULL);
    if (colorAttachments != NULL) {
        if (CFStringCompare(colorAttachments, kCVImageBufferYCbCrMatrix_ITU_R_601_4, 0) == kCFCompareEqualTo) {
            if (self.isFullYUVRange) {
                _preferredConversion = kColorConversion601FullRangeDefault;
            } else {
                _preferredConversion = kColorConversion601Default;
            }
        } else {
            _preferredConversion = kColorConversion709Default;
        }
    } else {
        if (self.isFullYUVRange) {
            _preferredConversion = kColorConversion601FullRangeDefault;
        } else {
            _preferredConversion = kColorConversion601Default;
        }
    }
    
    
    [TPImageContext useImageProcessingContext];
    if ([TPImageContext supportsFastTextureUpload]) {
        // 灰度纹理
        CVOpenGLESTextureRef luminanceTextureRef = NULL;
        // 色度纹理
        CVOpenGLESTextureRef chrominanceTextureRef = NULL;
        
        // 获取YUV平面数,去做RGB转换
        if (CVPixelBufferGetPlaneCount(movieFrame) > 0) {
            // fix issue 2221
            CVPixelBufferLockBaseAddress(movieFrame, 0);
            
            // 调整imageBuffer宽高
            if ((self.videoBufferW != bufferW) && (self.videoBufferH != bufferH)) {
                self.videoBufferW = bufferW;
                self.videoBufferH = bufferH;
            }
            
            // 接下来是CVPixelBufferRef转纹理
            CVReturn err;
            // Y-plane
            glActiveTexture(GL_TEXTURE4);
            err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[TPImageContext sharedImageProcessingContext] coreVideoTextureCache], movieFrame, NULL, GL_TEXTURE_2D, GL_LUMINANCE, bufferW, bufferH, GL_LUMINANCE, GL_UNSIGNED_BYTE, 0, &luminanceTextureRef);
            if (err) {
                NSLog(@"Error at Y plane CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
            }
            self.luminanceTexture = CVOpenGLESTextureGetName(luminanceTextureRef);
            
            // UV-plane,只包含2个通道，顾宽高度是一半
            glActiveTexture(GL_TEXTURE5);
            err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[TPImageContext sharedImageProcessingContext] coreVideoTextureCache], movieFrame, NULL, GL_TEXTURE_2D, GL_LUMINANCE_ALPHA, bufferW/2, bufferH/2, GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, 1, &chrominanceTextureRef);
            if (err) {
                NSLog(@"Error at UV plane CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
            }
            self.chrominanceTexture = CVOpenGLESTextureGetName(chrominanceTextureRef);
            
            glBindTexture(GL_TEXTURE_2D, self.chrominanceTexture);
            // 设置纹理环绕模式
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
            
            [self convertYUVToRGBOutput];
            
            CVPixelBufferUnlockBaseAddress(movieFrame, 0);
            CFRelease(luminanceTextureRef);   // 释放灰度、色度纹理
            CFRelease(chrominanceTextureRef);
        }
        else {
            // TODO: Mesh this with the new framebuffer cache
        }
    }
    else {
        NSLog(@"have cache outputFrameBuffer");
    }
}

/** YUV 转 RGB 输出到outputFrameBuffer */
- (void)convertYUVToRGBOutput {
    // 激活着色器程序
    [TPImageContext setActiveShaderProgram:self.yuvConversionProgram];
    // 激活当前输出的FBO
    [self.outputFrameBuffer activateFramebuffer];
    
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glActiveTexture(GL_TEXTURE4);
    glBindTexture(GL_TEXTURE_2D, self.luminanceTexture);
    // 设置fs中灰度纹理为 GL_TEXTURE4
    glUniform1i(yuvConversionLuminanceTextureUniform, 4);
    
    glActiveTexture(GL_TEXTURE5);
    glBindTexture(GL_TEXTURE_2D, self.chrominanceTexture);
    // 设置fs中色度纹理为 GL_TEXTURE4
    glUniform1i(yuvConversionChrominanceTextureUniform, 5);
    
    // 设置fs中的颜色矩阵
    glUniformMatrix3fv(yuvConversionMatrixUniform, 1, GL_FALSE, _preferredConversion);
    
    // 设置顶点数据
    glVertexAttribPointer(yuvConversionPositionAttribute, 2, GL_FLOAT, 0, 0, imageVertices);
    // 设置纹理数据
    glVertexAttribPointer(yuvConversionTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, textureCoordinates);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4); // 把视频帧数据绘制到framebuffer上了
    
    glFinish();
}

/** 取消movie的处理流程 */
- (void)cancelProcessing {
    if (self.redader) {
        [self.redader cancelReading];// 取消读取
    }
}

#pragma mark ---------处理asset的流程
- (void)processAsset {
    self.redader = [self createAssetReader];
    
    AVAssetReaderTrackOutput *readerVideoTrackOutput = nil;
    AVAssetReaderTrackOutput *readerAudioTrackOutput = nil;
    
    for (AVAssetReaderTrackOutput *output in self.redader.outputs) {
        if ([output.mediaType isEqualToString:AVMediaTypeVideo]) {
            readerVideoTrackOutput = output;
        }
        if ([output.mediaType isEqualToString:AVMediaTypeAudio]) {
            readerAudioTrackOutput = output;
        }
    }
    
    if ([self.redader startReading] == NO) {
        NSLog(@"Error reading Because not startReading");
        return;
    }
    
    while (self.redader.status == AVAssetReaderStatusReading) {
        [self readNextVideoFrameFromOutput:readerVideoTrackOutput];
    }
    
    if (self.redader.status == AVAssetReaderStatusCompleted) {
        [self.redader cancelReading];
    }
}

/** 创建videoReader资源，并添加输出源 */
- (AVAssetReader *)createAssetReader {
    NSError *error = nil;
    AVAssetReader *assetReader = [AVAssetReader assetReaderWithAsset:self.asset error:&error];
    
    NSMutableDictionary *outputSettings = [NSMutableDictionary dictionary];
    if ([TPImageContext supportsFastTextureUpload]) {
        [outputSettings setObject:@(kCVPixelFormatType_420YpCbCr8PlanarFullRange) forKey:(id)kCVPixelBufferPixelFormatTypeKey];
        self.isFullYUVRange = YES;
    } else {
        [outputSettings setObject:@(kCVPixelFormatType_32BGRA) forKey:(id)kCVPixelBufferPixelFormatTypeKey];
        self.isFullYUVRange = NO;
    }
    
    AVAssetReaderTrackOutput *readerVideoTrackOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:[[self.asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] outputSettings:outputSettings];
    // Maybe set alwaysCopiesSampleData to NO on iOS 5.0 for faster video decoding
    readerVideoTrackOutput.alwaysCopiesSampleData = NO;
    [assetReader addOutput:readerVideoTrackOutput];
    
    return assetReader;
}

/** 读取下一帧的视频输出数据 */
- (BOOL)readNextVideoFrameFromOutput:(AVAssetReaderTrackOutput *)readerVideoTrackOutput {
    if (self.redader.status == AVAssetReaderStatusReading && !self.videoEncodingIsFinished) {
        CMSampleBufferRef sampleBufferRef = [readerVideoTrackOutput copyNextSampleBuffer];
        if (sampleBufferRef) {
            runSyncOnVideoProcessingQueue(^{
                [self processMovieFrame:sampleBufferRef];
                CMSampleBufferInvalidate(sampleBufferRef);
                CFRelease(sampleBufferRef);
            });
            
            return YES;
        } else {
            self.videoEncodingIsFinished = YES;
        }
    }
    return  NO;
}

/** 处理asset中视频输出的每一帧数据 */
- (void)processMovieFrame:(CMSampleBufferRef)movieSampleBuffer {
    CMTime  currentSampleTime = CMSampleBufferGetOutputPresentationTimeStamp(movieSampleBuffer);
    CVImageBufferRef movieFrame = CMSampleBufferGetImageBuffer(movieSampleBuffer);
   
    self.processingFrameTime = currentSampleTime;
    
    [self processMovieFrame:movieFrame withSampleTime:currentSampleTime];
}

#pragma mark --------- AVPlayerItemOutputPullDelegate
// 告诉Delegate准备取样
- (void)outputMediaDataWillChange:(AVPlayerItemOutput *)sender {
    NSLog(@"begain to drive");
    self.isDataReady = YES;
}

@end
