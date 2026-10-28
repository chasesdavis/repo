THEOS ?= /Users/chase/theos
THEOS_PACKAGE_SCHEME = roothide
TARGET = iphone:clang:17.0:17.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = StayOn17 StayOn17Installd

SO17_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-function -I.
SO17_FILES = Tweak/StayOn17.xm SO17Prefs.m SO17Spoof.m
SO17_FRAMEWORKS = Foundation UIKit
SO17_LIBRARIES = MobileGestalt

StayOn17_FILES = $(SO17_FILES)
StayOn17_CFLAGS = $(SO17_CFLAGS)
StayOn17_FRAMEWORKS = $(SO17_FRAMEWORKS)
StayOn17_LIBRARIES = $(SO17_LIBRARIES)
StayOn17_PLIST = StayOn17.plist

StayOn17Installd_FILES = $(SO17_FILES)
StayOn17Installd_CFLAGS = $(SO17_CFLAGS)
StayOn17Installd_FRAMEWORKS = $(SO17_FRAMEWORKS)
StayOn17Installd_LIBRARIES = $(SO17_LIBRARIES)
StayOn17Installd_PLIST = StayOn17Installd.plist

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += Prefs tools/stayon17-scan
include $(THEOS_MAKE_PATH)/aggregate.mk

before-package::
	@mkdir -p $(THEOS_STAGING_DIR)/Library/ApplicationSupport/StayOn17
	@cp Resources/ios18_frameworks.json $(THEOS_STAGING_DIR)/Library/ApplicationSupport/StayOn17/ios18_frameworks.json

after-install::
	install.exec "killall -9 installd installcoordinationd appstored itunesstored AppStore 2>/dev/null || true"
