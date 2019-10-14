//
//  TPProgram.m
//  TPImage
//
//  Created by 张清泉 on 2019/10/10.
//  Copyright © 2019 Tapai. All rights reserved.
//

#import "TPProgram.h"

@interface TPProgram ()
{
    GLuint          program,
    vertShader,
    fragShader;
}

@end

@implementation TPProgram
#pragma mark ---------自定义初始化方法
- (instancetype)initWithVertexShaderString:(NSString *)vShaderString fragmentShaderString:(NSString *)fShaderString {
    if (self = [super init]) {
        _initialized = NO;
        
        program = glCreateProgram();
        
        if (![self compileShader:&vertShader type:GL_VERTEX_SHADER string:vShaderString]) {
            NSLog(@"Failed to compile vertex shader");
        }
        
        if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER string:fShaderString]) {
            NSLog(@"Failed to compile fragment shader");
        }
        
        glAttachShader(program, vertShader);
        glAttachShader(program, fragShader);
    }
    return self;
}

- (instancetype)initWithVertexShaderString:(NSString *)vShaderString fragmentShaderFilename:(NSString *)fShaderFilename {
    
    NSString *fragShaderPathname = [[NSBundle mainBundle] pathForResource:fShaderFilename ofType:@"fsh"];
    NSString *fragmentShaderString = [NSString stringWithContentsOfFile:fragShaderPathname encoding:NSUTF8StringEncoding error:nil];
    if (self = [self initWithVertexShaderString:vShaderString fragmentShaderString:fragmentShaderString]) {
    }
    return self;
}

- (instancetype)initWithVertexShaderFilename:(NSString *)vShaderFilename fragmentShaderFilename:(NSString *)fShaderFilename {
    
    NSString *vertShaderPathname = [[NSBundle mainBundle] pathForResource:vShaderFilename ofType:@"vsh"];
    NSString *vertexShaderString = [NSString stringWithContentsOfFile:vertShaderPathname encoding:NSUTF8StringEncoding error:nil];

    NSString *fragShaderPathname = [[NSBundle mainBundle] pathForResource:fShaderFilename ofType:@"fsh"];
    NSString *fragmentShaderString = [NSString stringWithContentsOfFile:fragShaderPathname encoding:NSUTF8StringEncoding error:nil];
    
    if (self = [self initWithVertexShaderString:vertexShaderString fragmentShaderString:fragmentShaderString]) {
    }
    return self;
}

- (void)dealloc {
    if (vertShader)
        glDeleteShader(vertShader);
        
    if (fragShader)
        glDeleteShader(fragShader);
    
    if (program)
        glDeleteProgram(program);
}

#pragma mark ---------私有方法
- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type string:(NSString *)shaderString {
    GLint status;
    const GLchar *source;
        
    source = (GLchar *)[shaderString UTF8String];
    if (!source) {
        NSAssert(NO, @"Failed to load vertex shader");
        return NO;
    }
        
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);
    
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);

    if (status != GL_TRUE) {
        GLint logLength;
        glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
        if (logLength > 0) {
            GLchar *log = (GLchar *)malloc(logLength);
            glGetShaderInfoLog(*shader, logLength, &logLength, log);
            if (shader == &vertShader) {
                self.vertexShaderLog = [NSString stringWithFormat:@"%s", log];
                NSAssert(NO, self.vertexShaderLog);
            } else {
                self.fragmentShaderLog = [NSString stringWithFormat:@"%s", log];
                NSAssert(NO, self.fragmentShaderLog);
                
            }
            free(log);
        }
    }
    return status == GL_TRUE;
}

#pragma mark ---------公有方法
- (BOOL)link {
    GLint status;
        
    glLinkProgram(program);
    
    glGetProgramiv(program, GL_LINK_STATUS, &status);
    if (status == GL_FALSE)
        return NO;
    
    if (vertShader) {
        glDeleteShader(vertShader);
        vertShader = 0;
    }
    if (fragShader) {
        glDeleteShader(fragShader);
        fragShader = 0;
    }
    
    self.initialized = YES;

    return YES;
}

- (void)use {
    glUseProgram(program);
}

#pragma mark ---------设置着色器Uniform属性
- (GLuint)attributeIndex:(NSString *)attributeName {
    return glGetAttribLocation(program, [attributeName UTF8String]);
}

- (GLuint)uniformIndex:(NSString *)uniformName {
    return glGetUniformLocation(program, [uniformName UTF8String]);
}

- (void)setInt:(int)value name:(GLint)nameID {
    glUniform1i(nameID, value);
}

- (void)setMatrix3:(GLfloat *)value name:(GLint)nameID {
    glUniformMatrix3fv(nameID, 1, GL_FALSE, value);
}
@end
