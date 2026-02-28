export THEOS=/var/jb/var/mobile/theos
ARCHS = arm64
DEBUG = 0
FINALPACKAGE = 1
FOR_RELEASE = 1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = GhostMenu

# source files for the tweak, case must match the TWEAK_NAME above
GhostMenu_FILES = Esp/PubgLoad.mm \
                 ImGuiDrawView.mm \
                 KittyMemory/KittyMemory.cpp \
                 KittyMemory/MemoryPatch.cpp \
                 KittyMemory/KittyUtils.cpp \
                 KittyMemory/writeData.cpp \
                 KittyMemory/imgui.cpp \
                 KittyMemory/imgui_demo.cpp \
                 KittyMemory/imgui_draw.cpp \
                 KittyMemory/imgui_tables.cpp \
                 KittyMemory/imgui_widgets.cpp \
                 KittyMemory/imgui_impl_metal.mm

GhostMenu_FRAMEWORKS = UIKit Foundation Security QuartzCore CoreGraphics CoreText Metal MetalKit

GhostMenu_CCFLAGS = -std=c++14 -fno-rtti -fno-exceptions -DNDEBUG -I./Esp -I./KittyMemory
GhostMenu_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-value -I./Esp -I./KittyMemory

# the build will automatically look for GhostMenu.plist or Filter.plist in the project root
# make sure the plist exists (see README for bundle ID information)

include $(THEOS_MAKE_PATH)/tweak.mk
