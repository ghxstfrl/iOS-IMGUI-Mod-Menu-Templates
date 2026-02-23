#import "ImGuiDrawView.h"
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

// ImGui Framework
#include "imgui.h"
#include "imgui_internal.h"
#include "imgui_impl_metal.h"

// KittyMemory for your Hacks
#include "KittyMemory/MemoryPatch.hpp"
#include "KittyMemory/writeData.hpp"

@implementation ImGuiDrawView

+ (instancetype)sharedInstance {
    static ImGuiDrawView *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UIWindow *mainWindow = [UIApplication sharedApplication].keyWindow;
        if (!mainWindow) {
            // FIX 1: Safely check for iOS 13+ to avoid compiler errors on older targets
            if (@available(iOS 13.0, *)) {
                for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                    if ([scene isKindOfClass:[UIWindowScene class]]) {
                        UIWindowScene *windowScene = (UIWindowScene *)scene;
                        for (UIWindow *w in windowScene.windows) {
                            if (w.isKeyWindow) { mainWindow = w; break; }
                        }
                    }
                }
            }
        }
        
        sharedInstance = [[ImGuiDrawView alloc] initWithFrame:mainWindow.bounds];
        [mainWindow addSubview:sharedInstance];
    });
    return sharedInstance;
}

+ (void)showMenu {
    [self sharedInstance];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.device = MTLCreateSystemDefaultDevice();
        self.commandQueue = [self.device newCommandQueue];
        
        self.clearColor = MTLClearColorMake(0, 0, 0, 0); // Transparent background
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        self.delegate = self;
        
        self.isMenuVisible = NO; 
        self.userInteractionEnabled = YES; 

        [self setupImGui];
        [self setupStyle];
    }
    return self;
}

- (void)setupImGui {
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO();
    io.IniFilename = NULL; 
    
    CGFloat screenScale = [UIScreen mainScreen].scale;
    io.FontGlobalScale = (screenScale >= 3.0f) ? 2.0f : 1.5f; 
    
    ImGui_ImplMetal_Init(self.device);
}

// ==========================================
// M1 NEON PURPLE & BLUE THEME
// ==========================================
- (void)setupStyle {
    ImGuiStyle& style = ImGui::GetStyle();
    style.WindowRounding = 14.0f;
    style.FrameRounding = 8.0f;
    style.ScrollbarRounding = 8.0f;
    style.TabRounding = 8.0f;
    style.ChildRounding = 8.0f;
    style.PopupRounding = 8.0f;
    style.WindowBorderSize = 1.5f;
    style.FrameBorderSize = 0.0f;
    
    ImVec4* colors = style.Colors;
    
    colors[ImGuiCol_WindowBg]         = ImVec4(0.06f, 0.03f, 0.09f, 0.95f);
    colors[ImGuiCol_ChildBg]          = ImVec4(0.08f, 0.04f, 0.12f, 0.60f);
    colors[ImGuiCol_Border]           = ImVec4(0.60f, 0.10f, 1.00f, 0.60f);
    colors[ImGuiCol_TitleBg]          = ImVec4(0.12f, 0.06f, 0.20f, 1.00f);
    colors[ImGuiCol_TitleBgActive]    = ImVec4(0.40f, 0.10f, 0.80f, 1.00f);
    colors[ImGuiCol_Button]           = ImVec4(0.30f, 0.10f, 0.60f, 1.00f);
    colors[ImGuiCol_ButtonHovered]    = ImVec4(0.40f, 0.15f, 0.80f, 1.00f);
    colors[ImGuiCol_ButtonActive]     = ImVec4(0.00f, 0.60f, 1.00f, 1.00f); 
    colors[ImGuiCol_FrameBg]          = ImVec4(0.15f, 0.08f, 0.25f, 1.00f);
    colors[ImGuiCol_FrameBgHovered]   = ImVec4(0.25f, 0.12f, 0.40f, 1.00f);
    colors[ImGuiCol_FrameBgActive]    = ImVec4(0.35f, 0.18f, 0.55f, 1.00f);
    colors[ImGuiCol_CheckMark]        = ImVec4(0.00f, 0.80f, 1.00f, 1.00f);
    colors[ImGuiCol_SliderGrab]       = ImVec4(0.60f, 0.10f, 1.00f, 1.00f);
    colors[ImGuiCol_SliderGrabActive] = ImVec4(0.00f, 0.80f, 1.00f, 1.00f);
    colors[ImGuiCol_Tab]              = ImVec4(0.20f, 0.08f, 0.40f, 1.00f);
    colors[ImGuiCol_TabHovered]       = ImVec4(0.40f, 0.15f, 0.80f, 1.00f);
    colors[ImGuiCol_TabActive]        = ImVec4(0.50f, 0.20f, 0.95f, 1.00f);
    colors[ImGuiCol_Text]             = ImVec4(0.95f, 0.95f, 0.98f, 1.00f);
    colors[ImGuiCol_TextDisabled]     = ImVec4(0.50f, 0.50f, 0.60f, 1.00f);
}

// ==========================================
// TOUCH HANDLING
// ==========================================
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];
    if (hitView != self) return hitView;

    ImGuiContext* g = ImGui::GetCurrentContext();
    if (!g) return nil;

    for (int i = g->Windows.Size - 1; i >= 0; i--) {
        ImGuiWindow* window = g->Windows[i];
        if (!window->WasActive || window->Hidden || (window->Flags & ImGuiWindowFlags_NoInputs)) continue;
        
        CGRect windowRect = CGRectMake(window->Pos.x, window->Pos.y, window->Size.x, window->Size.y);
        if (CGRectContainsPoint(windowRect, point)) return self; 
    }
    return nil; 
}

- (void)updateIOWithTouchEvent:(UIEvent *)event {
    ImGuiIO& io = ImGui::GetIO();
    UITouch *touch = [[event allTouches] anyObject];
    if (touch) {
        CGPoint pos = [touch locationInView:self];
        bool isDown = (touch.phase == UITouchPhaseBegan || touch.phase == UITouchPhaseMoved || touch.phase == UITouchPhaseStationary);
#if IMGUI_VERSION_NUM >= 18700
        io.AddMousePosEvent(pos.x, pos.y);
        io.AddMouseButtonEvent(0, isDown);
#else
        io.MousePos = ImVec2(pos.x, pos.y);
        io.MouseDown[0] = isDown;
#endif
    }
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateIOWithTouchEvent:event]; }
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateIOWithTouchEvent:event]; }
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateIOWithTouchEvent:event]; }
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateIOWithTouchEvent:event]; }

// ==========================================
// RENDERING LOOP & METAL DELEGATE
// ==========================================

// FIX 2: Added missing rotation method required by Apple's protocol
- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    // Left empty safely
}

- (void)drawInMTKView:(MTKView *)view {
    ImGuiIO& io = ImGui::GetIO();
    io.DisplaySize.x = view.bounds.size.width;
    io.DisplaySize.y = view.bounds.size.height;
    CGFloat framebufferScale = view.window.screen.scale ?: [UIScreen mainScreen].scale;
    io.DisplayFramebufferScale = ImVec2(framebufferScale, framebufferScale);

    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
    if (renderPassDescriptor != nil) {
        id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];

        ImGui_ImplMetal_NewFrame(renderPassDescriptor);
        ImGui::NewFrame();
        
        [self renderImGuiLayout];

        ImGui::Render();
        id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), commandBuffer, renderEncoder);
        [renderEncoder endEncoding];

        [commandBuffer presentDrawable:view.currentDrawable];
        [commandBuffer commit];
    }
}

// ==========================================
// MENU LAYOUT & LOGIC
// ==========================================
- (void)renderImGuiLayout {
    
    // ---------------------------------------------------
    // FLOATING M1 TOGGLE BUTTON (Custom Gradient Design)
    // ---------------------------------------------------
    if (!self.isMenuVisible) {
        ImGui::SetNextWindowPos(ImVec2(60, 60), ImGuiCond_FirstUseEver);
        ImGui::SetNextWindowSize(ImVec2(70, 70), ImGuiCond_Always);
        
        ImGui::PushStyleColor(ImGuiCol_WindowBg, ImVec4(0, 0, 0, 0));
        ImGui::PushStyleVar(ImGuiStyleVar_WindowBorderSize, 0.0f);
        
        ImGui::Begin("##M1Toggle", nullptr, ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoScrollbar);
        
        ImVec2 pos = ImGui::GetWindowPos();
        ImDrawList* drawList = ImGui::GetWindowDrawList();
        
        // Custom Blue-Purple Gradient pill/circle
        ImVec2 center = ImVec2(pos.x + 35, pos.y + 35);
        float radius = 30.0f;
        
        drawList->AddCircleFilled(center, radius, IM_COL32(30, 20, 60, 240));
        drawList->AddCircle(center, radius, IM_COL32(180, 40, 255, 255), 0, 4.0f); // Outer Purple
        drawList->AddCircle(center, radius - 3.0f, IM_COL32(0, 195, 255, 200), 0, 2.0f); // Inner Cyan Blue
        
        ImGui::PushFont(ImGui::GetIO().Fonts->Fonts[0]);
        ImGui::SetCursorPos(ImVec2(18, 22));
        ImGui::TextColored(ImVec4(1.0f, 1.0f, 1.0f, 1.0f), "M1");
        ImGui::PopFont();
        
        if (ImGui::IsWindowHovered() && ImGui::IsMouseReleased(0) && !ImGui::IsMouseDragging(0)) {
            self.isMenuVisible = YES;
        }
        
        ImGui::End();
        ImGui::PopStyleVar();
        ImGui::PopStyleColor();
        return; 
    }
    
    // ---------------------------------------------------
    // MAIN "M1 V1" MOD MENU
    // ---------------------------------------------------
    ImGui::SetNextWindowSize(ImVec2(550, 480), ImGuiCond_FirstUseEver);
    
    ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(0.0f, 0.8f, 1.0f, 1.0f)); 
    bool windowOpen = true;
    ImGui::Begin("M1 V1", &windowOpen, ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoSavedSettings);
    ImGui::PopStyleColor();
    
    if (!windowOpen) {
        self.isMenuVisible = NO; 
    }

    if (ImGui::BeginTabBar("MenuTabs", ImGuiTabBarFlags_None)) {
        
        // ==========================================
        // TAB 1: ITEMS
        // ==========================================
        if (ImGui::BeginTabItem("Items")) {
            ImGui::Spacing();
            ImGui::TextColored(ImVec4(0.8f, 0.4f, 1.0f, 1.0f), "Item Spawner:");
            ImGui::Separator();
            ImGui::Spacing();
            
            static char searchBuffer[64] = "";
            ImGui::InputTextWithHint("##Search", "Search items...", searchBuffer, IM_ARRAYSIZE(searchBuffer));
            ImGui::Spacing();
            
            const char* items[] = { "item_goldbar", "item_ruby", "item_timebomb", "item_jetpack", "item_rpg", "item_shield", "item_medkit" };
            static int item_current_idx = 0;
            if (ImGui::BeginListBox("##ItemList", ImVec2(-FLT_MIN, 130))) {
                for (int n = 0; n < IM_ARRAYSIZE(items); n++) {
                    const bool is_selected = (item_current_idx == n);
                    if (ImGui::Selectable(items[n], is_selected)) item_current_idx = n;
                    if (is_selected) ImGui::SetItemDefaultFocus();
                }
                ImGui::EndListBox();
            }
            
            ImGui::Spacing();
            static int spawnQty = 5;
            ImGui::SliderInt("Quantity", &spawnQty, 1, 100);
            
            ImGui::Spacing();
            if (ImGui::Button("Spawn Selected Item", ImVec2(-1, 45))) {
                // Example of where you put your spawn code
                // spawnItem(items[item_current_idx], spawnQty);
            }
            ImGui::EndTabItem();
        }
        
        // ==========================================
        // TAB 2: OP MODS
        // ==========================================
        if (ImGui::BeginTabItem("OP Mods")) {
            ImGui::Spacing();
            ImGui::TextColored(ImVec4(0.0f, 0.8f, 1.0f, 1.0f), "Exploits & Cheats:");
            ImGui::Separator();
            ImGui::Spacing();
            
            static bool aimbot = false;
            if (ImGui::Checkbox("Aimbot / Magic Bullet", &aimbot)) {
                if (aimbot) {
                    // Turn on KittyMemory patch
                    // MemoryPatch::createWithHex("UnityFramework", 0x123456, "00 00 A0 E3").Modify();
                } else {
                    // Turn off
                    // MemoryPatch::createWithHex("UnityFramework", 0x123456, "1F 20 03 D5").Modify();
                }
            }
            
            static bool noRecoil = false;
            if (ImGui::Checkbox("No Recoil", &noRecoil)) {
                // Hook No recoil
            }
            
            static bool godMode = false;
            if (ImGui::Checkbox("God Mode (Invincible)", &godMode)) {
                // Hook God mode
            }
            
            ImGui::Spacing(); ImGui::Separator(); ImGui::Spacing();
            
            if (ImGui::Button("Spawn Bomb (50 Random Items)", ImVec2(-1, 40))) {
                // Trigger bomb
            }
            ImGui::Spacing();
            if (ImGui::Button("Teleport Everyone To Moon", ImVec2(-1, 40))) {
                // Trigger moon TP
            }
            
            ImGui::Spacing(); ImGui::Separator(); ImGui::Spacing();
            
            ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0.8f, 0.1f, 0.2f, 1.0f));
            ImGui::PushStyleColor(ImGuiCol_ButtonHovered, ImVec4(1.0f, 0.2f, 0.3f, 1.0f));
            if (ImGui::Button("NUKE SERVER", ImVec2(-1, 45))) {
                // Nuke code
            }
            ImGui::PopStyleColor(2);

            ImGui::EndTabItem();
        }
        
        // ==========================================
        // TAB 3: SPAWNS
        // ==========================================
        if (ImGui::BeginTabItem("Spawns")) {
            ImGui::Spacing();
            ImGui::TextColored(ImVec4(0.6f, 0.2f, 1.0f, 1.0f), "Entity & Mob Spawner:");
            ImGui::Separator();
            ImGui::Spacing();
            
            const char* mobs[] = { "mob_zombie", "mob_skeleton", "mob_creeper", "mob_dragon" };
            static int mob_current_idx = 0;
            
            if (ImGui::BeginListBox("##MobList", ImVec2(-FLT_MIN, 130))) {
                for (int n = 0; n < IM_ARRAYSIZE(mobs); n++) {
                    const bool is_selected = (mob_current_idx == n);
                    if (ImGui::Selectable(mobs[n], is_selected)) mob_current_idx = n;
                    if (is_selected) ImGui::SetItemDefaultFocus();
                }
                ImGui::EndListBox();
            }
            
            ImGui::Spacing();
            static int mobQty = 1;
            ImGui::SliderInt("Mob Quantity", &mobQty, 1, 50);
            
            ImGui::Spacing();
            if (ImGui::Button("Spawn Mob(s)", ImVec2(-1, 45))) {
                // Hook Spawn Mob
            }
            ImGui::EndTabItem();
        }
        
        // ==========================================
        // TAB 4: SETTINGS
        // ==========================================
        if (ImGui::BeginTabItem("Settings")) {
            ImGui::Spacing();
            ImGui::TextColored(ImVec4(0.8f, 0.8f, 0.8f, 1.0f), "M1 V1 Configuration:");
            ImGui::Separator();
            ImGui::Spacing();
            
            ImGuiIO& io = ImGui::GetIO();
            ImGui::SliderFloat("Menu Scale", &io.FontGlobalScale, 0.8f, 2.5f, "%.1f");
            
            ImGui::Spacing(); ImGui::Spacing();
            
            ImGui::TextDisabled("Status: Injected & Running");
            ImGui::TextDisabled("Theme: Neon Purple / Blue");
            
            ImGui::Spacing(); ImGui::Spacing(); ImGui::Spacing();
            
            ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0.8f, 0.2f, 0.2f, 1.0f));
            ImGui::PushStyleColor(ImGuiCol_ButtonHovered, ImVec4(1.0f, 0.3f, 0.3f, 1.0f));
            if (ImGui::Button("Panic! Unload Menu", ImVec2(-1, 45))) {
                [self removeFromSuperview];
            }
            ImGui::PopStyleColor(2);
            
            ImGui::EndTabItem();
        }
        
        ImGui::EndTabBar();
    }
    
    ImGui::End();
}

@end
