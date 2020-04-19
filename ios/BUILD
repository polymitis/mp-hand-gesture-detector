# MIT License
#
# Copyright (c) 2020 Petros Fountas
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

load(
    "@build_bazel_rules_apple//apple:ios.bzl",
    "ios_framework",
)

licenses(["notice"]) # MIT

MIN_IOS_VERSION = "11.0"

genrule(
    name = "model",
    srcs = [
        "//mediapipe/models:hand_landmark_3d.tflite"
    ],
    outs = [
        "hand_landmark.tflite"
    ],
    cmd = "cp $< $@",
)

ios_framework(
    name = "HandGestureDetector",
    bundle_id = "com.polymitis.framework.handgesturedetector",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = ["Info.plist"],
    minimum_os_version = MIN_IOS_VERSION,
    hdrs = [
        "HandGestureDetector.h",
    ],
    deps = [":HandGestureDetectorLib"],
)

objc_library(
    name = "HandGestureDetectorLib",
    hdrs = [
        "HandGestureDetector.h",
    ],
    srcs = [
        "HandGestureDetector.mm",
    ],
    data = [
        ":model",
        "//mediapipe/graphs/hand_tracking:multi_hand_tracking_mobile_gpu_binary_graph",
        "//mediapipe/models:palm_detection.tflite",
        "//mediapipe/models:palm_detection_labelmap.txt",
    ],
    sdk_frameworks = [
        "AVFoundation",
        "CoreGraphics",
        "CoreMedia",
        "UIKit",
    ],
    deps = [
        "//mediapipe/objc:mediapipe_framework_ios",
        "//mediapipe/objc:mediapipe_input_sources_ios",
        "//mediapipe/objc:mediapipe_layer_renderer",
        "//mediapipe/graphs/hand_tracking:multi_hand_mobile_calculators",
        "//mediapipe/framework/formats:landmark_cc_proto",
        "@ios_opencv//:OpencvFramework",
    ],
)
