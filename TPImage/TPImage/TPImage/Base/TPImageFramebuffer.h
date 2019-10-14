//
//  TPImageFrameBuffer.h
//  TPImage
//
//  Created by 张清泉 on 2019/10/10.
//  Copyright © 2019 Tapai. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <QuartzCore/QuartzCore.h>

NS_ASSUME_NONNULL_BEGIN

@interface TPImageFramebuffer : NSObject

/** frameBuffer的尺寸 */
@property(readonly) CGSize size;
/** frameBuffer转换的纹理 */
@property(readonly) GLuint texture;

- (id)initWithSize:(CGSize)framebufferSize;

/** 使用FrameBuffer */
- (void)activateFramebuffer;
- (void)destroyFramebuffer;

@end

NS_ASSUME_NONNULL_END
