ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DCPTweak
DCPTweak_FILES = Tweak.xm WebKitSpoofer.xm
DCPTweak_FRAMEWORKS = UIKit CoreLocation AdSupport WebKit CoreTelephony SystemConfiguration
DCPTweak_PRIVATE_FRAMEWORKS = IOKit
DCPTweak_CFLAGS = -fobjc-arc
include $(THEOS_MAKE_PATH)/tweak.mk

APPLICATION_NAME = DCPApp
DCPApp_FILES = main.m AppDelegate.m RootViewController.m
DCPApp_FRAMEWORKS = UIKit CoreLocation
DCPApp_CFLAGS = -fobjc-arc
DCPApp_CODESIGN_FLAGS = -Sentitlements.plist
include $(THEOS_MAKE_PATH)/application.mk
