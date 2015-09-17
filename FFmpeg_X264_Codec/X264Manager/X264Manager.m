//
//  X264Manager.m
//  FFmpeg_X264_Codec
//
//  Created by sunminmin on 15/9/7.
//  Copyright (c) 2015年 suntongmian@163.com. All rights reserved.
//

#import "X264Manager.h"

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


@implementation X264Manager
{
    AVFormatContext                     *pFormatCtx;
    AVOutputFormat                      *fmt;
    AVStream                            *video_st;
    AVCodecContext                      *pCodecCtx;
    AVCodec                             *pCodec;
    AVPacket                             pkt;
    uint8_t                             *picture_buf;
    AVFrame                             *pFrame;
    int                                  picture_size;
    int                                  y_size;
    int                                  framecnt;
    char                                *out_file;
    
    int                                  encoder_h264_frame_width; // 编码的图像宽度
    int                                  encoder_h264_frame_height; // 编码的图像高度
}



/*
 * 设置编码后文件的文件名，保存路径
 */
- (void)setFileSavedPath:(NSString *)path;
{
    out_file = [self nsstring2char:path];
}

- (char*)nsstring2char:(NSString *)path
{

    NSUInteger len = [path length];
    char *filepath = (char*)malloc(sizeof(char) * (len + 1));
    
    [path getCString:filepath maxLength:len + 1 encoding:[NSString defaultCStringEncoding]];
    
    return filepath;
}


/*
 *  设置X264
 */
- (int)setX264Resource
{
    framecnt = 0;
    
    // AVCaptureSessionPresetMedium
    encoder_h264_frame_width = 480;
    encoder_h264_frame_height = 360;

    // AVCaptureSessionPresetHigh
//    encoder_h264_frame_width = 1920;
//    encoder_h264_frame_height = 1080;
    
    av_register_all(); // 注册FFmpeg所有编解码器
    
    //Method1.
    pFormatCtx = avformat_alloc_context();
    //Guess Format
    fmt = av_guess_format(NULL, out_file, NULL);
    pFormatCtx->oformat = fmt;
    
    // Method2.
    // avformat_alloc_output_context2(&pFormatCtx, NULL, NULL, out_file);
    // fmt = pFormatCtx->oformat;
    
    //Open output URL
    if (avio_open(&pFormatCtx->pb, out_file, AVIO_FLAG_READ_WRITE) < 0){
        printf("Failed to open output file! \n");
        return -1;
    }
    
    video_st = avformat_new_stream(pFormatCtx, 0);
    video_st->time_base.num = 1;
    video_st->time_base.den = 15;
    
    if (video_st==NULL){
        return -1;
    }
    
    // Param that must set
    pCodecCtx = video_st->codec;
    pCodecCtx->codec_id = fmt->video_codec;
    pCodecCtx->codec_type = AVMEDIA_TYPE_VIDEO;
    pCodecCtx->pix_fmt = PIX_FMT_YUV420P;
    pCodecCtx->width = encoder_h264_frame_width;
    pCodecCtx->height = encoder_h264_frame_height;
    pCodecCtx->time_base.num = 1;
    pCodecCtx->time_base.den = 15;
    pCodecCtx->bit_rate = 400000;
    pCodecCtx->gop_size = 250;
    // H264
    // pCodecCtx->me_range = 16;
    // pCodecCtx->max_qdiff = 4;
    // pCodecCtx->qcompress = 0.6;
    pCodecCtx->qmin = 10;
    pCodecCtx->qmax = 51;
    
    // Optional Param
    pCodecCtx->max_b_frames=3;
    
    // Set Option
    AVDictionary *param = 0;
    
    // H.264
    if(pCodecCtx->codec_id == AV_CODEC_ID_H264) {
        
        av_dict_set(&param, "preset", "slow", 0);
        av_dict_set(&param, "tune", "zerolatency", 0);
        // av_dict_set(&param, "profile", "main", 0);
    }
    
    // Show some Information
    av_dump_format(pFormatCtx, 0, out_file, 1);

    pCodec = avcodec_find_encoder(pCodecCtx->codec_id);
    if (!pCodec) {
        
        printf("Can not find encoder! \n");
        return -1;
    }
    
    if (avcodec_open2(pCodecCtx, pCodec,&param) < 0) {
        
        printf("Failed to open encoder! \n");
        return -1;
    }
    
    pFrame = av_frame_alloc();
//    picture_size = avpicture_get_size(pCodecCtx->pix_fmt, pCodecCtx->width, pCodecCtx->height);
//    picture_buf = (uint8_t *)av_malloc(picture_size);
    avpicture_fill((AVPicture *)pFrame, picture_buf, pCodecCtx->pix_fmt, pCodecCtx->width, pCodecCtx->height);
    
    //Write File Header
    avformat_write_header(pFormatCtx, NULL);
    
    av_new_packet(&pkt, picture_size);
    
    y_size = pCodecCtx->width * pCodecCtx->height;
    
    return 0;
}

/*
 * 将CMSampleBufferRef格式的数据编码成h264并写入文件
 * 
 */
- (void)encoderToH264:(CMSampleBufferRef)sampleBuffer
{
    CVPixelBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    if (CVPixelBufferLockBaseAddress(imageBuffer, 0) == kCVReturnSuccess) {
        
//        int pixelFormat = CVPixelBufferGetPixelFormatType(imageBuffer);
//        switch (pixelFormat) {
//            case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
//                NSLog(@"Capture pixel format=NV12");
//                break;
//            case kCVPixelFormatType_422YpCbCr8:
//                NSLog(@"Capture pixel format=UYUY422");
//                break;
//            default:
//                NSLog(@"Capture pixel format=RGB32");
//                break;
//        }

        
        UInt8 *bufferbasePtr = (UInt8 *)CVPixelBufferGetBaseAddress(imageBuffer);
        UInt8 *bufferPtr = (UInt8 *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer,0);
        UInt8 *bufferPtr1 = (UInt8 *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer,1);
        size_t buffeSize = CVPixelBufferGetDataSize(imageBuffer);
        size_t width = CVPixelBufferGetWidth(imageBuffer);
        size_t height = CVPixelBufferGetHeight(imageBuffer);
        size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
        size_t bytesrow0 = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer,0);
        size_t bytesrow1  = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer,1);
        size_t bytesrow2 = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer,2);
        UInt8 *yuv420_data = (UInt8 *)malloc(width * height *3/ 2); // buffer to store YUV with layout YYYYYYYYUUVV
        
        /* convert NV12 data to YUV420*/
        UInt8 *pY = bufferPtr ;
        UInt8 *pUV = bufferPtr1;
        UInt8 *pU = yuv420_data + width*height;
        UInt8 *pV = pU + width*height/4;
        for(int i =0;i<height;i++)
        {
            memcpy(yuv420_data+i*width,pY+i*bytesrow0,width);
        }
        for(int j = 0;j<height/2;j++)
        {
            for(int i =0;i<width/2;i++)
            {
                *(pU++) = pUV[i<<1];
                *(pV++) = pUV[(i<<1) + 1];
            }
            pUV+=bytesrow1;
        }
        
        // add code to push yuv420_data to video encoder here
        
        // scale
        // add code to scale image here
        // ...
        
        //Read raw YUV data
        picture_buf = yuv420_data;
        pFrame->data[0] = picture_buf;              // Y
        pFrame->data[1] = picture_buf+ y_size;      // U
        pFrame->data[2] = picture_buf+ y_size*5/4;  // V
        
        // PTS
        pFrame->pts = framecnt;
        int got_picture = 0;
        
        // Encode
        pFrame->width = encoder_h264_frame_width;
        pFrame->height = encoder_h264_frame_height;
        pFrame->format = PIX_FMT_YUV420P;
        
        int ret = avcodec_encode_video2(pCodecCtx, &pkt, pFrame, &got_picture);
        if(ret < 0) {
            
            printf("Failed to encode! \n");
            
        }
        if (got_picture==1) {
            
            printf("Succeed to encode frame: %5d\tsize:%5d\n", framecnt, pkt.size);
            framecnt++;
            pkt.stream_index = video_st->index;
            ret = av_write_frame(pFormatCtx, &pkt);
            av_free_packet(&pkt);
        }

        free(yuv420_data);
    }
    
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
}


/*
 * 释放资源
 */
- (void)freeX264Resource
{
    //Flush Encoder
    int ret = flush_encoder(pFormatCtx,0);
    if (ret < 0) {
        
        printf("Flushing encoder failed\n");
    }
    
    //Write file trailer
    av_write_trailer(pFormatCtx);
    
    //Clean
    if (video_st){
        avcodec_close(video_st->codec);
        av_free(pFrame);
//        av_free(picture_buf);
    }
    avio_close(pFormatCtx->pb);
    avformat_free_context(pFormatCtx);
}

int flush_encoder(AVFormatContext *fmt_ctx,unsigned int stream_index)
{
    int ret;
    int got_frame;
    AVPacket enc_pkt;
    if (!(fmt_ctx->streams[stream_index]->codec->codec->capabilities &
          CODEC_CAP_DELAY))
        return 0;
    
    while (1) {
        enc_pkt.data = NULL;
        enc_pkt.size = 0;
        av_init_packet(&enc_pkt);
        ret = avcodec_encode_video2 (fmt_ctx->streams[stream_index]->codec, &enc_pkt,
                                     NULL, &got_frame);
        av_frame_free(NULL);
        if (ret < 0)
            break;
        if (!got_frame){
            ret=0;
            break;
        }
        printf("Flush Encoder: Succeed to encode 1 frame!\tsize:%5d\n",enc_pkt.size);
        /* mux encoded frame */
        ret = av_write_frame(fmt_ctx, &enc_pkt);
        if (ret < 0)
            break;
    }
    return ret;
}

@end
