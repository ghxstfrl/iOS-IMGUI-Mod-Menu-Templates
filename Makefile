export THEOS=/var/jb/var/mobile/theos
ARCHS = arm64
DEBUG = 0
FINALPACKAGE = 1
FOR_RELEASE = 1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = GhostMenu

# GhostMenu slim build; only core ImGui files are compiled
GHOSTMENU_FILES = Esp/PubgLoad.mm \
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

GHOSTMENU_FRAMEWORKS = UIKit Foundation Security QuartzCore CoreGraphics CoreText Metal MetalKit

GHOSTMENU_CCFLAGS = -std=c++14 -fno-rtti -fno-exceptions -DNDEBUG -I./Esp -I./KittyMemory
GHOSTMENU_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-value -I./Esp -I./KittyMemory

include $(THEOS_MAKE_PATH)/tweak.mk
