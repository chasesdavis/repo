include $(THEOS)/makefiles/common.mk
BUNDLE_NAME = HarborPrefs
HarborPrefs_FILES = HBPreferencesController.m ../HBPreferences.m
HarborPrefs_CFLAGS = -fobjc-arc -Wall -Wextra -Wno-unused-parameter -I..
HarborPrefs_FRAMEWORKS = UIKit Foundation
HarborPrefs_PRIVATE_FRAMEWORKS = Preferences
HarborPrefs_INSTALL_PATH = /Library/PreferenceBundles
HarborPrefs_RESOURCE_DIRS = Resources
include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/Harbor.plist$(ECHO_END)
