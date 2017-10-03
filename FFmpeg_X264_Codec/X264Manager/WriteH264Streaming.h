//
//  WriteH264Streaming.h
//  FFmpeg_X264_Codec
//
//  Created by suntongmian on 2017/10/1.
//  Copyright © 2017年 suntongmian@163.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "H264OutputProtocol.h"
#ifdef __cplusplus
extern "C" {
#endif
#include <libavutil/opt.h>
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libswscale/swscale.h>
#ifdef __cplusplus
};
#endif

@interface WriteH264Streaming : NSObject  <H264OutputProtocol>

@property (strong, nonatomic) NSString *filePath;

- (void)writeFrame:(AVPacket)packet streamIndex:(NSInteger)streamIndex;

@end
