//
//  TPImageUtils.h
//  TPImage
//
//  Created by 张清泉 on 2019/10/10.
//  Copyright © 2019 Tapai. All rights reserved.
//
#import <Foundation/Foundation.h>
#import "TPImageConstShaderString.h"

#ifndef TPImageUtils_h
#define TPImageUtils_h


#define TPImageUtilsBundle [[NSBundle mainBundle] bundlePath]

// 顶点坐标
static const GLfloat imageVertices[] = {
    -1.0f, -1.0f,  // 左下
    1.0f, -1.0f,   // 右下
    -1.0f,  1.0f,  // 左上
    1.0f,  1.0f,   // 右上
};

// 纹理坐标
static const GLfloat textureCoordinates[] = {
    0.0f, 0.0f,  // 左下
    1.0f, 0.0f,  // 右下
    0.0f, 1.0f,  // 左上
    1.0f, 1.0f,  // 右上
};

/**
   以下三个是颜色转换常量 （YUV to RGB）包括调整自 16-235/16-240 (video range)
*/
//编辑顶点坐标源数组
static const GLfloat vertexData_src[30] = {
    
    1.0, -1.0, 0.0f,    1.0f, 0.0f, //右下
    1.0, 1.0, -0.0f,    1.0f, 1.0f, //右上
    -1.0, 1.0, 0.0f,    0.0f, 1.0f, //左上
    
    1.0, -1.0, 0.0f,    1.0f, 0.0f, //右下
    -1.0, 1.0, 0.0f,    0.0f, 1.0f, //左上
    -1.0, -1.0, 0.0f,   0.0f, 0.0f, //左下
};

// BT.601, 是 SDTV.YUV422 的标准
static const GLfloat kColorConversion601Default[] = {
    1.164,  1.164, 1.164,
    0.0, -0.392, 2.017,
    1.596, -0.813,   0.0,
};

// BT.601 full range YUV422
static const GLfloat kColorConversion601FullRangeDefault[] = {
    1.0,    1.0,    1.0,
    0.0,    -0.343, 1.765,
    1.4,    -0.711, 0.0,
};

// BT.709, 是 HDTV.YUV420 的标准
static const GLfloat kColorConversion709Default[] = {
    1.164,  1.164, 1.164,
    0.0, -0.213, 2.112,
    1.793, -0.533,   0.0,
};


#endif
