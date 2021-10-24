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

#include "mediapipe/framework/formats/detection.pb.h"
#include "mediapipe/framework/formats/landmark.pb.h"
#include "mediapipe/framework/formats/location_data.pb.h"
#include "mediapipe/framework/formats/rect.pb.h"

// Landmarks packet HLM_PKT (N_HANDS #N, N_HLM #0, N_HLM #1, LM #0_0, .., LM #0_1, LM #1_0, .., LM #1_20)
#define HGD_HLM_PKT_HEADER_LEN                  (3)
#define HGD_HLM_PKT_NUM_HANDS_OFFSET            (0)
#define HGD_HLM_PKT_NUM_HANDS                   (2)
#define HGD_HLM_PKT_NUM_HAND_LANDMARKS_OFFSET   (HGD_HLM_PKT_NUM_HANDS_OFFSET + 1)
#define HGD_HLM_PKT_NUM_HAND_LANDMARKS          (21)
// Landmark LM (X, Y, Z)
#define HGD_HLM_PKT_HAND_LANDMARK_LEN           (3)
#define HGD_HLM_PKT_HAND_LANDMARK_X_OFFSET      (0)
#define HGD_HLM_PKT_HAND_LANDMARK_Y_OFFSET      (1)
#define HGD_HLM_PKT_HAND_LANDMARK_Z_OFFSET      (2)
// Size of landmarks packet
#define HGD_HLM_PKT_LEN                         (HGD_HLM_PKT_HEADER_LEN + (HGD_HLM_PKT_NUM_HANDS * HGD_HLM_PKT_NUM_HAND_LANDMARKS * HGD_HLM_PKT_HAND_LANDMARK_LEN))

// Rects packet HRC_PKT (N_HANDS #N, RECT_ID #0, .., RECT_R #0, RECT_ID #1, .., RECT_R #1)
#define HGD_HRC_PKT_HEADER_LEN                  (1)
#define HGD_HRC_PKT_NUM_HANDS_OFFSET            (0)
#define HGD_HRC_PKT_NUM_HANDS                   (2)
#define HGD_HRC_PKT_RECT_NUM_PROP               (6)
// Rect RECT (ID, X, Y, W, H, R)
#define HGD_HRC_PKT_RECT_ID_OFFSET              (0)
#define HGD_HRC_PKT_RECT_X_OFFSET               (1)
#define HGD_HRC_PKT_RECT_Y_OFFSET               (2)
#define HGD_HRC_PKT_RECT_W_OFFSET               (3)
#define HGD_HRC_PKT_RECT_H_OFFSET               (4)
#define HGD_HRC_PKT_RECT_R_OFFSET               (5)
// Size of rects packet
#define HGD_HRC_PKT_LEN                         (HGD_HRC_PKT_HEADER_LEN + (HGD_HRC_PKT_NUM_HANDS * HGD_HRC_PKT_RECT_NUM_PROP))

// Max number of hands to detect/process.
static const int kNumHands = 2;

static NSString* const kGraphName = @"hand_tracking_mobile_gpu";

// Input streams
static const char* kInputStream = "input_video";
static const char* kNumHandsInputSidePacket = "num_hands";

// Output streams
static const char* kOutputStream = "output_video";
static const char* kPalmDetectionsOutputStream = "palm_detections";
static const char* kHandRectsOutputStream = "hand_rects_from_palm_detections";
static const char* kLandmarksOutputStream = "hand_landmarks";

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

- (void)processPixelBuffer:(CVPixelBufferRef)imageBuffer {
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
        NSLog(@"Failed to load MediaPipe graph config: Unreadable resource: %@", resource);
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
    config.ParseFromArray(data.bytes, (int)data.length);
    
    // Create MediaPipe graph with mediapipe::CalculatorGraphConfig proto object.
    MPPGraph* newGraph = [[MPPGraph alloc] initWithGraphConfig:config];

    [newGraph setSidePacket:(mediapipe::MakePacket<int>(kNumHands))
                      named:kNumHandsInputSidePacket];

    [newGraph addFrameOutputStream:kOutputStream
                  outputPacketType:MPPPacketTypePixelBuffer];
    [newGraph addFrameOutputStream:kPalmDetectionsOutputStream
                  outputPacketType:MPPPacketTypeRaw];
    [newGraph addFrameOutputStream:kHandRectsOutputStream
                  outputPacketType:MPPPacketTypeRaw];
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
                [self.delegate handGestureDetector:self
                              didOutputPixelBuffer:pixelBuffer];
            CVPixelBufferRelease(pixelBuffer);
        });
    }
}

// Receives a raw packet from the MediaPipe graph. Invoked on a MediaPipe worker thread.
- (void)mediapipeGraph:(MPPGraph*)graph
       didOutputPacket:(const ::mediapipe::Packet&)packet
            fromStream:(const std::string&)streamName {
    if (streamName == kLandmarksOutputStream) {
        float hlm_pkt[HGD_HLM_PKT_LEN];
        for(int i = 0; i < HGD_HLM_PKT_LEN; ++i)
            hlm_pkt[i] = 0.0f;
        
        if (packet.IsEmpty())
            return;
        
        const auto& multi_hand_landmarks = packet.Get<std::vector<::mediapipe::NormalizedLandmarkList>>();
        hlm_pkt[HGD_HLM_PKT_NUM_HANDS_OFFSET] = (float) multi_hand_landmarks.size();
        NSLog(@"[TS:%lld] Number of hand instances with landmarks: %lu", packet.Timestamp().Microseconds(), multi_hand_landmarks.size());
        
        for (int hand_index = 0; hand_index < multi_hand_landmarks.size() && hand_index < HGD_HLM_PKT_NUM_HANDS; hand_index++) {
            const auto& landmarks = multi_hand_landmarks[hand_index];
            hlm_pkt[HGD_HLM_PKT_NUM_HAND_LANDMARKS_OFFSET + hand_index] = (float) landmarks.landmark_size();
            NSLog(@"[TS:%lld]\t Number of landmarks for hand[%d]: %d", packet.Timestamp().Microseconds(), hand_index, landmarks.landmark_size());
            
            for (int i = 0; i < landmarks.landmark_size() && i < HGD_HLM_PKT_NUM_HAND_LANDMARKS; i++) {
                int lm_index = (int)(HGD_HLM_PKT_HEADER_LEN + (hand_index * HGD_HLM_PKT_NUM_HAND_LANDMARKS * HGD_HLM_PKT_HAND_LANDMARK_LEN) + i);
                hlm_pkt[lm_index + HGD_HLM_PKT_HAND_LANDMARK_X_OFFSET] = (float) landmarks.landmark(i).x();
                hlm_pkt[lm_index + HGD_HLM_PKT_HAND_LANDMARK_Y_OFFSET] = (float) landmarks.landmark(i).y();
                hlm_pkt[lm_index + HGD_HLM_PKT_HAND_LANDMARK_Z_OFFSET] = (float) landmarks.landmark(i).z();
                NSLog(@"[TS:%lld]\t\t Landmark[%d]: (%f, %f, %f)", packet.Timestamp().Microseconds(), i, landmarks.landmark(i).x(), landmarks.landmark(i).y(), landmarks.landmark(i).z());
            }
        }
        
        if ([self.delegate respondsToSelector:@selector(handGestureDetector:didOutputHandLandmarks:)])
            [self.delegate handGestureDetector:self didOutputHandLandmarks:hlm_pkt];
    }
    else if (streamName == kHandRectsOutputStream) {
        float hrc_pkt[HGD_HRC_PKT_LEN];
        for(int i = 0; i < HGD_HRC_PKT_LEN; ++i)
            hrc_pkt[i] = 0.0f;
        
        if (packet.IsEmpty())
            return;
        
        const auto& multi_hand_rects = packet.Get<std::vector<::mediapipe::NormalizedRect>>();
        hrc_pkt[HGD_HRC_PKT_NUM_HANDS_OFFSET] = (float) multi_hand_rects.size();
        NSLog(@"[TS:%lld] Report: Number of hand rects: %lu", packet.Timestamp().Microseconds(), multi_hand_rects.size());
        
        for (int hand_index = 0; hand_index < multi_hand_rects.size() && hand_index < HGD_HLM_PKT_NUM_HANDS; hand_index++) {
            const auto& rect = multi_hand_rects[hand_index];
            int rect_index = (int)(HGD_HRC_PKT_HEADER_LEN + (hand_index * HGD_HRC_PKT_RECT_NUM_PROP));
            hrc_pkt[rect_index + HGD_HRC_PKT_RECT_ID_OFFSET] = rect.rect_id();
            hrc_pkt[rect_index + HGD_HRC_PKT_RECT_X_OFFSET] = rect.x_center();
            hrc_pkt[rect_index + HGD_HRC_PKT_RECT_Y_OFFSET] = rect.y_center();
            hrc_pkt[rect_index + HGD_HRC_PKT_RECT_W_OFFSET] = rect.width();
            hrc_pkt[rect_index + HGD_HRC_PKT_RECT_H_OFFSET] = rect.height();
            hrc_pkt[rect_index + HGD_HRC_PKT_RECT_R_OFFSET] = rect.rotation();
            NSLog(@"[TS:%lld]\t Report: Rect[%d]: (X %f, Y %f, W %f, H %f, R %f)", packet.Timestamp().Microseconds(), hand_index, rect.x_center(), rect.y_center(), rect.width(), rect.height(), rect.rotation());
        }
        
        if ([self.delegate respondsToSelector:@selector(handGestureDetector:didOutputHandRects:)])
            [self.delegate handGestureDetector:self didOutputHandRects:hrc_pkt];
    }
    else if (streamName == kPalmDetectionsOutputStream) {
        float hrc_pkt[HGD_HRC_PKT_LEN];
        for(int i = 0; i < HGD_HRC_PKT_LEN; ++i)
            hrc_pkt[i] = 0.0f;
        
        if (packet.IsEmpty())
            return;
        
        const auto& multi_palm_detections = packet.Get<std::vector<::mediapipe::Detection>>();
        hrc_pkt[HGD_HRC_PKT_NUM_HANDS_OFFSET] = (float) multi_palm_detections.size();
        NSLog(@"[TS:%lld] Report: Number of palm detections: %lu", packet.Timestamp().Microseconds(), multi_palm_detections.size());
        
        for (int hand_index = 0; hand_index < multi_palm_detections.size() && hand_index < HGD_HLM_PKT_NUM_HANDS; hand_index++) {
            const auto& bbox = multi_palm_detections[hand_index].location_data().relative_bounding_box();
            int rect_index = (int)(HGD_HRC_PKT_HEADER_LEN + (hand_index * HGD_HRC_PKT_RECT_NUM_PROP));
            hrc_pkt[rect_index + HGD_HRC_PKT_RECT_X_OFFSET] = bbox.xmin() + bbox.width() / 2;
            hrc_pkt[rect_index + HGD_HRC_PKT_RECT_Y_OFFSET] = bbox.ymin() + bbox.height() / 2;
            hrc_pkt[rect_index + HGD_HRC_PKT_RECT_W_OFFSET] = bbox.width();
            hrc_pkt[rect_index + HGD_HRC_PKT_RECT_H_OFFSET] = bbox.height();
            NSLog(@"[TS:%lld]\t Report: Location BBox Rect[%d]: (X %f, Y %f, W %f, H %f)", packet.Timestamp().Microseconds(), hand_index, hrc_pkt[rect_index + HGD_HRC_PKT_RECT_X_OFFSET], hrc_pkt[rect_index + HGD_HRC_PKT_RECT_Y_OFFSET], bbox.width(), bbox.height());
        }
        
        if ([self.delegate respondsToSelector:@selector(handGestureDetector:didOutputPalmRects:)])
            [self.delegate handGestureDetector:self didOutputPalmRects:hrc_pkt];
    }
}


@end
