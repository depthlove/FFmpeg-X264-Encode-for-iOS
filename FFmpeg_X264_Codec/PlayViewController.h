//
//  PlayViewController.h
//  FFmpeg_X264_Codec
//
//  Created by suntongmian on 2017/9/30.
//  Copyright © 2017年 suntongmian@163.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "VideoConfiguration.h"

@interface PlayViewController : UIViewController

@property (strong, nonatomic) NSString *h264FilePath;
@property (strong, nonatomic) VideoConfiguration *videoConfiguration;

@end
