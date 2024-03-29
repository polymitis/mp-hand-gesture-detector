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
    "ios_application",
    "ios_framework",
)

licenses(["notice"]) # MIT

MIN_IOS_VERSION = "11.0"

ios_application(
    name = "HandGestureDetectorApp",
    app_icons = [
        "Assets.xcassets/AppIcon.appiconset/Icon-60@2x.png",
        ],
    bundle_id = "com.polymitis.ios.handgesturedetector.app",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = ["AppInfo.plist"],
    minimum_os_version = MIN_IOS_VERSION,
    provisioning_profile = ":provisioning_profile.mobileprovision",
    deps = [
        ":HandGestureDetectorAppLib",
    ],
)

ios_framework(
    name = "HandGestureDetector",
    bundle_id = "com.polymitis.ios.handgesturedetector.framework",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = ["FrameworkInfo.plist"],
    minimum_os_version = MIN_IOS_VERSION,
    hdrs = [
        "HandGestureDetector.h",
    ],
    deps = [":HandGestureDetectorLib"],
)

objc_library(
    name = "HandGestureDetectorAppLib",
    srcs = [
        "AppDelegate.m",
        "ViewController.mm",
        "main.m",
    ],
    hdrs = [
        "AppDelegate.h",
        "ViewController.h",
    ],
    data = [
        "Base.lproj/LaunchScreen.storyboard",
        "Base.lproj/Main.storyboard",
    ],
    sdk_frameworks = [
        "AVFoundation",
        "CoreGraphics",
        "CoreMedia",
        "UIKit",
    ],
    deps = [
        "//mediapipe/objc:mediapipe_input_sources_ios",
        "//mediapipe/objc:mediapipe_layer_renderer",
	":HandGestureDetectorLib",
    ],
)

objc_library(
    name = "HandGestureDetectorLib",
    hdrs = [
        "HandGestureDetector.h",
    ],
    srcs = [
        "HandGestureDetector.mm",
    ],
    copts = [
        "-std=c++17"
    ],
    data = [
        "//mediapipe/graphs/hand_tracking:hand_tracking_mobile_gpu.binarypb",
        "//mediapipe/modules/hand_landmark:hand_landmark_full.tflite",
        "//mediapipe/modules/hand_landmark:handedness.txt",
        "//mediapipe/modules/palm_detection:palm_detection.tflite",
    ],
    sdk_frameworks = [
        "AVFoundation",
        "CoreGraphics",
        "CoreMedia",
        "UIKit",
    ],
    deps = [
        "//mediapipe/objc:mediapipe_framework_ios",
        "//mediapipe/graphs/hand_tracking:mobile_calculators",
        "//mediapipe/framework/formats:landmark_cc_proto",
        "@ios_opencv//:OpencvFramework",
    ],
)
