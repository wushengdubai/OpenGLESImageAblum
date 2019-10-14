//
//  TPImageTestView.m
//  TPImage
//
//  Created by 张清泉 on 2019/10/14.
//  Copyright © 2019 Tapai. All rights reserved.
//

#import "TPImageTestView.h"
#import "TPImageContext.h"
#import "TPProgram.h"
#import "TPImageUtils.h"
#import "TPImageConstShaderString.h"
#import "TPImageModel.h"
#import "GLProgram.hpp"
#include "utils.hpp"

@interface TPImageTestView ()
{
    GLuint displayPositionAttribute, displayTextureCoordinateAttribute, depthbuffer;
    GLint displayInputTextureUniform;
    
    GLuint displayRenderbuffer, displayFramebuffer;
    CGSize boundsSizeAtFrameBufferEpoch;
//    GLuint _program;
}

@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) TPProgram *program;

@property (nonatomic, strong) TPImageModel *imageModel;

@end

@implementation TPImageTestView

+ (Class)layerClass {
    return [CAEAGLLayer class];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder:coder]) {
        [self configData];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self configData];
    }
    return self;
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

- (void)configData {
    if ([self respondsToSelector:@selector(setContentScaleFactor:)]) {
        self.contentScaleFactor = [[UIScreen mainScreen] scale];
    }
    
    self.opaque = YES;
    self.hidden = NO;
    CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
    eaglLayer.opaque = YES;
    eaglLayer.drawableProperties = @{kEAGLDrawablePropertyRetainedBacking: @(NO), kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8};
    
    [self configProgram];
}

- (void)configProgram {
    runSyncOnVideoProcessingQueue(^{
        [TPImageContext useImageProcessingContext];
    
        self.program = [[TPProgram alloc] initWithVertexShaderString:kTPImageVideoVertexShaderString fragmentShaderString:kTPImageVideoHalfFragmentShaderString];

        if (![self.program link]) {
            NSLog(@"Link faild");
        }
    
        [TPImageContext setActiveShaderProgram:self.program];
                                  
        self->displayPositionAttribute = [self->_program attributeIndex:@"position"];
        //从program中获取textCoordinate 纹理属性
        self->displayTextureCoordinateAttribute = [self.program attributeIndex:@"inputTextureCoordinate"];
        self->displayInputTextureUniform = [self.program uniformIndex:@"inputImageTexture"];
        
        // 激活顶点属性，默认是关闭的
        glEnableVertexAttribArray(self->displayPositionAttribute);
        glEnableVertexAttribArray( self->displayTextureCoordinateAttribute);

        // 向program传递顶点和纹理坐标
        glVertexAttribPointer(self->displayPositionAttribute, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(GLfloat), imageVertices);
        glVertexAttribPointer(self->displayTextureCoordinateAttribute, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(GLfloat), textureCoordinates);
        
        [self createDisplayFramebuffer];
    });
    
    [self startTimer];
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

//    // 使用之前，必须检查FBO状态是否完整
    GLenum framebufferCreationStatus = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    NSAssert(framebufferCreationStatus != GL_FRAMEBUFFER_COMPLETE, @"Failure with display framebuffer generation for display of size: %f, %f", self.frame.size.width, self.frame.size.height);
    boundsSizeAtFrameBufferEpoch = self.frame.size;
    
    NSString *resPath = [TPImageUtilsBundle stringByAppendingPathComponent:@"1"];
    NSString *imgPath = [resPath stringByAppendingPathComponent:@"images/img_0.png"];
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

- (void)startTimer {
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0/25 target:self selector:@selector(previewScheduleTimerCallback) userInfo:nil repeats:YES];
}

- (void)previewScheduleTimerCallback {
    runSyncOnVideoProcessingQueue(^{
        [TPImageContext sharedImageProcessingContext];
        
        // 把准备好的离屏FBO切换上来
        [self setDisplayFramebuffer];
                
        // 清除上次绘制的缓存
        glClearColor(0.2f, 0.3f, 0.3f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
        
        // 激活着色器
        [TPImageContext setActiveShaderProgram:self.program];
        
        glActiveTexture(GL_TEXTURE5);
        glBindTexture(GL_TEXTURE_2D, self.imageModel.imageTexture);
        [self.program setInt:5 name:self->displayInputTextureUniform];
        
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        
        [self presentFramebuffer];
    });
}

- (void)setDisplayFramebuffer {
    if (!displayFramebuffer) {
        [self createDisplayFramebuffer];
    }
    glBindBuffer(GL_FRAMEBUFFER, displayFramebuffer);
    glViewport(0, 0, (GLuint)_sizeInPixels.width, (GLuint)_sizeInPixels.height);
}

/** 展示绘制的renderBuffer到屏幕上 */
- (void)presentFramebuffer {
    glBindRenderbuffer(GL_RENDERBUFFER, displayRenderbuffer);
    [[[TPImageContext sharedImageProcessingContext] context] presentRenderbuffer:GL_RENDERBUFFER];
}
@end
