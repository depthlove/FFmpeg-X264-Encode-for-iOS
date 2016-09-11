//
//  ViewController.m
//  FFmpeg_X264_Codec
//
//  Created by sunminmin on 15/9/7.
//  Copyright (c) 2015年 suntongmian@163.com. All rights reserved.
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



#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "X264Manager.h"
#import "OpenGLView.h"

// 1 : 编码模式
// 0 : 渲染模式，当前只能渲染 32BGRA，后续增加 NV12 的渲染支持
// 将 encodeModel 设置为1，就是编码采集到视频数据；将 encodeModel 设置为0，就是渲染采集到的视频数据
#define encodeModel 1

@interface ViewController () <AVCaptureVideoDataOutputSampleBufferDelegate>

@end

@implementation ViewController
{
    AVCaptureSession                *captureSession;
    AVCaptureDevice                 *captureDevice;
    AVCaptureDeviceInput            *captureDeviceInput;
    AVCaptureVideoDataOutput        *captureVideoDataOutput;
    
    AVCaptureConnection             *videoCaptureConnection;
    
    AVCaptureVideoPreviewLayer      *previewLayer;
    
    UIButton                        *recordVideoButton;
    
    X264Manager                     *manager264;
    
    CGSize                           videoSize;
    
    OpenGLView                      *openglView;
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
    
#pragma mark -- AVCaptureSession init
    captureSession = [[AVCaptureSession alloc] init];
//    captureSession.sessionPreset = AVCaptureSessionPresetMedium;
    captureSession.sessionPreset = AVCaptureSessionPreset1920x1080;
    
    videoSize = [self getVideoSize:captureSession.sessionPreset];
    
    captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    NSError *error = nil;
    captureDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:&error];
    
    if([captureSession canAddInput:captureDeviceInput])
        [captureSession addInput:captureDeviceInput];
    else
        NSLog(@"Error: %@", error);
    
    dispatch_queue_t queue = dispatch_queue_create("myEncoderH264Queue", NULL);
    
    captureVideoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    [captureVideoDataOutput setSampleBufferDelegate:self queue:queue];

#if encodeModel
    // nv12
    NSDictionary *settings = [[NSDictionary alloc] initWithObjectsAndKeys:
                              [NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange],
                              kCVPixelBufferPixelFormatTypeKey,
                              nil];
#else
    // 32bgra
    NSDictionary *settings = [[NSDictionary alloc] initWithObjectsAndKeys:
                              [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA],
                              kCVPixelBufferPixelFormatTypeKey,
                              nil];
#endif
    
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

#pragma mark -- OpenGLView init
    openglView = [[OpenGLView alloc] initWithFrame:CGRectMake(0, 80, 240, 135)];
    [self.view addSubview:openglView];
    
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
}

// 当前系统时间
- (NSString* )nowTime2String
{
    NSString *date = nil;
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"YYYY-MM-dd hh:mm:ss";
    date = [formatter stringFromDate:[NSDate date]];
    
    return date;
}

- (NSString *)savedFileName
{
    return [[self nowTime2String] stringByAppendingString:@".h264"];
}

- (NSString *)savedFilePath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask,YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    NSString *fileName = [self savedFileName];
    
    NSString *writablePath = [documentsDirectory stringByAppendingPathComponent:fileName];
    
    return writablePath;
}

- (void)recordVideo:(UIButton *)button
{
    button.selected = !button.selected;
    
    if (button.selected) {
        
        NSLog(@"recordVideo....");

        #pragma mark -- manager X264
        manager264 = [[X264Manager alloc]init];
        [manager264 setFileSavedPath:[self savedFilePath]];
        [manager264 setX264ResourceWithVideoWidth:videoSize.width height:videoSize.height bitrate:1500000];
        
        [captureSession startRunning];
    } else {
        
        NSLog(@"stopRecord!!!");
        
        [captureSession stopRunning];
        
        [manager264 freeX264Resource];
        manager264 = nil;
    }
}


#pragma mark --
#pragma mark --  AVCaptureVideo(Audio)DataOutputSampleBufferDelegate method
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    
    // 这里的sampleBuffer就是采集到的数据了，但它是Video还是Audio的数据，得根据connection来判断
    if (connection == videoCaptureConnection) {
    
        // Video
//        NSLog(@"在这里获得video sampleBuffer，做进一步处理（编码H.264）");
        
#if encodeModel
        // encode
        [manager264 encoderToH264:sampleBuffer];
#else
        CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        
//        int pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
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
        
        CVPixelBufferLockBaseAddress(pixelBuffer, 0);

        // render
        [openglView render:pixelBuffer];
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
#endif
    }
//    else if (connection == _audioConnection) {
//        
//        // Audio
//        NSLog(@"这里获得audio sampleBuffer，做进一步处理（编码AAC）");
//    }

}


#pragma mark --
#pragma mark -- 锁定屏幕为竖屏
- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

- (BOOL)shouldAutorotate
{
    return YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc
{
    [previewLayer removeFromSuperlayer];
    previewLayer = nil;
    captureSession = nil;
    
    manager264 = nil;
}


@end
