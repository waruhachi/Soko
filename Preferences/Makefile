BUNDLE_NAME = SokoPreferences

$(BUNDLE_NAME)_FILES = $(wildcard Controllers/*.swift) $(wildcard ../Shared/Preferences/*.swift)
$(BUNDLE_NAME)_CFLAGS = -fobjc-arc
$(BUNDLE_NAME)_FRAMEWORKS = UIKit
$(BUNDLE_NAME)_PRIVATE_FRAMEWORKS = Preferences
$(BUNDLE_NAME)_INSTALL_PATH = /Library/PreferenceBundles

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/bundle.mk