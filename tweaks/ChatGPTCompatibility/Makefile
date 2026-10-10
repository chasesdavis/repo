THEOS ?= /Users/chase/theos
THEOS_PACKAGE_SCHEME = roothide
TARGET = iphone:clang:17.0:17.0
ARCHS = arm64 arm64e
export CLANG_MODULE_CACHE_PATH := $(CURDIR)/.theos/module-cache

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ChatGPTCompatibility
ChatGPTCompatibility_FILES = Tweak.m CompatPolicy.m MethodTypes.m
ChatGPTCompatibility_CFLAGS = -fobjc-arc -Wall -Wextra -Wno-unused-parameter -Werror
ChatGPTCompatibility_FRAMEWORKS = Foundation
ChatGPTCompatibility_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS = Preferences
include $(THEOS_MAKE_PATH)/aggregate.mk
