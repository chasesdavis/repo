THEOS ?= /Users/chase/theos
THEOS_PACKAGE_SCHEME = roothide
TARGET = iphone:clang:17.0:15.0
ARCHS = arm64 arm64e

# AppSync-style split: separate dylibs so injectors load installd reliably
INSTALL_TARGET_PROCESSES = installd appstored

include $(THEOS)/makefiles/common.mk

# Shared flags
LI_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-function
LI_FRAMEWORKS = Foundation
LI_LIBRARIES = MobileGestalt
LI_FILES = Tweak/LowerInstall.xm

TWEAK_NAME = LowerInstall LowerInstallInstalld

# Store / App Store UI + appstored daemon
LowerInstall_FILES = $(LI_FILES)
LowerInstall_CFLAGS = $(LI_CFLAGS)
LowerInstall_FRAMEWORKS = $(LI_FRAMEWORKS)
LowerInstall_LIBRARIES = $(LI_LIBRARIES)

# installd only — dedicated filter (critical for finishing updates)
LowerInstallInstalld_FILES = $(LI_FILES)
LowerInstallInstalld_CFLAGS = $(LI_CFLAGS)
LowerInstallInstalld_FRAMEWORKS = $(LI_FRAMEWORKS)
LowerInstallInstalld_LIBRARIES = $(LI_LIBRARIES)

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += Prefs
include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "killall -9 installd installcoordinationd appstored itunesstored AppStore 2>/dev/null || true"
