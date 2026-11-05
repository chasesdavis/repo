include $(THEOS)/makefiles/common.mk
BUNDLE_NAME = SpoofyPrefs
SpoofyPrefs_FILES = SpoofyPrefs.m ../SpoofyConfig.m
SpoofyPrefs_FRAMEWORKS = Foundation UIKit
SpoofyPrefs_PRIVATE_FRAMEWORKS = Preferences
SpoofyPrefs_INSTALL_PATH = /Library/PreferenceBundles
SpoofyPrefs_CFLAGS = -fobjc-arc -Wall -Wextra -I.. -fmodules-cache-path=$(THEOS_PROJECT_DIR)/build/ModuleCache
include $(THEOS_MAKE_PATH)/bundle.mk
internal-stage::
	$(ECHO_NOTHING)mkdir -p "$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences"$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist "$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/Spoofy.plist"$(ECHO_END)
