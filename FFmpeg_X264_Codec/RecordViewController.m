//
//  RecordViewController.m
//  FFmpeg_X264_Codec
//
//  Created by suntongmian on 2017/9/30.
//  Copyright © 2017年 suntongmian@163.com. All rights reserved.
//

/*
 *** Terminating app due to uncaught exception 'NSInvalidArgumentException', reason: '*** -[AVCaptureVideoDataOutput setVideoSettings:] - y420 (2033463856) is not a supported pixel format type.  See AVCaptureOutput.h for a list of supported formats.  Available pixel format types on this platform are (
 420v,
 420f,
 BGRA
 ).'
 
 ----------------------------
 得到了buffer之后填充进FFmpeg的AFrame 然后sws_scale转化成yuv420p格式，用x264编码 输出buff传输，解码，贴图
 
 */


#import "RecordViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "VideoConfiguration.h"
#import "X264Encoder.h"
#import "WriteH264Streaming.h"
#import "PlayViewController.h"

@interface RecordViewController () <AVCaptureVideoDataOutputSampleBufferDelegate>

@end

@implementation RecordViewController
{
    AVCaptureSession                *captureSession;
    AVCaptureDevice                 *captureDevice;
    AVCaptureDeviceInput            *captureDeviceInput;
    AVCaptureVideoDataOutput        *captureVideoDataOutput;
    
    AVCaptureConnection             *videoCaptureConnection;
    
    AVCaptureVideoPreviewLayer      *previewLayer;
    
    UIButton                        *recordVideoButton;
    
    BOOL                             isRecording;
    
    dispatch_queue_t                 encodeQueue;
    VideoConfiguration              *videoConfiguration;
    X264Encoder                     *x264Encoder;
    WriteH264Streaming              *writeH264Streaming;
    
    NSString                        *h264FilePath;
}

- (CGSize)getVideoSize:(NSString *)sessionPreset {
    CGSize size = CGSizeZero;
    if ([sessionPreset isEqualToString:AVCaptureSessionPresetMedium]) {
        size = CGSizeMake(480, 360);
    } else if ([sessionPreset isEqualToString:AVCaptureSessionPreset1920x1080]) {
        size = CGSizeMake(1920, 1080);
    } else if ([sessionPreset isEqualToString:AVCaptureSessionPreset1280x720]) {
        size = CGSizeMake(1280, 720);
    } else if ([sessionPreset isEqualToString:AVCaptureSessionPreset640x480]) {
        size = CGSizeMake(640, 480);
    }
    
    return size;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    encodeQueue = dispatch_queue_create(DISPATCH_QUEUE_SERIAL, NULL);

#pragma mark -- AVCaptureSession init
    captureSession = [[AVCaptureSession alloc] init];
    captureSession.sessionPreset = AVCaptureSessionPreset1280x720;
    
    captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    NSError *error = nil;
    captureDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:&error];
    
    if([captureSession canAddInput:captureDeviceInput])
        [captureSession addInput:captureDeviceInput];
    else
        NSLog(@"Error: %@", error);
    
    dispatch_queue_t outputQueue = dispatch_queue_create("outputQueue", NULL);
    
    captureVideoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    [captureVideoDataOutput setSampleBufferDelegate:self queue:outputQueue];
    
    // nv12
    NSDictionary *settings = [[NSDictionary alloc] initWithObjectsAndKeys:
                              [NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange],
                              kCVPixelBufferPixelFormatTypeKey,
                              nil];
    
    captureVideoDataOutput.videoSettings = settings;
    captureVideoDataOutput.alwaysDiscardsLateVideoFrames = YES;
    
    if ([captureSession canAddOutput:captureVideoDataOutput]) {
        [captureSession addOutput:captureVideoDataOutput];
    }
    
    // 保存Connection，用于在SampleBufferDelegate中判断数据来源（是Video/Audio？）
    videoCaptureConnection = [captureVideoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    
#pragma mark -- AVCaptureVideoPreviewLayer init
    previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:captureSession];
    previewLayer.frame = self.view.layer.bounds;
    previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill; // 设置预览时的视频缩放方式
    [[previewLayer connection] setVideoOrientation:AVCaptureVideoOrientationPortrait]; // 设置视频的朝向
    [self.view.layer addSublayer:previewLayer];
    
#pragma mark -- Button init
    recordVideoButton = [UIButton buttonWithType:UIButtonTypeCustom];
    recordVideoButton.frame = CGRectMake(45, self.view.frame.size.height - 60 - 15, 60, 60);
    recordVideoButton.center = CGPointMake(self.view.frame.size.width / 2, recordVideoButton.frame.origin.y + recordVideoButton.frame.size.height / 2);
    
    CGFloat lineWidth = recordVideoButton.frame.size.width * 0.12f;
    recordVideoButton.layer.cornerRadius = recordVideoButton.frame.size.width / 2;
    recordVideoButton.layer.borderColor = [UIColor greenColor].CGColor;
    recordVideoButton.layer.borderWidth = lineWidth;
    
    [recordVideoButton setTitleColor:[UIColor greenColor] forState:UIControlStateNormal];
    [recordVideoButton setTitle:@"录制" forState:UIControlStateNormal];
    
    recordVideoButton.selected = NO;
    [recordVideoButton setTitleColor:[UIColor redColor] forState:UIControlStateSelected];
    [recordVideoButton setTitle:@"停止" forState:UIControlStateSelected];
    
    [recordVideoButton addTarget:self action:@selector(recordVideo:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:recordVideoButton];
    
    UIButton *backButton = [UIButton buttonWithType:UIButtonTypeCustom];
    backButton.frame = CGRectMake(15, self.view.frame.size.height - 50 - 15, 50, 50);
    lineWidth = backButton.frame.size.width * 0.12f;
    backButton.layer.cornerRadius = backButton.frame.size.width / 2;
    backButton.layer.borderColor = [UIColor whiteColor].CGColor;
    backButton.layer.borderWidth = lineWidth;
    [backButton setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [backButton setTitle:@"返回" forState:UIControlStateNormal];
    [backButton addTarget:self action:@selector(backButtonEvent:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:backButton];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [captureSession startRunning];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [captureSession stopRunning];
}

#pragma mark --  返回
- (void)backButtonEvent:(id)sender {
    [self stopRecording];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)recordVideo:(UIButton *)button {
    button.selected = !button.selected;
    
    if (button.selected) {
        [self startRecording];
    } else {
        [self stopRecording];
    }
}

- (void)startRecording {
#pragma mark --  X264Encoder
    dispatch_sync(encodeQueue, ^{
        NSLog(@"recordVideo....");
        writeH264Streaming = [[WriteH264Streaming alloc] init];
        h264FilePath = writeH264Streaming.filePath;
        
        videoConfiguration = [VideoConfiguration defaultConfiguration];
        x264Encoder = [[X264Encoder alloc] initWithVideoConfiguration:videoConfiguration];
        [x264Encoder setOutputObject:writeH264Streaming];
        
        isRecording = YES;
    });
}

- (void)stopRecording {
    __weak typeof(self)weakSelf = self;
    dispatch_sync(encodeQueue, ^{
        NSLog(@"stopRecord!!!");
        isRecording = NO;
        
        [x264Encoder teardown];
        
        PlayViewController *playViewController = [[PlayViewController alloc] init];
        playViewController.h264FilePath = h264FilePath;
        [weakSelf presentViewController:playViewController animated:YES completion:nil];
    });
}

#pragma mark --  AVCaptureVideo(Audio)DataOutputSampleBufferDelegate method
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    dispatch_sync(encodeQueue, ^{
        // 这里的sampleBuffer就是采集到的数据了，但它是Video还是Audio的数据，得根据connection来判断
        if (connection == videoCaptureConnection) {
            // Video
            // NSLog(@"在这里获得video sampleBuffer，做进一步处理（编码H.264）");
            
            if (isRecording) {
                // X264Encoder
                CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
                CMTime ptsTime = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer);
                CGFloat pts = CMTimeGetSeconds(ptsTime);
                [x264Encoder encoding:pixelBuffer timestamp:pts];
            }
        }
        //    else if (connection == audioCaptureConnection) {
        //
        //        // Audio
        //        NSLog(@"这里获得audio sampleBuffer，做进一步处理（编码AAC）");
        //    }
    });
}

#pragma mark -- 锁定屏幕为竖屏
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

- (BOOL)shouldAutorotate {
    return NO;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc {
    [previewLayer removeFromSuperlayer];
    previewLayer = nil;
    captureSession = nil;
}

@end
