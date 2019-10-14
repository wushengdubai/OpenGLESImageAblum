//
//  TPDisplayPreview.m
//  TPImage
//
//  Created by 张清泉 on 2019/10/10.
//  Copyright © 2019 Tapai. All rights reserved.
//

#import "TPDisplayPreview.h"
#import <AVFoundation/AVFoundation.h>
#import "TPImageContext.h"
#import "TPImageVideo.h"
#import "TPImageUtils.h"
#import "TPImageConstShaderString.h"
#import "TPImageFilter.h"
#import "TPImageModel.h"

@interface TPDisplayPreview ()
{
    GLint displayPositionAttribute, displayTextureCoordinateAttribute;
    GLint displayInputTextureUniform;
    GLint displayInputTextureUniform2;
    
    GLuint displayRenderbuffer, displayFramebuffer;
    CGSize boundsSizeAtFrameBufferEpoch; // 在framebuffer时期的bounds
    
    // 帧率
    int _fr;
    int _total_fr; // 总帧数
    
    ParseAE parseAE;
    ParseAE camera_parseAE;
    AEConfigEntity configEntity;
    AEConfigEntity camera_configEntity;
    
    GLuint _texture_ae; // ae纹理
    GLuint _texture_video;  // video纹理
}

@property (nonatomic, strong) AVPlayer *player;

@property (nonatomic, strong) TPProgram *program;

/** 用于预览的movie */
@property (nonatomic, strong) TPImageVideo *previewMovie;

/** 音频播放器 */
@property (nonatomic, strong) AVAudioPlayer *audioPlayer;

/** 渲染使用的计时器 */
@property (nonatomic, strong) NSTimer *renderTimer;

@property (nonatomic, strong) TPImageFilter *imageFilter;

/** 是否进入后台 */
@property (nonatomic, assign) BOOL isEnterBackground;

/** 视频总时长 */
@property (nonatomic, assign) CGFloat duration;
/** 播放速率 */
@property (nonatomic, assign) int32_t timeScale;

@property (nonatomic, strong) TPImageModel *imageModel;
@end

@implementation TPDisplayPreview

#pragma mark ---------自定义初始化方法
+ (Class)layerClass {
    return [CAEAGLLayer class];
}

- (void)dealloc {
    [self stopPlay];
    runSyncOnVideoProcessingQueue(^{
        [self destroyDisplayFramebuffer];
    });
}

- (void)layoutSubviews {
    [super layoutSubviews];
    // 当view size改变是，frameBuffer需要销毁旧的，并重新创建
    if (!CGSizeEqualToSize(self.bounds.size, boundsSizeAtFrameBufferEpoch) &&
        !CGSizeEqualToSize(self.bounds.size, CGSizeZero)) {
        runSyncOnVideoProcessingQueue(^{
            [self destroyDisplayFramebuffer];
            [self createDisplayFramebuffer];
        });
    }
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self  =[super initWithCoder:coder]) {
//        [self commonInit];
//        [self addNotification];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame withResourceName:(NSString *)fileName {
    if (!(self = [super initWithFrame:frame])) {
        return nil;
    }
    self.resourceName = fileName;
    [self commonInit];
    [self addNotification];
    return self;
}

- (void)commonInit {
    if ([self respondsToSelector:@selector(setContentScaleFactor:)]) {
        self.contentScaleFactor = [[UIScreen mainScreen] scale];
    }
    
    self.opaque = YES;
    self.hidden = NO;
    CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
    eaglLayer.opaque = YES;
    eaglLayer.drawableProperties = @{kEAGLDrawablePropertyRetainedBacking: @(NO), kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8};

    runSyncOnVideoProcessingQueue(^{
        [TPImageContext useImageProcessingContext];
        
        self.program = [[TPImageContext sharedImageProcessingContext] programForVertexShaderString:kTPImageVideoVertexShaderString fragmentShaderString:kTPImageVideoHalfFragmentShaderString];
        if (![self.program link]) {
            NSLog(@"Link faild");
        }
        [TPImageContext setActiveShaderProgram:self.program];
                                  
        self->displayPositionAttribute = [self.program attributeIndex:@"position"];
        //从program中获取textCoordinate 纹理属性
        self->displayTextureCoordinateAttribute = [self.program attributeIndex:@"inputTextureCoordinate"];
        self->displayInputTextureUniform = [self.program uniformIndex:@"inputImageTexture"];
        self->displayInputTextureUniform2 = [self.program uniformIndex:@"inputImageTexture2"];
                                
        // 激活顶点属性，默认是关闭的
        glEnableVertexAttribArray(self->displayPositionAttribute);
        glEnableVertexAttribArray( self->displayTextureCoordinateAttribute);

        // 向program传递顶点和纹理坐标
        glVertexAttribPointer(self->displayPositionAttribute, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(GLfloat), imageVertices);
        glVertexAttribPointer(self->displayTextureCoordinateAttribute, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(GLfloat), textureCoordinates);
        
        [self createDisplayFramebuffer];
    });
}

/** 创建用于展示的framebuffer */
- (void)createDisplayFramebuffer {
    [TPImageContext useImageProcessingContext];
    
    // FBO管理RBO
    glGenRenderbuffers(1, &displayFramebuffer);
    glBindRenderbuffer(GL_FRAMEBUFFER, displayFramebuffer);
    
    glGenRenderbuffers(1, &displayRenderbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, displayRenderbuffer);
    
    // 为renderbuffer分配存储空间
    BOOL result =  [[[TPImageContext sharedImageProcessingContext] context] renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer*)self.layer];
    
    if (!result) {
        NSLog(@"=== renderbuffer storage failed");
        [self destroyDisplayFramebuffer];
        return;
    }
    
    GLint backingW, backingH;

    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingW);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingH);

    if (backingW == 0 || backingH == 0) {
        NSLog(@"=== displayRenderBuffer was destory. Size:(%d,%d)", backingW, backingH);
        [self destroyDisplayFramebuffer];
        return;
    }
    _sizeInPixels.width = backingW;
    _sizeInPixels.height = backingH;
    NSLog(@"=== displayRenderBuffer Size:(%d,%d)", backingW, backingH);
    
    // 将renderbuffer附加到framebuffer的颜色附加点上，即关联到FBO上
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, displayRenderbuffer);
    
    // 使用之前，必须检查FBO状态是否完整
    GLenum framebufferCreationStatus = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    NSAssert(framebufferCreationStatus != GL_FRAMEBUFFER_COMPLETE, @"Failure with display framebuffer generation for display of size: %f, %f", self.frame.size.width, self.frame.size.height);
    boundsSizeAtFrameBufferEpoch = self.frame.size;
    
    NSString *resPath = [TPImageUtilsBundle stringByAppendingPathComponent:self.resourceName];
    NSString *imgPath = [resPath stringByAppendingPathComponent:@"1/images/img_0.png"];
    self.imageModel = [[TPImageModel alloc] initWithImageData:imgPath];
}

/** 销毁frameBuffer */
- (void)destroyDisplayFramebuffer {
    [TPImageContext useImageProcessingContext];
    
    if (displayFramebuffer) {
        glDeleteFramebuffers(1, &displayFramebuffer);
        displayFramebuffer = 0;
    }
    
    if (displayRenderbuffer) {
        glDeleteRenderbuffers(1, &displayRenderbuffer);
        displayRenderbuffer = 0;
    }
}

#pragma mark ---------准备和刷新数据
- (void)setDataAndRefreash {
    [self stopPlay];
    
//    [self setMaskMovieTexture];
    
    float scale = [UIScreen mainScreen].scale;
    CGSize screenSize = CGSizeMake(self.frame.size.width * scale, self.frame.size.height * scale);
    // 加载AE相关资源
    self.imageFilter = [[TPImageFilter alloc] initSize:screenSize ae:configEntity camera:camera_configEntity withFileName:self.resourceName];
    [self startPlay];
}

// 初始化预览播放相关资源
- (void)setMaskMovieTexture {
    NSString *resPath = [TPImageUtilsBundle stringByAppendingPathComponent:self.resourceName];
    NSString *audio_Path = [resPath stringByAppendingPathComponent:@"music.mp3"];
    NSString *video_Path = [resPath stringByAppendingPathComponent:@"tp_fg.mp4"];
    NSString *tp_json_Path = [resPath stringByAppendingPathComponent:@"tp.json"];
    NSString *tp_camera_Path = [resPath stringByAppendingPathComponent:@"tp_camera.json"];
    
    NSError *error = nil;
    self.audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL URLWithString:audio_Path] error:&error];
    [self.audioPlayer prepareToPlay];
    
    // 加载AE模型
    NSLog(@"%f",[[NSDate date] timeIntervalSince1970]);
   char *configPath = (char *)[tp_json_Path UTF8String];
    parseAE.dofile(configPath, configEntity);
    _fr = configEntity.fr;
    _total_fr = configEntity.op - configEntity.ip + 1;
    if (configEntity.ddd) {
        configPath = (char *)[tp_camera_Path UTF8String];
        camera_parseAE.dofile(configPath, camera_configEntity);
    }
    NSLog(@"%f",[[NSDate date] timeIntervalSince1970]);
    
    NSURL *tmpUrl = [NSURL fileURLWithPath:video_Path];
    AVAsset *tmpAsset = [AVAsset assetWithURL:tmpUrl];
    self.timeScale = tmpAsset.duration.timescale;
    self.duration = tmpAsset.duration.value/tmpAsset.duration.timescale;
    
    AVPlayerItem *playerItem = [[AVPlayerItem alloc] initWithAsset:tmpAsset];
    self.player = [AVPlayer playerWithPlayerItem:playerItem];
    
    self.previewMovie = [[TPImageVideo alloc] initWithPlayerItem:playerItem size:self.frame.size];
    self.player.rate = 1.0;
    [self.previewMovie startProcessing];
}

#pragma mark ---------预览控制
- (void)startPlay {
    // 时间间隔1s/帧数
    self.renderTimer = [NSTimer scheduledTimerWithTimeInterval:1.0/_fr target:self selector:@selector(previewScheduleTimerCallback) userInfo:nil repeats:YES];
}

/** 结束播放 */
- (void)stopPlay {
    if (self.player) {
        [self.player pause];
    }
    
    if (self.audioPlayer) {
        [self.audioPlayer pause];
    }
    
    if (self.renderTimer) {
        [self.renderTimer invalidate];
        self.renderTimer = nil;
    }
}

/** 暂停 */
- (void)pause {
    [self.player pause];
    [self.audioPlayer pause];
}
/** 继续 */
- (void)resume {
    [self.player play];
    [self.audioPlayer play];
}

/** 跳转进度 */
- (void)seekToPercent:(CGFloat)percent {
    CGFloat tmpNowSecond = self.duration * percent;
    [self.player seekToTime:CMTimeMakeWithSeconds(tmpNowSecond, self.timeScale) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
    self.audioPlayer.currentTime = self.audioPlayer.duration * percent;
}

/** 切换资源名字 */
- (void)resetResourceName:(NSString *)name {
    _resourceName = name;
    
    if (self.audioPlayer) {
        [self.audioPlayer stop];
        self.audioPlayer = nil;
    }
    
    if (self.previewMovie) {
        [self.previewMovie cancelProcessing];
        self.previewMovie = nil;
    }
    
    if (self.player) {
        [self.player.currentItem cancelPendingSeeks];
        [self.player.currentItem.asset cancelLoading];
    }
    
    [self setDataAndRefreash];
}

#pragma mark ---------预览视频的计时器
- (void)previewScheduleTimerCallback {
    runSyncOnVideoProcessingQueue(^{
        if (self.previewMovie && self.previewMovie.isDataReady) {
            // 播放到第几帧
            __block int fr_pts =  (int)(self.player.currentTime.value*1.0/self.player.currentTime.timescale*self->_fr);
            if (fr_pts >= self->_total_fr) { // 播放完毕
//                NSLog(@"fr_pts = %d %lf", fr_pts, [[NSDate date] timeIntervalSince1970]);
                [self.player seekToTime:kCMTimeZero toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished) {
                    if (self.player.rate == 0) {
                        [self.player play];
                    }
                    self.audioPlayer.currentTime = 0;
                    fr_pts = 0;
                    [self drawAction:fr_pts];
                }];
            } else {
//                NSLog(@"fr_pts = %d %lf", fr_pts, [[NSDate date] timeIntervalSince1970]);
                [self drawAction:fr_pts];
            }
        }
    });
}

/** 绘制帧画面 */
- (void)drawAction:(int)fr_pts {
    if (self.previewMovie && self.imageFilter) {
//        [self.imageFilter renderToTexture:fr_pts];
        [self.previewMovie processPixelBufferAtTime:self.player.currentTime];
        
        _texture_video = [self.previewMovie videoTexture];
//        _texture_ae = [self.imageFilter imageTexture];
    
        if (self.player.rate == 0) {
            [self.player play];
        }
        if (!self.audioPlayer.playing) {
            [self.audioPlayer play];
        }
        [self draw];
    }
}


- (void)draw {
    runSyncOnVideoProcessingQueue(^{
        [TPImageContext useImageProcessingContext];
        // 激活着色器
        [TPImageContext setActiveShaderProgram:self.program];
        // 把准备好的离屏FBO切换上来
        [self setDisplayFramebuffer];
        
        // 清除上次绘制的缓存
        glClearColor(1.0, 1.0, 1.0, 1.0);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        glEnable(GL_DEPTH_TEST);
        
        // 修改纹理数据，重新绑定到renderbuffer上
        glActiveTexture(GL_TEXTURE4);
        glBindTexture(GL_TEXTURE_2D,self->_texture_ae);
        glUniform1i(self->displayInputTextureUniform, 4);
        
        glActiveTexture(GL_TEXTURE5);
        glBindTexture(GL_TEXTURE_2D, self.imageModel.imageTexture);
        [self.program setInt:5 name:self->displayInputTextureUniform2];
        
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        
        [self presentFramebuffer];
    });
}

- (void)setDisplayFramebuffer {
    if (!displayFramebuffer) {
        [self createDisplayFramebuffer];
    }
    glBindBuffer(GL_FRAMEBUFFER, displayFramebuffer);
    glViewport(0, 0, (GLint)_sizeInPixels.width, (GLint)_sizeInPixels.height);
}

/** 展示绘制的renderBuffer到屏幕上 */
- (void)presentFramebuffer {
    glBindRenderbuffer(GL_RENDERBUFFER, displayRenderbuffer);
    [[[TPImageContext sharedImageProcessingContext] context] presentRenderbuffer:GL_RENDERBUFFER];
}

#pragma mark ---------通知事件处理
- (void)addNotification {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dealApplicationWillEnterbackground) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dealApplicationWillEnterForefround) name:UIApplicationWillEnterForegroundNotification object:nil];
}

- (void)dealApplicationWillEnterbackground {
    // 保存部分资源
    // 删除消耗大量内存的对象
    [self.player pause];
    [self.audioPlayer pause];
    [self.renderTimer setFireDate:[NSDate distantFuture]];
    glFinish();
}

- (void)dealApplicationWillEnterForefround {
    // 重新创建删除的对象，使用保存的对象，恢复退出后台时的状态
    // 重新绘制
    [self.player play];
    [self.audioPlayer play];
    [self.renderTimer setFireDate:[NSDate date]];
}

#pragma mark ---------懒加载
- (void)setResourceName:(NSString *)resourceName {
    _resourceName = resourceName;
    [self resetResourceName:resourceName];
}
@end
