//
//  VideoConfiguration.m
//  FFmpeg_X264_Codec
//
//  Created by suntongmian on 2017/10/1.
//  Copyright © 2017年 suntongmian@163.com. All rights reserved.
//

#import "VideoConfiguration.h"

@implementation VideoConfiguration

+ (instancetype)defaultConfiguration {
    VideoConfiguration *videoConfiguration = [[VideoConfiguration alloc] initWithVideoSize:CGSizeMake(720, 1280) frameRate:30 maxKeyframeInterval:60 bitrate:1536*1000 profileLevel:@""];
    return videoConfiguration;
}

- (instancetype)initWithVideoSize:(CGSize)videoSize
                        frameRate:(NSUInteger)frameRate
              maxKeyframeInterval:(CGFloat)maxKeyframeInterval
                          bitrate:(NSUInteger)bitrate
                     profileLevel:(NSString *)profileLevel {
    self = [super init];
    if (self) {
        _videoSize = videoSize;
        _frameRate = frameRate;
        _maxKeyframeInterval = maxKeyframeInterval;
        _bitrate = bitrate;
        _profileLevel = profileLevel;
    }
    
    return self;
}

@end
