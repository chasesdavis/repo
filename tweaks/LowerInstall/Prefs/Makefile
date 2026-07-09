include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = LowerInstallPrefs

LowerInstallPrefs_FILES = LowerInstallPrefs.mm
LowerInstallPrefs_FRAMEWORKS = UIKit
LowerInstallPrefs_PRIVATE_FRAMEWORKS = Preferences
LowerInstallPrefs_INSTALL_PATH = /Library/PreferenceBundles
LowerInstallPrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/LowerInstall.plist$(ECHO_END)
