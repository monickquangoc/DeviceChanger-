ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DCPTweak
DCPTweak_FILES = Tweak.xm
DCPTweak_FRAMEWORKS = UIKit CoreLocation AdSupport
DCPTweak_PRIVATE_FRAMEWORKS = MobileGestalt
DCPTweak_CFLAGS = -fobjc-arc
include $(THEOS_MAKE_PATH)/tweak.mk

APPLICATION_NAME = DCPApp
DCPApp_FILES = main.m AppDelegate.m RootViewController.m
DCPApp_FRAMEWORKS = UIKit CoreLocation
DCPApp_CFLAGS = -fobjc-arc
DCPApp_CODESIGN_FLAGS = -Sentitlements.plist
include $(THEOS_MAKE_PATH)/application.mk

after-install::
	install.exec "killall -9 SpringBoard"
