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
#define kTest 0
#define g 0.86602540378444
// --- ANIMAL COMPANY SPAWNER GLOBALS ---
// Added "static" to everything to prevent Theos "missing prototype" build crashes!
static int selected_category = 0;
static int selected_item_idx = 0;
static int selected_location = 0;
static int item_hue = 0;
static int item_saturation = 0;
static int item_size = 0;
struct Vec3 { float x, y, z; };
static float custom_coords[3] = { 0.0f, 0.0f, 0.0f };
static const char* locations[] = { "On Player (Local)", "Inside Selling Machine", "Ship / Safety Zone", "Loading Screen Room", "Mines / Sewers Entrance", "Custom Coordinates" };
static const char* categories[] = { "Gadgets & Tools", "Weapons", "Explosives & Traps", "Loot (For Nuts)", "Troll / Toys" };
static const char* gadgets[] = { "Flashlight", "Walkie Talkie", "Scanner", "Tablet", "Flaregun", "Jetpack", "Umbrella" };
static const char* weapons[] = { "Baseball Bat", "Crowbar", "Police Baton", "Shotgun", "Revolver", "Crossbow" };
static const char* explosives[] = { "Dynamite", "Sticky Bomb", "Time Bomb", "Tripmine", "Impact Grenade" };
static const char* loot[] = { "Gold Bar", "Cash Pile", "Calculator", "Painting", "Ruby", "Silver Chunk", "Keycard" };
static const char* troll[] = { "Whoopee Cushion", "Boombox", "Traffic Light", "Glowstick", "Apple", "Banana" };
static inline int GetRealItemID(int category, int index) { return (category * 100) + index; }
static inline Vec3 GetTargetCoordinates(int loc_idx) {
    Vec3 coords;
    coords.x = 0.0f; coords.y = 0.0f; coords.z = 0.0f; // Safe C++ initialization
    
    if (loc_idx == 1) { coords.x = 15.5f; coords.y = 2.0f; coords.z = -10.2f; }
    else if (loc_idx == 2) { coords.y = 5.0f; }
    else if (loc_idx == 3) { coords.x = -50.0f; coords.y = 10.0f; coords.z = -50.0f; }
    else if (loc_idx == 4) { coords.x = 100.0f; coords.y = -20.0f; coords.z = 50.0f; }
    else if (loc_idx == 5) { coords.x = custom_coords[0]; coords.y = custom_coords[1]; coords.z = custom_coords[2]; }
    
    return coords;
}
static inline uint64_t GetBaseAddress() {
    return (uint64_t)_dyld_get_image_header(0);
}
// --- M1-V1 MODERN THEME ---
static void SetupM1V1Theme() {
     ImGuiStyle& style = ImGui::GetStyle(); // Removed C++11 'auto' keyword
     style.WindowPadding = ImVec2(15, 15);
     style.WindowRounding = 12.0f;
     style.FramePadding = ImVec2(8, 6);
     style.FrameRounding = 6.0f;
     style.ItemSpacing = ImVec2(10, 10);
     style.GrabRounding = 4.0f;
 style.ScrollbarRounding = 8.0f;
 style.ChildRounding = 10.0f;
 style.PopupRounding = 10.0f;
    
     ImVec4* colors = style.Colors;
 colors[ImGuiCol_WindowBg] = ImVec4(0.03f, 0.05f, 0.10f, 0.97f);
 colors[ImGuiCol_TitleBg] = ImVec4(0.08f, 0.09f, 0.18f, 1.00f);
 colors[ImGuiCol_TitleBgActive] = ImVec4(0.14f, 0.10f, 0.26f, 1.00f);
 colors[ImGuiCol_FrameBg] = ImVec4(0.07f, 0.08f, 0.16f, 1.00f);
 colors[ImGuiCol_FrameBgHovered] = ImVec4(0.14f, 0.12f, 0.30f, 1.00f);
 colors[ImGuiCol_FrameBgActive] = ImVec4(0.19f, 0.15f, 0.38f, 1.00f);
 colors[ImGuiCol_Button] = ImVec4(0.15f, 0.20f, 0.45f, 1.00f);
 colors[ImGuiCol_ButtonHovered] = ImVec4(0.23f, 0.28f, 0.60f, 1.00f);
 colors[ImGuiCol_ButtonActive] = ImVec4(0.34f, 0.24f, 0.68f, 1.00f);
 colors[ImGuiCol_SliderGrab] = ImVec4(0.45f, 0.60f, 0.95f, 1.00f);
 colors[ImGuiCol_CheckMark] = ImVec4(0.60f, 0.40f, 0.95f, 1.00f);
 colors[ImGuiCol_Border] = ImVec4(0.30f, 0.24f, 0.55f, 0.80f);
 colors[ImGuiCol_Separator] = ImVec4(0.28f, 0.30f, 0.58f, 0.95f);
 colors[ImGuiCol_Header] = ImVec4(0.16f, 0.18f, 0.44f, 0.95f);
 colors[ImGuiCol_HeaderHovered] = ImVec4(0.25f, 0.26f, 0.57f, 1.00f);
 colors[ImGuiCol_HeaderActive] = ImVec4(0.32f, 0.24f, 0.62f, 1.00f);
 colors[ImGuiCol_Text] = ImVec4(0.96f, 0.97f, 1.00f, 1.00f);
 }
 @interface ImGuiDrawView () <MTKViewDelegate>
 @property (nonatomic, strong) id <MTLDevice> device;
 @property (nonatomic, strong) id <MTLCommandQueue> commandQueue;
 @end
 @implementation ImGuiDrawView
 static bool MenDeal = true;
 - (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil
 {
     self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
     _device = MTLCreateSystemDefaultDevice();
     _commandQueue = [_device newCommandQueue];
     if (!self.device) abort();
     IMGUI_CHECKVERSION();
     ImGui::CreateContext();
     ImGuiIO& io = ImGui::GetIO(); (void)io;
     ImGui::StyleColorsClassic();
    
     NSString *FontPath = @"/System/Library/Fonts/AppFonts/Charter.ttc";
     io.Fonts->AddFontFromFileTTF(FontPath.UTF8String, 40.f,NULL,io.Fonts->GetGlyphRangesChineseSimplifiedCommon());
     - (void)drawInMTKView:(MTKView*)view
{
    CGFloat framebufferScale = view.window.screen.scale ?: UIScreen.mainScreen.scale;
     CGFloat framebufferScale = view.window.screen.scale ?: UIScreen.mainScreen.scale;
     io.DisplayFramebufferScale = ImVec2(framebufferScale, framebufferScale);
     io.DeltaTime = 1 / float(view.preferredFramesPerSecond ?: 60);
    
     id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    
     if (MenDeal == true) {
         [self.view setUserInteractionEnabled:YES];
     } else {
         [self.view setUserInteractionEnabled:NO];
     }
     MTLRenderPassDescriptor* renderPassDescriptor = view.currentRenderPassDescriptor;
     if (renderPassDescriptor != nil)
     {
         id <MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
         [renderEncoder pushDebugGroup:@"ImGui Jane"];
         ImGui_ImplMetal_NewFrame(renderPassDescriptor);
         ImGui::NewFrame();
        
         ImFont* font = ImGui::GetFont();
         font->Scale = 15.f / font->FontSize;
         static bool theme_applied = false;
 if (!theme_applied) { SetupM1V1Theme(); theme_applied = true; }
        
 // --- M1-V1 SPAWNER MENU ---
         if (MenDeal == true)
 {
 ImGui::SetNextWindowSize(ImVec2(460, 610), ImGuiCond_FirstUseEver);
 ImGui::Begin("M1-V1 | Companion Spawner", &MenDeal, ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoSavedSettings);

 float t = ImGui::GetTime();
 ImVec4 pulse = ImVec4(0.45f + 0.15f * sinf(t * 1.8f), 0.60f + 0.12f * sinf(t * 1.5f + 1.0f), 1.0f, 1.0f);
 ImGui::TextColored(pulse, "M1-V1 // Blue Black Purple");
             ImGui::Separator();
             ImGui::Spacing();
 ImGui::BeginChild("##selector", ImVec2(0, 180), true);
 ImGui::TextColored(ImVec4(0.75f, 0.75f, 0.92f, 1.0f), "1) Select item group");
 ImGui::Combo("Category", &selected_category, categories, IM_ARRAYSIZE(categories));
 if (selected_category == 0) ImGui::Combo("Item", &selected_item_idx, gadgets, IM_ARRAYSIZE(gadgets));
 if (selected_category == 1) ImGui::Combo("Item", &selected_item_idx, weapons, IM_ARRAYSIZE(weapons));
 if (selected_category == 2) ImGui::Combo("Item", &selected_item_idx, explosives, IM_ARRAYSIZE(explosives));
 if (selected_category == 3) ImGui::Combo("Item", &selected_item_idx, loot, IM_ARRAYSIZE(loot));
 if (selected_category == 4) ImGui::Combo("Item", &selected_item_idx, troll, IM_ARRAYSIZE(troll));
 ImGui::EndChild();
 ImGui::Spacing();
 ImGui::BeginChild("##style", ImVec2(0, 155), true);
 ImGui::TextColored(ImVec4(0.75f, 0.75f, 0.92f, 1.0f), "2) Item style");
 ImGui::SliderInt("Hue", &item_hue, 0, 360);
 ImGui::SliderInt("Saturation", &item_saturation, 0, 255);
 ImGui::SliderInt("Size", &item_size, -5, 10);
 ImGui::EndChild();
 ImGui::Spacing();
 ImGui::BeginChild("##location", ImVec2(0, 120), true);
 ImGui::TextColored(ImVec4(0.75f, 0.75f, 0.92f, 1.0f), "3) Spawn location");
 ImGui::Combo("Area", &selected_location, locations, IM_ARRAYSIZE(locations));
 if (selected_location == 5) {
 ImGui::InputFloat3("X, Y, Z", custom_coords);
 }
 ImGui::EndChild();

 ImGui::Spacing();
 ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0.16f, 0.29f, 0.67f, 1.0f));
 ImGui::PushStyleColor(ImGuiCol_ButtonHovered, ImVec4(0.26f, 0.38f, 0.79f, 1.0f));
 ImGui::PushStyleColor(ImGuiCol_ButtonActive, ImVec4(0.35f, 0.26f, 0.78f, 1.0f));
 if (ImGui::Button("SPAWN ITEM", ImVec2(-1, 52))) {
 int item_id = GetRealItemID(selected_category, selected_item_idx);
 Vec3 coords = GetTargetCoordinates(selected_location);

 uint64_t network_spawn = 0x14fA0;
 void (*BypassSpawn)(float, float, float, int, int, int, int) =
 (void (*)(float, float, float, int, int, int, int))(GetBaseAddress() + network_spawn);

 BypassSpawn(coords.x, coords.y, coords.z, item_id, item_hue, item_saturation, item_size);
             }
 ImGui::PopStyleColor(3);
             ImGui::End();
         }
        
         ImDrawList* draw_list = ImGui::GetBackgroundDrawList();
         (void)draw_list; // This completely prevents the unused variable build crash!
         ImGui::Render();
         ImDrawData* draw_data = ImGui::GetDrawData();
         ImGui_ImplMetal_RenderDrawData(draw_data, commandBuffer, renderEncoder);
      
         [renderEncoder popDebugGroup];
         [renderEncoder endEncoding];
         [commandBuffer presentDrawable:view.currentDrawable];
     }
     [commandBuffer commit];
 }
 - (void)mtkView:(MTKView*)view drawableSizeWillChange:(CGSize)size { }}
 @end
