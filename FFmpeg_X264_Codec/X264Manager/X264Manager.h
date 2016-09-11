//
//  X264Manager.h
//  FFmpeg_X264_Codec
//
//  Created by sunminmin on 15/9/7.
//  Copyright (c) 2015年 suntongmian@163.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

@interface X264Manager : NSObject

/*
 * 设置编码后文件的保存路径
 */
- (void)setFileSavedPath:(NSString *)path;

/*
 * 设置X264
 * 0: 成功； －1: 失败
 */
- (int)setX264ResourceWithVideoWidth:(int)width height:(int)height;

/*
 * 将CMSampleBufferRef格式的数据编码成h264并写入文件
 */
- (void)encoderToH264:(CMSampleBufferRef)sampleBuffer;

/*
 * 释放资源
 */
- (void)freeX264Resource;


@end
