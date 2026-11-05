THEOS ?= $(HOME)/theos
THEOS_PACKAGE_SCHEME = roothide
TARGET = iphone:clang:17.0:17.0
ARCHS = arm64 arm64e
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = SpoofyCompat
SpoofyCompat_FILES = Tweak.xm SpoofyPolicy.m SpoofyConfig.m
SpoofyCompat_CFLAGS = -fobjc-arc -Wall -Wextra -fmodules-cache-path=$(THEOS_PROJECT_DIR)/build/ModuleCache
SpoofyCompat_FRAMEWORKS = Foundation UIKit
include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += Prefs
include $(THEOS_MAKE_PATH)/aggregate.mk
