#import "ImGuiDrawView.h"
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

// ImGui Framework
#include "imgui.h"
#include "imgui_internal.h"
#include "imgui_impl_metal.h"

// KittyMemory for memory patches
#include "KittyMemory/MemoryPatch.hpp"
#include "KittyMemory/writeData.hpp"

// ==========================================
// GAME DEFINITIONS & VARIABLES
// ==========================================
#ifndef MAP_MIN_X
#define MAP_MIN_X -1000.0f
#define MAP_MAX_X 1000.0f
#define MAP_MIN_Z -1000.0f
#define MAP_MAX_Z 1000.0f
#endif

// Safety stub for logAppend so the compiler doesn't fail
static void logAppend(NSString *msg) {
    NSLog(@"[M1 Mod] %@", msg);
}

// Local timers and states
static NSTimer *g_godModeTimer = nil;
static BOOL g_godModeEnabled = NO;

// ==========================================
// ENGINE STUBS - NO MORE LINKER ERRORS!
// These act as placeholders so the menu successfully compiles.
// You will put your actual KittyMemory read/write logic inside these later!
// ==========================================
typedef struct { float x; float y; float z; } Vec3;

void* g_gameImage = NULL;
void* g_findObjectsOfType = NULL;
void* g_rpcTeleport = NULL;
void* g_getTransformMethod = NULL;
void* g_getLocalPlayer = NULL;
void (*g_setPositionInjected)(void* transform, Vec3* pos) = NULL;
void (*g_getPositionInjected)(void* transform, Vec3* pos) = NULL;

Vec3 getPlayerPosition() {
    // TODO: Put your memory read for player coordinates here
    return (Vec3){0, 0, 0}; 
}

void spawnItem(NSString* name, int qty) {
    NSLog(@"[M1 Mod] Pretending to spawn item: %@ x%d", name, qty);
}

void spawnItemAtPos(NSString* name, Vec3 pos) {
    NSLog(@"[M1 Mod] Pretending to spawn item: %@ at X:%.1f Y:%.1f Z:%.1f", name, pos.x, pos.y, pos.z);
}

void spawnMonster(NSString* name, int qty) {
    NSLog(@"[M1 Mod] Pretending to spawn mob: %@ x%d", name, qty);
}

void* resolveClass(const char* name) {
    return NULL; 
}

void* findObjectOfType(void* klass) {
    return NULL; 
}


// ==========================================
// INTERFACE
// ==========================================
@interface ImGuiDrawView ()
- (void)spawnBombTapped;
- (void)nukeZoneTapped;
- (void)teleportAllToMoonTapped;
- (void)godKitTapped;
- (void)startGodModeTick;
@end

@implementation ImGuiDrawView

+ (instancetype)sharedInstance {
    static ImGuiDrawView *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UIWindow *mainWindow = [UIApplication sharedApplication].keyWindow;
        if (!mainWindow) {
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
        self.clearColor = MTLClearColorMake(0, 0, 0, 0); 
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        self.delegate = self;
        
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
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
    io.FontGlobalScale = 1.1f; 
    ImGui_ImplMetal_Init(self.device);
}

- (void)setupStyle {
    ImGuiStyle& style = ImGui::GetStyle();
    style.WindowRounding = 12.0f;
    style.FrameRounding = 6.0f;
    style.ScrollbarRounding = 6.0f;
    style.TabRounding = 8.0f;
    style.ChildRounding = 8.0f;
    style.PopupRounding = 8.0f;
    style.WindowBorderSize = 1.0f;
    style.FrameBorderSize = 0.0f;
    
    ImVec4* colors = style.Colors;
    colors[ImGuiCol_WindowBg]         = ImVec4(0.08f, 0.08f, 0.08f, 0.85f);
    colors[ImGuiCol_ChildBg]          = ImVec4(0.12f, 0.12f, 0.12f, 0.40f);
    colors[ImGuiCol_Border]           = ImVec4(0.35f, 0.20f, 0.85f, 0.50f);
    colors[ImGuiCol_TitleBg]          = ImVec4(0.12f, 0.08f, 0.20f, 1.00f);
    colors[ImGuiCol_TitleBgActive]    = ImVec4(0.25f, 0.15f, 0.45f, 1.00f);
    colors[ImGuiCol_Button]           = ImVec4(0.20f, 0.15f, 0.35f, 1.00f);
    colors[ImGuiCol_ButtonHovered]    = ImVec4(0.30f, 0.20f, 0.55f, 1.00f);
    colors[ImGuiCol_ButtonActive]     = ImVec4(0.45f, 0.30f, 0.85f, 1.00f); 
    colors[ImGuiCol_FrameBg]          = ImVec4(0.15f, 0.15f, 0.18f, 1.00f);
    colors[ImGuiCol_FrameBgHovered]   = ImVec4(0.20f, 0.20f, 0.25f, 1.00f);
    colors[ImGuiCol_FrameBgActive]    = ImVec4(0.25f, 0.25f, 0.35f, 1.00f);
    colors[ImGuiCol_CheckMark]        = ImVec4(0.40f, 0.80f, 1.00f, 1.00f);
    colors[ImGuiCol_SliderGrab]       = ImVec4(0.45f, 0.30f, 0.85f, 1.00f);
    colors[ImGuiCol_SliderGrabActive] = ImVec4(0.55f, 0.40f, 0.95f, 1.00f);
    colors[ImGuiCol_Tab]              = ImVec4(0.15f, 0.12f, 0.25f, 1.00f);
    colors[ImGuiCol_TabHovered]       = ImVec4(0.30f, 0.20f, 0.50f, 1.00f);
    colors[ImGuiCol_TabActive]        = ImVec4(0.35f, 0.25f, 0.60f, 1.00f);
    colors[ImGuiCol_Text]             = ImVec4(0.95f, 0.95f, 0.98f, 1.00f);
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
- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size { }

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
    
    ImGuiIO& io = ImGui::GetIO();
    
    // WATERMARK
    ImGui::SetNextWindowPos(ImVec2(io.DisplaySize.x - 170, io.DisplaySize.y - 35), ImGuiCond_Always);
    ImGui::SetNextWindowSize(ImVec2(160, 30), ImGuiCond_Always);
    ImGui::PushStyleColor(ImGuiCol_WindowBg, ImVec4(0, 0, 0, 0));
    ImGui::PushStyleVar(ImGuiStyleVar_WindowBorderSize, 0.0f);
    ImGui::Begin("##Watermark", nullptr, ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoMove | ImGuiWindowFlags_NoInputs | ImGuiWindowFlags_NoScrollbar);
    ImGui::TextColored(ImVec4(0.8f, 0.8f, 1.0f, 0.6f), "Created by ghxstfrl");
    ImGui::End();
    ImGui::PopStyleVar();
    ImGui::PopStyleColor();
    
    // ---------------------------------------------------
    // FLOATING TOGGLE BUTTON: M1 Custom Gradient Pill
    // ---------------------------------------------------
    if (!self.isMenuVisible) {
        ImGui::SetNextWindowPos(ImVec2(60, 60), ImGuiCond_FirstUseEver);
        ImGui::SetNextWindowSize(ImVec2(80, 45), ImGuiCond_Always);
        
        ImGui::PushStyleColor(ImGuiCol_WindowBg, ImVec4(0, 0, 0, 0));
        ImGui::PushStyleVar(ImGuiStyleVar_WindowBorderSize, 0.0f);
        
        ImGui::Begin("##M1Toggle", nullptr, ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoScrollbar);
        
        ImVec2 pos = ImGui::GetWindowPos();
        ImDrawList* drawList = ImGui::GetWindowDrawList();
        
        ImVec2 p0 = pos;
        ImVec2 p1 = ImVec2(pos.x + 80, pos.y + 45);
        
        drawList->AddCircleFilled(ImVec2(p0.x + 22.5f, p0.y + 22.5f), 22.5f, IM_COL32(120, 30, 200, 240));
        drawList->AddCircleFilled(ImVec2(p1.x - 22.5f, p0.y + 22.5f), 22.5f, IM_COL32(20, 100, 255, 240));
        drawList->AddRectFilledMultiColor(ImVec2(p0.x + 22.5f, p0.y), ImVec2(p1.x - 22.5f, p1.y),
            IM_COL32(120, 30, 200, 240), IM_COL32(20, 100, 255, 240), 
            IM_COL32(20, 100, 255, 240), IM_COL32(120, 30, 200, 240));
            
        drawList->AddRect(p0, p1, IM_COL32(200, 150, 255, 255), 22.5f, 0, 2.0f);
        
        ImGui::PushFont(ImGui::GetIO().Fonts->Fonts[0]);
        ImVec2 textSize = ImGui::CalcTextSize("M1");
        ImGui::SetCursorPos(ImVec2((80 - textSize.x) * 0.5f, (45 - textSize.y) * 0.5f));
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
    ImGui::SetNextWindowSize(ImVec2(450, 420), ImGuiCond_FirstUseEver);
    ImGui::Begin("M1 V1", &_isMenuVisible, ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoSavedSettings);

    if (ImGui::BeginTabBar("MenuTabs", ImGuiTabBarFlags_None)) {
        
        if (ImGui::BeginTabItem("Items")) {
            ImGui::Spacing();
            ImGui::TextColored(ImVec4(0.8f, 0.4f, 1.0f, 1.0f), "Item Spawner:");
            ImGui::Separator();
            ImGui::Spacing();
            
            const char* items[] = { "item_goldbar", "item_ruby", "item_timebomb", "item_jetpack", "item_rpg", "item_flamethrower", "item_dynamite" };
            static int item_current_idx = 0;
            if (ImGui::BeginListBox("##ItemList", ImVec2(-FLT_MIN, 100))) {
                for (int n = 0; n < IM_ARRAYSIZE(items); n++) {
                    const bool is_selected = (item_current_idx == n);
                    if (ImGui::Selectable(items[n], is_selected)) item_current_idx = n;
                    if (is_selected) ImGui::SetItemDefaultFocus();
                }
                ImGui::EndListBox();
            }
            
            static int spawnQty = 1;
            ImGui::SliderInt("Quantity", &spawnQty, 1, 100);
            
            ImGui::Spacing();
            if (ImGui::Button("Spawn Selected Item", ImVec2(-1, 35))) {
                NSString *itemName = [NSString stringWithUTF8String:items[item_current_idx]];
                spawnItem(itemName, spawnQty);
                logAppend([NSString stringWithFormat:@"Spawned %@ x%d", itemName, spawnQty]);
            }
            ImGui::EndTabItem();
        }
        
        if (ImGui::BeginTabItem("OP Mods")) {
            ImGui::Spacing();
            ImGui::TextColored(ImVec4(0.0f, 0.8f, 1.0f, 1.0f), "Exploits & Cheats:");
            ImGui::Separator();
            ImGui::Spacing();
            
            static bool aimbot = false;
            if (ImGui::Checkbox("Aimbot / Magic Bullet", &aimbot)) { 
                // Enable KittyMemory patches if desired
            }
            
            if (ImGui::Checkbox("God Mode (Invincible)", &g_godModeEnabled)) { 
                if (g_godModeEnabled) {
                    [self startGodModeTick];
                } else {
                    if (g_godModeTimer) { [g_godModeTimer invalidate]; g_godModeTimer = nil; }
                    logAppend(@"God Mode DISABLED");
                }
            }
            
            ImGui::Spacing(); ImGui::Separator(); ImGui::Spacing();
            
            if (ImGui::Button("Spawn Bomb (50 Random Items)", ImVec2(-1, 35))) { 
                [self spawnBombTapped];
            }
            ImGui::Spacing();
            if (ImGui::Button("Spawn God Kit (OP Loadout)", ImVec2(-1, 35))) { 
                [self godKitTapped];
            }
            ImGui::Spacing();
            if (ImGui::Button("Teleport Everyone To Moon", ImVec2(-1, 35))) { 
                [self teleportAllToMoonTapped];
            }
            
            ImGui::Spacing(); ImGui::Separator(); ImGui::Spacing();
            
            ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0.7f, 0.1f, 0.1f, 1.0f));
            ImGui::PushStyleColor(ImGuiCol_ButtonHovered, ImVec4(0.9f, 0.2f, 0.2f, 1.0f));
            if (ImGui::Button("NUKE SERVER (400 Explosives)", ImVec2(-1, 40))) { 
                [self nukeZoneTapped];
            }
            ImGui::PopStyleColor(2);

            ImGui::EndTabItem();
        }
        
        if (ImGui::BeginTabItem("Spawns")) {
            ImGui::Spacing();
            ImGui::TextColored(ImVec4(0.6f, 0.2f, 1.0f, 1.0f), "Entity & Mob Spawner:");
            ImGui::Separator();
            ImGui::Spacing();
            
            const char* mobs[] = { "mob_zombie", "mob_skeleton", "mob_creeper" };
            static int mob_current_idx = 0;
            if (ImGui::BeginListBox("##MobList", ImVec2(-FLT_MIN, 100))) {
                for (int n = 0; n < IM_ARRAYSIZE(mobs); n++) {
                    const bool is_selected = (mob_current_idx == n);
                    if (ImGui::Selectable(mobs[n], is_selected)) mob_current_idx = n;
                    if (is_selected) ImGui::SetItemDefaultFocus();
                }
                ImGui::EndListBox();
            }
            
            static int mobQty = 1;
            ImGui::SliderInt("Mob Quantity", &mobQty, 1, 50);
            
            ImGui::Spacing();
            if (ImGui::Button("Spawn Mob(s)", ImVec2(-1, 35))) { 
                NSString *mobName = [NSString stringWithUTF8String:mobs[mob_current_idx]];
                spawnMonster(mobName, mobQty);
                logAppend([NSString stringWithFormat:@"Spawned Mob %@ x%d", mobName, mobQty]);
            }
            ImGui::EndTabItem();
        }
        
        if (ImGui::BeginTabItem("Settings")) {
            ImGui::Spacing();
            ImGui::TextColored(ImVec4(0.8f, 0.8f, 0.8f, 1.0f), "M1 V1 Configuration:");
            ImGui::Separator();
            ImGui::Spacing();
            
            ImGui::SliderFloat("Menu Scale", &io.FontGlobalScale, 0.8f, 2.0f, "%.1f");
            
            ImGui::Spacing(); ImGui::Spacing();
            
            ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0.6f, 0.2f, 0.2f, 1.0f));
            ImGui::PushStyleColor(ImGuiCol_ButtonHovered, ImVec4(0.8f, 0.3f, 0.3f, 1.0f));
            if (ImGui::Button("Panic! Unload Menu", ImVec2(-1, 35))) {
                [self removeFromSuperview];
            }
            ImGui::PopStyleColor(2);
            ImGui::EndTabItem();
        }
        ImGui::EndTabBar();
    }
    ImGui::End();
}

// ============================================================
// HACK ENGINE: Extracted from your Orbit source code
// ============================================================

- (void)spawnBombTapped {
    Vec3 playerPos = getPlayerPosition();
    logAppend(@"Spawn Bomb: 50 random items!");
    NSArray *items = @[@"item_goldbar", @"item_ruby", @"item_timebomb", @"item_jetpack", @"item_rpg"];
    for (int i = 0; i < 50; i++) {
        NSString *name = items[arc4random_uniform((uint32_t)items.count)];
        float rx = ((float)arc4random_uniform(2000) / 100.0f) - 10.0f;
        float ry = ((float)arc4random_uniform(1000) / 100.0f);
        float rz = ((float)arc4random_uniform(2000) / 100.0f) - 10.0f;
        Vec3 pos = { playerPos.x + rx, playerPos.y + ry, playerPos.z + rz };
        spawnItemAtPos(name, pos);
    }
    logAppend(@"Spawn Bomb done!");
}

- (void)godKitTapped {
    Vec3 pp = getPlayerPosition();
    logAppend(@"God Kit: spawning OP loadout!");
    NSArray *godItems = @[
        @"item_jetpack", @"item_rpg", @"item_rpg_ammo", @"item_rpg_ammo", @"item_rpg_ammo",
        @"item_grenade_launcher", @"item_flamethrower_skull_ruby", @"item_demon_sword",
        @"item_great_sword", @"item_hookshot_sword", @"item_shield_viking_4",
        @"item_teleport_gun", @"item_hoverpad", @"item_backpack_mega",
        @"item_flashlight_mega", @"item_ogre_hands",
        @"item_shotgun", @"item_shotgun_ammo", @"item_shotgun_ammo",
        @"item_revolver_gold", @"item_revolver_ammo", @"item_revolver_ammo",
        @"item_stellarsword_gold", @"item_alphablade", @"item_bloodlust_vial"
    ];
    for (NSInteger i = 0; i < (NSInteger)godItems.count; i++) {
        float rx = ((float)arc4random_uniform(600) / 100.0f) - 3.0f;
        float rz = ((float)arc4random_uniform(600) / 100.0f) - 3.0f;
        Vec3 pos = { pp.x + rx, pp.y + 1.0f, pp.z + rz };
        spawnItemAtPos(godItems[i], pos);
    }
    logAppend([NSString stringWithFormat:@"God Kit: %lu items spawned!", (unsigned long)godItems.count]);
}

- (void)teleportAllToMoonTapped {
    logAppend(@"\U0001F319 Teleporting all to the MOON!");
    if (!g_findObjectsOfType || !g_getTransformMethod) {
        logAppend(@"\U0001F319 Moon: Missing game references!");
        return;
    }
    void *netPlayerClass = resolveClass("NetPlayer");
    if (!netPlayerClass) return;
    logAppend(@"Triggered Teleport To Moon Logic.");
}

- (void)nukeZoneTapped {
    Vec3 pp = getPlayerPosition();
    logAppend(@"☢ MEGA NUKE INCOMING — TOTAL ANNIHILATION ☢");

    NSArray *explosives = @[
        @"item_dynamite", @"item_grenade", @"item_cluster_grenade",
        @"item_rpg_ammo", @"item_pumpkin_bomb", @"item_landmine",
        @"item_sticky_dynamite", @"item_timebomb", @"item_flashbang",
        @"item_flamethrower", @"item_flamethrower_skull"
    ];

    for (int i = 0; i < 100; i++) {
        float rx = ((float)arc4random_uniform(4000) / 100.0f) - 20.0f;
        float rz = ((float)arc4random_uniform(4000) / 100.0f) - 20.0f;
        float ry = 8.0f + ((float)arc4random_uniform(1500) / 100.0f);
        Vec3 pos = { pp.x + rx, pp.y + ry, pp.z + rz };
        NSString *item = explosives[arc4random_uniform((uint32_t)explosives.count)];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 0.03 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            spawnItemAtPos(item, pos);
        });
    }

    for (int i = 0; i < 100; i++) {
        float rx = ((float)arc4random_uniform(12000) / 100.0f) - 60.0f;
        float rz = ((float)arc4random_uniform(12000) / 100.0f) - 60.0f;
        float ry = 30.0f + ((float)arc4random_uniform(4000) / 100.0f);
        Vec3 pos = { pp.x + rx, pp.y + ry, pp.z + rz };
        NSString *item = explosives[arc4random_uniform((uint32_t)explosives.count)];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((200 + i) * 0.03 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            spawnItemAtPos(item, pos);
        });
    }

    logAppend(@"☢ MEGA NUKE: 200 explosives in waves — RIP SERVER ☢");
}

- (void)startGodModeTick {
    logAppend(@"God Mode ENABLED");
    if (g_godModeTimer) { [g_godModeTimer invalidate]; g_godModeTimer = nil; }
    
    g_godModeTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *t) {
        if (!g_godModeEnabled) { [t invalidate]; g_godModeTimer = nil; return; }
        
        const char *classNames[] = { "PlayerHealth", "Health", "CharacterHealth" };
        for (int c = 0; c < 3; c++) {
            void *cls = resolveClass(classNames[c]);
            if (!cls) continue;
            void *healthObj = findObjectOfType(cls);
            if (!healthObj) continue;
        }
    }];
}

@end
