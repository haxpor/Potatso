//
//  HMScannerViewController.m
//  HMQRCodeScanner
//
//  Created by 刘凡 on 16/1/2.
//  Copyright © 2016年 itheima. All rights reserved.
//

#import "HMScannerViewController.h"
#import "HMScannerBorder.h"
#import "HMScannerMaskView.h"
#import "HMScanner.h"
#import "Potatso-Swift.h"
@import PotatsoLibrary;

/// 控件间距
#define kControlMargin  32.0

@interface HMScannerViewController () <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
/// 完成回调
@property (nonatomic, copy) void (^completionCallBack)(NSString *);
@end

@implementation HMScannerViewController {
    /// 扫描框
    HMScannerBorder *scannerBorder;
    /// 扫描器
    HMScanner *scanner;
}

- (instancetype)initWithCompletion:(void (^)(NSString *))completion {
    self = [super init];
    if (self) {
        self.completionCallBack = completion;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self prepareUI];
    
    // 实例化扫描器
    __weak typeof(self) weakSelf = self;
    scanner = [HMScanner scanerWithView:self.view scanFrame:scannerBorder.frame completion:^(NSString *stringValue) {
        // 关闭
        [weakSelf clickCloseButton];
        // 完成回调
        weakSelf.completionCallBack(stringValue);
    }];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [scannerBorder startScannerAnimating];
    [scanner startScan];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [scannerBorder stopScannerAnimating];
    [scanner stopScan];
}

#pragma mark - 监听方法
/// 点击关闭按钮
- (void)clickCloseButton {
    [self.navigationController popViewControllerAnimated:true];
}

/// 点击相册按钮
- (void)clickAlbumButton {
    
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
        [self showTextHUD:NSLocalizedString(@"qrcode.denied", nil) dismissAfterDelay:1.0f];
        return;
    }
    
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    
    picker.view.backgroundColor = [UIColor whiteColor];
    picker.delegate = self;
    
    [self showDetailViewController:picker sender:nil];
}


#pragma mark - UIImagePickerControllerDelegate
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    
    // 扫描图像
    [HMScanner scaneImage:info[UIImagePickerControllerOriginalImage] completion:^(NSArray *values) {
        
        if (values.count > 0) {
            self.completionCallBack(values.firstObject);
            [self dismissViewControllerAnimated:NO completion:^{
                [self clickCloseButton];
            }];
        } else {
            [self showTextHUD:NSLocalizedString(@"qrcode.nocode", nil) dismissAfterDelay:1.0f];

            [self dismissViewControllerAnimated:YES completion:nil];
        }
    }];
}

#pragma mark - 设置界面
- (void)prepareUI {
    self.view.backgroundColor = [UIColor darkGrayColor];
    
    [self prepareNavigationBar];
    [self prepareScanerBorder];
}


/// 准备扫描框
- (void)prepareScanerBorder {
    
    CGFloat width = self.view.bounds.size.width - 80;
    scannerBorder = [[HMScannerBorder alloc] initWithFrame:CGRectMake(0, 0, width, width)];
    
    scannerBorder.center = CGPointMake(self.view.center.x, self.view.center.y - 60);
    scannerBorder.tintColor = self.navigationController.navigationBar.tintColor;
    
    [self.view addSubview:scannerBorder];
    
    HMScannerMaskView *maskView = [HMScannerMaskView maskViewWithFrame:self.view.bounds cropRect:scannerBorder.frame];
    [self.view insertSubview:maskView atIndex:0];
}

/// 准备导航栏
- (void)prepareNavigationBar {
    // 1> 背景颜色
//    [self.navigationController.navigationBar setBarTintColor:[UIColor colorWithWhite:0.1 alpha:1.0]];
//    self.navigationController.navigationBar.translucent = YES;
//    self.navigationController.navigationBar.shadowImage = [[UIImage alloc] init];
    
    // 2> 标题
    self.title = NSLocalizedString(@"qrcode.title", nil);
    
    // 3> 左右按钮
//    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"关闭" style:UIBarButtonItemStylePlain target:self action:@selector(clickCloseButton)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"qrcode.album", nil) style:UIBarButtonItemStylePlain target:self action:@selector(clickAlbumButton)];
}

@end
