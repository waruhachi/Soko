export ARCHS = arm64 arm64e
export TARGET = iphone:16.5:14.0

INSTALL_TARGET_PROCESSES = SpringBoard PosterBoard Preferences

SUBPROJECTS += Tweak Preferences

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/aggregate.mk

commands::
	@jq '[.[] | select((.command | contains("-dumpversion")) | not)]' compile_commands.json > .theos/compile_commands.clean.json
	@mv .theos/compile_commands.clean.json compile_commands.json