//
//  ImGuiDrawView.mm
//  Custom M1-Style / Orbit ImGui Mod Menu
//

#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

// Standard ImGui imports
#include "imgui.h"
#include "imgui_internal.h"
#include "imgui_impl_metal.h"

// ==========================================
// INTERFACE DECLARATION
// ==========================================

@interface ImGuiDrawView : MTKView <MTKViewDelegate>
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, assign) BOOL isMenuVisible;

+ (instancetype)sharedInstance;
+ (void)showMenu;
@end

// ==========================================
// IMPLEMENTATION
// ==========================================

@implementation ImGuiDrawView

+ (instancetype)sharedInstance {
    static ImGuiDrawView *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UIWindow *mainWindow = [UIApplication sharedApplication].keyWindow;
        if (!mainWindow) {
            // Fallback for iOS 13+
            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]]) {
                    UIWindowScene *windowScene = (UIWindowScene *)scene;
                    for (UIWindow *w in windowScene.windows) {
                        if (w.isKeyWindow) { mainWindow = w; break; }
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
        
        // Ensure background is fully transparent so the game is visible
        self.clearColor = MTLClearColorMake(0, 0, 0, 0);
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        self.delegate = self;
        
        self.isMenuVisible = NO; // Starts hidden, showing only the toggle button
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
    
    io.IniFilename = NULL; // Keep file system clean
    
    // Scale up slightly for high DPI mobile screens
    CGFloat screenScale = [UIScreen mainScreen].scale;
    io.FontGlobalScale = (screenScale >= 3.0f) ? 2.0f : 1.5f; 
    
    ImGui_ImplMetal_Init(self.device);
}

- (void)setupStyle {
    // M1 / Orbit Galaxy Style Dark Theme
    ImGuiStyle& style = ImGui::GetStyle();
    style.WindowRounding = 14.0f;
    style.FrameRounding = 8.0f;
    style.ScrollbarRounding = 8.0f;
    style.TabRounding = 8.0f;
    style.ChildRounding = 8.0f;
    style.PopupRounding = 8.0f;
    style.WindowBorderSize = 1.0f;
    style.FrameBorderSize = 0.0f;
    
    ImVec4* colors = style.Colors;
    colors[ImGuiCol_WindowBg]         = ImVec4(0.05f, 0.04f, 0.08f, 0.95f); // Deep space purple/black
    colors[ImGuiCol_Border]           = ImVec4(0.40f, 0.20f, 0.80f, 0.50f); // Purple border
    colors[ImGuiCol_FrameBg]          = ImVec4(0.12f, 0.10f, 0.18f, 1.00f);
    colors[ImGuiCol_FrameBgHovered]   = ImVec4(0.20f, 0.15f, 0.30f, 1.00f);
    colors[ImGuiCol_FrameBgActive]    = ImVec4(0.30f, 0.20f, 0.45f, 1.00f);
    colors[ImGuiCol_TitleBg]          = ImVec4(0.08f, 0.06f, 0.12f, 1.00f);
    colors[ImGuiCol_TitleBgActive]    = ImVec4(0.10f, 0.08f, 0.15f, 1.00f);
    colors[ImGuiCol_Button]           = ImVec4(0.15f, 0.12f, 0.25f, 1.00f);
    colors[ImGuiCol_ButtonHovered]    = ImVec4(0.25f, 0.18f, 0.40f, 1.00f);
    colors[ImGuiCol_ButtonActive]     = ImVec4(0.35f, 0.25f, 0.55f, 1.00f);
    colors[ImGuiCol_CheckMark]        = ImVec4(0.00f, 0.80f, 1.00f, 1.00f); // Cyan accent
    colors[ImGuiCol_SliderGrab]       = ImVec4(0.55f, 0.35f, 1.00f, 1.00f); // Purple accent
    colors[ImGuiCol_SliderGrabActive] = ImVec4(0.70f, 0.45f, 1.00f, 1.00f);
    colors[ImGuiCol_Tab]              = ImVec4(0.10f, 0.08f, 0.15f, 1.00f);
    colors[ImGuiCol_TabHovered]       = ImVec4(0.25f, 0.18f, 0.40f, 1.00f);
    colors[ImGuiCol_TabActive]        = ImVec4(0.35f, 0.25f, 0.55f, 1.00f);
    colors[ImGuiCol_Header]           = ImVec4(0.20f, 0.15f, 0.30f, 1.00f);
    colors[ImGuiCol_HeaderHovered]    = ImVec4(0.30f, 0.20f, 0.45f, 1.00f);
    colors[ImGuiCol_HeaderActive]     = ImVec4(0.40f, 0.25f, 0.60f, 1.00f);
    colors[ImGuiCol_Text]             = ImVec4(0.95f, 0.95f, 0.95f, 1.00f);
    colors[ImGuiCol_TextDisabled]     = ImVec4(0.60f, 0.60f, 0.65f, 1.00f);
}

// ==========================================
// TOUCH HANDLING & EXACT HIT TESTING
// ==========================================

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];
    if (hitView != self) return hitView;

    ImGuiContext* g = ImGui::GetCurrentContext();
    if (!g) return nil;

    // Check if the user is touching INSIDE any active ImGui window.
    for (int i = g->Windows.Size - 1; i >= 0; i--) {
        ImGuiWindow* window = g->Windows[i];
        if (!window->WasActive || window->Hidden || (window->Flags & ImGuiWindowFlags_NoInputs)) {
            continue;
        }
        
        CGRect windowRect = CGRectMake(window->Pos.x, window->Pos.y, window->Size.x, window->Size.y);
        if (CGRectContainsPoint(windowRect, point)) {
            return self; // ImGui intercepts this touch
        }
    }
    
    return nil; // Touch passes through to the game
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
// RENDER LOOP
// ==========================================

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
// IMGUI MENU LOGIC & LAYOUT
// ==========================================

- (void)renderImGuiLayout {
    // ---------------------------------------------------
    // FLOATING TOGGLE BUTTON
    // ---------------------------------------------------
    if (!self.isMenuVisible) {
        ImGui::SetNextWindowPos(ImVec2(50, 50), ImGuiCond_FirstUseEver);
        ImGui::SetNextWindowSize(ImVec2(64, 64), ImGuiCond_Always);
        
        ImGui::PushStyleColor(ImGuiCol_WindowBg, ImVec4(0, 0, 0, 0));
        ImGui::PushStyleVar(ImGuiStyleVar_WindowBorderSize, 0.0f);
        
        ImGui::Begin("##Toggle", nullptr, ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoScrollbar);
        
        ImVec2 pos = ImGui::GetWindowPos();
        ImDrawList* drawList = ImGui::GetWindowDrawList();
        
        // Draw Glassmorphism/Galaxy Orb
        drawList->AddCircleFilled(ImVec2(pos.x + 32, pos.y + 32), 28.0f, IM_COL32(20, 15, 45, 230));
        drawList->AddCircle(ImVec2(pos.x + 32, pos.y + 32), 28.0f, IM_COL32(140, 90, 255, 255), 0, 2.5f);
        
        // Glowing Text
        ImGui::SetCursorPos(ImVec2(18, 20));
        ImGui::TextColored(ImVec4(1.0f, 1.0f, 1.0f, 1.0f), " \xC3\x98 "); // Ø symbol
        
        // Handle click (if not dragging)
        if (ImGui::IsWindowHovered() && ImGui::IsMouseReleased(0) && !ImGui::IsMouseDragging(0)) {
            self.isMenuVisible = YES;
        }
        
        ImGui::End();
        ImGui::PopStyleVar();
        ImGui::PopStyleColor();
        return; // Don't draw the rest of the menu
    }
    
    // ---------------------------------------------------
    // MAIN MENU WINDOW
    // ---------------------------------------------------
    ImGui::SetNextWindowSize(ImVec2(550, 480), ImGuiCond_FirstUseEver);
    
    // Title bar custom colors
    ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(0.0f, 0.8f, 1.0f, 1.0f)); // Cyan title
    bool windowOpen = true;
    ImGui::Begin("\xC3\x98rbit V10 | iOS Native UI", &windowOpen, ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoSavedSettings);
    ImGui::PopStyleColor();
    
    // If the standard close button (X) is pressed, hide the menu
    if (!windowOpen) {
        self.isMenuVisible = NO;
    }

    if (ImGui::BeginTabBar("MenuTabs", ImGuiTabBarFlags_NoTooltip)) {
        
        // ==========================================
        // TAB 1: ITEMS SPAWNER
        // ==========================================
        if (ImGui::BeginTabItem("Items")) {
            ImGui::Spacing();
            ImGui::TextColored(ImVec4(0.6f, 0.2f, 0.8f, 1.0f), "Item Spawner Setup:");
            ImGui::Separator();
            ImGui::Spacing();
            
            static char searchBuffer[64] = "";
            ImGui::InputTextWithHint("##Search", "Search items...", searchBuffer, IM_ARRAYSIZE(searchBuffer));
            
            // Dummy ListBox to replicate categories
            const char* items[] = { "item_goldbar", "item_ruby", "item_timebomb", "item_jetpack", "item_rpg" };
            static int item_current_idx = 0;
            if (ImGui::BeginListBox("##ItemList", ImVec2(-FLT_MIN, 120))) {
                for (int n = 0; n < IM_ARRAYSIZE(items); n++) {
                    const bool is_selected = (item_current_idx == n);
                    if (ImGui::Selectable(items[n], is_selected)) item_current_idx = n;
                    if (is_selected) ImGui::SetItemDefaultFocus();
                }
                ImGui::EndListBox();
            }
            
            static int spawnQty = 5;
            ImGui::SliderInt("Quantity", &spawnQty, 1, 999);
            
            ImGui::Spacing();
            if (ImGui::Button("Spawn Selected Item", ImVec2(-1, 40))) {
                // TODO: Call your spawn logic here
                // Example: spawnItem(items[item_current_idx], spawnQty);
            }
            
            ImGui::Spacing(); ImGui::Separator(); ImGui::Spacing();
            
            ImGui::TextColored(ImVec4(0.0f, 0.8f, 1.0f, 1.0f), "Item Colors:");
            static bool enableColor = false;
            static float itemColor[3] = { 1.0f, 0.0f, 0.0f }; // Red default
            ImGui::Checkbox("Enable Custom Colors", &enableColor);
            ImGui::SameLine();
            if (enableColor) {
                ImGui::ColorEdit3("##ItemColorPicker", itemColor, ImGuiColorEditFlags_NoInputs);
                // TODO: Convert float colors to RGB/Hue and apply to spawned items
            }

            ImGui::EndTabItem();
        }
        
        // ==========================================
        // TAB 2: OP MODS / EXPERIMENTS
        // ==========================================
        if (ImGui::BeginTabItem("OP Mods")) {
            ImGui::Spacing();
            ImGui::TextColored(ImVec4(1.0f, 0.5f, 0.0f, 1.0f), "Mods & Exploits:");
            ImGui::Separator();
            ImGui::Spacing();
            
            if (ImGui::Button(u8"\U0001F4A3 Spawn Bomb (50 random items)", ImVec2(-1, 35))) {
                // TODO: Hook SpawnBomb
            }
            if (ImGui::Button(u8"\U0001F3D7 Spawn Tower (Stack)", ImVec2(-1, 35))) {
                // TODO: Hook SpawnTower
            }
            if (ImGui::Button(u8"\U0001F47E Monster Wave (All Types)", ImVec2(-1, 35))) {
                // TODO: Hook MonsterWave
            }
            
            ImGui::Spacing(); ImGui::Separator(); ImGui::Spacing();
            
            // Toggles
            static bool flyMode = false;
            if (ImGui::Checkbox(u8"\U0001F54A Fly / Noclip Mode", &flyMode)) {
                // TODO: Toggle Fly Mode logic
            }
            
            static bool godMode = false;
            if (ImGui::Checkbox(u8"\U0001F49B God Mode", &godMode)) {
                // TODO: Toggle God Mode
            }
            
            static bool orbitPlayers = false;
            if (ImGui::Checkbox(u8"\U0001FA90 Orbit Players Around Self", &orbitPlayers)) {
                // TODO: Toggle Orbit
            }
            
            ImGui::Spacing(); ImGui::Separator(); ImGui::Spacing();
            
            // Dangerous Mods
            ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0.6f, 0.1f, 0.1f, 1.0f));
            ImGui::PushStyleColor(ImGuiCol_ButtonHovered, ImVec4(0.8f, 0.2f, 0.2f, 1.0f));
            if (ImGui::Button(u8"\u2622 MEGA NUKE (Server Crash Warning)", ImVec2(-1, 40))) {
                // TODO: Hook Nuke
            }
            ImGui::PopStyleColor(2);

            ImGui::EndTabItem();
        }
        
        // ==========================================
        // TAB 3: MOBS / SPAWNS
        // ==========================================
        if (ImGui::BeginTabItem("Spawns")) {
            ImGui::Spacing();
            ImGui::TextColored(ImVec4(0.2f, 0.8f, 0.2f, 1.0f), "Entity & Mob Spawner:");
            ImGui::Separator();
            ImGui::Spacing();
            
            const char* mobs[] = { "mob_zombie", "mob_skeleton", "mob_creeper", "mob_dragon" };
            static int mob_current_idx = 0;
            
            if (ImGui::BeginListBox("##MobList", ImVec2(-FLT_MIN, 150))) {
                for (int n = 0; n < IM_ARRAYSIZE(mobs); n++) {
                    const bool is_selected = (mob_current_idx == n);
                    if (ImGui::Selectable(mobs[n], is_selected)) mob_current_idx = n;
                    if (is_selected) ImGui::SetItemDefaultFocus();
                }
                ImGui::EndListBox();
            }
            
            static int mobQty = 1;
            ImGui::SliderInt("Mob Quantity", &mobQty, 1, 100);
            
            ImGui::Spacing();
            if (ImGui::Button("Spawn Mob(s)", ImVec2(-1, 40))) {
                // TODO: Hook Spawn Mob
            }
            
            ImGui::Spacing();
            if (ImGui::Button(u8"\U0001F319 Teleport All To Moon", ImVec2(-1, 40))) {
                // TODO: Hook Teleport to Moon (Y=999)
            }
            
            ImGui::EndTabItem();
        }
        
        // ==========================================
        // TAB 4: SETTINGS
        // ==========================================
        if (ImGui::BeginTabItem("Settings")) {
            ImGui::Spacing();
            ImGui::TextColored(ImVec4(0.8f, 0.8f, 0.8f, 1.0f), "Menu Configuration:");
            ImGui::Separator();
            ImGui::Spacing();
            
            ImGuiIO& io = ImGui::GetIO();
            ImGui::SliderFloat("UI Scale", &io.FontGlobalScale, 0.8f, 2.5f, "%.1f");
            
            ImGui::Spacing(); ImGui::Spacing();
            
            ImGui::TextDisabled("Status: Injected Successfully");
            ImGui::TextDisabled("By: Your Name / polarGTT Base");
            
            ImGui::Spacing(); ImGui::Spacing(); ImGui::Spacing();
            
            // Unload Menu Panic Button
            ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0.8f, 0.2f, 0.2f, 1.0f));
            ImGui::PushStyleColor(ImGuiCol_ButtonHovered, ImVec4(0.9f, 0.3f, 0.3f, 1.0f));
            if (ImGui::Button("Unload Menu", ImVec2(-1, 40))) {
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
