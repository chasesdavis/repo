THEOS ?= /Users/chase/theos
THEOS_PACKAGE_SCHEME = roothide
# Pin SDK so Preferences private framework is available
TARGET = iphone:clang:17.0:15.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = installd appstored itunesstored

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = LowerInstall

LowerInstall_FILES = Tweak/LowerInstall.xm
LowerInstall_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-function
LowerInstall_FRAMEWORKS = Foundation

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += Prefs
include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "killall -9 installd appstored itunesstored 2>/dev/null || true"
