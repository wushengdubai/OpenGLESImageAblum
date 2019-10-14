//
//  TPImageConstShaderString.h
//  TPImage
//
//  Created by 张清泉 on 2019/10/10.
//  Copyright © 2019 Tapai. All rights reserved.
//

#import <Foundation/Foundation.h>

#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)
#define SHADER_STRING(text) @ STRINGIZE2(text)

// 基础顶点着色器
extern NSString * const kTPImageVideoVertexShaderString;
// 
extern NSString * const kTPImageVideoPassthroughFragmentShaderString;
// AE video的片段着色器
extern NSString *const kTPImageVideoHalfFragmentShaderString;
// AE Json中控制的图片顶点着色器
extern NSString *const kTPImagePictureVertexShaderString;
// AE Json中控制的图片片段着色器
extern NSString *const kTPImagePicturePassthroughFragmentShaderString;
// FullRange YUV转RGB片段着色器
extern NSString *const kTPImageYUVFullRangeConversionForLAFragmentShaderString;
// YUV转RGB片段着色器
extern NSString *const kTPImageYUVVideoRangeConversionForRGFragmentShaderString;
