include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = StayOn17Prefs

StayOn17Prefs_FILES = StayOn17Prefs.mm ../SO17Prefs.m
StayOn17Prefs_FRAMEWORKS = UIKit
StayOn17Prefs_PRIVATE_FRAMEWORKS = Preferences
StayOn17Prefs_INSTALL_PATH = /Library/PreferenceBundles
StayOn17Prefs_CFLAGS = -fobjc-arc -I..

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/StayOn17.plist$(ECHO_END)
