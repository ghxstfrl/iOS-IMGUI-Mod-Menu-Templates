#import "Esp/ImGuiDrawView.h"
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <Foundation/Foundation.h>
#include "KittyMemory/imgui.h"
#include "KittyMemory/imgui_impl_metal.h"
#import "Esp/CaptainHook.h"
#import "x2nios.h"
#include <cmath>
#include <mach-o/dyld.h> 

#define kWidth  [UIScreen mainScreen].bounds.size.width
#define kHeight [UIScreen mainScreen].bounds.size.height
#define kScale [UIScreen mainScreen].scale
#define kTest   0 
#define g 0.86602540378444 

// --- ANIMAL COMPANY SPAWNER GLOBALS ---
// Added "static" to everything to prevent Theos "missing prototype" build crashes!
static int current_tab = 0;
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

// --- PREMIUM MENU THEME ---
static void SetupPremiumTheme() {
    ImGuiStyle& style = ImGui::GetStyle(); // Removed C++11 'auto' keyword
    style.WindowPadding = ImVec2(15, 15);
    style.WindowRounding = 12.0f;
    style.FramePadding = ImVec2(8, 6);
    style.FrameRounding = 6.0f;
    style.ItemSpacing = ImVec2(10, 10);
    style.GrabRounding = 4.0f;
    
    ImVec4* colors = style.Colors;
    colors[ImGuiCol_WindowBg]       = ImVec4(0.06f, 0.06f, 0.06f, 0.98f);
    colors[ImGuiCol_FrameBg]        = ImVec4(0.12f, 0.12f, 0.12f, 1.00f);
    colors[ImGuiCol_FrameBgHovered] = ImVec4(0.20f, 0.15f, 0.30f, 1.00f);
    colors[ImGuiCol_FrameBgActive]  = ImVec4(0.30f, 0.20f, 0.50f, 1.00f);
    colors[ImGuiCol_Button]         = ImVec4(0.18f, 0.11f, 0.27f, 1.00f);
    colors[ImGuiCol_ButtonHovered]  = ImVec4(0.34f, 0.21f, 0.51f, 1.00f);
    colors[ImGuiCol_ButtonActive]   = ImVec4(0.44f, 0.28f, 0.66f, 1.00f);
    colors[ImGuiCol_SliderGrab]     = ImVec4(0.55f, 0.35f, 0.83f, 1.00f);
    colors[ImGuiCol_Text]           = ImVec4(0.95f, 0.95f, 0.95f, 1.00f);
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
    
    ImGui_ImplMetal_Init(_device);
    return self;
}

+ (void)showChange:(BOOL)open { MenDeal = open; }

- (MTKView *)mtkView { return (MTKView *)self.view; }

- (void)loadView
{
    CGFloat w = [UIApplication sharedApplication].windows[0].rootViewController.view.frame.size.width;
    CGFloat h = [UIApplication sharedApplication].windows[0].rootViewController.view.frame.size.height;
    self.view = [[MTKView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.mtkView.device = self.device;
    self.mtkView.delegate = self;
    self.mtkView.clearColor = MTLClearColorMake(0, 0, 0, 0);
    self.mtkView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0];
    self.mtkView.clipsToBounds = YES;
}

#pragma mark - Interaction
- (void)updateIOWithTouchEvent:(UIEvent *)event
{
    UITouch *anyTouch = event.allTouches.anyObject;
    CGPoint touchLocation = [anyTouch locationInView:self.view];
    ImGuiIO &io = ImGui::GetIO();
    io.MousePos = ImVec2(touchLocation.x, touchLocation.y);

    BOOL hasActiveTouch = NO;
    for (UITouch *touch in event.allTouches) {
        if (touch.phase != UITouchPhaseEnded && touch.phase != UITouchPhaseCancelled) {
            hasActiveTouch = YES; break;
        }
    }
    io.MouseDown[0] = hasActiveTouch;
}
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateIOWithTouchEvent:event]; }
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateIOWithTouchEvent:event]; }
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateIOWithTouchEvent:event]; }
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateIOWithTouchEvent:event]; }

#pragma mark - MTKViewDelegate
- (void)drawInMTKView:(MTKView*)view
{
    ImGuiIO& io = ImGui::GetIO();
    io.DisplaySize.x = view.bounds.size.width;
    io.DisplaySize.y = view.bounds.size.height;
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
        if (!theme_applied) { SetupPremiumTheme(); theme_applied = true; }
        
        // --- ANIMAL COMPANY MENU ---
        if (MenDeal == true)
        {                
            ImGui::SetNextWindowSize(ImVec2(450, 580), ImGuiCond_FirstUseEver);
            ImGui::Begin("ANIMAL COMPANY BYPASS", &MenDeal, ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoSavedSettings);
            
            float time = ImGui::GetTime();
            ImVec4 rgb = ImVec4(sinf(time * 2.0f) * 0.5f + 0.5f, sinf(time * 2.0f + 2.0f) * 0.5f + 0.5f, sinf(time * 2.0f + 4.0f) * 0.5f + 0.5f, 1.0f);
            ImGui::TextColored(rgb, "XMOD INTERNAL BYPASS v1.48");
            ImGui::Separator();
            ImGui::Spacing();

            if (ImGui::Button("SPAWNER", ImVec2(200, 35))) current_tab = 0;
            ImGui::SameLine();
            if (ImGui::Button("EXPLOITS", ImVec2(200, 35))) current_tab = 1;
            ImGui::Spacing(); ImGui::Separator(); ImGui::Spacing();

            if (current_tab == 0) {
                ImGui::TextColored(ImVec4(0.7f, 0.7f, 0.7f, 1.0f), "1. SELECT ITEM");
                ImGui::Combo("Category", &selected_category, categories, IM_ARRAYSIZE(categories));
                if (selected_category == 0) ImGui::Combo("Item", &selected_item_idx, gadgets, IM_ARRAYSIZE(gadgets));
                if (selected_category == 1) ImGui::Combo("Item", &selected_item_idx, weapons, IM_ARRAYSIZE(weapons));
                if (selected_category == 2) ImGui::Combo("Item", &selected_item_idx, explosives, IM_ARRAYSIZE(explosives));
                if (selected_category == 3) ImGui::Combo("Item", &selected_item_idx, loot, IM_ARRAYSIZE(loot));
                if (selected_category == 4) ImGui::Combo("Item", &selected_item_idx, troll, IM_ARRAYSIZE(troll));
                
                ImGui::Spacing();
                
                ImGui::TextColored(ImVec4(0.7f, 0.7f, 0.7f, 1.0f), "2. XMOD PARAMETERS");
                ImGui::SliderInt("Hue", &item_hue, -124, 124);
                ImGui::SliderInt("Saturation", &item_saturation, -124, 124);
                ImGui::SliderInt("Size", &item_size, -127, 127);
                
                ImGui::Spacing();

                ImGui::TextColored(ImVec4(0.7f, 0.7f, 0.7f, 1.0f), "3. TARGET LOCATION");
                ImGui::Combo("Area", &selected_location, locations, IM_ARRAYSIZE(locations));
                if (selected_location == 5) {
                    ImGui::InputFloat3("X, Y, Z", custom_coords);
                }

                ImGui::Spacing(); ImGui::Spacing();

                if (ImGui::Button("EXECUTE NETWORK SPAWN", ImVec2(-1, 50))) {
                    int item_id = GetRealItemID(selected_category, selected_item_idx);
                    Vec3 coords = GetTargetCoordinates(selected_location);

                    uint64_t network_spawn = 0x14fA0; 
                    void (*BypassSpawn)(float, float, float, int, int, int, int) = 
                        (void (*)(float, float, float, int, int, int, int))(GetBaseAddress() + network_spawn);

                    BypassSpawn(coords.x, coords.y, coords.z, item_id, item_hue, item_saturation, item_size);
                }
            }

            if (current_tab == 1) {
                ImGui::TextColored(ImVec4(1.0f, 0.3f, 0.3f, 1.0f), "DANGEROUS EXPLOITS");
                ImGui::Spacing();

                if (ImGui::Button("Trigger Custom Sell", ImVec2(-1, 40))) {
                    uint64_t sell_offset = 0x2A1B4; 
                    void (*ForceSell)(int) = (void (*)(int))(GetBaseAddress() + sell_offset);
                    ForceSell(9999999); 
                }
            }

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

- (void)mtkView:(MTKView*)view drawableSizeWillChange:(CGSize)size { }

@end
