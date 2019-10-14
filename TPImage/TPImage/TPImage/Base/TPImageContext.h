//
//  TPImageContext.h
//  TPImage
//
//  Created by 张清泉 on 2019/10/10.
//  Copyright © 2019 Tapai. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TPProgram.h"
#import "TPImageFramebuffer.h"

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif
/** 串行同步在videoQueue中执行 */
void runSyncOnVideoProcessingQueue(void (^block)(void));
/** 串行异步在videoQueue中执行 */
void runAsyncOnVideoProcessingQueue(void (^block)(void));

#ifdef __cplusplus
}
#endif

@interface TPImageContext : NSObject

/** 上下文队列 */
@property(readonly, nonatomic) dispatch_queue_t contextQueue;
/** 当前的着色器程序 */
@property(readonly, retain, nonatomic) TPProgram *currentShaderProgram;
/** 当前上下文 */
@property(readonly, strong, nonatomic) EAGLContext *context;

/** 预览用的FBO(必须在正确的context下使用) */
@property (readonly, nonatomic, assign) GLuint displayFramebuffer;

/** 视频纹理缓存 */
@property(readonly) CVOpenGLESTextureCacheRef coreVideoTextureCache;

/** 单例方法，创建一个context */
+ (TPImageContext *)sharedImageProcessingContext;

/** 可重入队列的key */
+ (void *)contextKey;
/** 共享使用的上下文队列 */
+ (dispatch_queue_t)sharedContextQueue;

/** 使用上下文 */
+ (void)useImageProcessingContext;
/** 使用当前上下文 */
- (void)useAsCurrentContext;

/** 设置活跃的着色器 */
+ (void)setActiveShaderProgram:(TPProgram *)shaderProgram;

/** 是否支持快速加载纹理 */
+ (BOOL)supportsFastTextureUpload;

/** 生成新的着色器程勋 */
- (TPProgram *)programForVertexShaderString:(NSString *)vertexShaderString fragmentShaderString:(NSString *)fragmentShaderString;
/** 使用共享组 */
- (void)useSharegroup:(EAGLSharegroup *)sharegroup;

/** 使用当前上下文，显示fbo */
- (void)presentBufferForDisplay;
@end

NS_ASSUME_NONNULL_END
