//
//  TPImageModel.m
//  TPImage
//
//  Created by 张清泉 on 2019/10/12.
//  Copyright © 2019 Tapai. All rights reserved.
//

#import "TPImageModel.h"
#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>

@interface TPImageModel ()
@property (nonatomic, copy) NSString *imagePath;
@end

@implementation TPImageModel

@synthesize w = _w;
@synthesize h = _h;
@synthesize imageTexture = _imageTexture;

- (instancetype)initWithImageData:(NSString *)imagePath {
    if (!(self = [super init])) {
        return nil;
    }
    self.imagePath = imagePath;
    [self imageEncoder];
    return self;
}

- (void)imageEncoder {
    //获取纹理图片
    CGImageRef cgImgRef = [UIImage imageWithContentsOfFile:self.imagePath].CGImage;
    if (!cgImgRef) {
        NSLog(@"AE 图片不存在");
    }
    //获取图片长、宽
    size_t wd = CGImageGetWidth(cgImgRef);
    size_t ht = CGImageGetHeight(cgImgRef);
    void *imageData = malloc(wd * ht * 4);
    CGContextRef contextRef = CGBitmapContextCreate(imageData, wd, ht, 8, wd * 4, CGImageGetColorSpace(cgImgRef), kCGImageAlphaPremultipliedLast);
    
    //长宽转成float 方便下面方法使用
    _w = (int)wd;
    _h = (int)ht;
    CGRect rect = CGRectMake(0, 0, wd, ht);
    CGContextDrawImage(contextRef, rect, cgImgRef);
    
    glGenTextures(1, &_imageTexture);
    glBindTexture(GL_TEXTURE_2D, _imageTexture);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    // 线性过滤：使用距离当前渲染像素中心最近的4个纹理像素加权平均值
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    
    // 将图像数据传递给 GL_TEXTURE_2D
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, _w, _h, 0, GL_RGBA, GL_UNSIGNED_BYTE, imageData);
    
    //图片绘制完成后，contextRef就没用了，释放
    CGContextRelease(contextRef);
}

#pragma mark --------- Getter方法
- (GLuint)imageTexture {
    return _imageTexture;
}

- (int)w {
    return _w;
}

- (int)h {
    return _h;
}
@end
