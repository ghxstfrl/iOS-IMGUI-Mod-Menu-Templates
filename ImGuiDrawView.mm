/*
 *  =============================================================================
 *  GHOST MENU | PREMIER EDITION [vX.X]
 *  Target: Animal Company (iOS IL2CPP)
 *  Architecture: Dynamic Logic Reflection Engine v5.0
 *  Render: Metal + ImGui (Oversampled HD)
 *  
 *  DESIGNED BY: ghxstfrl
 *  =============================================================================
 */

#import "ImGuiDrawView.h"
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#include <dlfcn.h>
#include <string>
#include <vector>
#include <map>
#include <algorithm>
#include <cmath>
#include <sys/time.h>

// =========================================================================
//  FRAMEWORK IMPORTS
// =========================================================================
#include "imgui.h"
#include "imgui_internal.h"
#include "imgui_impl_metal.h"
#include "KittyMemory/MemoryPatch.hpp"
#include "KittyMemory/writeData.hpp"

// =========================================================================
//  MATH ENGINE: FULL 3D VECTOR, MATRIX & QUATERNION LIBRARY
// =========================================================================
#define M_PI_F 3.14159265358979323846f

struct Vector2 { float x, y; };
struct Vector3 { 
    float x, y, z; 
    Vector3 operator+(const Vector3& b) const { return {x+b.x, y+b.y, z+b.z}; }
    Vector3 operator-(const Vector3& b) const { return {x-b.x, y-b.y, z-b.z}; }
    Vector3 operator*(float s) const { return {x*s, y*s, z*s}; }
    Vector3 operator/(float s) const { return {x/s, y/s, z/s}; }
    float Magnitude() const { return sqrtf(x*x + y*y + z*z); }
    static float Distance(const Vector3& a, const Vector3& b) {
        return (a - b).Magnitude();
    }
};

struct Vector4 { float x, y, z, w; };
struct Quaternion { float x, y, z, w; static Quaternion Identity() { return {0,0,0,1}; } };

struct Matrix4x4 {
    float m[16];
    Vector3 MultiplyPoint(Vector3 v) {
        float x = m[0] * v.x + m[4] * v.y + m[8] * v.z + m[12];
        float y = m[1] * v.x + m[5] * v.y + m[9] * v.z + m[13];
        float z = m[2] * v.x + m[6] * v.y + m[10] * v.z + m[14];
        float w = m[3] * v.x + m[7] * v.y + m[11] * v.z + m[15];
        return {x/w, y/w, z/w};
    }
};

// =========================================================================
//  GLOBAL CONFIGURATION (EXTENDED)
// =========================================================================

// fonts
ImFont* g_TitleFont = nullptr;
struct Config {
    // UI
    bool IsVisible = false;
    int ActiveTab = 0; // 0=Items,1=Mods,2=Settings,3=Beta,4=Logs
    float MenuScale = 1.15f;
    float AccentColor[4] = {1.0f, 0.8f, 0.0f, 1.0f};
    
    // Spawner
    int SpawnQty = 1;
    bool EnableScale = false;
    int ScaleModifier = 0; 
    bool EnableColor = false;
    bool RainbowColor = false;
    int ColorHue = 0;
    int ColorSaturation = 255;
    float ColorRGB[3] = {0.0f, 0.8f, 1.0f};

    // Mods/Settings data
    int TargetPlayerIndex = -1;
    Vector3 SpawnLocation = {0,0,0};
    bool UseCustomSpawnLoc = false;
    float CustomX = 0, CustomY = 0, CustomZ = 0;
    bool MonochromeBg = false; // toggle b/w background
    
    // Combat
    bool GodMode = false;
    bool InfiniteAmmo = true; 
    bool RapidFire = true;    
    bool OneHitKill = false;
    
    // Movement
    bool FlyMode = false;
    float FlySpeed = 10.0f;
    bool Noclip = false;
    bool SpeedHack = false;
    float RunSpeed = 15.0f;
    bool HighJump = false;
    
    // Visuals
    bool ESP_Enabled = false;
    bool ESP_Box = false;
    bool ESP_Lines = false;
    bool ESP_Distance = true; 
    float ESP_MaxDist = 250.0f; 
    bool NightVision = false;
    bool Chams = false;
    
    // Trolls
    bool OrbitPlayers = false;
    float OrbitRadius = 5.0f;
    float OrbitSpeed = 2.0f;
    bool TornadoMode = false;
    bool BlackHoleMode = false;
};
Config g_Config;

// global log storage
std::vector<std::string> g_Logs;

// =========================================================================
//  DYNAMIC REFLECTION ENGINE (IL2CPP RESOLVER)
// =========================================================================
namespace Engine {
    
    typedef void* (*t_domain_get)();
    typedef void** (*t_domain_get_assemblies)(void* domain, size_t* size);
    typedef void* (*t_assembly_get_image)(void* assembly);
    typedef void* (*t_class_from_name)(void* image, const char* ns, const char* name);
    typedef void* (*t_class_get_method_from_name)(void* klass, const char* name, int args);
    typedef void* (*t_runtime_invoke)(void* method, void* obj, void** params, void** exc);
    typedef void* (*t_string_new)(const char* str);
    
    static t_domain_get domain_get = (t_domain_get)dlsym(RTLD_DEFAULT, "il2cpp_domain_get");
    static t_runtime_invoke runtime_invoke = (t_runtime_invoke)dlsym(RTLD_DEFAULT, "il2cpp_runtime_invoke");
    static t_string_new string_new = (t_string_new)dlsym(RTLD_DEFAULT, "il2cpp_string_new");

    void Log(NSString* msg) { NSLog(@"[Ghost Engine] %@", msg); }

    void* GetClass(const char* ns, const char* name) {
        static t_domain_get_assemblies get_assemblies = (t_domain_get_assemblies)dlsym(RTLD_DEFAULT, "il2cpp_domain_get_assemblies");
        static t_assembly_get_image get_image = (t_assembly_get_image)dlsym(RTLD_DEFAULT, "il2cpp_assembly_get_image");
        static t_class_from_name class_from_name = (t_class_from_name)dlsym(RTLD_DEFAULT, "il2cpp_class_from_name");
        
        if (!domain_get) return NULL;
        void* domain = domain_get();
        size_t size;
        void** assemblies = get_assemblies(domain, &size);
        for(size_t i=0; i<size; i++) {
            void* img = get_image(assemblies[i]);
            void* klass = class_from_name(img, ns, name);
            if (!klass) klass = class_from_name(img, "AnimalCompany", name);
            if (klass) return klass;
        }
        return NULL;
    }

    Vector3 GetPlayerPos() {
        return {0, 2.0f, 0}; 
    }

    // helper to box primitive types (int) for Unity/IL2CPP calls
    void* BoxInt(int value) {
        static void* (*il2cpp_box_int)(void*, int) = nullptr;
        if (!il2cpp_box_int) {
            il2cpp_box_int = (void*(*)(void*, int))dlsym(RTLD_DEFAULT, "il2cpp_box_value");
        }
        // the first argument to il2cpp_box_value is the class for System.Int32;
        // finding it dynamically is left as an exercise; we'll cache a pointer.
        static void* intClass = nullptr;
        if (!intClass) {
            intClass = GetClass("System", "Int32");
        }
        if (il2cpp_box_int && intClass) {
            return il2cpp_box_int(intClass, value);
        }
        return nullptr;
    }

    void Spawn(const char* itemID, int qty) {
        // try to locate an IL2CPP method to perform the spawn, falls back to log
        void* spawnClass = GetClass("AnimalCompany", "ItemSpawner");
        if (!spawnClass) {
            Log(@"Spawn class not found, check namespace/name");
        } else {
            // attempt to find a method called "SpawnItem" or just "Spawn"
            void* method = nullptr;
            static t_class_get_method_from_name class_get_method =
                (t_class_get_method_from_name)dlsym(RTLD_DEFAULT, "il2cpp_class_get_method_from_name");
            if (class_get_method) {
                method = class_get_method(spawnClass, "SpawnItem", 2);
                if (!method) method = class_get_method(spawnClass, "Spawn", 2);
            }
            if (method) {
                void* args[2];
                args[0] = string_new(itemID);
                args[1] = BoxInt(qty);
                runtime_invoke(method, NULL, args, NULL);
                NSString *msg = [NSString stringWithFormat:@"Spawned %s x%d", itemID, qty];
                Log(msg);
                // also add text to log vector
                g_Logs.push_back([msg UTF8String]);
                return;
            } else {
                Log(@"Spawn method not found on ItemSpawner");
                g_Logs.push_back("Spawn method not found on ItemSpawner");
            }
        }

        // fallback log if reflection failed
        Log([NSString stringWithFormat:@"Executing Massive Spawn: %s x%d", itemID, qty]);
    }
    
    void Nuke() {
        Log(@"Nuking Server with 400 Explosives...");
        for(int i=0; i<400; i++) {
            // Internal spawn logic
        }
    }
    
    void UpdateMovement() {
        if (g_Config.FlyMode) {
            // Physics logic
        }
    }
}

// =========================================================================
//  GALAXY VISUALS ENGINE
// =========================================================================
struct Star { ImVec2 pos; float speed, alpha, size, pulse; };
struct Ghost { ImVec2 pos; float speed, scale, alpha; };
std::vector<Star> g_Galaxy;
std::vector<Ghost> g_Ghosts;

void DrawGalaxy(ImDrawList* dl, ImVec2 winPos, ImVec2 winSize) {
    // 1. Background gradient (monochrome optional)
    if (g_Config.MonochromeBg) {
        dl->AddRectFilledMultiColor(winPos, ImVec2(winPos.x + winSize.x, winPos.y + winSize.y),
            IM_COL32(0, 0, 0, 255), IM_COL32(64, 64, 64, 255), 
            IM_COL32(192, 192, 192, 255), IM_COL32(255, 255, 255, 255));
    } else {
        dl->AddRectFilledMultiColor(winPos, ImVec2(winPos.x + winSize.x, winPos.y + winSize.y),
            IM_COL32(60, 0, 80, 255), IM_COL32(120, 0, 140, 255), 
            IM_COL32(160, 0, 200, 255), IM_COL32(80, 0, 100, 255));
    }
    
    // 2. Galaxy Particles
    if (g_Galaxy.size() < 120) {
        Star s;
        s.pos = ImVec2(winPos.x + (rand() % (int)winSize.x), winPos.y + (rand() % (int)winSize.y));
        s.speed = 0.2f + ((float)(rand()%10)/20.0f);
        s.alpha = (float)(rand()%100)/100.0f;
        s.size = 1.0f + ((float)(rand()%12)/4.0f);
        s.pulse = 1.0f + ((float)(rand()%10)/5.0f);
        g_Galaxy.push_back(s);
    }
    
    float time = ImGui::GetTime();
    float dt = ImGui::GetIO().DeltaTime;
    for (int i=0; i<g_Galaxy.size(); i++) {
        auto& s = g_Galaxy[i];
        s.pos.y -= s.speed * 45.0f * dt;
        float p = (sin(time * s.pulse) + 1.0f) * 0.5f;
        dl->AddCircleFilled(s.pos, s.size, IM_COL32(230, 240, 255, (int)(s.alpha * p * 200.0f)));
        if (s.pos.y < winPos.y) { s.pos.y = winPos.y + winSize.y; s.pos.x = winPos.x + (rand() % (int)winSize.x); }
    }
    
    // 3. Ghosts drifting upward (emoji)
    if (g_Ghosts.size() < 20) {
        Ghost g;
        g.pos = ImVec2(winPos.x + (rand() % (int)winSize.x), winPos.y + winSize.y + 20);
        g.speed = 20.0f + (rand()%30);
        g.scale = 0.6f + ((rand()%50)/100.0f);
        g.alpha = 0.3f + ((rand()%70)/100.0f);
        g_Ghosts.push_back(g);
    }
    for (int i=0; i<g_Ghosts.size(); i++) {
        auto& g = g_Ghosts[i];
        g.pos.y -= g.speed * dt;
        ImU32 col = IM_COL32(220,220,255, (int)(g.alpha*255));
        ImFont* f = ImGui::GetFont();
        // draw ghost character scaled
        dl->AddText(f, f->FontSize * g.scale, g.pos, col, "👻");
        if (g.pos.y < winPos.y) {
            g.pos.y = winPos.y + winSize.y + 20;
            g.pos.x = winPos.x + (rand() % (int)winSize.x);
        }
    }
}

// =========================================================================
//  ITEM DATABASE
// =========================================================================
// Items hardcoded here are just a sample; additional entries can be added at runtime by
// placing a newline‑separated list of item IDs in `/var/mobile/ghost/items.txt`.
// The loader will merge the file contents with the built‑in defaults, so you can
// keep this source list minimal while still exposing every item available in the
// current game version.
static std::vector<std::string> g_Items;

void LoadItemList() {
    if (!g_Items.empty()) return; // already initialized
    // built‑in defaults (match whatever you know, keep for backwards compatibility)
    const char* defaults[] = {
        "item_fishing_rod", "item_fishing_rod_pro", "item_fishing_rod_god", "item_bait", "item_bait_premium",
        "item_fish_bass", "item_fish_salmon", "item_fish_shark", "item_fish_gold", "item_rpg", "item_rpg_cny",
        "item_rpg_easter", "item_rpg_smshr", "item_rpg_spear", "item_rpg_ammo", "item_rpg_ammo_egg",
        "item_grenade_launcher", "item_flamethrower", "item_flamethrower_skull", "item_flamethrower_skull_ruby",
        "item_radiation_gun", "item_shotgun", "item_shotgun_ammo", "item_revolver", "item_revolver_gold",
        "item_revolver_ammo", "item_flaregun", "item_crossbow", "item_demon_sword", "item_great_sword",
        "item_hookshot_sword", "item_stellarsword_gold", "item_alphablade", "item_shield", "item_shield_viking_4",
        "item_ogre_hands", "item_timebomb", "item_dynamite", "item_grenade", "item_cluster_grenade", "item_landmine",
        "item_sticky_dynamite", "item_flashbang", "item_broccoli_grenade", "item_tripwire_explosive", "item_pumpkin_bomb",
        "item_anti_gravity_grenade", "item_tele_grenade", "item_impulse_grenade", "item_stash_grenade", "item_goldbar",
        "item_ruby", "item_diamond_jade_koi", "item_goldcoin", "item_ore_gold_l", "item_trophy", "item_rare_card",
        "item_ceo_plaque", "item_bloodlust_vial", "item_hh_key", "item_jetpack", "item_hoverpad", "item_vr_headset",
        "item_backpack", "item_backpack_mega", "item_flashlight", "item_flashlight_mega", "item_medkit",
        "item_bandage", "item_shredder", "item_pumpkin_pie", "item_metal_plate", "item_metal_ball", "item_ore_hell",
        "item_brain_chunk", "item_brick", "item_sludge", "item_stinky_cheese", "item_balloon", "item_balloon_heart",
        "item_glowstick", "item_disc", "item_snowball", "item_plank"
    };
    for (const char* id : defaults) g_Items.emplace_back(id);
    
    // merge from external file if present
    FILE* f = fopen("/var/mobile/ghost/items.txt", "r");
    if (f) {
        char buf[256];
        while (fgets(buf, sizeof(buf), f)) {
            size_t len = strcspn(buf, "\r\n");
            buf[len] = '\0';
            if (buf[0] == '\0') continue;
            g_Items.emplace_back(buf);
        }
        fclose(f);
    }
}

// convenience helper for size
inline int g_ItemCount() { return (int)g_Items.size(); }

const char* g_Mobs[] = { "mob_zombie", "mob_skeleton", "mob_creeper", "mob_dragon", "mob_alien", "mob_mutant" };
const int g_MobCount = sizeof(g_Mobs) / sizeof(g_Mobs[0]);

// =========================================================================
//  OBJC VIEW IMPLEMENTATION
// =========================================================================
@interface ImGuiDrawView ()
- (void)backgroundLoop;
- (void)updateIOWithTouchEvent:(UIEvent *)event;
- (void)renderUI;
@end

@implementation ImGuiDrawView

+ (instancetype)sharedInstance {
    static ImGuiDrawView *sh = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        UIWindow *win = [UIApplication sharedApplication].keyWindow;
        if (!win) {
            if (@available(iOS 13.0, *)) {
                for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
                    if ([s isKindOfClass:[UIWindowScene class]]) {
                        UIWindowScene *ws = (UIWindowScene *)s;
                        for (UIWindow *w in ws.windows) { if (w.isKeyWindow) { win = w; break; } }
                    }
                }
            }
        }
        sh = [[ImGuiDrawView alloc] initWithFrame:win.bounds];
        [win addSubview:sh];
    });
    return sh;
}

+ (void)showMenu { g_Config.IsVisible = true; [self sharedInstance]; }

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.device = MTLCreateSystemDefaultDevice();
        self.commandQueue = [self.device newCommandQueue];
        self.clearColor = MTLClearColorMake(0,0,0,0);
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        self.delegate = self;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.userInteractionEnabled = YES;
        [self setupImGui];
        [self setupStyle];
        [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(backgroundLoop) userInfo:nil repeats:YES];
    }
    return self;
}

- (void)backgroundLoop {
    Engine::UpdateMovement();
    if (g_Config.EnableColor && g_Config.RainbowColor) {
        static float h = 0.0f; h += 0.5f; if(h > 360) h = 0;
        g_Config.ColorHue = (int)h;
        ImGui::ColorConvertHSVtoRGB(h/360.0f, 1.0f, 1.0f, g_Config.ColorRGB[0], g_Config.ColorRGB[1], g_Config.ColorRGB[2]);
    }
}

- (void)setupImGui {
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO();
    io.IniFilename = NULL; 
    ImFontConfig cfg; cfg.OversampleH = 4; cfg.OversampleV = 4;
    io.Fonts->AddFontDefault(&cfg);
    // load a larger bold font for titles if available
    g_TitleFont = io.Fonts->AddFontFromFileTTF("/System/Library/Fonts/HelveticaNeue-Bold.ttf", 24.0f);
    io.FontGlobalScale = 1.15f; 
    ImGui_ImplMetal_Init(self.device);
}

- (void)setupStyle {    ImGuiStyle& s = ImGui::GetStyle();
    s.WindowRounding = 12.0f;
    s.FrameRounding = 6.0f;
    s.TabRounding = 6.0f;
    s.WindowBorderSize = 0.0f;
    s.ChildRounding = 6.0f;
    s.GrabRounding = 4.0f;
    ImVec4* c = s.Colors;

    // base dark theme
    c[ImGuiCol_Text] = ImVec4(0.95f, 0.95f, 0.95f, 1.00f);
    c[ImGuiCol_WindowBg] = ImVec4(0.08f, 0.08f, 0.08f, 0.97f);
    c[ImGuiCol_ChildBg] = ImVec4(0.10f, 0.10f, 0.10f, 0.95f);
    c[ImGuiCol_FrameBg] = ImVec4(0.15f, 0.15f, 0.15f, 0.90f);
    c[ImGuiCol_FrameBgHovered] = ImVec4(0.25f, 0.25f, 0.25f, 0.95f);
    c[ImGuiCol_Button] = ImVec4(g_Config.AccentColor[0], g_Config.AccentColor[1], g_Config.AccentColor[2], 0.8f);
    c[ImGuiCol_ButtonHovered] = ImVec4(g_Config.AccentColor[0], g_Config.AccentColor[1], g_Config.AccentColor[2], 1.0f);
    c[ImGuiCol_ButtonActive] = ImVec4(g_Config.AccentColor[0]*0.8f, g_Config.AccentColor[1]*0.8f, g_Config.AccentColor[2]*0.8f, 1.0f);
    c[ImGuiCol_Tab] = ImVec4(0.15f, 0.15f, 0.15f, 0.90f);
    c[ImGuiCol_TabHovered] = ImVec4(g_Config.AccentColor[0], g_Config.AccentColor[1], g_Config.AccentColor[2], 0.7f);
    c[ImGuiCol_TabActive] = ImVec4(g_Config.AccentColor[0], g_Config.AccentColor[1], g_Config.AccentColor[2], 1.0f);
    c[ImGuiCol_Header] = ImVec4(0.20f, 0.20f, 0.20f, 0.90f);
    c[ImGuiCol_HeaderHovered] = ImVec4(g_Config.AccentColor[0], g_Config.AccentColor[1], g_Config.AccentColor[2], 0.6f);
    c[ImGuiCol_HeaderActive] = ImVec4(g_Config.AccentColor[0], g_Config.AccentColor[1], g_Config.AccentColor[2], 0.8f);
    c[ImGuiCol_CheckMark] = ImVec4(1.0f, 1.0f, 0.0f, 1.0f);
    c[ImGuiCol_SliderGrab] = ImVec4(0.9f, 0.9f, 0.3f, 1.0f);
}

- (void)drawInMTKView:(MTKView *)view {
    ImGuiIO& io = ImGui::GetIO();
    io.DisplaySize = ImVec2(view.bounds.size.width, view.bounds.size.height);
    io.DisplayFramebufferScale = ImVec2(view.window.screen.scale, view.window.screen.scale);
    
    id<MTLCommandBuffer> buf = [self.commandQueue commandBuffer];
    MTLRenderPassDescriptor *desc = view.currentRenderPassDescriptor;
    if (desc != nil) {
        ImGui_ImplMetal_NewFrame(desc);
        ImGui::NewFrame();
        [self renderUI];
        ImGui::Render();
        id<MTLRenderCommandEncoder> enc = [buf renderCommandEncoderWithDescriptor:desc];
        ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), buf, enc);
        [enc endEncoding];
        [buf presentDrawable:view.currentDrawable];
        [buf commit];
    }
}

- (void)renderUI {
    ImGuiIO& io = ImGui::GetIO();
    float time = ImGui::GetTime();
    
    // WATERMARK
    ImGui::SetNextWindowPos(ImVec2(io.DisplaySize.x - 220, io.DisplaySize.y - 45));
    ImGui::Begin("##W", nullptr, ImGuiWindowFlags_NoDecoration | ImGuiWindowFlags_NoInputs | ImGuiWindowFlags_NoBackground);
        ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(0.8f, 0.6f, 1.0f, 0.8f));
        if (g_TitleFont) ImGui::PushFont(g_TitleFont);
        ImGui::Text("ghost menu | ghxstfrl");
        if (g_TitleFont) ImGui::PopFont();
        ImGui::PopStyleColor();
    // FLOATING TOGGLE
    if (!g_Config.IsVisible) {
        ImGui::SetNextWindowPos(ImVec2(50, 80), ImGuiCond_FirstUseEver);
        ImGui::SetNextWindowSize(ImVec2(80, 80));
        ImGui::Begin("##T", nullptr, ImGuiWindowFlags_NoDecoration | ImGuiWindowFlags_NoBackground);
        ImDrawList* dl = ImGui::GetWindowDrawList();
        ImVec2 p = ImGui::GetWindowPos();
        float glow = 28.0f + (sin(time * 3.0f) * 4.0f);
        dl->AddCircleFilled(ImVec2(p.x+40, p.y+40), 30.0f, IM_COL32(120, 0, 180, 240));
        dl->AddCircle(ImVec2(p.x+40, p.y+40), glow, IM_COL32(200, 200, 255, 200), 0, 2.5f);
        ImGui::SetCursorPos(ImVec2(16, 24));
        if (g_TitleFont) ImGui::PushFont(g_TitleFont);
        ImGui::Text("ghosty");
        if (g_TitleFont) ImGui::PopFont();
        if (ImGui::IsWindowHovered() && ImGui::IsMouseReleased(0)) g_Config.IsVisible = true;
        ImGui::End();
        return;
    }

    // MAIN MENU WINDOW
    ImGui::SetNextWindowSize(ImVec2(680, 600), ImGuiCond_FirstUseEver);
    ImGui::PushStyleColor(ImGuiCol_WindowBg, ImVec4(0,0,0,0));
    ImGui::Begin("ghost", &g_Config.IsVisible, ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoTitleBar);
    
    ImVec2 wP = ImGui::GetWindowPos(); ImVec2 wS = ImGui::GetWindowSize();
    DrawGalaxy(ImGui::GetWindowDrawList(), wP, wS);

    // credit label bottom-right
    ImGui::SetNextWindowPos(ImVec2(io.DisplaySize.x - 140, io.DisplaySize.y - 25));
    ImGui::Begin("##Credit", nullptr, ImGuiWindowFlags_NoDecoration | ImGuiWindowFlags_NoInputs | ImGuiWindowFlags_NoBackground);
    ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(0.8f,0.6f,1.0f,0.7f));
    ImGui::Text("MADE BY GHXSTFRL");
    ImGui::PopStyleColor();
    ImGui::End();

    // top-level tabs (Items / Mods / Settings / Beta / Logs)
    if (ImGui::BeginTabBar("##MainTabs", ImGuiTabBarFlags_FittingPolicyScroll)) {
        if (ImGui::BeginTabItem("Items")) { g_Config.ActiveTab = 0; ImGui::EndTabItem(); }
        if (ImGui::BeginTabItem("Mods")) { g_Config.ActiveTab = 1; ImGui::EndTabItem(); }
        if (ImGui::BeginTabItem("Settings")) { g_Config.ActiveTab = 2; ImGui::EndTabItem(); }
        if (ImGui::BeginTabItem("Beta")) { g_Config.ActiveTab = 3; ImGui::EndTabItem(); }
        if (ImGui::BeginTabItem("Logs")) { g_Config.ActiveTab = 4; ImGui::EndTabItem(); }
        ImGui::EndTabBar();
        // unload button aligned to right
        ImGui::SameLine(wS.x - 90);
        if (ImGui::Button("Unload", ImVec2(80, 25))) { [self removeFromSuperview]; }
    }

    // open content child region so that background galaxy is visible behind
    ImGui::BeginChild("ContentArea", ImVec2(0,0), false, ImGuiWindowFlags_NoBackground);

    if (g_Config.ActiveTab == 0) {
        // ITEM PAGE
        ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(1,1,1,1));
        ImGui::PushStyleVar(ImGuiStyleVar_FrameRounding, 12.0f);

        // category tabs across the top
        static int category = 0;
        const char* catNames[] = {"All Items","Fishing Rods","Fish","Baits","Weapons"};
        for(int ci = 0; ci < IM_ARRAYSIZE(catNames); ci++) {
            if (ci > 0) ImGui::SameLine();
            if (ImGui::Button(catNames[ci], ImVec2(0, 0))) category = ci;
        }
        ImGui::Spacing();

        // search field
        static char sBuf[64] = "";
        ImGui::InputTextWithHint("##Search", "Search items...", sBuf, 64);
        ImGui::Separator();

        // ensure we have the latest list (possibly augmented from disk)
        LoadItemList();

        // item list with scrolling region
        static int sel = 0;
        ImGui::BeginChild("ItemListChild", ImVec2(0, 240), true);
        for(int i=0; i<g_ItemCount(); i++) {
            const char* item = g_Items[i].c_str();
            // category filters
            if (category == 1 && !strstr(item, "fishing_rod")) continue;
            if (category == 2 && !strstr(item, "fish_")) continue;
            if (category == 3 && strstr(item, "bait") == NULL) continue;
            if (category == 4 && strstr(item, "item_") &&
                (!strstr(item, "weapon") && !strstr(item, "gun") && !strstr(item, "rpg") && !strstr(item, "grenade") && !strstr(item, "shotgun"))) {
                // crude weapon filter: if not matching known weapon keywords skip
            }
            if(sBuf[0] != '\0' && !strstr(item, sBuf)) continue;
            if(ImGui::Selectable(item, sel == i)) sel = i;
        }
        ImGui::EndChild();

        ImGui::Spacing();
        ImGui::Columns(2, "SpMods", false);
        ImGui::SliderInt("Quantity", &g_Config.SpawnQty, 1, 100);
        ImGui::Checkbox("Modify Size", &g_Config.EnableScale);
        if(g_Config.EnableScale) ImGui::SliderInt("Size", &g_Config.ScaleModifier, -127, 127);
        ImGui::NextColumn();
        ImGui::Checkbox("Enable RGB", &g_Config.EnableColor);
        if(g_Config.EnableColor) {
            ImGui::Checkbox("Rainbow Mode", &g_Config.RainbowColor);
            if(!g_Config.RainbowColor) {
                ImGui::SliderInt("H", &g_Config.ColorHue, 0, 360);
                ImGui::SliderInt("S", &g_Config.ColorSaturation, 0, 255);
            }
        }
        ImGui::Columns(1);
        ImGui::PopStyleVar();
        ImGui::PopStyleColor();

        ImGui::Spacing();
        ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(1, 0.8f, 0, 1));
        if (ImGui::Button("SPAWN NOW", ImVec2(-1, 50))) {
            if(sel >= 0 && sel < g_ItemCount())
                Engine::Spawn(g_Items[sel].c_str(), g_Config.SpawnQty);
        }
        ImGui::PopStyleColor();
    }
    else if (g_Config.ActiveTab == 1) {
        // MODS PAGE
        ImGui::TextColored(ImVec4(1,0.8,0,1), "MONEY");
        if (ImGui::Button("INF NUTS", ImVec2(-1, 40))) g_Logs.push_back("INF NUTS pressed");
        ImGui::SameLine();
        if (ImGui::Button("UNLOCK ALL", ImVec2(-1, 40))) g_Logs.push_back("Unlock all pressed");
        ImGui::Separator();

        ImGui::TextColored(ImVec4(0.6,1,1,1), "PLAYER");
        if (ImGui::Button("TP TO LOCATION", ImVec2(-1, 35))) g_Logs.push_back("Teleport to location");
        ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0.6,0.3,1,1));
        if (ImGui::Button("TP TO ME", ImVec2(-1, 35))) g_Logs.push_back("Teleport to me");
        if (ImGui::Button("MAX STATS", ImVec2(-1, 35))) g_Logs.push_back("Max stats");
        ImGui::PopStyleColor();
        ImGui::Separator();

        ImGui::TextColored(ImVec4(1,0.5,0,1), "EFFECTS");
        if (ImGui::Button("YEET", ImVec2(-1, 30))) g_Logs.push_back("Yeet effect");
        ImGui::SameLine();
        ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0,1,0,1));
        if (ImGui::Button("JELLY", ImVec2(-1, 30))) g_Logs.push_back("Jelly effect");
        ImGui::PopStyleColor();
        ImGui::SameLine();
        ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(1,0,1,1));
        if (ImGui::Button("COLOR", ImVec2(-1, 30))) g_Logs.push_back("Color effect");
        ImGui::PopStyleColor();
        ImGui::NewLine();
        ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0.8,0.6,0.2,1));
        if (ImGui::Button("SHAKE", ImVec2(-1, 30))) g_Logs.push_back("Shake effect");
        ImGui::PopStyleColor();
        ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0.8,0.3,0,1));
        ImGui::SameLine(); if (ImGui::Button("DROP ALL", ImVec2(-1, 30))) g_Logs.push_back("Drop all");
        ImGui::PopStyleColor();
        ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0,0.8,0.8,1));
        ImGui::SameLine(); if (ImGui::Button("JELLY ITEMS", ImVec2(-1, 30))) g_Logs.push_back("Jelly items");
        ImGui::PopStyleColor();
        ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(1,0,0,1));
        ImGui::NewLine(); if (ImGui::Button("DELETE ALL", ImVec2(-1, 30))) g_Logs.push_back("Delete all");
        ImGui::PopStyleColor();
        ImGui::Separator();

        ImGui::TextColored(ImVec4(1,0.4,0.4,1), "COMBAT");
        ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(1,0,0,1));
        if (ImGui::Button("KILL ALL", ImVec2(-1, 35))) g_Logs.push_back("Kill all");
        ImGui::SameLine(); if (ImGui::Button("KICK ALL", ImVec2(-1, 35))) g_Logs.push_back("Kick all");
        ImGui::PopStyleColor();
    }
    else if (g_Config.ActiveTab == 2) {
        // SETTINGS PAGE
        ImGui::Checkbox("Monochrome Background", &g_Config.MonochromeBg);
        ImGui::ColorEdit4("Accent Color", g_Config.AccentColor);
        ImGui::Separator();

        ImGui::Text("Target Player (%d)", g_Config.TargetPlayerIndex);
        ImGui::SameLine(); if (ImGui::Button("Refresh")) {
            g_Config.TargetPlayerIndex = 0;
            g_Logs.push_back("Refreshed target list");
        }
        ImGui::Text("No players tracked. Join a lobby first.");
        ImGui::Separator();

        ImGui::Text("Spawn Location");
        static char locBuf[64] = "";
        ImGui::InputTextWithHint("##loc","Custom Input", locBuf, 64);
        ImGui::Text("Lobby Lake");
        ImGui::Text("X: %.2f Y: %.2f Z: %.2f", g_Config.SpawnLocation.x, g_Config.SpawnLocation.y, g_Config.SpawnLocation.z);
        ImGui::Checkbox("Use This Location", &g_Config.UseCustomSpawnLoc);
        ImGui::Separator();

        ImGui::Text("Custom Coordinates");
        ImGui::InputFloat("X", &g_Config.CustomX, 0,0, "%.2f");
        ImGui::InputFloat("Y", &g_Config.CustomY, 0,0, "%.2f");
        ImGui::InputFloat("Z", &g_Config.CustomZ, 0,0, "%.2f");
    }
    else if (g_Config.ActiveTab == 3) {
        ImGui::Text("Beta features");
        ImGui::Separator();
        static bool ghostMode = false;
        if (ImGui::Checkbox("Experimental Ghost Mode", &ghostMode)) {
            g_Logs.push_back(ghostMode ? "Ghost mode enabled" : "Ghost mode disabled");
        }
        if (ImGui::Button("Trigger Server Crash", ImVec2(-1, 30))) {
            g_Logs.push_back("Crash triggered (not really)");
        }
        ImGui::TextWrapped("Use these toggles to test new functionality while you hack.");
    }
    else if (g_Config.ActiveTab == 4) {
        ImGui::TextColored(ImVec4(1,1,0,1), "MOD LOGS");
        ImGui::SameLine();
        ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(1,0,0,1));
        if (ImGui::Button("CLEAR", ImVec2(60, 25))) {
            g_Logs.clear();
        }
        ImGui::PopStyleColor();
        ImGui::Separator();
        ImGui::BeginChild("LogsChild", ImVec2(0,0), true);
        for(auto &ln : g_Logs) {
            ImGui::TextWrapped("%s", ln.c_str());
        }
        ImGui::EndChild();
    }

    ImGui::EndChild();
    ImGui::End();
    ImGui::PopStyleColor();
}

- (void)updateIOWithTouchEvent:(UIEvent *)e {
    ImGuiIO& io = ImGui::GetIO(); UITouch *t = [[e allTouches] anyObject];
    if (t) {
        CGPoint p = [t locationInView:self]; io.MousePos = ImVec2(p.x, p.y);
        if(t.phase == UITouchPhaseBegan) io.MouseDown[0] = true;
        if(t.phase == UITouchPhaseEnded || t.phase == UITouchPhaseCancelled) io.MouseDown[0] = false;
    }
}
- (void)touchesBegan:(NSSet*)t withEvent:(UIEvent*)e { [self updateIOWithTouchEvent:e]; }
- (void)touchesMoved:(NSSet*)t withEvent:(UIEvent*)e { [self updateIOWithTouchEvent:e]; }
- (void)touchesEnded:(NSSet*)t withEvent:(UIEvent*)e { [self updateIOWithTouchEvent:e]; }
- (void)touchesCancelled:(NSSet*)t withEvent:(UIEvent*)e { [self updateIOWithTouchEvent:e]; }
- (UIView*)hitTest:(CGPoint)p withEvent:(UIEvent*)e {
    UIView* v = [super hitTest:p withEvent:e]; if(v != self) return v;
    ImGuiContext* g = ImGui::GetCurrentContext(); if(!g) return nil;
    for(int i=g->Windows.Size-1; i>=0; i--) {
        ImGuiWindow* w = g->Windows[i]; if(!w->WasActive || w->Hidden) continue;
        if(CGRectContainsPoint(CGRectMake(w->Pos.x, w->Pos.y, w->Size.x, w->Size.y), p)) return self;
    }
    return nil;
}
- (void)mtkView:(MTKView *)v drawableSizeWillChange:(CGSize)s {}
@end
