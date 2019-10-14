//
//  TPImageTestView.h
//  TPImage
//
//  Created by 张清泉 on 2019/10/14.
//  Copyright © 2019 Tapai. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface TPImageTestView : UIView

/** 考虑到Retina屏幕，重新计算当前显示的尺寸 */
@property (nonatomic, assign, readonly) CGSize sizeInPixels;

@end

NS_ASSUME_NONNULL_END
