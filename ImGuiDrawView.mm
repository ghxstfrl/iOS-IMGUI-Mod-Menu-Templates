#import "Esp/ImGuiDrawView.h"
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <Foundation/Foundation.h>
#include "KittyMemory/imgui.h"
#include "KittyMemory/imgui_impl_metal.h"
#import "Esp/CaptainHook.h"
#import <cmath>
#import <mach-o/dyld.h>

#define kWidth [UIScreen mainScreen].bounds.size.width
#define kHeight [UIScreen mainScreen].bounds.size.height

// Item selection
static int selected_category = 0;
static int selected_item_idx = 0;
static int selected_location = 0;
static int item_hue = 0;
static int item_saturation = 0;
static int item_size = 0;
static struct Vec3 { float x, y, z; } custom_coords = {0.0f, 0.0f, 0.0f};

// Static bool for ImGui window
static bool menuVisible = false;
static ImVec2 menuPos = ImVec2(100, 100);

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

static inline struct Vec3 GetTargetCoordinates(int loc_idx) {
    struct Vec3 coords = {0.0f, 0.0f, 0.0f};
    if (loc_idx == 1) coords = (struct Vec3){15.5f, 2.0f, -10.2f};
    else if (loc_idx == 2) coords.y = 5.0f;
    else if (loc_idx == 3) coords = (struct Vec3){-50.0f, 10.0f, -50.0f};
    else if (loc_idx == 4) coords = (struct Vec3){100.0f, -20.0f, 50.0f};
    else if (loc_idx == 5) coords = custom_coords;
    return coords;
}

static inline uint64_t GetBaseAddress() {
    return (uint64_t)_dyld_get_image_header(0);
}

@interface ImGuiDrawView () <MTKViewDelegate>
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, assign) BOOL imguiInitialized;
@end

@implementation ImGuiDrawView

// Restore old interface so other files still compile
+ (void)showChange:(BOOL)open {
    menuVisible = open;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (!self) return nil;

    self.device = MTLCreateSystemDefaultDevice();
    self.commandQueue = [self.device newCommandQueue];
    if (!self.device) abort();

    // Pass touches to app
    self.view.userInteractionEnabled = NO;

    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO();
    io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;
    ImGui::StyleColorsDark();

    ImGuiStyle& style = ImGui::GetStyle();
    style.WindowRounding = 10.0f;
    style.FrameRounding = 6.0f;
    style.ScrollbarRounding = 6.0f;
    style.GrabRounding = 6.0f;
    style.FramePadding = ImVec2(10, 6);
    style.WindowPadding = ImVec2(12, 12);
    style.Colors[ImGuiCol_WindowBg] = ImVec4(0.15f, 0.0f, 0.25f, 0.95f);
    style.Colors[ImGuiCol_Button] = ImVec4(0.6f, 0.2f, 1.0f, 0.9f);
    style.Colors[ImGuiCol_ButtonHovered] = ImVec4(0.8f, 0.4f, 1.0f, 0.95f);
    style.Colors[ImGuiCol_ButtonActive] = ImVec4(0.9f, 0.6f, 1.0f, 1.0f);
    style.Colors[ImGuiCol_SliderGrab] = ImVec4(0.7f, 0.3f, 1.0f, 1.0f);
    style.Colors[ImGuiCol_SliderGrabActive] = ImVec4(0.9f, 0.5f, 1.0f, 1.0f);
    style.Colors[ImGuiCol_Header] = ImVec4(0.5f, 0.1f, 0.9f, 0.9f);
    style.Colors[ImGuiCol_HeaderHovered] = ImVec4(0.7f, 0.3f, 1.0f, 0.95f);

    ImGui_ImplMetal_Init(self.device);

    NSString *FontPath = @"/System/Library/Fonts/AppFonts/Charter.ttc";
    io.Fonts->AddFontFromFileTTF(FontPath.UTF8String, 22.f);

    self.imguiInitialized = YES;
    return self;
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {}

- (void)drawInMTKView:(MTKView *)view {
    if (!self.imguiInitialized) return;

    ImGuiIO& io = ImGui::GetIO();
    io.DisplaySize = ImVec2(view.bounds.size.width, view.bounds.size.height);
    io.DisplayFramebufferScale = ImVec2(view.contentScaleFactor, view.contentScaleFactor);
    io.DeltaTime = 1.0f / float(view.preferredFramesPerSecond ?: 60);

    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    MTLRenderPassDescriptor* renderPassDescriptor = view.currentRenderPassDescriptor;
    if (!renderPassDescriptor) { [commandBuffer commit]; return; }

    id<MTLRenderCommandEncoder> renderEncoder =
        [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];

    ImGui_ImplMetal_NewFrame(renderPassDescriptor);
    ImGui::NewFrame();

    // Floating toggle button
    ImGui::SetNextWindowPos(ImVec2(20, 20), ImGuiCond_Always);
    ImGui::SetNextWindowBgAlpha(0.6f);
    if (ImGui::Begin("ToggleButton", NULL,
                     ImGuiWindowFlags_NoTitleBar |
                     ImGuiWindowFlags_NoResize |
                     ImGuiWindowFlags_AlwaysAutoResize |
                     ImGuiWindowFlags_NoMove |
                     ImGuiWindowFlags_NoSavedSettings |
                     ImGuiWindowFlags_NoScrollbar)) {

        if (ImGui::Button(menuVisible ? "CLOSE MENU" : "OPEN MENU", ImVec2(120, 40))) {
            menuVisible = !menuVisible;
        }
    }
    ImGui::End();

    // Main menu
    if (menuVisible) {
        ImGui::SetNextWindowPos(menuPos, ImGuiCond_FirstUseEver);
        ImGui::SetNextWindowSize(ImVec2(460, 610), ImGuiCond_FirstUseEver);
        ImGui::SetNextWindowBgAlpha(0.95f);

        if (ImGui::Begin("M1-V1 | Companion Spawner", &menuVisible,
                         ImGuiWindowFlags_NoSavedSettings | ImGuiWindowFlags_NoCollapse |
                         ImGuiWindowFlags_NoBringToFrontOnFocus)) {

            menuPos = ImGui::GetWindowPos();

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
                ImGui::InputFloat3("X, Y, Z", (float*)&custom_coords);

            if (ImGui::Button("SPAWN ITEM", ImVec2(-1, 52))) {
                int item_id = GetRealItemID(selected_category, selected_item_idx);
                struct Vec3 coords = GetTargetCoordinates(selected_location);

                uint64_t network_spawn = 0x14fA0;
                void (*BypassSpawn)(float, float, float, int, int, int, int) =
                (void (*)(float, float, float, int, int, int, int))
                (GetBaseAddress() + network_spawn);

                BypassSpawn(coords.x, coords.y, coords.z,
                            item_id, item_hue, item_saturation, item_size);
            }

            // Credit text
            ImGui::SetCursorPosY(ImGui::GetWindowHeight() - 25);
            ImGui::TextColored(ImVec4(0.8f, 0.5f, 1.0f, 1.0f), "Created by GhxstFRL");
        }
        ImGui::End();
    }

    io.WantCaptureMouse = false;

    ImGui::Render();
    ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), commandBuffer, renderEncoder);

    [renderEncoder endEncoding];
    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer commit];
}

@end
