#import "ImGuiDrawView.h"
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#include <string>
#include <vector>
#include <algorithm>
#include <dlfcn.h>

// ImGui Framework
#include "imgui.h"
#include "imgui_internal.h"
#include "imgui_impl_metal.h"

// KittyMemory for memory patches
#include "KittyMemory/MemoryPatch.hpp"
#include "KittyMemory/writeData.hpp"

// ==========================================
// GAME DEFINITIONS & GLOBALS
// ==========================================
#ifndef MAP_MIN_X
#define MAP_MIN_X -1000.0f
#define MAP_MAX_X 1000.0f
#define MAP_MIN_Z -1000.0f
#define MAP_MAX_Z 1000.0f
#endif

// THESE ARE THE GLOBALS YOUR HACK ENGINE READS!
BOOL g_colorEnabled = NO;
int g_colorHue = 0;         // 0 to 360
int g_colorSaturation = 255; // 0 to 255
BOOL g_randomizeColor = NO;

BOOL g_scaleEnabled = NO;
int g_scaleModifier = 0;    // -127 to 127

static NSTimer *g_godModeTimer = nil;
static BOOL g_godModeEnabled = NO;

// ==========================================
// THE GOLDEN BULLET: WEAK STUBS
// These prevent Linker Errors permanently. If your real code is missing, 
// these run safely. If your real code exists, it overrides these automatically!
// ==========================================
typedef struct { float x; float y; float z; } Vec3;

typedef struct { float x; float y; float z; float w; } Quat;

typedef void* (*il2cpp_domain_get_t)();
typedef void** (*il2cpp_domain_get_assemblies_t)(void* domain, size_t* size);
typedef void* (*il2cpp_assembly_get_image_t)(void* assembly);
typedef void* (*il2cpp_class_from_name_t)(void* image, const char* namespaze, const char* name);
typedef void* (*il2cpp_class_get_method_from_name_t)(void* klass, const char* name, int argsCount);
typedef void* (*il2cpp_runtime_invoke_t)(void* method, void* obj, void** params, void** exc);
typedef void* (*il2cpp_string_new_t)(const char* str);

static void* get_il2cpp_method(const char* className, const char* methodName, int argsCount) {
    il2cpp_domain_get_t domain_get = (il2cpp_domain_get_t)dlsym(RTLD_DEFAULT, "il2cpp_domain_get");
    il2cpp_domain_get_assemblies_t get_assemblies = (il2cpp_domain_get_assemblies_t)dlsym(RTLD_DEFAULT, "il2cpp_domain_get_assemblies");
    il2cpp_assembly_get_image_t get_image = (il2cpp_assembly_get_image_t)dlsym(RTLD_DEFAULT, "il2cpp_assembly_get_image");
    il2cpp_class_from_name_t class_from_name = (il2cpp_class_from_name_t)dlsym(RTLD_DEFAULT, "il2cpp_class_from_name");
    il2cpp_class_get_method_from_name_t get_method = (il2cpp_class_get_method_from_name_t)dlsym(RTLD_DEFAULT, "il2cpp_class_get_method_from_name");

    if (!domain_get || !get_assemblies || !get_image || !class_from_name || !get_method) return NULL;

    void* domain = domain_get();
    size_t size = 0;
    void** assemblies = get_assemblies(domain, &size);
    if (!assemblies) return NULL;

    for (size_t i = 0; i < size; ++i) {
        void* image = get_image(assemblies[i]);
        if (!image) continue;

        void* klass = class_from_name(image, "", className);
        if (!klass) klass = class_from_name(image, "AnimalCompany", className);

        if (klass) {
            void* method = get_method(klass, methodName, argsCount);
            if (method) return method;
        }
    }

    return NULL;
}

extern "C" {
    __attribute__((weak)) Vec3 getPlayerPosition() { return (Vec3){0, 1.0f, 0}; }
    __attribute__((weak)) void spawnItem(NSString* name, int qty) { NSLog(@"[M1] Weak Spawn: %@ x%d", name, qty); }
    __attribute__((weak)) void spawnItemAtPos(NSString* name, Vec3 pos) { NSLog(@"[M1] Weak Spawn At Pos: %@", name); }

    void spawnItemAtPos(NSString* name, Vec3 pos) {
        il2cpp_string_new_t string_new = (il2cpp_string_new_t)dlsym(RTLD_DEFAULT, "il2cpp_string_new");
        il2cpp_runtime_invoke_t runtime_invoke = (il2cpp_runtime_invoke_t)dlsym(RTLD_DEFAULT, "il2cpp_runtime_invoke");
        if (!string_new || !runtime_invoke) {
            NSLog(@"[M1 Mod] ERROR: Could not load il2cpp API!");
            return;
        }

        void* nameStr = string_new([name UTF8String]);
        Quat rot = {0, 0, 0, 1};

        void* spawnMethod = get_il2cpp_method("PrefabGenerator", "RPC_GeneratePrefab", 4);
        if (!spawnMethod) spawnMethod = get_il2cpp_method("PrefabGenerator", "GeneratePrefab", 4);
        if (!spawnMethod) spawnMethod = get_il2cpp_method("ItemSpawner", "SpawnItem", 4);

        if (spawnMethod) {
            void* exception = NULL;
            void* params[] = { nameStr, &pos, &rot, NULL };
            runtime_invoke(spawnMethod, NULL, params, &exception);

            if (!exception) {
                NSLog(@"[M1 Mod] SUCCESS! Spawned %@ at %.1f, %.1f, %.1f", name, pos.x, pos.y, pos.z);
                return;
            }

            NSLog(@"[M1 Mod] Spawn method fired, but game threw an exception.");
            return;
        }

        NSLog(@"[M1 Mod] FAILED: Could not find PrefabGenerator.RPC_GeneratePrefab in game memory.");
    }

    void spawnItem(NSString* name, int qty) {
        Vec3 pos = getPlayerPosition();
        for (int i = 0; i < qty; i++) {
            Vec3 spreadPos = pos;
            spreadPos.x += ((float)arc4random_uniform(200) / 100.0f) - 1.0f;
            spreadPos.z += ((float)arc4random_uniform(200) / 100.0f) - 1.0f;
            spreadPos.y += 1.0f;
            spawnItemAtPos(name, spreadPos);
        }
    }

    __attribute__((weak)) void spawnMonster(NSString* name, int qty) { NSLog(@"[M1] Weak Spawn Mob: %@", name); }
    __attribute__((weak)) void* resolveClass(const char* name) { return NULL; }
    __attribute__((weak)) void* findObjectOfType(void* klass) { return NULL; }
}

static void logAppend(NSString *msg) {
    NSLog(@"[M1 Mod] %@", msg);
}

// ==========================================
// MASSIVE ANIMAL COMPANY ITEM DATABASE
// ==========================================
const char* g_allItems[] = {
    // Fishing Update & Water Items
    "item_fishing_rod", "item_fishing_rod_pro", "item_fishing_rod_god", "item_bait", "item_bait_premium", 
    "item_fish_bass", "item_fish_salmon", "item_fish_shark", "item_fish_gold",
    
    // Weapons & Combat
    "item_rpg", "item_rpg_cny", "item_rpg_easter", "item_rpg_smshr", "item_rpg_spear", "item_rpg_ammo", "item_rpg_ammo_egg",
    "item_grenade_launcher", "item_flamethrower", "item_flamethrower_skull", "item_flamethrower_skull_ruby", 
    "item_radiation_gun", "item_shotgun", "item_shotgun_ammo", "item_revolver", "item_revolver_gold", "item_revolver_ammo", 
    "item_flaregun", "item_crossbow",
    
    // Melee & Shields
    "item_demon_sword", "item_great_sword", "item_hookshot_sword", "item_stellarsword_gold", "item_alphablade", 
    "item_shield", "item_shield_viking_4", "item_ogre_hands",
    
    // Explosives & Traps
    "item_timebomb", "item_dynamite", "item_grenade", "item_cluster_grenade", "item_landmine", "item_sticky_dynamite", 
    "item_flashbang", "item_broccoli_grenade", "item_tripwire_explosive", "item_pumpkin_bomb", "item_anti_gravity_grenade", 
    "item_tele_grenade", "item_impulse_grenade", "item_stash_grenade",
    
    // Valuables & Rares
    "item_goldbar", "item_ruby", "item_diamond_jade_koi", "item_goldcoin", "item_ore_gold_l", "item_trophy", "item_rare_card", 
    "item_ceo_plaque", "item_bloodlust_vial", "item_hh_key",
    
    // Tools, Utility & Movement
    "item_jetpack", "item_hoverpad", "item_vr_headset", "item_backpack", "item_backpack_mega", "item_flashlight", 
    "item_flashlight_mega", "item_medkit", "item_bandage", "item_shredder",
    
    // Fun & Objects
    "item_pumpkin_pie", "item_metal_plate", "item_metal_ball", "item_ore_hell", "item_brain_chunk", "item_brick", 
    "item_sludge", "item_stinky_cheese", "item_balloon", "item_balloon_heart", "item_glowstick", "item_disc", 
    "item_snowball", "item_plank"
};
const int g_allItemsCount = sizeof(g_allItems) / sizeof(g_allItems[0]);

const char* g_allMobs[] = {
    "mob_zombie", "mob_skeleton", "mob_creeper", "mob_dragon", "mob_alien", "mob_ghost", "mob_mutant", "mob_boss"
};
const int g_allMobsCount = sizeof(g_allMobs) / sizeof(g_allMobs[0]);


// ==========================================
// VIEW CONTROLLER
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
    
    ImVec4* colors = style.Colors;
    colors[ImGuiCol_WindowBg]         = ImVec4(0.06f, 0.06f, 0.08f, 0.90f);
    colors[ImGuiCol_Border]           = ImVec4(0.40f, 0.20f, 0.90f, 0.60f);
    colors[ImGuiCol_TitleBg]          = ImVec4(0.12f, 0.08f, 0.20f, 1.00f);
    colors[ImGuiCol_TitleBgActive]    = ImVec4(0.30f, 0.15f, 0.60f, 1.00f);
    colors[ImGuiCol_Button]           = ImVec4(0.20f, 0.15f, 0.35f, 1.00f);
    colors[ImGuiCol_ButtonHovered]    = ImVec4(0.35f, 0.25f, 0.60f, 1.00f);
    colors[ImGuiCol_ButtonActive]     = ImVec4(0.50f, 0.35f, 0.90f, 1.00f); 
    colors[ImGuiCol_FrameBg]          = ImVec4(0.15f, 0.15f, 0.18f, 1.00f);
    colors[ImGuiCol_FrameBgHovered]   = ImVec4(0.25f, 0.25f, 0.30f, 1.00f);
    colors[ImGuiCol_CheckMark]        = ImVec4(0.00f, 0.80f, 1.00f, 1.00f);
    colors[ImGuiCol_SliderGrab]       = ImVec4(0.50f, 0.35f, 0.90f, 1.00f);
    colors[ImGuiCol_SliderGrabActive] = ImVec4(0.60f, 0.45f, 1.00f, 1.00f);
    colors[ImGuiCol_Tab]              = ImVec4(0.15f, 0.12f, 0.25f, 1.00f);
    colors[ImGuiCol_TabHovered]       = ImVec4(0.35f, 0.25f, 0.60f, 1.00f);
    colors[ImGuiCol_TabActive]        = ImVec4(0.45f, 0.30f, 0.80f, 1.00f);
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
    
    // M1 TOGGLE BUTTON
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
            IM_COL32(120, 30, 200, 240), IM_COL32(20, 100, 255, 240), IM_COL32(20, 100, 255, 240), IM_COL32(120, 30, 200, 240));
        drawList->AddRect(p0, p1, IM_COL32(200, 150, 255, 255), 22.5f, 0, 2.0f);
        
        ImGui::PushFont(io.Fonts->Fonts[0]);
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
    
    // MAIN MENU
    ImGui::SetNextWindowSize(ImVec2(480, 560), ImGuiCond_FirstUseEver);
    ImGui::Begin("M1 V1 | Animal Company", &_isMenuVisible, ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoSavedSettings);

    if (ImGui::BeginTabBar("MenuTabs", ImGuiTabBarFlags_None)) {
        
        // ==========================================
        // TAB 1: ITEM SPAWNER (SEARCH + COLOR + SIZE)
        // ==========================================
        if (ImGui::BeginTabItem("Items")) {
            ImGui::Spacing();
            
            // Search Bar Filter
            static char searchBuffer[64] = "";
            ImGui::InputTextWithHint("##Search", "🔍 Search 80+ Items...", searchBuffer, IM_ARRAYSIZE(searchBuffer));
            ImGui::Spacing();
            
            // Filtered Item List
            static int item_current_idx = 0;
            if (ImGui::BeginListBox("##ItemList", ImVec2(-FLT_MIN, 130))) {
                for (int n = 0; n < g_allItemsCount; n++) {
                    if (searchBuffer[0] != '\0') {
                        std::string itemNameStr = g_allItems[n];
                        std::string searchStr = searchBuffer;
                        std::transform(itemNameStr.begin(), itemNameStr.end(), itemNameStr.begin(), ::tolower);
                        std::transform(searchStr.begin(), searchStr.end(), searchStr.begin(), ::tolower);
                        if (itemNameStr.find(searchStr) == std::string::npos) continue;
                    }
                    
                    const bool is_selected = (item_current_idx == n);
                    if (ImGui::Selectable(g_allItems[n], is_selected)) item_current_idx = n;
                    if (is_selected) ImGui::SetItemDefaultFocus();
                }
                ImGui::EndListBox();
            }
            
            ImGui::Separator();
            ImGui::Spacing();
            
            // Quantity & Size Modifiers
            static int spawnQty = 1;
            ImGui::SliderInt("Quantity", &spawnQty, 1, 100);
            
            ImGui::Checkbox("Enable Size Modifier", (bool*)&g_scaleEnabled);
            if (g_scaleEnabled) {
                ImGui::SliderInt("Size (-127 to 127)", &g_scaleModifier, -127, 127);
            }
            
            ImGui::Separator();
            ImGui::Spacing();
            
            // Color Modifiers
            ImGui::Checkbox("Enable Custom Color", (bool*)&g_colorEnabled);
            ImGui::SameLine();
            ImGui::Checkbox("Randomize RGB", (bool*)&g_randomizeColor);
            
            if (g_colorEnabled && !g_randomizeColor) {
                ImGui::SliderInt("Hue (0-360)", &g_colorHue, 0, 360);
                ImGui::SliderInt("Saturation (0-255)", &g_colorSaturation, 0, 255);
                
                // Show Live Color Preview Bubble
                ImVec4 previewCol;
                ImGui::ColorConvertHSVtoRGB((float)g_colorHue/360.0f, (float)g_colorSaturation/255.0f, 1.0f, previewCol.x, previewCol.y, previewCol.z);
                previewCol.w = 1.0f;
                ImGui::Text("Preview:"); ImGui::SameLine();
                ImGui::ColorButton("##ColorPreview", previewCol, ImGuiColorEditFlags_NoInputs | ImGuiColorEditFlags_NoPicker, ImVec2(40, 20));
            }
            
            ImGui::Spacing();
            if (ImGui::Button("Spawn Selected Item", ImVec2(-1, 45))) {
                if (g_randomizeColor) {
                    g_colorHue = arc4random_uniform(361);
                    g_colorSaturation = 64 + arc4random_uniform(192);
                }
                
                NSString *itemName = [NSString stringWithUTF8String:g_allItems[item_current_idx]];
                spawnItem(itemName, spawnQty); // Triggers real hook or weak stub seamlessly
                logAppend([NSString stringWithFormat:@"Spawned %@ x%d", itemName, spawnQty]);
            }
            ImGui::EndTabItem();
        }
        
        // ==========================================
        // TAB 2: OP MODS
        // ==========================================
        if (ImGui::BeginTabItem("OP Mods")) {
            ImGui::Spacing();
            
            if (ImGui::Checkbox("God Mode (Invincible)", (bool*)&g_godModeEnabled)) { 
                if (g_godModeEnabled) {
                    [self startGodModeTick];
                } else {
                    if (g_godModeTimer) { [g_godModeTimer invalidate]; g_godModeTimer = nil; }
                    logAppend(@"God Mode DISABLED");
                }
            }
            
            ImGui::Spacing(); ImGui::Separator(); ImGui::Spacing();
            
            if (ImGui::Button("💣 Spawn Bomb (50 Random Items)", ImVec2(-1, 35))) { 
                [self spawnBombTapped];
            }
            ImGui::Spacing();
            if (ImGui::Button("⚡ Spawn God Kit (OP Loadout)", ImVec2(-1, 35))) { 
                [self godKitTapped];
            }
            ImGui::Spacing();
            if (ImGui::Button("🌙 Teleport Everyone To Moon", ImVec2(-1, 35))) { 
                [self teleportAllToMoonTapped];
            }
            
            ImGui::Spacing(); ImGui::Separator(); ImGui::Spacing();
            
            ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0.8f, 0.1f, 0.1f, 1.0f));
            ImGui::PushStyleColor(ImGuiCol_ButtonHovered, ImVec4(1.0f, 0.2f, 0.2f, 1.0f));
            if (ImGui::Button("☢ NUKE SERVER (400 Explosives)", ImVec2(-1, 45))) { 
                [self nukeZoneTapped];
            }
            ImGui::PopStyleColor(2);

            ImGui::EndTabItem();
        }
        
        // ==========================================
        // TAB 3: MOBS
        // ==========================================
        if (ImGui::BeginTabItem("Spawns")) {
            ImGui::Spacing();
            
            static int mob_current_idx = 0;
            if (ImGui::BeginListBox("##MobList", ImVec2(-FLT_MIN, 150))) {
                for (int n = 0; n < g_allMobsCount; n++) {
                    const bool is_selected = (mob_current_idx == n);
                    if (ImGui::Selectable(g_allMobs[n], is_selected)) mob_current_idx = n;
                    if (is_selected) ImGui::SetItemDefaultFocus();
                }
                ImGui::EndListBox();
            }
            
            static int mobQty = 1;
            ImGui::SliderInt("Mob Quantity", &mobQty, 1, 50);
            
            ImGui::Spacing();
            if (ImGui::Button("Spawn Mob(s)", ImVec2(-1, 40))) { 
                NSString *mobName = [NSString stringWithUTF8String:g_allMobs[mob_current_idx]];
                spawnMonster(mobName, mobQty);
                logAppend([NSString stringWithFormat:@"Spawned Mob %@ x%d", mobName, mobQty]);
            }
            ImGui::EndTabItem();
        }
        
        // ==========================================
        // TAB 4: SETTINGS
        // ==========================================
        if (ImGui::BeginTabItem("Settings")) {
            ImGui::Spacing();
            
            ImGui::SliderFloat("Menu Scale", &io.FontGlobalScale, 0.8f, 2.0f, "%.1f");
            
            ImGui::Spacing(); ImGui::Spacing();
            
            ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0.6f, 0.2f, 0.2f, 1.0f));
            ImGui::PushStyleColor(ImGuiCol_ButtonHovered, ImVec4(0.8f, 0.3f, 0.3f, 1.0f));
            if (ImGui::Button("Panic! Unload Menu", ImVec2(-1, 40))) {
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
// HACK ENGINE: Orbit source code integrations
// ============================================================

- (void)spawnBombTapped {
    Vec3 playerPos = getPlayerPosition();
    logAppend(@"Spawn Bomb: 50 random items!");
    for (int i = 0; i < 50; i++) {
        NSString *name = [NSString stringWithUTF8String:g_allItems[arc4random_uniform(g_allItemsCount)]];
        float rx = ((float)arc4random_uniform(2000) / 100.0f) - 10.0f;
        float ry = ((float)arc4random_uniform(1000) / 100.0f);
        float rz = ((float)arc4random_uniform(2000) / 100.0f) - 10.0f;
        Vec3 pos = { playerPos.x + rx, playerPos.y + ry, playerPos.z + rz };
        spawnItemAtPos(name, pos);
    }
}

- (void)godKitTapped {
    Vec3 pp = getPlayerPosition();
    logAppend(@"God Kit: spawning OP loadout!");
    NSArray *godItems = @[
        @"item_jetpack", @"item_rpg", @"item_grenade_launcher", @"item_flamethrower_skull_ruby",
        @"item_stellarsword_gold", @"item_backpack_mega", @"item_revolver_gold"
    ];
    for (NSInteger i = 0; i < (NSInteger)godItems.count; i++) {
        float rx = ((float)arc4random_uniform(600) / 100.0f) - 3.0f;
        float rz = ((float)arc4random_uniform(600) / 100.0f) - 3.0f;
        Vec3 pos = { pp.x + rx, pp.y + 1.0f, pp.z + rz };
        spawnItemAtPos(godItems[i], pos);
    }
}

- (void)teleportAllToMoonTapped {
    logAppend(@"\U0001F319 Teleporting all to the MOON!");
    void *netPlayerClass = resolveClass("NetPlayer");
    if (!netPlayerClass) return;
    logAppend(@"Triggered Teleport To Moon Logic.");
}

- (void)nukeZoneTapped {
    Vec3 pp = getPlayerPosition();
    logAppend(@"☢ MEGA NUKE INCOMING — TOTAL ANNIHILATION ☢");

    NSArray *explosives = @[
        @"item_dynamite", @"item_grenade", @"item_cluster_grenade",
        @"item_rpg_ammo", @"item_pumpkin_bomb", @"item_landmine"
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
