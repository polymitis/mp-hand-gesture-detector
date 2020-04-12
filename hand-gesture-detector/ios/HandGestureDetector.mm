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
#import "HandGestureDetector.h"
#import "mediapipe/objc/MPPGraph.h"

#include "mediapipe/framework/formats/landmark.pb.h"

static NSString* const kGraphName = @"multi_hand_tracking_mobile_gpu";

static const char* kInputStream = "input_video";
static const char* kOutputStream = "output_video";
static const char* kLandmarksOutputStream = "multi_hand_landmarks";

@interface HandGestureDetector () <MPPGraphDelegate>

@property(nonatomic) MPPGraph* mediapipeGraph;

@end

@implementation HandGestureDetector

#pragma mark - Setup methods

- (HandGestureDetector*)init {
    if (self = [super init]) {
        // Load graph
        self.mediapipeGraph = [[self class] loadGraphFromResource:kGraphName];
        self.mediapipeGraph.delegate = self;
        // Set maxFramesInFlight to a small value to avoid memory contention for real-time processing.
        self.mediapipeGraph.maxFramesInFlight = 2;
        
        // Start running self.mediapipeGraph.
        NSError* error;
        if (![self.mediapipeGraph startWithError:&error])
            NSLog(@"Failed to start graph: %@", error);
    }
    
    return self;
}

#pragma mark - Cleanup methods

- (void)dealloc {
    self.mediapipeGraph.delegate = nil;
    [self.mediapipeGraph cancel];
    // Ignore errors since we're cleaning up.
    [self.mediapipeGraph closeAllInputStreamsWithError:nil];
    [self.mediapipeGraph waitUntilDoneWithError:nil];
}

#pragma mark - External methods

- (void)processVideoFrame:(CVPixelBufferRef)imageBuffer {
    [self.mediapipeGraph sendPixelBuffer:imageBuffer
                              intoStream:kInputStream
                              packetType:MPPPacketTypePixelBuffer];
}

#pragma mark - MediaPipe graph methods

+ (MPPGraph*)loadGraphFromResource:(NSString*)resource {
    // Load the graph config resource.
    NSError* configLoadError = nil;
    NSBundle* bundle = [NSBundle bundleForClass:[self class]];
    
    if (!resource || resource.length == 0) {
        return nil;
    }
    
    NSURL* graphURL = [bundle URLForResource:resource
                               withExtension:@"binarypb"];
    
    NSData* data = [NSData dataWithContentsOfURL:graphURL
                                         options:0
                                           error:&configLoadError];
    if (!data) {
        NSLog(@"Failed to load MediaPipe graph config: %@", configLoadError);
        return nil;
    }
    
    // Parse the graph config resource into mediapipe::CalculatorGraphConfig proto object.
    mediapipe::CalculatorGraphConfig config;
    config.ParseFromArray(data.bytes, data.length);
    
    // Create MediaPipe graph with mediapipe::CalculatorGraphConfig proto object.
    MPPGraph* newGraph = [[MPPGraph alloc] initWithGraphConfig:config];
    [newGraph addFrameOutputStream:kOutputStream
                  outputPacketType:MPPPacketTypePixelBuffer];
    [newGraph addFrameOutputStream:kLandmarksOutputStream
                  outputPacketType:MPPPacketTypeRaw];
    
    return newGraph;
}

#pragma mark - MPPGraphDelegate methods

// Receives CVPixelBufferRef from the MediaPipe graph. Invoked on a MediaPipe worker thread.
- (void)mediapipeGraph:(MPPGraph*)graph
  didOutputPixelBuffer:(CVPixelBufferRef)pixelBuffer
            fromStream:(const std::string&)streamName {
    if (streamName == kOutputStream) {
        // Display the captured image on the screen.
        CVPixelBufferRetain(pixelBuffer);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(handGestureDetector:didOutputPixelBuffer:)])
                [self.delegate handGestureDetector:self didOutputPixelBuffer:pixelBuffer];
            CVPixelBufferRelease(pixelBuffer);
        });
    }
}

// Receives a raw packet from the MediaPipe graph. Invoked on a MediaPipe worker thread.
- (void)mediapipeGraph:(MPPGraph*)graph
       didOutputPacket:(const ::mediapipe::Packet&)packet
            fromStream:(const std::string&)streamName {
    if (streamName == kLandmarksOutputStream) {
        if (packet.IsEmpty()) {
            NSLog(@"[TS:%lld] No hand landmarks", packet.Timestamp().Value());
            return;
        }
        
        const auto& multi_hand_landmarks = packet.Get<std::vector<::mediapipe::NormalizedLandmarkList>>();
        NSLog(@"[TS:%lld] Number of hand instances with landmarks: %lu",
              packet.Timestamp().Value(), multi_hand_landmarks.size());
        
        for (int hand_index = 0; hand_index < multi_hand_landmarks.size(); ++hand_index) {
            const auto& landmarks = multi_hand_landmarks[hand_index];
            NSLog(@"\tNumber of landmarks for hand[%d]: %d",
                  hand_index, landmarks.landmark_size());
            
            for (int i = 0; i < landmarks.landmark_size(); ++i)
                NSLog(@"\t\tLandmark[%d]: (%f, %f, %f)",
                      i, landmarks.landmark(i).x(), landmarks.landmark(i).y(), landmarks.landmark(i).z());
        }
    }
}


@end
