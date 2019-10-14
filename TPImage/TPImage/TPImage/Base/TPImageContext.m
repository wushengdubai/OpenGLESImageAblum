//
//  TPImageContext.m
//  TPImage
//
//  Created by 张清泉 on 2019/10/10.
//  Copyright © 2019 Tapai. All rights reserved.
//

#import "TPImageContext.h"

void runSyncOnVideoProcessingQueue(void (^block)(void)) {
    dispatch_queue_t videoProcessingQueue = [TPImageContext sharedContextQueue];
    if (dispatch_get_specific([TPImageContext contextKey])) {
        block();
    } else {
        dispatch_sync(videoProcessingQueue, block);
    }
}

void runAsyncOnVideoProcessingQueue(void (^block)(void)) {
    dispatch_queue_t videoProcessingQueue = [TPImageContext sharedContextQueue];
    if (dispatch_get_specific([TPImageContext contextKey])) {
        block();
    } else {
        dispatch_async(videoProcessingQueue, block);
    }
}

@interface TPImageContext ()
{
    EAGLSharegroup          *_sharegroup;
}

@end

@implementation TPImageContext

@synthesize context = _context;
@synthesize currentShaderProgram = _currentShaderProgram;
@synthesize contextQueue = _contextQueue;
@synthesize coreVideoTextureCache = _coreVideoTextureCache;
@synthesize displayFramebuffer = _displayFramebuffer;

static void *openGLESContextQueueKey;

#pragma mark ---------初始化方法
- (instancetype)init {
    if (!(self = [super init])) {
        return nil;
    }
    
    openGLESContextQueueKey = &openGLESContextQueueKey;
    _contextQueue = dispatch_queue_create("com.wushengdubai.TPImage.openGLESContextQueue",DISPATCH_QUEUE_SERIAL);
    
#if OS_OBJECT_USE_OBJC
    dispatch_queue_set_specific(_contextQueue, openGLESContextQueueKey, (__bridge void *)self, NULL);
#endif
    return self;
}

#pragma mark ---------公有方法
+ (TPImageContext *)sharedImageProcessingContext {
    static dispatch_once_t onceToken;
    static TPImageContext *sharedImageProcessingContext = nil;
    dispatch_once(&onceToken, ^{
        sharedImageProcessingContext = [[[self class] alloc] init];
    });
    return sharedImageProcessingContext;
}

+ (void *)contextKey {
    return openGLESContextQueueKey;
}

+ (dispatch_queue_t)sharedContextQueue {
    return [[self sharedImageProcessingContext] contextQueue];
}

+ (void)useImageProcessingContext {
    [[TPImageContext sharedImageProcessingContext] useAsCurrentContext];
}

- (void)useAsCurrentContext {
    EAGLContext *imageProcessingContext = [self context];
    if (imageProcessingContext != [EAGLContext currentContext]) {
        NSLog(@"%@", imageProcessingContext);
        glFlush();// 在相同线程，切换context
        [EAGLContext setCurrentContext:imageProcessingContext];
    }
}

+ (void)setActiveShaderProgram:(TPProgram *)shaderProgram {
    TPImageContext *sharedContext = [TPImageContext sharedImageProcessingContext];
    [sharedContext setContextShaderProgram:shaderProgram];
}

- (void)setContextShaderProgram:(TPProgram *)shaderProgram {
    EAGLContext *imageProcessingContext = [self context];
    if (imageProcessingContext != [EAGLContext currentContext]) {
        [EAGLContext setCurrentContext:imageProcessingContext];
    }
    
    if (self.currentShaderProgram != shaderProgram) {
        _currentShaderProgram = shaderProgram;
    }
    [shaderProgram use];
}

+ (BOOL)supportsFastTextureUpload {
#if TARGET_IPHONE_SIMULATOR
    return NO;
#else
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-pointer-compare"
    return (CVOpenGLESTextureCacheCreate != NULL);
#pragma clang diagnostic pop

#endif
}

- (TPProgram *)programForVertexShaderString:(NSString *)vertexShaderString fragmentShaderString:(NSString *)fragmentShaderString {
    TPProgram *program = [[TPProgram alloc] initWithVertexShaderString:vertexShaderString fragmentShaderString:fragmentShaderString];
    return program;
}

- (void)useSharegroup:(EAGLSharegroup *)sharegroup {
    NSAssert(_context == nil, @"Unable to use a share group when the context has already been created. Call this method before you use the context for the first time.");
    _sharegroup = self.context.sharegroup;
}

- (void)presentBufferForDisplay {
    [self.context presentRenderbuffer:GL_RENDERBUFFER];
}

#pragma mark ---------私有方法
- (EAGLContext *)createContext {
    EAGLContext *context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    if (!context) {
        context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    }
    return  context;
}

#pragma mark ---------Accessors访问器
- (EAGLContext *)context {
    if (!_context) {
        _context = [self createContext];
        [EAGLContext setCurrentContext:_context];
        // 为图像处理管道配置全局设置
        glEnable(GL_DEPTH_TEST);
    }
    return _context;
}

- (CVOpenGLESTextureCacheRef)coreVideoTextureCache {
    if (_coreVideoTextureCache == NULL) {
        CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, [self context], NULL, &_coreVideoTextureCache);
        if (err) {
            NSAssert(NO, @"Error at CVOpenGLESTextureCacheCreate %d", err);
        }
    }
    return _coreVideoTextureCache;
}

- (TPProgram *)currentShaderProgram {
    return _currentShaderProgram;
}

- (GLuint)displayFramebuffer {
    if (!_displayFramebuffer) {
        glGenFramebuffers(1, &_displayFramebuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, _displayFramebuffer);
    }
    return _displayFramebuffer;
}
@end
