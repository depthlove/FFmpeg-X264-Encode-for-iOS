//
//  STMGLView.h
//  STM_PROCESS_RGB_YUV
//
//  Created by suntongmian on 16/11/9.
//  Copyright © 2016年 suntongmian. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>


typedef enum {
    
    STMVideoFrameFormatRGB,
    STMVideoFrameFormatYUV,
    
} STMVideoFrameFormat;

@interface STMVideoFrame : NSObject
@property (nonatomic) STMVideoFrameFormat format;
@property (nonatomic) NSUInteger width;
@property (nonatomic) NSUInteger height;
@end

@interface STMVideoFrameRGB : STMVideoFrame
@property (nonatomic) NSUInteger linesize;
@property (nonatomic) UInt8 *rgb;
@end

@interface STMVideoFrameYUV : STMVideoFrame
@property (nonatomic) UInt8 *luma;
@property (nonatomic) UInt8 *chromaB;
@property (nonatomic) UInt8 *chromaR;
@end


@interface STMGLView : UIView

- (id) initWithFrame:(CGRect)frame videoFrameSize:(CGSize)videoFrameSize videoFrameFormat:(STMVideoFrameFormat)videoFrameFormat;

- (void)render: (STMVideoFrame *) frame;

@end
