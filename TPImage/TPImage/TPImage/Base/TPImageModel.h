//
//  TPImageModel.h
//  TPImage
//
//  Created by 张清泉 on 2019/10/12.
//  Copyright © 2019 Tapai. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenGLES/ES3/gl.h>

NS_ASSUME_NONNULL_BEGIN

@interface TPImageModel : NSObject

/** 第几张图片 */
@property (nonatomic, assign) int index;
/** 图像宽 */
@property (readonly) int w;
/** 图像高 */
@property (readonly) int h;

/** 根据image创建的Texture */
@property (readonly) GLuint imageTexture;

- (instancetype)initWithImageData:(NSString *)imagePath;

@end

NS_ASSUME_NONNULL_END
