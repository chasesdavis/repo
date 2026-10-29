THEOS ?= /Users/chase/theos
THEOS_PACKAGE_SCHEME = roothide
TARGET = iphone:clang:16.5:15.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Lumen
Lumen_FILES = Tweak.xm LumenPrefs.m LumenPill.m LumenProviders.m LumenCard.m
Lumen_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
Lumen_FRAMEWORKS = UIKit Foundation QuartzCore MessageUI

include $(THEOS_MAKE_PATH)/tweak.mk

BUNDLE_NAME = LumenPrefs
LumenPrefs_FILES = Prefs/LumenPrefsController.m LumenPrefs.m
LumenPrefs_CFLAGS = -fobjc-arc -I.
LumenPrefs_FRAMEWORKS = UIKit Foundation
LumenPrefs_PRIVATE_FRAMEWORKS = Preferences
LumenPrefs_INSTALL_PATH = /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk
