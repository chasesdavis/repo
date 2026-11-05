THEOS ?= /Users/chase/theos
THEOS_PACKAGE_SCHEME = roothide
TARGET = iphone:clang:17.0:17.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Harbor
Harbor_FILES = Tweak.xm HBSession.m HBNativeControls.m HBDashboardController.m HBMediaProvider.m HBPreferences.m HBProfileModel.m HBProfileStore.m HBTheme.m HBFocusMonitor.m HBProfileEditorController.m HBPolicy.c
Harbor_CFLAGS = -fobjc-arc -Wall -Wextra -Wno-unused-parameter
Harbor_FRAMEWORKS = UIKit Foundation QuartzCore MediaPlayer ImageIO AVKit

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += Prefs
include $(THEOS_MAKE_PATH)/aggregate.mk
