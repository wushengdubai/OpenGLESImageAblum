//
//  TPImageFilter.h
//  TPImage
//
//  Created by 张清泉 on 2019/10/10.
//  Copyright © 2019 Tapai. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "Parse_AE.h"

NS_ASSUME_NONNULL_BEGIN

@interface TPImageFilter : NSObject

@property (nonatomic, copy) NSString *resourceName;
/** 纹理尺寸 */
@property (nonatomic) CGSize texture_size;

- (instancetype)initSize:(CGSize)size ae:(AEConfigEntity &)aeConfig camera:(AEConfigEntity &)cameraConfig withFileName:(NSString *)fileName;

/** 渲染帧数据到texture */
- (void)renderToTexture:(int)fr;

- (GLuint)imageTexture;

@end

NS_ASSUME_NONNULL_END
