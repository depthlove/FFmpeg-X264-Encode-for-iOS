//
//  X264Encoder.h
//  FFmpeg_X264_Codec
//
//  Created by suntongmian on 2017/10/1.
//  Copyright © 2017年 suntongmian@163.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "VideoConfiguration.h"
#import "H264OutputProtocol.h"

@interface X264Encoder : NSObject <H264OutputProtocol>

@property (nonatomic, strong) id<H264OutputProtocol> outputObject;

- (instancetype)initWithVideoConfiguration:(VideoConfiguration *)videoConfiguration;

- (void)encoding:(CVPixelBufferRef)pixelBuffer timestamp:(CGFloat)timestamp;

- (void)teardown;

@end
