include ../config.mk
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = AxonReborn
AxonReborn_FILES = AXNRuntime.mm AXNRailView.m AXNListMount.mm AXNListResolver.m AXNNativeFilter.m ../Shared/AXNPreferences.m
AxonReborn_FRAMEWORKS = UIKit Foundation QuartzCore
AxonReborn_LIBRARIES = substrate
AxonReborn_CFLAGS = -fobjc-arc -Wall -Wextra
AxonReborn_CCFLAGS = -std=c++17
INSTALL_TARGET_PROCESSES = SpringBoard
include $(THEOS_MAKE_PATH)/tweak.mk
