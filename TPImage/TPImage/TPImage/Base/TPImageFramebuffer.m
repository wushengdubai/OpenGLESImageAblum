//
//  TPImageFrameBuffer.m
//  TPImage
//
//  Created by 张清泉 on 2019/10/10.
//  Copyright © 2019 Tapai. All rights reserved.
//

#import "TPImageFramebuffer.h"
#import "TPImageContext.h"

@interface TPImageFramebuffer ()
{
    NSMutableDictionary *framebufferCache;
    GLuint framebuffer;
    
    CVPixelBufferRef renderTarget;
    CVOpenGLESTextureRef renderTexture;
}

@end

@implementation TPImageFramebuffer

@synthesize size = _size;
@synthesize texture = _texture;

#pragma mark ---------自定义初始化方法
- (instancetype)initWithSize:(CGSize)framebufferSize {
    if (!(self = [super init])) {
        return nil;
    }
    _size = framebufferSize;
    
    [self generateFramebuffer];
    return self;
}

- (void)dealloc {
    [self destroyFramebuffer];
}

#pragma mark ---------私有方法
- (void)generateFramebuffer {
    runSyncOnVideoProcessingQueue(^{
        [TPImageContext useImageProcessingContext];
        
        glGenFramebuffers(1, &(self->framebuffer));
        glBindFramebuffer(GL_FRAMEBUFFER, self->framebuffer);
        
        if ([TPImageContext supportsFastTextureUpload]) {
            CVOpenGLESTextureCacheRef coreViedoTextureCache = [[TPImageContext sharedImageProcessingContext] coreVideoTextureCache];
            
            CFDictionaryRef empty;// 创建空的字典
            CFMutableDictionaryRef attrs;
            // our empty IOSurface properties dictionary
            empty = CFDictionaryCreate(kCFAllocatorDefault, NULL, NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
            attrs = CFDictionaryCreateMutable(kCFAllocatorDefault, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
            CFDictionarySetValue(attrs, kCVPixelBufferIOSurfacePropertiesKey, empty);
            
            CVReturn err = CVPixelBufferCreate(kCFAllocatorDefault, (int)self.size.width, (int)self.size.height, kCVPixelFormatType_32BGRA, attrs, &(self->renderTarget));
            if (err) {
                NSLog(@"FBO size: %f, %f", self.size.width, self.size.height);
                NSAssert(NO, @"Error at CVPixelBufferCreate %d", err);
            }
            
            err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, coreViedoTextureCache, self->renderTarget,NULL,GL_TEXTURE_2D, GL_RGBA, (int)self.size.width, (int)self.size.height, GL_RGBA, GL_UNSIGNED_BYTE, 0, &(self->renderTexture));
            if (err) {
                NSAssert(NO, @"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
            }
            
            CFRelease(attrs);
            CFRelease(empty);
            
            glBindTexture(CVOpenGLESTextureGetTarget(self->renderTexture), CVOpenGLESTextureGetName(self->renderTexture));
            self->_texture = CVOpenGLESTextureGetName(self->renderTexture);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
            
            // 将图像数据关联到FBO上
            glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, CVOpenGLESTextureGetName(self->renderTexture), 0);
        } else {
            [self generateTexture];
            
            glBindTexture(GL_TEXTURE_2D, self->_texture);
            // 最后一个参数传0，正常的framebuffer传imageData。是为了把当前的framebuffer转换为离屏的frameBuffer
            glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (int)self.size.width, (int)self.size.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, 0);
        }
        
        // 使用之前，必须检查FBO状态是否完整
        #ifndef NS_BLOCK_ASSERTIONS
        GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
        NSAssert(status == GL_FRAMEBUFFER_COMPLETE, @"Incomplete filter FBO: %d", status);
        #endif
        
        glBindTexture(GL_TEXTURE_2D, 0);
    });
}

- (void)generateTexture {
    glActiveTexture(GL_TEXTURE1);
    glGenTextures(1, &_texture);
    glBindTexture(GL_TEXTURE_2D, _texture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    // TODO: Handle mipmaps
}


- (void)destroyFramebuffer {
    runSyncOnVideoProcessingQueue(^{
        if (self->framebuffer) {
            glDeleteRenderbuffers(1, &(self->framebuffer));
            self->framebuffer = 0;
        }
        
        glDeleteTextures(1, &(self->_texture));
    });
}

- (void)activateFramebuffer {
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
    glViewport(0, 0, (int)self.size.width, self.size.height);
}

- (void)restoreRenderTarget {
    CFRelease(renderTarget);
}

- (GLuint)texture {
    return _texture;
}
@end
