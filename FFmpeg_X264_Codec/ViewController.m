//
//  ViewController.m
//  FFmpeg_X264_Codec
//
//  Created by sunminmin on 15/9/7.
//  Copyright (c) 2015年 suntongmian@163.com. All rights reserved.
//

#import "ViewController.h"
#import "RecordViewController.h"

@interface ViewController () 

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    UIButton *recordButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 62, 62)];
    recordButton.center = CGPointMake(CGRectGetWidth([UIScreen mainScreen].bounds) / 2, CGRectGetHeight([UIScreen mainScreen].bounds) / 2);
    recordButton.backgroundColor = [UIColor redColor];
    recordButton.layer.cornerRadius = 31;
    recordButton.layer.borderWidth = 2;
    recordButton.layer.borderColor = [UIColor grayColor].CGColor;
    [self.view addSubview:recordButton];
    [recordButton addTarget:self action:@selector(pressRecordButton:) forControlEvents:UIControlEventTouchUpInside];
    
    UILabel *recordLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 100, 44)];
    recordLabel.text = @"录制H264";
    recordLabel.textAlignment = NSTextAlignmentCenter;
    recordLabel.textColor = [UIColor grayColor];
    recordLabel.center = CGPointMake(recordButton.center.x, recordButton.center.y + 44);
    [self.view addSubview:recordLabel];
}

- (void)pressRecordButton:(id)sender {
    RecordViewController *recordViewController = [[RecordViewController alloc] init];
    [self presentViewController:recordViewController animated:YES completion:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
