//
//  ViewController.m
//  I420-Color-Space-Process
//
//  Created by suntongmian on 16/11/15.
//  Copyright © 2016年 suntongmian. All rights reserved.
//

#import "PlayViewController.h"

#include "libavcodec/avcodec.h"
#include "libavformat/avformat.h"
#include "libswscale/swscale.h"

#import "StmGLView.h"

@interface PlayViewController ()

@end

@implementation PlayViewController
{
    AVFormatContext    *pFormatCtx;
    int                videoindex;
    AVCodecContext    *pCodecCtx;
    AVCodec            *pCodec;
    
    NSString *path;
    
    STMVideoFrameYUV   *videoFrameYUV;
    STMGLView          *stmGLView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.view.backgroundColor = [UIColor whiteColor];
    
    path = self.h264FilePath;
    
    videoFrameYUV = [[STMVideoFrameYUV alloc] init];
    stmGLView = [[STMGLView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height) videoFrameSize:CGSizeMake(1280, 720) videoFrameFormat:STMVideoFrameFormatYUV];
    [self.view addSubview:stmGLView];
    
    UIButton *backButton = [UIButton buttonWithType:UIButtonTypeCustom];
    backButton.frame = CGRectMake(15, self.view.frame.size.height - 50 - 15, 50, 50);
    CGFloat lineWidth = backButton.frame.size.width * 0.12f;
    backButton.layer.cornerRadius = backButton.frame.size.width / 2;
    backButton.layer.borderColor = [UIColor whiteColor].CGColor;
    backButton.layer.borderWidth = lineWidth;
    [backButton setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [backButton setTitle:@"返回" forState:UIControlStateNormal];
    [backButton addTarget:self action:@selector(backButtonEvent:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:backButton];
    
    // 开始／停止 button
    UIButton *startButton = [UIButton buttonWithType:UIButtonTypeCustom];
    startButton.frame = CGRectMake(self.view.frame.size.width - 65, self.view.frame.size.height - 50 - 15, 50, 50);
    lineWidth = backButton.frame.size.width * 0.12f;
    backButton.layer.cornerRadius = backButton.frame.size.width / 2;
    backButton.layer.borderColor = [UIColor greenColor].CGColor;
    backButton.layer.borderWidth = lineWidth;
    [startButton setTitleColor:[UIColor greenColor] forState:UIControlStateNormal];
    [startButton setTitle:@"开始" forState:UIControlStateNormal];
    [startButton addTarget:self action:@selector(startButtonEvent:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:startButton];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

#pragma mark --  返回
- (void)backButtonEvent:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)startButtonEvent:(id)sender {
    [self displayImage];
}

- (void)displayImage {
    const char *filepath = [path UTF8String];
    
    av_register_all();
    avformat_network_init();
    pFormatCtx = avformat_alloc_context();
    if(avformat_open_input(&pFormatCtx, filepath, NULL, NULL) != 0) {
        printf("Couldn't open input stream.\n");
        exit(1);
    }
    
    if(avformat_find_stream_info(pFormatCtx, NULL) < 0) {
        printf("Couldn't find stream information.\n");
        exit(1);
    }
    
    videoindex = -1;
    for(int i = 0; i < pFormatCtx->nb_streams; i++)
        if(pFormatCtx->streams[i]->codec->codec_type == AVMEDIA_TYPE_VIDEO) {
            videoindex=i;
            break;
        }
    
    if(videoindex==-1) {
        printf("Didn't find a video stream.\n");
        exit(1);
    }
    
    pCodecCtx = pFormatCtx->streams[videoindex]->codec;
    pCodec = avcodec_find_decoder(pCodecCtx->codec_id);
    if(pCodec == NULL) {
        printf("Codec not found.\n");
        exit(1);
    }
    if(avcodec_open2(pCodecCtx, pCodec, NULL) < 0) {
        printf("Could not open codec.\n");
        exit(1);
    }
    
    AVFrame    *pFrame, *pFrameYUV;
    pFrame = av_frame_alloc();
    pFrameYUV = av_frame_alloc();
    
    int ret, got_picture;
    int y_size = pCodecCtx->width * pCodecCtx->height;
    
    AVPacket *packet=(AVPacket *)malloc(sizeof(AVPacket));
    av_new_packet(packet, y_size);
    
    printf("video infomation：\n");
    av_dump_format(pFormatCtx,0,filepath,0);
    
    while(av_read_frame(pFormatCtx, packet) >= 0) {
        if(packet->stream_index==videoindex) {
            ret = avcodec_decode_video2(pCodecCtx, pFrame, &got_picture, packet);
            if(ret < 0) {
                printf("Decode Error.\n");
                exit(1);
            }
            
            if(got_picture) {
                char *buf = (char *)malloc(pFrame->width * pFrame->height * 3 / 2);
                
                AVPicture *pict;
                int w, h;
                char *y, *u, *v;
                pict = (AVPicture *)pFrame;//这里的frame就是解码出来的AVFrame
                w = pFrame->width;
                h = pFrame->height;
                y = buf;
                u = y + w * h;
                v = u + w * h / 4;
                
                for (int i=0; i<h; i++)
                    memcpy(y + w * i, pict->data[0] + pict->linesize[0] * i, w);
                for (int i=0; i<h/2; i++)
                    memcpy(u + w / 2 * i, pict->data[1] + pict->linesize[1] * i, w / 2);
                for (int i=0; i<h/2; i++)
                    memcpy(v + w / 2 * i, pict->data[2] + pict->linesize[2] * i, w / 2);
                
                
                // 将得到的 i420 数据赋值给 videoFrameYUV 对象
                int yuvWidth, yuvHeight;
                void *planY, *planU, *planV;
                
                yuvWidth = pFrame->width;
                yuvHeight = pFrame->height;
                
                planY = buf;
                planU = buf + pFrame->width * pFrame->height;
                planV = buf + pFrame->width * pFrame->height * 5 / 4;
                
                videoFrameYUV.format = STMVideoFrameFormatYUV;
                videoFrameYUV.width = yuvWidth;
                videoFrameYUV.height = yuvHeight;
                videoFrameYUV.luma = planY;
                videoFrameYUV.chromaB = planU;
                videoFrameYUV.chromaR = planV;
                
                // 渲染 i420
                [stmGLView render:videoFrameYUV];
                
                
                free(buf);
            }
        }
        av_packet_unref(packet);
    }
    av_frame_free(&pFrameYUV);
    avcodec_close(pCodecCtx);
    avformat_close_input(&pFormatCtx);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc {
    
}

@end

