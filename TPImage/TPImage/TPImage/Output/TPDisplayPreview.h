//
//  TPDisplayPreview.h
//  TPImage
//
//  Created by 张清泉 on 2019/10/10.
//  Copyright © 2019 Tapai. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface TPDisplayPreview : UIView
/** 资源name */
@property (nonatomic, copy) NSString *resourceName;
/** 考虑到Retina屏幕，重新计算当前显示的尺寸 */
@property (nonatomic, assign, readonly) CGSize sizeInPixels;

- (instancetype)initWithFrame:(CGRect)frame withResourceName:(NSString *)fileName;


/** 开始播放 */
- (void)startPlay;

/** 结束播放 */
- (void)stopPlay;

/** 暂停 */
- (void)pause;
/** 继续 */
- (void)resume;

/** 跳转进度 */
- (void)seekToPercent:(CGFloat)percent;

/** 切换资源名字 */
- (void)resetResourceName:(NSString *)name;
@end

NS_ASSUME_NONNULL_END
