#import "Esp/ImGuiDrawView.h"
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <Foundation/Foundation.h>
#include "KittyMemory/imgui.h"
#include "KittyMemory/imgui_impl_metal.h"
#import "Esp/CaptainHook.h"
#include <cmath>
#include <mach-o/dyld.h>

#define kWidth [UIScreen mainScreen].bounds.size.width
#define kHeight [UIScreen mainScreen].bounds.size.height
#define kScale [UIScreen mainScreen].scale

static int selected_category = 0;
static int selected_item_idx = 0;
static int selected_location = 0;
static int item_hue = 0;
static int item_saturation = 0;
static int item_size = 0;

struct Vec3 { float x, y, z; };

static float custom_coords[3] = { 0.0f, 0.0f, 0.0f };

static const char* locations[] = {
    "On Player (Local)", "Inside Selling Machine", "Ship / Safety Zone",
    "Loading Screen Room", "Mines / Sewers Entrance", "Custom Coordinates"
};

static const char* categories[] = {
    "Gadgets & Tools", "Weapons", "Explosives & Traps",
    "Loot (For Nuts)", "Troll / Toys"
};

static const char* gadgets[] = {
    "Flashlight", "Walkie Talkie", "Scanner", "Tablet",
    "Flaregun", "Jetpack", "Umbrella"
};

static const char* weapons[] = {
    "Baseball Bat", "Crowbar", "Police Baton",
    "Shotgun", "Revolver", "Crossbow"
};

static const char* explosives[] = {
    "Dynamite", "Sticky Bomb", "Time Bomb",
    "Tripmine", "Impact Grenade"
};

static const char* loot[] = {
    "Gold Bar", "Cash Pile", "Calculator",
    "Painting", "Ruby", "Silver Chunk", "Keycard"
};

static const char* troll[] = {
    "Whoopee Cushion", "Boombox", "Traffic Light",
    "Glowstick", "Apple", "Banana"
};

static inline int GetRealItemID(int category, int index) {
    return (category * 100) + index;
}

static inline Vec3 GetTargetCoordinates(int loc_idx) {
    Vec3 coords = {0.0f, 0.0f, 0.0f};

    if (loc_idx == 1) { coords = {15.5f, 2.0f, -10.2f}; }
    else if (loc_idx == 2) { coords.y = 5.0f; }
    else if (loc_idx == 3) { coords = {-50.0f, 10.0f, -50.0f}; }
    else if (loc_idx == 4) { coords = {100.0f, -20.0f, 50.0f}; }
    else if (loc_idx == 5) {
        coords.x = custom_coords[0];
        coords.y = custom_coords[1];
        coords.z = custom_coords[2];
    }

    return coords;
}

static inline uint64_t GetBaseAddress() {
    return (uint64_t)_dyld_get_image_header(0);
}

@interface ImGuiDrawView () <MTKViewDelegate>
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@end

@implementation ImGuiDrawView

static bool MenDeal = true;

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (!self) return nil;

    _device = MTLCreateSystemDefaultDevice();
    _commandQueue = [_device newCommandQueue];
    if (!_device) abort();

    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO();
    ImGui::StyleColorsClassic();

    NSString *FontPath = @"/System/Library/Fonts/AppFonts/Charter.ttc";
    io.Fonts->AddFontFromFileTTF(FontPath.UTF8String, 40.f, NULL,
                                io.Fonts->GetGlyphRangesChineseSimplifiedCommon());

    return self;
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    // Required by MTKViewDelegate (can stay empty)
}

- (void)drawInMTKView:(MTKView *)view {

    ImGuiIO& io = ImGui::GetIO();

    CGFloat framebufferScale =
        view.window.screen ? view.window.screen.scale : UIScreen.mainScreen.scale;

    io.DisplayFramebufferScale = ImVec2(framebufferScale, framebufferScale);
    io.DeltaTime = 1.0f / float(view.preferredFramesPerSecond ?: 60);

    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    MTLRenderPassDescriptor* renderPassDescriptor = view.currentRenderPassDescriptor;

    if (!renderPassDescriptor) {
        [commandBuffer commit];
        return;
    }

    id<MTLRenderCommandEncoder> renderEncoder =
        [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];

    ImGui_ImplMetal_NewFrame(renderPassDescriptor);
    ImGui::NewFrame();

    if (MenDeal) {
        ImGui::SetNextWindowSize(ImVec2(460, 610), ImGuiCond_FirstUseEver);
        ImGui::Begin("M1-V1 | Companion Spawner", &MenDeal);

        ImGui::Combo("Category", &selected_category, categories, IM_ARRAYSIZE(categories));

        if (selected_category == 0)
            ImGui::Combo("Item", &selected_item_idx, gadgets, IM_ARRAYSIZE(gadgets));
        else if (selected_category == 1)
            ImGui::Combo("Item", &selected_item_idx, weapons, IM_ARRAYSIZE(weapons));
        else if (selected_category == 2)
            ImGui::Combo("Item", &selected_item_idx, explosives, IM_ARRAYSIZE(explosives));
        else if (selected_category == 3)
            ImGui::Combo("Item", &selected_item_idx, loot, IM_ARRAYSIZE(loot));
        else if (selected_category == 4)
            ImGui::Combo("Item", &selected_item_idx, troll, IM_ARRAYSIZE(troll));

        ImGui::SliderInt("Hue", &item_hue, 0, 360);
        ImGui::SliderInt("Saturation", &item_saturation, 0, 255);
        ImGui::SliderInt("Size", &item_size, -5, 10);

        ImGui::Combo("Area", &selected_location, locations, IM_ARRAYSIZE(locations));

        if (selected_location == 5)
            ImGui::InputFloat3("X, Y, Z", custom_coords);

        if (ImGui::Button("SPAWN ITEM", ImVec2(-1, 52))) {
            int item_id = GetRealItemID(selected_category, selected_item_idx);
            Vec3 coords = GetTargetCoordinates(selected_location);

            uint64_t network_spawn = 0x14fA0;
            void (*BypassSpawn)(float, float, float, int, int, int, int) =
                (void (*)(float, float, float, int, int, int, int))
                (GetBaseAddress() + network_spawn);

            BypassSpawn(coords.x, coords.y, coords.z,
                        item_id, item_hue, item_saturation, item_size);
        }

        ImGui::End();
    }

    ImGui::Render();
    ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(),
                                   commandBuffer, renderEncoder);

    [renderEncoder endEncoding];
    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer commit];
}

// **Fixed missing method**
+ (void)showChange:(BOOL)open {
    MenDeal = open;
}

@end
