//
//  H264OutputProtocol.h
//  FFmpeg_X264_Codec
//
//  Created by suntongmian on 2017/10/1.
//  Copyright © 2017年 suntongmian@163.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol H264OutputProtocol <NSObject>

- (void)setOutput:(id<H264OutputProtocol>)output;
//- (void)pushBuffer:(void *)object;

@end
