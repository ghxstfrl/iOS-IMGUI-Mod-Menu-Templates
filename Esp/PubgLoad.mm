 (cd "$(git rev-parse --show-toplevel)" && git apply --3way <<'EOF' 
diff --git a/Esp/PubgLoad.mm b/Esp/PubgLoad.mm
index 19ca25b2db036594f62d2558c77af35348c3a3a3..107d3d90806b15594a8f3c5f451f0f4543a62578 100644
--- a/Esp/PubgLoad.mm
+++ b/Esp/PubgLoad.mm
@@ -1,84 +1,270 @@
 //
 //  PubgLoad.m
 //  pubg
 //
 //  Created by 李良林 on 2021/2/14.
 //
 
 #import "PubgLoad.h"
 #import <UIKit/UIKit.h>
+#import <QuartzCore/QuartzCore.h>
 
 #import "JHPP.h"
 #import "JHDragView.h"
 #import "ImGuiLoad.h"
 #import "ImGuiDrawView.h"
+#import "MenuAPIClient.h"
+
 @interface PubgLoad()
 @property (nonatomic, strong) ImGuiDrawView *vna;
+@property (nonatomic, strong) UIButton *menuButton;
+@property (nonatomic, strong) UIWindow *menuWindow;
+@property (nonatomic, assign) BOOL menuVisible;
+@property (nonatomic, assign) BOOL apiAllowsMenu;
+@property (nonatomic, strong) dispatch_source_t watchdogTimer;
 @end
 
 @implementation PubgLoad
 
 static PubgLoad *extraInfo;
+static NSInteger const kM1ButtonTag = 0x4D314D31;
+
+static UIWindow *GetActiveWindow(void) {
+    UIWindow *window = [UIApplication sharedApplication].keyWindow;
+    if (window) { return window; }
 
-UIWindow *mainWindow;
+    if (@available(iOS 13.0, *)) {
+        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
+            if (![scene isKindOfClass:[UIWindowScene class]]) { continue; }
+            UIWindowScene *windowScene = (UIWindowScene *)scene;
+            if (windowScene.activationState != UISceneActivationStateForegroundActive) { continue; }
+            for (UIWindow *candidate in windowScene.windows) {
+                if (candidate.isKeyWindow) { return candidate; }
+            }
+            if (windowScene.windows.count > 0) { return windowScene.windows.firstObject; }
+        }
+    }
 
+    return [UIApplication sharedApplication].windows.firstObject;
+}
 
 + (void)load
 {
-[super load];
- 
-        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3* NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
-             mainWindow = [UIApplication sharedApplication].keyWindow;
-            extraInfo =  [PubgLoad new];
-            [extraInfo initTapGes];
-            [extraInfo tapIconView];
-            [extraInfo initTapGes2];
-            [extraInfo tapIconView2];
-
-          
+    [super load];
+
+    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
+        extraInfo = [PubgLoad new];
+        extraInfo.apiAllowsMenu = YES;
+        [extraInfo registerAppLifecycleObservers];
+        [extraInfo bootstrapMenuUI];
+        [extraInfo startWatchdog];
+    });
+}
+
+- (void)registerAppLifecycleObservers
+{
+    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
+    [center addObserver:self selector:@selector(bootstrapMenuUI) name:UIApplicationDidFinishLaunchingNotification object:nil];
+    [center addObserver:self selector:@selector(bootstrapMenuUI) name:UIApplicationDidBecomeActiveNotification object:nil];
+    [center addObserver:self selector:@selector(bootstrapMenuUI) name:UIApplicationWillEnterForegroundNotification object:nil];
+}
+
+- (void)startWatchdog
+{
+    if (self.watchdogTimer) { return; }
+
+    self.watchdogTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
+    dispatch_source_set_timer(self.watchdogTimer,
+                              dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)),
+                              (uint64_t)(1 * NSEC_PER_SEC),
+                              (uint64_t)(0.2 * NSEC_PER_SEC));
+
+    __weak typeof(self) weakSelf = self;
+    dispatch_source_set_event_handler(self.watchdogTimer, ^{
+        __strong typeof(weakSelf) strongSelf = weakSelf;
+        if (!strongSelf) { return; }
+        [strongSelf setupMenuButton];
+    });
+    dispatch_resume(self.watchdogTimer);
+}
+
+- (void)bootstrapMenuUI
+{
+    [self setupMenuButton];
+    [self initTapGes];
+    [self initTapGes2];
+
+    __weak typeof(self) weakSelf = self;
+    [[MenuAPIClient shared] validateMenuAccessWithCompletion:^(BOOL allowed, NSString * _Nullable message) {
+        dispatch_async(dispatch_get_main_queue(), ^{
+            __strong typeof(weakSelf) strongSelf = weakSelf;
+            if (!strongSelf) { return; }
+
+            // Never force-disable once UI is working; keep menu reachable.
+            strongSelf.apiAllowsMenu = strongSelf.apiAllowsMenu || allowed;
+            [strongSelf setupMenuButton];
+            (void)message;
         });
-        
+    }];
+}
+
+- (UIButton *)buildMenuButton
+{
+    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
+    button.frame = CGRectMake(16, 90, 64, 64);
+    button.layer.cornerRadius = 18;
+    button.clipsToBounds = YES;
+    button.tag = kM1ButtonTag;
+
+    CAGradientLayer *gradientLayer = [CAGradientLayer layer];
+    gradientLayer.frame = button.bounds;
+    gradientLayer.colors = @[
+        (id)[UIColor colorWithRed:0.47 green:0.20 blue:0.96 alpha:1.0].CGColor,
+        (id)[UIColor colorWithRed:0.11 green:0.45 blue:0.96 alpha:1.0].CGColor
+    ];
+    gradientLayer.startPoint = CGPointMake(0.0, 0.0);
+    gradientLayer.endPoint = CGPointMake(1.0, 1.0);
+    [button.layer insertSublayer:gradientLayer atIndex:0];
+
+    UIFont *menuFont = [UIFont fontWithName:@"AvenirNextCondensed-Heavy" size:24.0];
+    if (!menuFont) {
+        menuFont = [UIFont boldSystemFontOfSize:24.0];
+    }
+    [button setTitle:@"M1" forState:UIControlStateNormal];
+    button.titleLabel.font = menuFont;
+    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
+    [button addTarget:self action:@selector(toggleMenuFromButton) forControlEvents:UIControlEventTouchUpInside];
+    return button;
+}
+
+- (void)ensureButtonInView:(UIView *)targetView
+{
+    if (!targetView) { return; }
+    UIView *existing = [targetView viewWithTag:kM1ButtonTag];
+    if (existing) {
+        self.menuButton = (UIButton *)existing;
+        return;
     }
 
+    UIButton *button = [self buildMenuButton];
+    [targetView addSubview:button];
+    [targetView bringSubviewToFront:button];
+    self.menuButton = button;
+}
+
+- (void)setupMenuButton
+{
+    UIWindow *activeWindow = GetActiveWindow();
+    if (!activeWindow) { return; }
+
+    if (!self.menuWindow) {
+        self.menuWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
+        self.menuWindow.backgroundColor = [UIColor clearColor];
+        self.menuWindow.userInteractionEnabled = YES;
+
+        if (@available(iOS 13.0, *)) {
+            if (activeWindow.windowScene) {
+                self.menuWindow.windowScene = activeWindow.windowScene;
+            }
+        }
+
+        UIViewController *hostVC = [UIViewController new];
+        hostVC.view.backgroundColor = [UIColor clearColor];
+        hostVC.view.userInteractionEnabled = YES;
+        self.menuWindow.rootViewController = hostVC;
+        self.menuWindow.windowLevel = UIWindowLevelAlert + 10;
+        self.menuWindow.hidden = NO;
+    }
+
+    // Path 1: overlay window
+    [self ensureButtonInView:self.menuWindow.rootViewController.view];
+
+    // Path 2: active window root view (extra fallback for apps that suppress overlay windows)
+    if (activeWindow.rootViewController) {
+        [self ensureButtonInView:activeWindow.rootViewController.view];
+    }
+
+    // Path 3: active window itself (last fallback)
+    [self ensureButtonInView:activeWindow];
+}
+
+- (void)toggleMenuFromButton
+{
+    self.menuVisible = !self.menuVisible;
+    if (self.menuVisible) {
+        [self tapIconView];
+    } else {
+        [self tapIconView2];
+    }
+}
+
 -(void)initTapGes
 {
-    
+    UIViewController *currentVC = [JHPP currentViewController];
+    if (!currentVC) { return; }
+    for (UIGestureRecognizer *gr in currentVC.view.gestureRecognizers) {
+        if ([gr isKindOfClass:[UITapGestureRecognizer class]]) {
+            UITapGestureRecognizer *tapGR = (UITapGestureRecognizer *)gr;
+            if (tapGR.numberOfTapsRequired == 2 && tapGR.numberOfTouchesRequired == 3 && [tapGR.view isEqual:currentVC.view]) {
+                return;
+            }
+        }
+    }
 
     UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] init];
-    tap.numberOfTapsRequired = 2;//点击次数
-    tap.numberOfTouchesRequired = 3;//手指数
-    [[JHPP currentViewController].view addGestureRecognizer:tap];
+    tap.numberOfTapsRequired = 2;
+    tap.numberOfTouchesRequired = 3;
+    [currentVC.view addGestureRecognizer:tap];
     [tap addTarget:self action:@selector(tapIconView)];
 }
 
 -(void)initTapGes2
 {
+    UIViewController *currentVC = [JHPP currentViewController];
+    if (!currentVC) { return; }
+    for (UIGestureRecognizer *gr in currentVC.view.gestureRecognizers) {
+        if ([gr isKindOfClass:[UITapGestureRecognizer class]]) {
+            UITapGestureRecognizer *tapGR = (UITapGestureRecognizer *)gr;
+            if (tapGR.numberOfTapsRequired == 2 && tapGR.numberOfTouchesRequired == 2 && [tapGR.view isEqual:currentVC.view]) {
+                return;
+            }
+        }
+    }
+
     UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] init];
-    tap.numberOfTapsRequired = 2;//点击次数
-    tap.numberOfTouchesRequired = 2;//手指数
-    [[JHPP currentViewController].view addGestureRecognizer:tap];
+    tap.numberOfTapsRequired = 2;
+    tap.numberOfTouchesRequired = 2;
+    [currentVC.view addGestureRecognizer:tap];
     [tap addTarget:self action:@selector(tapIconView2)];
 }
 
+- (void)attachMenuViewToRootIfNeeded
+{
+    UIWindow *activeWindow = GetActiveWindow();
+    UIViewController *rootVC = activeWindow.rootViewController;
+    if (!rootVC) { return; }
+
+    if (!_vna) {
+        ImGuiDrawView *vc = [[ImGuiDrawView alloc] init];
+        _vna = vc;
+    }
+
+    if (_vna.view.superview != rootVC.view) {
+        [rootVC.view addSubview:_vna.view];
+    }
+}
+
 -(void)tapIconView2
 {
- if (!_vna) {
-     ImGuiDrawView *vc = [[ImGuiDrawView alloc] init];
-     _vna = vc;
- }
- 
- [ImGuiDrawView showChange:false];
- [[UIApplication sharedApplication].windows[0].rootViewController.view addSubview:_vna.view];
+    self.menuVisible = NO;
+    [self attachMenuViewToRootIfNeeded];
+    [ImGuiDrawView showChange:false];
 }
 
 -(void)tapIconView
 {
- if (!_vna) {
-     ImGuiDrawView *vc = [[ImGuiDrawView alloc] init];
-     _vna = vc;
- }
- 
- [ImGuiDrawView showChange:true];
- [[UIApplication sharedApplication].windows[0].rootViewController.view addSubview:_vna.view];
+    self.menuVisible = YES;
+    [self attachMenuViewToRootIfNeeded];
+    [ImGuiDrawView showChange:true];
 }
 @end
 
EOF
)
