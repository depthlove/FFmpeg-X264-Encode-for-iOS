//
//  VideoConfiguration.h
//  FFmpeg_X264_Codec
//
//  Created by suntongmian on 2017/10/1.
//  Copyright © 2017年 suntongmian@163.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface VideoConfiguration : NSObject

@property (assign, nonatomic) CGSize videoSize;
@property (assign, nonatomic) CGFloat frameRate;
@property (assign, nonatomic) CGFloat maxKeyframeInterval;
@property (assign, nonatomic) CGFloat bitrate;
@property (strong, nonatomic) NSString *profileLevel;

+ (instancetype)defaultConfiguration;

- (instancetype)initWithVideoSize:(CGSize)videoSize
                        frameRate:(NSUInteger)frameRate
              maxKeyframeInterval:(CGFloat)maxKeyframeInterval
                          bitrate:(NSUInteger)bitrate
                     profileLevel:(NSString *)profileLevel;

@end
