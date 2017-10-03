//
//  X264Encoder.m
//  FFmpeg_X264_Codec
//
//  Created by suntongmian on 2017/10/1.
//  Copyright © 2017年 suntongmian@163.com. All rights reserved.
//

#import "X264Encoder.h"
#import "WriteH264Streaming.h"

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

@interface X264Encoder ()

@property (strong, nonatomic) VideoConfiguration *videoConfiguration;

@end

@implementation X264Encoder
{
    AVCodecContext                      *pCodecCtx;
    AVCodec                             *pCodec;
    AVPacket                             packet;
    AVFrame                             *pFrame;
    int                                  pictureSize;
    int                                  frameCounter;
    int                                  frameWidth; // 编码的图像宽度
    int                                  frameHeight; // 编码的图像高度
}

- (instancetype)initWithVideoConfiguration:(VideoConfiguration *)videoConfiguration {
    self = [super init];
    if (self) {
        self.videoConfiguration = videoConfiguration;
        [self setupEncoder];
    }
    return self;
}

- (void)setupEncoder {
    avcodec_register_all(); // 注册FFmpeg所有编解码器
    
    frameCounter = 0;
    frameWidth = self.videoConfiguration.videoSize.width;
    frameHeight = self.videoConfiguration.videoSize.height;
    // Param that must set
    pCodecCtx = avcodec_alloc_context3(pCodec);
    pCodecCtx->codec_id = AV_CODEC_ID_H264;
    pCodecCtx->codec_type = AVMEDIA_TYPE_VIDEO;
    pCodecCtx->pix_fmt = PIX_FMT_YUV420P;
    pCodecCtx->width = frameWidth;
    pCodecCtx->height = frameHeight;
    pCodecCtx->time_base.num = 1;
    pCodecCtx->time_base.den = self.videoConfiguration.frameRate;
    pCodecCtx->bit_rate = self.videoConfiguration.bitrate;
    pCodecCtx->gop_size = self.videoConfiguration.maxKeyframeInterval;
    pCodecCtx->qmin = 10;
    pCodecCtx->qmax = 51;
//    pCodecCtx->me_range = 16;
//    pCodecCtx->max_qdiff = 4;
//    pCodecCtx->qcompress = 0.6;
    // Optional Param
//    pCodecCtx->max_b_frames = 3;
    
    // Set Option
    AVDictionary *param = NULL;
    if(pCodecCtx->codec_id == AV_CODEC_ID_H264) {
        av_dict_set(&param, "preset", "slow", 0);
        av_dict_set(&param, "tune", "zerolatency", 0);
//        av_dict_set(&param, "profile", "main", 0);
    }
    
    pCodec = avcodec_find_encoder(pCodecCtx->codec_id);
    if (!pCodec) {
        NSLog(@"Can not find encoder!");
    }
    
    if (avcodec_open2(pCodecCtx, pCodec, &param) < 0) {
        NSLog(@"Failed to open encoder!");
    }
    
    pFrame = av_frame_alloc();
    pFrame->width = frameWidth;
    pFrame->height = frameHeight;
    pFrame->format = PIX_FMT_YUV420P;

    avpicture_fill((AVPicture *)pFrame, NULL, pCodecCtx->pix_fmt, pCodecCtx->width, pCodecCtx->height);
    
    pictureSize = avpicture_get_size(pCodecCtx->pix_fmt, pCodecCtx->width, pCodecCtx->height);
    av_new_packet(&packet, pictureSize);
}

- (void)encoding:(CVPixelBufferRef)pixelBuffer timestamp:(CGFloat)timestamp {
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
//    int pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
//    switch (pixelFormat) {
//        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
//            NSLog(@"pixel format NV12");
//            break;
//        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
//            NSLog(@"pixel format NV12");
//            break;
//        case kCVPixelFormatType_32BGRA:
//            NSLog(@"pixel format 32BGRA");
//            break;
//        default:
//            NSLog(@"pixel format unknown");
//            break;
//    }
    
    UInt8 *pY = (UInt8 *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    UInt8 *pUV = (UInt8 *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    size_t pYBytes = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
    size_t pUVBytes = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);
    
    UInt8 *pYUV420P = (UInt8 *)malloc(width * height * 3 / 2); // buffer to store YUV with layout YYYYYYYYUUVV
    
    /* convert NV12 data to YUV420*/
    UInt8 *pU = pYUV420P + (width * height);
    UInt8 *pV = pU + (width * height / 4);
    for(int i = 0; i < height; i++) {
        memcpy(pYUV420P + i * width, pY + i * pYBytes, width);
    }
    for(int j = 0; j < height / 2; j++) {
        for(int i = 0; i < width / 2; i++) {
            *(pU++) = pUV[i<<1];
            *(pV++) = pUV[(i<<1) + 1];
        }
        pUV += pUVBytes;
    }
    
    // add code to push pYUV420P to video encoder here
    
    // scale
    // add code to scale image here
    // ...
    
    //Read raw YUV data
    pFrame->data[0] = pYUV420P;                                // Y
    pFrame->data[1] = pFrame->data[0] + width * height;        // U
    pFrame->data[2] = pFrame->data[1] + (width * height) / 4;  // V
    // PTS
    pFrame->pts = frameCounter;
    // Encode
    int got_picture = 0;
    if (!pCodecCtx) {
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        return;
    }
    int ret = avcodec_encode_video2(pCodecCtx, &packet, pFrame, &got_picture);
    if(ret < 0) {
        NSLog(@"Failed to encode!");
    }
    if (got_picture == 1) {
        NSLog(@"Succeed to encode frame: %5d\tsize:%5d", frameCounter, packet.size);
        frameCounter++;
        
        WriteH264Streaming *writeH264Streaming = self.outputObject;
        [writeH264Streaming writeFrame:packet streamIndex:packet.stream_index];
        
        av_free_packet(&packet);
    }
    
    free(pYUV420P);
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
}

- (void)teardown {
    WriteH264Streaming *writeH264Streaming = self.outputObject;
    writeH264Streaming = nil;
    
    avcodec_close(pCodecCtx);
    av_free(pFrame);
    pCodecCtx = NULL;
    pFrame = NULL;
}

#pragma mark -- H264OutputProtocol
- (void)setOutput:(id<H264OutputProtocol>)output {
    self.outputObject = output;
}

- (void)dealloc {
    
}

@end
