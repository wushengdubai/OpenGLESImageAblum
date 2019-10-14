//
//  TPProgram.h
//  TPImage
//
//  Created by 张清泉 on 2019/10/10.
//  Copyright © 2019 Tapai. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenGLES/ES3/gl.h>
//#import <OpenGLES/ES3/glext.h>

NS_ASSUME_NONNULL_BEGIN

@interface TPProgram : NSObject

/** 是否初始化 */
@property(assign, nonatomic) BOOL initialized;
@property(readwrite, copy, nonatomic) NSString *vertexShaderLog;
@property(readwrite, copy, nonatomic) NSString *fragmentShaderLog;
@property(readwrite, copy, nonatomic) NSString *programLog;

- (instancetype)initWithVertexShaderString:(NSString *)vShaderString
            fragmentShaderString:(NSString *)fShaderString;
- (instancetype)initWithVertexShaderString:(NSString *)vShaderString
          fragmentShaderFilename:(NSString *)fShaderFilename;
- (instancetype)initWithVertexShaderFilename:(NSString *)vShaderFilename
            fragmentShaderFilename:(NSString *)fShaderFilename;

- (GLuint)attributeIndex:(NSString *)attributeName;
- (GLuint)uniformIndex:(NSString *)uniformName;

- (BOOL)link;
- (void)use;

// 设置着色器传入的Uniform属性
- (void)setInt:(int)value name:(GLint)nameID;
- (void)setMatrix3:(GLfloat *)value name:(GLint)nameID;

@end

NS_ASSUME_NONNULL_END
