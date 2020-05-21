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
#import <Availability.h>
#import <AVFoundation/AVFoundation.h>

#ifdef __cplusplus
#define HANDGESTUREDETECTOR_EXTERN         extern "C" __attribute__((visibility ("default")))
#else
#define HANDGESTUREDETECTOR_EXTERN         extern __attribute__((visibility ("default")))
#endif

HANDGESTUREDETECTOR_EXTERN API_AVAILABLE(ios(11.0)) @protocol HandGestureDetectorDelegate <NSObject>
@optional
- (void)handGestureDetector:(id)hgd didOutputPixelBuffer:(CVPixelBufferRef)pixelBuffer;
- (void)handGestureDetector:(id)hgd didOutputHandLandmarks:(float*)hlmPkt;
- (void)handGestureDetector:(id)hgd didOutputHandRects:(float*)hrcPkt;

@end

HANDGESTUREDETECTOR_EXTERN API_AVAILABLE(ios(11.0)) @interface HandGestureDetector : NSObject

- (void)processPixelBuffer:(CVPixelBufferRef)pixelBuffer;

@property (nonatomic, weak) id <HandGestureDetectorDelegate> delegate;

@end
