//
//  TPImageVideo.h
//  TPImage
//
//  Created by 张清泉 on 2019/10/10.
//  Copyright © 2019 Tapai. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "TPProgram.h"
#import "TPImageFrameBuffer.h"

NS_ASSUME_NONNULL_BEGIN

@interface TPImageVideo : NSObject

@property (nonatomic, retain) AVPlayerItem *playerItem;
@property (nonatomic, retain) AVAsset *asset;
/** 管理输出的FBO */
@property (nonatomic, retain) TPImageFramebuffer *outputFrameBuffer;

/** video 帧数据是否准备好 */
@property (nonatomic, assign) BOOL isDataReady;

/** 自定义初始化方法 */
- (instancetype)initWithPlayerItem:(AVPlayerItem *)playerItem size:(CGSize)size;
- (instancetype)initWithAsset:(AVAsset *)asset size:(CGSize)size;

/** 开始流程处理Video,获取每一帧数据 */
- (void)startProcessing;
/** 取消流程处理Video */
- (void)cancelProcessing;

/** 视频帧转为的texture */
- (GLuint)videoTexture;

/** 获取outputItemTime帧的数据,并转成frameBuffer */
- (void)processPixelBufferAtTime:(CMTime)outputItemTime;

@end

NS_ASSUME_NONNULL_END
