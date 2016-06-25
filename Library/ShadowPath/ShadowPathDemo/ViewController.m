//
//  ViewController.m
//  ShadowPathDemo
//
//  Created by LEI on 5/17/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

#import "ViewController.h"
#import "ShadowPath.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
//    char *path = strdup([[[NSBundle mainBundle] pathForResource:@"config" ofType:@""] UTF8String]);
//    shadowpath_main(path);
    profile_t t;
    start_ss_local_server(t);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
