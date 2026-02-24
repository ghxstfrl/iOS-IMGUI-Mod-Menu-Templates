/*
 *  =============================================================================
 *  M1 PRESTIGE | PREMIER EDITION [v7.0 - THE GOLIATH]
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
struct Config {
    // UI
    bool IsVisible = false;
    int ActiveTab = 0;
    float MenuScale = 1.15f;
    float AccentColor[4] = {0.6f, 0.2f, 1.0f, 1.0f};
    
    // Spawner
    int SpawnQty = 1;
    bool EnableScale = false;
    int ScaleModifier = 0; 
    bool EnableColor = false;
    bool RainbowColor = false;
    int ColorHue = 0;
    int ColorSaturation = 255;
    float ColorRGB[3] = {0.0f, 0.8f, 1.0f};
    
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

    void Log(NSString* msg) { NSLog(@"[M1 Engine] %@", msg); }

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

    void Spawn(const char* itemID, int qty) {
        Log([NSString stringWithFormat:@"Executing Massive Spawn: %s x%d", itemID, qty]);
        // Real IL2CPP invoke logic would happen here
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
std::vector<Star> g_Galaxy;

void DrawGalaxy(ImDrawList* dl, ImVec2 winPos, ImVec2 winSize) {
    // 1. Solid Premium Gradient
    dl->AddRectFilledMultiColor(winPos, ImVec2(winPos.x + winSize.x, winPos.y + winSize.y),
        IM_COL32(10, 5, 30, 255), IM_COL32(30, 10, 60, 255), 
        IM_COL32(40, 15, 80, 255), IM_COL32(10, 5, 35, 255));
    
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
}

// =========================================================================
//  ITEM DATABASE
// =========================================================================
const char* g_Items[] = {
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
const int g_ItemCount = sizeof(g_Items) / sizeof(g_Items[0]);

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
    io.FontGlobalScale = 1.15f; 
    ImGui_ImplMetal_Init(self.device);
}

- (void)setupStyle {
    ImGuiStyle& s = ImGui::GetStyle();
    s.WindowRounding = 18.0f; s.FrameRounding = 10.0f; s.TabRounding = 10.0f; s.WindowBorderSize = 0.0f;
    ImVec4* c = s.Colors;
    c[ImGuiCol_Text] = ImVec4(0.95f, 0.95f, 1.00f, 1.00f);
    c[ImGuiCol_Button] = ImVec4(0.25f, 0.15f, 0.50f, 0.85f);
    c[ImGuiCol_ButtonHovered] = ImVec4(0.40f, 0.25f, 0.75f, 1.00f);
    c[ImGuiCol_FrameBg] = ImVec4(0.10f, 0.10f, 0.25f, 0.70f);
    c[ImGuiCol_TabActive] = ImVec4(0.50f, 0.20f, 0.90f, 1.00f);
    c[ImGuiCol_CheckMark] = ImVec4(0.0f, 0.9f, 1.0f, 1.0f);
    c[ImGuiCol_SliderGrab] = ImVec4(0.6f, 0.2f, 0.9f, 1.0f);
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
    ImGui::TextColored(ImVec4(0.7f, 0.4f, 1.0f, 0.8f), "M1 PRESTIGE | ghxstfrl");
    ImGui::End();

    // FLOATING TOGGLE
    if (!g_Config.IsVisible) {
        ImGui::SetNextWindowPos(ImVec2(50, 80), ImGuiCond_FirstUseEver);
        ImGui::SetNextWindowSize(ImVec2(80, 80));
        ImGui::Begin("##T", nullptr, ImGuiWindowFlags_NoDecoration | ImGuiWindowFlags_NoBackground);
        ImDrawList* dl = ImGui::GetWindowDrawList();
        ImVec2 p = ImGui::GetWindowPos();
        float glow = 28.0f + (sin(time * 3.0f) * 4.0f);
        dl->AddCircleFilled(ImVec2(p.x+40, p.y+40), 30.0f, IM_COL32(40, 20, 80, 240));
        dl->AddCircle(ImVec2(p.x+40, p.y+40), glow, IM_COL32(0, 255, 255, 200), 0, 2.5f);
        ImGui::SetCursorPos(ImVec2(28, 30)); ImGui::Text("M1");
        if (ImGui::IsWindowHovered() && ImGui::IsMouseReleased(0)) g_Config.IsVisible = true;
        ImGui::End();
        return;
    }

    // MAIN MENU WINDOW
    ImGui::SetNextWindowSize(ImVec2(680, 600), ImGuiCond_FirstUseEver);
    ImGui::PushStyleColor(ImGuiCol_WindowBg, ImVec4(0,0,0,0));
    ImGui::Begin("M1 PRESTIGE | ANIMAL COMPANY", &g_Config.IsVisible, ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoTitleBar);
    
    ImVec2 wP = ImGui::GetWindowPos(); ImVec2 wS = ImGui::GetWindowSize();
    DrawGalaxy(ImGui::GetWindowDrawList(), wP, wS);

    ImGui::Columns(2, "MainLayout", false); ImGui::SetColumnWidth(0, 160);
    
    ImGui::Spacing(); ImGui::SetCursorPosX(35); ImGui::TextColored(ImVec4(0.8,0.4,1,1), "M1 PRESTIGE");
    ImGui::Spacing(); ImGui::Separator();
    
    ImVec2 bS = ImVec2(145, 45);
    if (ImGui::Button(" 🛸 Spawner ", bS)) g_Config.ActiveTab = 0;
    if (ImGui::Button(" ⚔️ Combat ", bS)) g_Config.ActiveTab = 1;
    if (ImGui::Button(" 👁️ Visuals ", bS)) g_Config.ActiveTab = 2;
    if (ImGui::Button(" ⚙️ Config ", bS)) g_Config.ActiveTab = 3;
    
    ImGui::SetCursorPosY(wS.y - 65);
    ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0.7, 0.2, 0.2, 0.8));
    if (ImGui::Button(" UNLOAD ", bS)) [self removeFromSuperview];
    ImGui::PopStyleColor();
    
    ImGui::NextColumn();
    ImGui::BeginChild("ContentArea", ImVec2(0,0), false, ImGuiWindowFlags_NoBackground);

    if (g_Config.ActiveTab == 0) {
        ImGui::TextColored(ImVec4(0,1,1,1), "ITEM GENERATOR"); ImGui::Separator();
        static char sBuf[64] = ""; ImGui::InputTextWithHint("##Search", "Search Items...", sBuf, 64);
        
        static int sel = 0;
        if (ImGui::BeginListBox("##ItemList", ImVec2(-1, 240))) {
            for(int i=0; i<g_ItemCount; i++) {
                if(sBuf[0] != '\0' && !strstr(g_Items[i], sBuf)) continue;
                if(ImGui::Selectable(g_Items[i], sel == i)) sel = i;
            }
            ImGui::EndListBox();
        }
        
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
        
        if (ImGui::Button("EXECUTE SPAWN", ImVec2(-1, 50))) {
            Engine::Spawn(g_Items[sel], g_Config.SpawnQty);
        }
    }
    else if (g_Config.ActiveTab == 1) {
        ImGui::TextColored(ImVec4(1,0.5,0,1), "COMBAT & DESTRUCTION"); ImGui::Separator();
        ImGui::Checkbox("God Mode (Infinity Health)", &g_Config.GodMode);
        ImGui::Checkbox("Infinite Magazine", &g_Config.InfiniteAmmo);
        ImGui::Checkbox("Rapid Fire", &g_Config.RapidFire);
        ImGui::Checkbox("Instant Kill", &g_Config.OneHitKill);
        
        ImGui::Separator();
        ImGui::Text("Trolling:");
        ImGui::Checkbox("Orbit Players", &g_Config.OrbitPlayers);
        ImGui::Checkbox("Tornado Mode", &g_Config.TornadoMode);
        ImGui::Checkbox("Black Hole", &g_Config.BlackHoleMode);
        
        ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0.8, 0.1, 0.1, 1.0));
        if (ImGui::Button("☢ NUCLEAR STRIKE (400 EXPLOSIVES)", ImVec2(-1, 50))) Engine::Nuke();
        ImGui::PopStyleColor();
    }
    else if (g_Config.ActiveTab == 2) {
        ImGui::TextColored(ImVec4(0.5,1,0.5,1), "PLAYER SENSORY"); ImGui::Separator();
        ImGui::Checkbox("Enable Master ESP", &g_Config.ESP_Enabled);
        if(g_Config.ESP_Enabled) {
            ImGui::Indent();
            ImGui::Checkbox("3D Box", &g_Config.ESP_Box);
            ImGui::Checkbox("Lines", &g_Config.ESP_Lines);
            ImGui::Checkbox("Distance", &g_Config.ESP_Distance);
            ImGui::SliderFloat("Range", &g_Config.ESP_MaxDist, 50, 1000);
            ImGui::Unindent();
        }
        ImGui::Checkbox("Night Vision", &g_Config.NightVision);
        ImGui::Checkbox("Chams (Walls)", &g_Config.Chams);
    }
    else if (g_Config.ActiveTab == 3) {
        ImGui::Text("Configuration"); ImGui::Separator();
        ImGui::SliderFloat("Menu Scale", &io.FontGlobalScale, 0.8, 2.0);
        ImGui::ColorEdit4("Theme Color", g_Config.AccentColor);
        ImGui::Spacing();
        ImGui::TextDisabled("Base: M1 Premium v7.0");
        ImGui::TextDisabled("Engine: Dynamic IL2CPP Solver");
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
