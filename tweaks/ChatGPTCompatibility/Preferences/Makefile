include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = ChatGPTCompatibilityPrefs
ChatGPTCompatibilityPrefs_FILES = Controller.m ../CompatPolicy.m
ChatGPTCompatibilityPrefs_FRAMEWORKS = UIKit Foundation
ChatGPTCompatibilityPrefs_PRIVATE_FRAMEWORKS = Preferences
ChatGPTCompatibilityPrefs_INSTALL_PATH = /Library/PreferenceBundles
ChatGPTCompatibilityPrefs_CFLAGS = -fobjc-arc -Wall -Wextra -Wno-unused-parameter -Werror

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/ChatGPTCompatibility.plist$(ECHO_END)
