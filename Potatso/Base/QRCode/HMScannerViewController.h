//
//  HMScannerViewController.h
//  HMQRCodeScanner
//
//  Created by 刘凡 on 16/1/2.
//  Copyright © 2016年 itheima. All rights reserved.
//

#import <UIKit/UIKit.h>

/// 扫描控制器
@interface HMScannerViewController : UIViewController

/// 实例化扫描控制器
///
/// @param completion 完成回调
///
/// @return 扫描控制器
- (instancetype)initWithCompletion:(void (^)(NSString *))completion;

@end
