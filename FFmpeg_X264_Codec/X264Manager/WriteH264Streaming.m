//
//  WriteH264Streaming.m
//  FFmpeg_X264_Codec
//
//  Created by suntongmian on 2017/10/1.
//  Copyright © 2017年 suntongmian@163.com. All rights reserved.
//

#import "WriteH264Streaming.h"

@implementation WriteH264Streaming
{
    char *out_file;
    FILE *pFile;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.filePath = [self savedFilePath];
        [self setFileSavedPath:self.filePath];
    }
    return self;
}

/*
 * 设置编码后文件的文件名，保存路径
 */
- (void)setFileSavedPath:(NSString *)path; {
    char *filePath = (char *)[path UTF8String];
    pFile = fopen(filePath, "wb");
    NSLog(@"%s", filePath);
}

// 文件保存路径
- (NSString *)savedFilePath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask,YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    NSString *fileName = [self savedFileName];
    
    NSString *writablePath = [documentsDirectory stringByAppendingPathComponent:fileName];
    
    return writablePath;
}

// 拼接文件名
- (NSString *)savedFileName {
    return [[self nowTime2String] stringByAppendingString:@".h264"];
}

// 获取系统当前时间
- (NSString* )nowTime2String {
    NSString *date = nil;
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"YYYY-MM-dd-hh-mm-ss";
    date = [formatter stringFromDate:[NSDate date]];
    
    return date;
}

// 写视频帧
- (void)writeFrame:(AVPacket)packet streamIndex:(NSInteger)streamIndex {
    // 将编码数据写入文件
    fwrite(packet.data, packet.size, 1, pFile);
    fflush(pFile);
}

#pragma mark -- H264OutputProtocol
- (void)setOutput:(id<H264OutputProtocol>)output {

}

- (void)dealloc {
    fclose(pFile);
    pFile = NULL;
    
    NSLog(@"-- WriteH264Streaming dealloc --");
}

@end
