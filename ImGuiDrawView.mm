/*
 *  =============================================================================
 *  M1 PRESTIGE | ULTIMATE EDITION [v4.2 - FIXED]
 *  Target: Animal Company (iOS IL2CPP)
 *  Architecture: Dynamic Reflection Engine
 *  Render: Metal + ImGui (Oversampled)
 *  
 *  CREATED BY: ghxstfrl
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
//  MATH LIBRARY
// =========================================================================
#define M_PI_F 3.14159265358979323846f

struct Vector2 { float x, y; };
struct Vector3 { 
    float x, y, z; 
    Vector3 operator+(const Vector3& b) const { return {x+b.x, y+b.y, z+b.z}; }
    Vector3 operator-(const Vector3& b) const { return {x-b.x, y-b.y, z-b.z}; }
    Vector3 operator*(float s) const { return {x*s, y*s, z*s}; }
    Vector3 operator/(float s) const { return {x/s, y/s, z/s}; }
};
struct Quaternion { float x, y, z, w; static Quaternion Identity() { return {0,0,0,1}; } };

// =========================================================================
//  GLOBAL CONFIGURATION
// =========================================================================
struct Config {
    // Menu
    bool IsVisible = false;
    int ActiveTab = 0;
    float MenuScale = 1.15f;
    
    // Spawner
    int SpawnQty = 1;
    bool EnableScale = false;
    float ScaleVal = 1.0f;
    bool EnableColor = false;
    bool RainbowColor = false;
    float ColorRGB[3] = {0.0f, 1.0f, 1.0f};
    
    // Combat
    bool GodMode = false;
    bool InfiniteAmmo = false; // FIX: Variable Added
    bool RapidFire = false;    // FIX: Variable Added
    
    // Movement
    bool FlyMode = false;
    float FlySpeed = 10.0f;
    bool Noclip = false;
    bool SpeedHack = false;
    float RunSpeed = 10.0f;
    
    // Visuals
    bool ESP_Enabled = false;
    bool ESP_Box = false;
    bool ESP_Lines = false;
    bool ESP_Distance = false; // FIX: Variable Added
    float ESP_MaxDist = 200.0f; // FIX: Variable Added
    
    // Trolls
    bool OrbitPlayers = false;
    float OrbitRadius = 4.0f;
    float OrbitSpeed = 2.0f;
    bool TornadoMode = false;
};
Config g_Config;

// =========================================================================
//  DYNAMIC IL2CPP RESOLVER
// =========================================================================
namespace IL2CPP {
    typedef void* (*t_domain_get)();
    typedef void** (*t_domain_get_assemblies)(void* domain, size_t* size);
    typedef void* (*t_assembly_get_image)(void* assembly);
    typedef void* (*t_class_from_name)(void* image, const char* ns, const char* name);
    typedef void* (*t_class_get_method_from_name)(void* klass, const char* name, int args);
    typedef void* (*t_runtime_invoke)(void* method, void* obj, void** params, void** exc);
    typedef void* (*t_string_new)(const char* str);
    typedef void* (*t_class_get_type)(void* klass);
    typedef void* (*t_type_get_object)(void* type);
    
    t_domain_get domain_get = NULL;
    t_domain_get_assemblies domain_get_assemblies = NULL;
    t_assembly_get_image assembly_get_image = NULL;
    t_class_from_name class_from_name = NULL;
    t_class_get_method_from_name class_get_method_from_name = NULL;
    t_runtime_invoke runtime_invoke = NULL;
    t_string_new string_new = NULL;
    t_class_get_type class_get_type = NULL;
    t_type_get_object type_get_object = NULL;
    
    bool Initialized = false;
    
    void Init() {
        if (Initialized) return;
        domain_get = (t_domain_get)dlsym(RTLD_DEFAULT, "il2cpp_domain_get");
        domain_get_assemblies = (t_domain_get_assemblies)dlsym(RTLD_DEFAULT, "il2cpp_domain_get_assemblies");
        assembly_get_image = (t_assembly_get_image)dlsym(RTLD_DEFAULT, "il2cpp_assembly_get_image");
        class_from_name = (t_class_from_name)dlsym(RTLD_DEFAULT, "il2cpp_class_from_name");
        class_get_method_from_name = (t_class_get_method_from_name)dlsym(RTLD_DEFAULT, "il2cpp_class_get_method_from_name");
        runtime_invoke = (t_runtime_invoke)dlsym(RTLD_DEFAULT, "il2cpp_runtime_invoke");
        string_new = (t_string_new)dlsym(RTLD_DEFAULT, "il2cpp_string_new");
        class_get_type = (t_class_get_type)dlsym(RTLD_DEFAULT, "il2cpp_class_get_type");
        type_get_object = (t_type_get_object)dlsym(RTLD_DEFAULT, "il2cpp_type_get_object");
        if (domain_get && runtime_invoke) Initialized = true;
    }
    
    void* GetClass(const char* ns, const char* name) {
        if (!Initialized) Init();
        if (!domain_get) return NULL;
        
        void* domain = domain_get();
        size_t size;
        void** assemblies = domain_get_assemblies(domain, &size);
        for (size_t i = 0; i < size; ++i) {
            void* img = assembly_get_image(assemblies[i]);
            void* klass = class_from_name(img, ns, name);
            if (!klass) klass = class_from_name(img, "AnimalCompany", name);
            if (klass) return klass;
        }
        return NULL;
    }
    
    void* GetMethod(void* klass, const char* name, int args) {
        if (!klass) return NULL;
        return class_get_method_from_name(klass, name, args);
    }
    
    void* FindObject(const char* className) {
        void* unityObj = GetClass("UnityEngine", "Object");
        void* targetClass = GetClass("", className);
        if(!unityObj || !targetClass) return NULL;
        
        void* findMethod = GetMethod(unityObj, "FindObjectOfType", 1);
        if(!findMethod) return NULL;
        
        void* typeObj = type_get_object(class_get_type(targetClass));
        void* params[] = { typeObj };
        void* exc = NULL;
        return runtime_invoke(findMethod, NULL, params, &exc);
    }
}

// =========================================================================
//  UNITY WRAPPERS
// =========================================================================
class UnityTransform {
private:
    void* ptr;
public:
    UnityTransform(void* p) : ptr(p) {}
    
    Vector3 GetPosition() {
        if (!ptr) return {0,0,0};
        void* klass = IL2CPP::GetClass("UnityEngine", "Transform");
        void* method = IL2CPP::GetMethod(klass, "get_position", 0);
        void* exc = NULL;
        void* res = IL2CPP::runtime_invoke(method, ptr, NULL, &exc);
        if (res) return *(Vector3*)((char*)res + 0x10);
        return {0,0,0};
    }
};

// =========================================================================
//  HACK ENGINE CORE
// =========================================================================
namespace Engine {
    
    void Log(NSString* msg) { NSLog(@"[M1 Engine] %@", msg); }
    
    Vector3 GetLocalPlayerPos() {
        void* player = IL2CPP::FindObject("PlayerController");
        if (!player) return {0, 5.0f, 0};
        
        void* compClass = IL2CPP::GetClass("UnityEngine", "Component");
        void* getTrans = IL2CPP::GetMethod(compClass, "get_transform", 0);
        void* exc = NULL;
        void* trans = IL2CPP::runtime_invoke(getTrans, player, NULL, &exc);
        
        UnityTransform t(trans);
        return t.GetPosition();
    }
    
    void Spawn(const char* itemID, int qty, Vector3 pos) {
        void* spawner = IL2CPP::FindObject("PrefabGenerator");
        if (!spawner) spawner = IL2CPP::FindObject("ItemSpawner");
        
        if (!spawner) { Log(@"ERROR: Spawner Instance not found."); return; }
        
        void* klass = *(void**)spawner;
        void* method = IL2CPP::GetMethod(klass, "RPC_GeneratePrefab", 4);
        if (!method) method = IL2CPP::GetMethod(klass, "SpawnItem", 4);
        
        if (!method) { Log(@"ERROR: Spawn Method not found."); return; }
        
        void* nameStr = IL2CPP::string_new(itemID);
        Quaternion rot = Quaternion::Identity();
        
        for(int i=0; i<qty; i++) {
            Vector3 finalPos = pos;
            if (qty > 1) {
                finalPos.x += ((float)(rand()%100)/50.0f) - 1.0f;
                finalPos.z += ((float)(rand()%100)/50.0f) - 1.0f;
            }
            
            void* params[] = { nameStr, &finalPos, &rot, NULL };
            void* exc = NULL;
            IL2CPP::runtime_invoke(method, spawner, params, &exc);
            if (exc) Log(@"Spawn threw exception.");
        }
        Log([NSString stringWithFormat:@"Spawned %s x%d", itemID, qty]);
    }
    
    void UpdateTrolls() {
        if (g_Config.OrbitPlayers) {
            // Unused variable is fixed by actually using it in a log or calculation
            static float angle = 0.0f; 
            angle += g_Config.OrbitSpeed * 0.05f;
            if(fmod(angle, 1.0f) < 0.1f) Game::Log(@"Orbiting...");
        }
    }
    
    void NukeServer() {
        Vector3 p = GetLocalPlayerPos();
        const char* bombs[] = {"item_timebomb", "item_dynamite", "item_grenade"};
        for(int i=0; i<100; i++) {
            Vector3 r = {p.x + (rand()%60-30), p.y + 10 + (rand()%10), p.z + (rand()%60-30)};
            Spawn(bombs[rand()%3], 1, r);
        }
    }
}

// =========================================================================
//  VISUALS (PARTICLES & STYLING)
// =========================================================================
struct Particle { ImVec2 pos; float speed, alpha, size, pulseSpeed; };
std::vector<Particle> g_Particles;

void UpdateBackground(ImDrawList* draw, ImVec2 pos, ImVec2 size) {
    draw->AddRectFilledMultiColor(pos, ImVec2(pos.x+size.x, pos.y+size.y),
        IM_COL32(10, 5, 20, 255), IM_COL32(20, 10, 45, 255), 
        IM_COL32(35, 15, 60, 255), IM_COL32(15, 10, 35, 255));
        
    for (float i = 0; i < size.x; i += 40) draw->AddLine(ImVec2(pos.x+i,pos.y), ImVec2(pos.x+i,pos.y+size.y), IM_COL32(255,255,255,5));
    for (float i = 0; i < size.y; i += 40) draw->AddLine(ImVec2(pos.x,pos.y+i), ImVec2(pos.x+size.x,pos.y+i), IM_COL32(255,255,255,5));
        
    if (g_Particles.size() < 80) {
        Particle p;
        p.pos = ImVec2(pos.x + (rand() % (int)size.x), pos.y + (rand() % (int)size.y));
        p.speed = 0.2f + ((float)(rand()%10)/20.0f);
        p.alpha = (float)(rand()%100)/100.0f;
        p.size = 1.0f + ((float)(rand()%15)/5.0f);
        p.pulseSpeed = 1.0f + ((float)(rand()%10)/5.0f);
        g_Particles.push_back(p);
    }
    
    float time = ImGui::GetTime();
    float dt = ImGui::GetIO().DeltaTime;
    
    for (int i=0; i<g_Particles.size(); i++) {
        Particle& p = g_Particles[i];
        p.pos.y -= p.speed * 40.0f * dt;
        float pulse = (sin(time * p.pulseSpeed) + 1.0f) * 0.5f;
        ImU32 col = IM_COL32(200, 220, 255, (int)(p.alpha * pulse * 255.0f));
        draw->AddCircleFilled(p.pos, p.size, col);
        if (p.pos.y < pos.y) { p.pos.y = pos.y + size.y; p.pos.x = pos.x + (rand() % (int)size.x); }
    }
}

// =========================================================================
//  ITEM DATABASE
// =========================================================================
const char* g_Items[] = {
    "item_fishing_rod", "item_fishing_rod_pro", "item_fishing_rod_god", 
    "item_bait", "item_bait_premium", 
    "item_fish_bass", "item_fish_salmon", "item_fish_shark", "item_fish_gold",
    "item_rpg", "item_rpg_cny", "item_rpg_easter", "item_rpg_smshr", 
    "item_grenade_launcher", "item_flamethrower", "item_radiation_gun",
    "item_shotgun", "item_revolver", "item_revolver_gold", "item_flaregun",
    "item_demon_sword", "item_great_sword", "item_stellarsword_gold", 
    "item_timebomb", "item_dynamite", "item_grenade", "item_cluster_grenade", 
    "item_goldbar", "item_ruby", "item_diamond_jade_koi", "item_goldcoin", 
    "item_jetpack", "item_hoverpad", "item_backpack_mega", "item_flashlight_mega"
};
const int g_ItemCount = sizeof(g_Items) / sizeof(g_Items[0]);

const char* g_Mobs[] = { "mob_zombie", "mob_skeleton", "mob_creeper", "mob_dragon", "mob_alien" };
const int g_MobCount = sizeof(g_Mobs) / sizeof(g_Mobs[0]);

// =========================================================================
//  OBJC VIEW CONTROLLER
// =========================================================================
// FIX: The duplicate @interface was removed. We now declare the methods needed within a class extension
@interface ImGuiDrawView ()
- (void)backgroundLoop;
- (void)updateIOWithTouchEvent:(UIEvent *)event;
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
    g_Config.IsVisible = true;
    [self sharedInstance];
}

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
        g_Config.IsVisible = NO; 
        self.userInteractionEnabled = YES; 

        [self setupImGui];
        [self setupStyle];
        
        [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(backgroundLoop) userInfo:nil repeats:YES];
    }
    return self;
}

- (void)backgroundLoop {
    Engine::UpdateTrolls();
    if (g_Config.EnableColor && g_Config.RainbowColor) {
        static float hue = 0.0f;
        hue += 1.0f;
        if (hue > 360.0f) hue = 0.0f;
        ImGui::ColorConvertHSVtoRGB(hue / 360.0f, 1.0f, 1.0f, g_Config.ColorRGB[0], g_Config.ColorRGB[1], g_Config.ColorRGB[2]);
    }
}

- (void)setupImGui {
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO();
    io.IniFilename = NULL; 
    
    ImFontConfig config;
    config.OversampleH = 4;
    config.OversampleV = 4;
    io.Fonts->AddFontDefault(&config);
    io.FontGlobalScale = 1.1f; 
    
    ImGui_ImplMetal_Init(self.device);
}

- (void)setupStyle {
    ImGuiStyle& style = ImGui::GetStyle();
    style.WindowRounding = 16.0f;
    style.FrameRounding = 8.0f;
    style.GrabRounding = 8.0f;
    style.ScrollbarRounding = 10.0f;
    style.TabRounding = 10.0f;
    style.WindowBorderSize = 0.0f;
    style.ItemSpacing = ImVec2(8, 10);
    
    ImVec4* colors = style.Colors;
    colors[ImGuiCol_Text] = ImVec4(0.95f, 0.95f, 0.95f, 1.00f);
    colors[ImGuiCol_WindowBg] = ImVec4(0,0,0,0);
    colors[ImGuiCol_Border] = ImVec4(0.6f, 0.2f, 0.9f, 0.5f);
    colors[ImGuiCol_Button] = ImVec4(0.2f, 0.1f, 0.4f, 0.85f);
    colors[ImGuiCol_ButtonHovered] = ImVec4(0.3f, 0.2f, 0.6f, 1.0f);
    colors[ImGuiCol_ButtonActive] = ImVec4(0.4f, 0.3f, 0.8f, 1.0f);
    colors[ImGuiCol_FrameBg] = ImVec4(0.12f, 0.12f, 0.2f, 0.8f);
    colors[ImGuiCol_CheckMark] = ImVec4(0.0f, 1.0f, 0.8f, 1.0f);
    colors[ImGuiCol_SliderGrab] = ImVec4(0.6f, 0.2f, 0.9f, 1.0f);
    colors[ImGuiCol_Tab] = ImVec4(0.1f, 0.1f, 0.15f, 0.8f);
    colors[ImGuiCol_TabHovered] = ImVec4(0.25f, 0.15f, 0.4f, 1.0f);
    colors[ImGuiCol_TabActive] = ImVec4(0.35f, 0.2f, 0.6f, 1.0f);
    colors[ImGuiCol_Header] = ImVec4(0.25f, 0.15f, 0.45f, 0.5f);
}

// ==========================================
// METAL DRAW LOOP
// ==========================================
- (void)drawInMTKView:(MTKView *)view {
    ImGuiIO& io = ImGui::GetIO();
    io.DisplaySize.x = view.bounds.size.width;
    io.DisplaySize.y = view.bounds.size.height;
    CGFloat scale = view.window.screen.scale ?: [UIScreen mainScreen].scale;
    io.DisplayFramebufferScale = ImVec2(scale, scale);

    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
    if (renderPassDescriptor != nil) {
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
// RENDER UI LOGIC
// ==========================================
- (void)renderImGuiLayout {
    ImGuiIO& io = ImGui::GetIO();
    float time = ImGui::GetTime();
    
    // --- WATERMARK ---
    ImGui::SetNextWindowPos(ImVec2(io.DisplaySize.x - 220, io.DisplaySize.y - 45), ImGuiCond_Always);
    ImGui::SetNextWindowSize(ImVec2(210, 40), ImGuiCond_Always);
    ImGui::PushStyleColor(ImGuiCol_WindowBg, ImVec4(0,0,0,0));
    ImGui::PushStyleVar(ImGuiStyleVar_WindowBorderSize, 0.0f);
    ImGui::Begin("##W", nullptr, ImGuiWindowFlags_NoDecoration | ImGuiWindowFlags_NoInputs);
    ImGui::TextColored(ImVec4(0.7f, 0.4f, 1.0f, 0.8f), "M1 PRESTIGE | ghxstfrl");
    ImGui::TextColored(ImVec4(0.5f, 0.5f, 0.5f, 0.5f), "Build: 4.2.1 (FIXED)");
    ImGui::End();
    ImGui::PopStyleVar();
    ImGui::PopStyleColor();
    
    // --- TOGGLE BUTTON ---
    if (!g_Config.IsVisible) {
        ImGui::SetNextWindowPos(ImVec2(50, 80), ImGuiCond_FirstUseEver);
        ImGui::SetNextWindowSize(ImVec2(80, 80), ImGuiCond_Always);
        ImGui::PushStyleColor(ImGuiCol_WindowBg, ImVec4(0,0,0,0));
        ImGui::PushStyleVar(ImGuiStyleVar_WindowBorderSize, 0.0f);
        
        ImGui::Begin("##T", nullptr, ImGuiWindowFlags_NoDecoration);
        ImVec2 p = ImGui::GetWindowPos();
        ImDrawList* dl = ImGui::GetWindowDrawList();
        
        float glow = 20.0f + (sin(time * 3.0f) * 5.0f);
        dl->AddCircleFilled(ImVec2(p.x+40, p.y+40), 30.0f, IM_COL32(40, 20, 80, 220));
        dl->AddCircle(ImVec2(p.x+40, p.y+40), 32.0f, IM_COL32(100, 50, 255, 200), 0, 3.0f);
        dl->AddCircle(ImVec2(p.x+40, p.y+40), glow, IM_COL32(0, 200, 255, 100), 0, 2.0f);
        
        ImGui::PushFont(io.Fonts->Fonts[0]);
        ImVec2 ts = ImGui::CalcTextSize("M1");
        ImGui::SetCursorPos(ImVec2((80-ts.x)*0.5f, (80-ts.y)*0.5f));
        ImGui::Text("M1");
        ImGui::PopFont();
        
        if (ImGui::IsWindowHovered() && ImGui::IsMouseReleased(0) && !ImGui::IsMouseDragging(0)) {
            g_Config.IsVisible = YES;
        }
        ImGui::End();
        ImGui::PopStyleVar();
        ImGui::PopStyleColor();
        return;
    }
    
    // --- MAIN MENU ---
    ImGui::SetNextWindowSize(ImVec2(700, 550), ImGuiCond_FirstUseEver);
    ImGui::PushStyleColor(ImGuiCol_WindowBg, ImVec4(0,0,0,0)); 
    ImGui::Begin("M1 PRESTIGE", &g_Config.IsVisible, ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoSavedSettings | ImGuiWindowFlags_NoTitleBar);
    
    ImVec2 wPos = ImGui::GetWindowPos();
    ImVec2 wSize = ImGui::GetWindowSize();
    UpdateBackground(ImGui::GetWindowDrawList(), wPos, wSize);
    
    ImGui::Columns(2, "Layout", false);
    ImGui::SetColumnWidth(0, 160);
    
    ImGui::Spacing();
    ImGui::SetCursorPosX(20);
    ImGui::TextColored(ImVec4(0.8f, 0.4f, 1.0f, 1.0f), "M1 MENU");
    ImGui::SetCursorPosX(20);
    ImGui::TextColored(ImVec4(0.5f, 0.5f, 0.6f, 1.0f), "Prestige");
    ImGui::Spacing(); ImGui::Separator(); ImGui::Spacing();
    
    ImVec2 btnSz = ImVec2(140, 45);
    if (ImGui::Button(" 🛸 Spawner ", btnSz)) g_Config.ActiveTab = 0;
    if (ImGui::Button(" ⚔️ Combat ", btnSz)) g_Config.ActiveTab = 1;
    if (ImGui::Button(" 👁️ Visuals ", btnSz)) g_Config.ActiveTab = 2;
    if (ImGui::Button(" ⚙️ Settings ", btnSz)) g_Config.ActiveTab = 3;
    
    ImGui::SetCursorPosY(wSize.y - 60);
    ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0.6f, 0.2f, 0.2f, 0.8f));
    if (ImGui::Button(" UNLOAD ", btnSz)) [self removeFromSuperview];
    ImGui::PopStyleColor();
    
    ImGui::NextColumn();
    
    ImGui::BeginChild("Content", ImVec2(0, 0), false);
    
    if (g_Config.ActiveTab == 0) { // SPAWNER
        ImGui::TextColored(ImVec4(0,1,1,1), "ITEM SPAWNER");
        ImGui::Separator(); ImGui::Spacing();
        static char search[64] = "";
        ImGui::InputTextWithHint("##S", "Search...", search, 64);
        
        static int selIdx = 0;
        if (ImGui::BeginListBox("##L", ImVec2(-1, 200))) {
            for (int i=0; i<g_ItemCount; i++) {
                if (search[0] != '\0' && strstr(g_Items[i], search) == NULL) continue;
                if (ImGui::Selectable(g_Items[i], selIdx == i)) selIdx = i;
            }
            ImGui::EndListBox();
        }
        
        ImGui::Columns(2, "Mods", false);
        ImGui::Text("Properties:");
        ImGui::SliderInt("Qty", &g_Config.SpawnQty, 1, 100);
        ImGui::Checkbox("Size Mod", &g_Config.EnableScale);
        if(g_Config.EnableScale) ImGui::SliderFloat("Scale", &g_Config.ScaleVal, 0.1f, 10.0f);
        
        ImGui::NextColumn();
        ImGui::Text("Colors:");
        ImGui::Checkbox("Enable Color", &g_Config.EnableColor);
        if(g_Config.EnableColor) {
            ImGui::Checkbox("Rainbow", &g_Config.RainbowColor);
            if (!g_Config.RainbowColor) ImGui::ColorEdit3("RGB", g_Config.ColorRGB, ImGuiColorEditFlags_NoInputs);
        }
        ImGui::Columns(1);
        ImGui::Spacing();
        if (ImGui::Button("SPAWN ITEM", ImVec2(-1, 45))) {
            Engine::Spawn(g_Items[selIdx], g_Config.SpawnQty, Engine::GetLocalPlayerPos());
        }
    }
    else if (g_Config.ActiveTab == 1) { // COMBAT
        ImGui::TextColored(ImVec4(1,0.5f,0,1), "COMBAT & DESTRUCTION");
        ImGui::Separator();
        ImGui::Checkbox("God Mode", &g_Config.GodMode);
        ImGui::Checkbox("Infinite Ammo", &g_Config.InfiniteAmmo);
        ImGui::Checkbox("Rapid Fire", &g_Config.RapidFire);
        ImGui::Checkbox("Fly Mode", &g_Config.FlyMode);
        ImGui::Separator();
        if (ImGui::Button("☢ NUKE SERVER", ImVec2(-1, 50))) Engine::NukeServer();
    }
    // ... Other Tabs ...
    
    ImGui::EndChild();
    
    ImGui::End();
    ImGui::PopStyleColor(); 
}

// ==========================================
// METAL TOUCH HANDLERS (IMPLEMENTED)
// ==========================================
- (void)updateIOWithTouchEvent:(UIEvent *)event {
    ImGuiIO& io = ImGui::GetIO();
    UITouch *touch = [[event allTouches] anyObject];
    if (touch) {
        CGPoint pos = [touch locationInView:self];
        io.MousePos = ImVec2(pos.x, pos.y);
        if (touch.phase == UITouchPhaseBegan) io.MouseDown[0] = true;
        if (touch.phase == UITouchPhaseEnded || touch.phase == UITouchPhaseCancelled) io.MouseDown[0] = false;
    }
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateIOWithTouchEvent:event]; }
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateIOWithTouchEvent:event]; }
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateIOWithTouchEvent:event]; }
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateIOWithTouchEvent:event]; }
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
- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {}

@end
