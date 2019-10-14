//
//  TPImageConstShaderString.m
//  TPImage
//
//  Created by 张清泉 on 2019/10/10.
//  Copyright © 2019 Tapai. All rights reserved.
//

#import "TPImageConstShaderString.h"

// 基础顶点着色器 VS
NSString *const kTPImageVideoVertexShaderString = SHADER_STRING
(
 attribute vec4 position;
 attribute vec4 inputTextureCoordinate;
 
 varying vec2 textureCoordinate;
 
 void main()
 {
    gl_Position = position;
    textureCoordinate = inputTextureCoordinate.xy;
 }
);

// 片段着色器
NSString *const kTPImageVideoPassthroughFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 
 void main()
 {
     gl_FragColor = texture2D(inputImageTexture, textureCoordinate);
 }
);

// // AE video的片段着色器
NSString *const kTPImageVideoHalfFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
// uniform sampler2D inputImageTexture2;
 void main()
 {
     lowp vec4 textureColor = texture2D(inputImageTexture, textureCoordinate);
//    lowp vec4 textureColor = texture2D(inputImageTexture, textureCoordinate);
//     lowp vec4 textureColor2 = texture2D(inputImageTexture2, vec2(textureCoordinate.x/2.0,1.0-textureCoordinate.y));
//
//     lowp vec4 textureColor3 = texture2D(inputImageTexture2, vec2(0.5+textureCoordinate.x/2.0,1.0-textureCoordinate.y));
//
//     gl_FragColor = textureColor * (1.0-textureColor3.r) + textureColor2;
    gl_FragColor = textureColor;
 }
 );

// AE Json中控制的图片顶点着色器
NSString *const kTPImagePictureVertexShaderString = SHADER_STRING
(
 attribute vec4 position;
 attribute vec4 inputTextureCoordinate;
 
 varying vec2 textureCoordinate;
 
 uniform mat4 modelViewMatrix;
 
 void main()
 {
     gl_Position = modelViewMatrix * position;
     textureCoordinate = inputTextureCoordinate.xy;
 }
 );

// AE Json中控制的图片片段着色器
NSString *const kTPImagePicturePassthroughFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 uniform sampler2D inputImageTexture;
 void main()
 {
     gl_FragColor = texture2D(inputImageTexture, vec2(textureCoordinate.x,1.0-textureCoordinate.y));
 }
 );

// FullRange YUV转RGB片段着色器
NSString *const kTPImageYUVFullRangeConversionForLAFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D luminanceTexture;
 uniform sampler2D chrominanceTexture;
 uniform mediump mat3 colorConversionMatrix;
 
 void main()
 {
     mediump vec3 yuv;
     lowp vec3 rgb;
     
     yuv.x = texture2D(luminanceTexture, textureCoordinate).r;
     yuv.yz = texture2D(chrominanceTexture, textureCoordinate).ra - vec2(0.5, 0.5);
     rgb = colorConversionMatrix * yuv;
     
     gl_FragColor = vec4(rgb, 1);
 }
);

// YUV转RGB片段着色器
NSString *const kTPImageYUVVideoRangeConversionForRGFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D luminanceTexture;
 uniform sampler2D chrominanceTexture;
 uniform mediump mat3 colorConversionMatrix;
 
 void main()
 {
     mediump vec3 yuv;
     lowp vec3 rgb;
     
     yuv.x = texture2D(luminanceTexture, textureCoordinate).r;
     yuv.yz = texture2D(chrominanceTexture, textureCoordinate).rg - vec2(0.5, 0.5);
     rgb = colorConversionMatrix * yuv;
     
     gl_FragColor = vec4(rgb, 1);
 }
);
