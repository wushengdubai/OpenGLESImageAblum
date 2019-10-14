//
//  TPImageFilter.m
//  TPImage
//
//  Created by 张清泉 on 2019/10/10.
//  Copyright © 2019 Tapai. All rights reserved.
//

#import "TPImageFilter.h"
#import "TPImageContext.h"
#import "TPImageModel.h"
#import "TPImageConstShaderString.h"
#import "TPImageUtils.h"

@interface TPImageFilter ()
{
    AEConfigEntity *configEntity;
    AEConfigEntity *camera_configEntity;
    CGSize mySize;

    float cameraX;
    float cameraY;
    float cameraZ;

    float _aspectRatio;
    // 投影矩阵的属性
    float _perspective_left;
    float _perspective_right;
    float _perspective_bottom;
    float _perspective_top;
    float _perspective_near;
    float _perspective_far;
    // 屏幕和
    float _screen_ratio;
    ParseAE parseAE;
    
    // 顶点坐标，纹理坐标
    GLint filterPositionAttribute,filterTextureCoordinateAttribute;
    // uniform纹理
    GLint filterInputTextureUniform;
    // 观察矩阵
    GLint modelViewMartix_S;
    
    TPImageModel *_imageAsset[512];
}

@property (nonatomic, strong) TPProgram *program;
// 输出的FBO
@property (nonatomic, strong) TPImageFramebuffer *outputFramebuffer;

@property (nonatomic, strong) NSMutableArray *imageModelArray;

@end

@implementation TPImageFilter

- (instancetype)initSize:(CGSize)size ae:(AEConfigEntity &)aeConfig camera:(AEConfigEntity &)cameraConfig withFileName:(NSString *)fileName {
    if (!(self = [super init])) {
        return nil;
    }
    self.resourceName = fileName;
    configEntity = &aeConfig;
    camera_configEntity = &cameraConfig;
    mySize = size;
    
    [self initAEData];
    
    runSyncOnVideoProcessingQueue(^{
        [TPImageContext useImageProcessingContext];
        // 初始化program
        [self configProgram];
        
        // 创建初始的frameBuffer
        if (!self.outputFramebuffer) {
            self.outputFramebuffer = [[TPImageFramebuffer alloc] initWithSize:size];
        }
        
        [self proccessAEImage];
    });
    return self;
}

- (void)initAEData {
    if (configEntity->ddd == 1) { // 初始化Camera位置
        AELayerEntity layer = camera_configEntity->layers[0];
        cameraX = layer.ks.a.k_float[0]-layer.ks.p.k_float[0];
        cameraY = layer.ks.a.k_float[1]-layer.ks.p.k_float[1];
        cameraZ = layer.ks.a.k_float[2]-layer.ks.p.k_float[2];
    }
    
    self.texture_size = mySize;
    _aspectRatio = mySize.height/mySize.width;
    _perspective_left = -1;
    _perspective_right = 1;
    _perspective_bottom = -_aspectRatio;
    _perspective_top = _aspectRatio;
    _perspective_near = 0.1f;
    _perspective_far = 100.0f;
    _screen_ratio = mySize.width/configEntity->w;
}

// 配置program
- (void)configProgram {
    self.program = [[TPProgram alloc] initWithVertexShaderString:kTPImagePictureVertexShaderString fragmentShaderString:kTPImagePicturePassthroughFragmentShaderString];
    if (![self.program link]) {
        NSLog(@"program get something wrong");
    }
    //从program中获取属性位置
    self->filterPositionAttribute = [self.program attributeIndex:@"position"];
    //从program中获取textCoordinate 纹理属性
    self->filterTextureCoordinateAttribute = [self.program attributeIndex:@"inputTextureCoordinate"];
    self->filterInputTextureUniform = [self.program uniformIndex:@"inputImageTexture"];
    self->modelViewMartix_S = [self.program uniformIndex:@"modelViewMatrix"];
    
    glEnableVertexAttribArray(self->filterPositionAttribute);
    glEnableVertexAttribArray(self->filterTextureCoordinateAttribute);
}

// 处理AE images
- (void)proccessAEImage {
    self.imageModelArray = [NSMutableArray array];
    
    NSString *resourcePath = [TPImageUtilsBundle stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/images",self.resourceName]];
    
    // 处理AE image
    for (int i = 0; i < configEntity->assets_num; i++) {
        NSString *imgPath = [resourcePath stringByAppendingPathComponent:[NSString stringWithFormat:@"img_%d.png",i]];
        TPImageModel *imageModel = [[TPImageModel alloc] initWithImageData:imgPath];
        imageModel.index = i;
        [self.imageModelArray addObject:imageModel];
    }
    
    // 处理AE_Layer
    for (int i = 0; i < configEntity->layers_num; i++) {
        AELayerEntity &tmpEntity = configEntity->layers[i];
        int tmpAsset_index = parseAE.asset_index_refId(tmpEntity.refId, *configEntity);
        AEAssetEntity tmpAsset = configEntity->assets[tmpAsset_index];
        tmpEntity.layer_w = tmpAsset.w;
        tmpEntity.layer_h = tmpAsset.h;
        tmpEntity.asset_index = tmpAsset_index;
    }
}

#pragma mark ---------公有方法
- (GLuint)imageTexture {
    return self.outputFramebuffer.texture;
}

- (void)renderToTexture:(int)fr {
    runSyncOnVideoProcessingQueue(^{
        [TPImageContext useImageProcessingContext];
        [self.outputFramebuffer activateFramebuffer];
        
        //设置背景色
        glClearColor(1.0f, 1.0f, 1.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        //开启正背面剔除
        glEnable(GL_DEPTH_TEST);
        //开启颜色混合
        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        
    });
}
@end
