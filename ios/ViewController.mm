// MIT License
//
// Copyright (c) 2020 Petros Fountas
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
#import "ViewController.h"
#import "HandGestureDetector.h"

#import "mediapipe/objc/MPPCameraInputSource.h"
#import "mediapipe/objc/MPPLayerRenderer.h"

static const char* kVideoQueueLabel = "com.polymitis.ios.handgesturedetector.app";

@interface ViewController () <HandGestureDetectorDelegate, MPPInputSourceDelegate>

@property(nonatomic) HandGestureDetector* handGestureDetector;

@end

@implementation ViewController {
    MPPCameraInputSource* _cameraSource;
    IBOutlet UILabel* _noCameraLabel;
    IBOutlet UIView* _liveView;
    MPPLayerRenderer* _renderer;
    dispatch_queue_t _videoQueue;
}

#pragma mark - Cleanup methods

- (void)dealloc {
    
}

#pragma mark - UIViewController methods

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _renderer = [[MPPLayerRenderer alloc] init];
    _renderer.layer.frame = _liveView.layer.bounds;
    [_liveView.layer addSublayer:_renderer.layer];
    _renderer.frameScaleMode = MPPFrameScaleModeFillAndCrop;
    
    dispatch_queue_attr_t qosAttribute = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, /*relative_priority=*/0);
    _videoQueue = dispatch_queue_create(kVideoQueueLabel, qosAttribute);
    
    _cameraSource = [[MPPCameraInputSource alloc] init];
    [_cameraSource setDelegate:self queue:_videoQueue];
    _cameraSource.sessionPreset = AVCaptureSessionPresetHigh;
    _cameraSource.cameraPosition = AVCaptureDevicePositionBack;
    _cameraSource.orientation = AVCaptureVideoOrientationPortrait;
    _handGestureDetector = [[HandGestureDetector alloc] init];
    _handGestureDetector.delegate = self;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [_cameraSource requestCameraAccessWithCompletionHandler:^void(BOOL granted) {
        if (granted) {
            dispatch_async(_videoQueue, ^{
                [_cameraSource start];
            });
            dispatch_async(dispatch_get_main_queue(), ^{
                _noCameraLabel.hidden = YES;
            });
        }
    }];
}

#pragma mark - MPPGraphDelegate methods

- (void)handGestureDetector:hgd didOutputPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    // Display the captured image on the screen.
    CVPixelBufferRetain(pixelBuffer);
    
    dispatch_async(dispatch_get_main_queue(), ^{
            [_renderer renderPixelBuffer:pixelBuffer];
            CVPixelBufferRelease(pixelBuffer);
        });
}

#pragma mark - MPPInputSourceDelegate methods

// Must be invoked on _videoQueue.
- (void)processVideoFrame:(CVPixelBufferRef)imageBuffer
                timestamp:(CMTime)timestamp
               fromSource:(MPPInputSource*)source {
    if (source != _cameraSource) {
        NSLog(@"Unknown source: %@", source);
        return;
    }
    [_handGestureDetector processPixelBuffer:imageBuffer];
}

@end
