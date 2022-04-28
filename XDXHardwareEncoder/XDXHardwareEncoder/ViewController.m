//
//  ViewController.m
//  XDXHardwareEncoder
//
//  Created by 小东邪 on 09/11/2017.
//  Copyright © 2017 小东邪. All rights reserved.
//

/*************************************************************************************************************************************/

// 注意 ： 在initVideoEncoder 修改enableH264 = YES 或者 enableH265 = YES; 切换H264,H265,录制的文件为200帧左右，可以使用VLC 进行播放验证

// 本文具体解析请参考：  GitHub : https://github.com/ChengyangLi/Crop-sample-buffer
//                   博客    : https://chengyangli.github.io/2017/07/12/cropSampleBuffer/
//                   简书    : http://www.jianshu.com/p/ac79a80f1af2

/*************************************************************************************************************************************/

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "XDXHardwareEncoder.h"

@interface ViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate>
@property (nonatomic, strong) AVCaptureSession              *captureSession;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer    *captureVideoPreviewLayer;
@property (weak, nonatomic) IBOutlet UIButton *startRecordBtn;
@property (weak, nonatomic) IBOutlet UIButton *stopRecordBtn;
@property (weak, nonatomic) IBOutlet UILabel *noteLabel;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self initCapture];
    [self initVideoEncoder];
    [self.view bringSubviewToFront:self.noteLabel];
}

- (void)initVideoEncoder {
    XDXHardwareEncoder *encoder = [XDXHardwareEncoder getInstance];
    // 修改enableH264, H265实现切换
//    encoder.enableH264 = YES;
     encoder.enableH265 = YES;
    [encoder prepareForEncode];
}

- (void)initCapture
{
    // 获取后置摄像头设备
    AVCaptureDevice *inputDevice            = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    // 创建输入数据对象
    AVCaptureDeviceInput *captureInput      = [AVCaptureDeviceInput deviceInputWithDevice:inputDevice error:nil];
    if (!captureInput) return;
    
    // 创建一个视频输出对象
    AVCaptureVideoDataOutput *captureOutput = [[AVCaptureVideoDataOutput alloc] init];
    [captureOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    
//    NSString     *key           = (NSString *)kCVPixelBufferPixelFormatTypeKey;
//    NSNumber     *value         = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA];
//    NSDictionary *videoSettings = [NSDictionary dictionaryWithObject:value forKey:key];
    
//    [captureOutput setVideoSettings:videoSettings];
    
   
    self.captureSession = [[AVCaptureSession alloc] init];
//    NSString *preset    = 0;
////    An AVCaptureSession preset suitable for 3840x2160 (UHD 4K) video output.
//    if (!preset) preset = AVCaptureSessionPreset1280x720;
//
//    self.captureSession.sessionPreset = preset;
    if ([self.captureSession canAddInput:captureInput]) {
        [self.captureSession addInput:captureInput];
    }
    if ([self.captureSession canAddOutput:captureOutput]) {
        [self.captureSession addOutput:captureOutput];
    }
    
 //   An AVCaptureSession preset suitable for 3840x2160 (UHD 4K) video output.
 //   kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
    [self setCameraFrameRateAndResolutionWithFrameRate:60
                                               andResolutionHeight:2160
                                                         bySession:self.captureSession
                                                          position:AVCaptureDevicePositionBack
                                                       videoFormat:kCVPixelFormatType_420YpCbCr8PlanarFullRange];
    // 创建视频预览图层
    if (!self.captureVideoPreviewLayer) {
        self.captureVideoPreviewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
    }
    
    self.captureVideoPreviewLayer.frame         = self.view.bounds;
    self.captureVideoPreviewLayer.videoGravity  = AVLayerVideoGravityResizeAspectFill;
    [self.view.layer     addSublayer:self.captureVideoPreviewLayer];
    [self.captureSession startRunning];
}


#pragma mark Resolution
- (BOOL)setCameraFrameRateAndResolutionWithFrameRate:(int)frameRate andResolutionHeight:(CGFloat)resolutionHeight bySession:(AVCaptureSession *)session position:(AVCaptureDevicePosition)position videoFormat:(OSType)videoFormat {
    AVCaptureDevice *captureDevice = [self getCaptureDevicePosition:position];
    
    BOOL isSuccess = NO;
    for(AVCaptureDeviceFormat *vFormat in [captureDevice formats]) {
        CMFormatDescriptionRef description = vFormat.formatDescription;
        float maxRate = ((AVFrameRateRange*) [vFormat.videoSupportedFrameRateRanges objectAtIndex:0]).maxFrameRate;
        if (maxRate >= frameRate && CMFormatDescriptionGetMediaSubType(description) == videoFormat) {
            if ([captureDevice lockForConfiguration:NULL] == YES) {
                // 对比镜头支持的分辨率和当前设置的分辨率
                CMVideoDimensions dims = CMVideoFormatDescriptionGetDimensions(description);
                if (dims.height == resolutionHeight && dims.width == [self getResolutionWidthByHeight:resolutionHeight]) {
                    [session beginConfiguration];
                    if ([captureDevice lockForConfiguration:NULL]){
                        captureDevice.activeFormat = vFormat;
                        [captureDevice setActiveVideoMinFrameDuration:CMTimeMake(1, frameRate)];
                        [captureDevice setActiveVideoMaxFrameDuration:CMTimeMake(1, frameRate)];
                        [captureDevice unlockForConfiguration];
                    }
                    [session commitConfiguration];
                    
                    return YES;
                }
            }else {
                NSLog(@"%s: lock failed!",__func__);
            }
        }
    }
    
    NSLog(@"Set camera frame is success : %d, frame rate is %lu, resolution height = %f",isSuccess,(unsigned long)frameRate,resolutionHeight);
    return NO;
}

- (AVCaptureDevice *)getCaptureDevicePosition:(AVCaptureDevicePosition)position {
    NSArray *devices = nil;
    
    if (@available(iOS 10.0, *)) {
        AVCaptureDeviceDiscoverySession *deviceDiscoverySession =  [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera] mediaType:AVMediaTypeVideo position:position];
        devices = deviceDiscoverySession.devices;
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
#pragma clang diagnostic pop
    }
    
    for (AVCaptureDevice *device in devices) {
        if (position == device.position) {
            return device;
        }
    }
    return NULL;
}
- (int)getResolutionWidthByHeight:(int)height {
    switch (height) {
//            AVCaptureSession preset suitable for 3840x2160 (UHD 4K) video output.
        case 2160:
            return 3840;
        case 1080:
            return 1920;
        case 720:
            return 1280;
        case 480:
            return 640;
        default:
            return -1;
    }
}



#pragma mark - Btn Click Event
#pragma mark ------------------AVCaptureVideoDataOutputSampleBufferDelegate--------------------------------
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if( !CMSampleBufferDataIsReady(sampleBuffer)) {
        NSLog( @"sample buffer is not ready. Skipping sample" );
        return;
    }
    
    if([XDXHardwareEncoder getInstance] != NULL) {
        [[XDXHardwareEncoder getInstance] encode:sampleBuffer];
    }
}

@end
