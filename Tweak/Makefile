TWEAK_NAME = Soko

$(TWEAK_NAME)_FILES = $(TWEAK_NAME).S $(TWEAK_NAME).swift $(wildcard Hooks/*.swift) $(wildcard Layout/*.swift) $(wildcard Support/*.swift) $(wildcard ../Shared/*/*.swift)
$(TWEAK_NAME)_FRAMEWORKS = UIKit
$(TWEAK_NAME)_CFLAGS = -fobjc-arc

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk
