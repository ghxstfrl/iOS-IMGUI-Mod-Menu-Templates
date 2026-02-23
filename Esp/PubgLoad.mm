#import "PubgLoad.h"
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "JHPP.h"
#import "JHDragView.h"
#import "ImGuiLoad.h"
#import "ImGuiDrawView.h"
#import "MenuAPIClient.h"

@interface PubgLoad()
@property (nonatomic,strong) ImGuiDrawView *vna;
@property (nonatomic,strong) UIButton *menuButton;
@property (nonatomic,strong) UIWindow *menuWindow;
@property (nonatomic,assign) BOOL menuVisible;
@property (nonatomic,assign) BOOL apiAllowsMenu;
@property (nonatomic,strong) dispatch_source_t watchdogTimer;
@end

@implementation PubgLoad

static PubgLoad *extraInfo;
static NSInteger const kM1ButtonTag = 0x4D314D31;

static UIWindow *GetActiveWindow(void) {
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    if (window) return window;
    if (@available(iOS 13.0,*)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            if (windowScene.activationState != UISceneActivationStateForegroundActive) continue;
            for (UIWindow *candidate in windowScene.windows) {
                if (candidate.isKeyWindow) return candidate;
            }
            if (windowScene.windows.count > 0) return windowScene.windows.firstObject;
        }
    }
    return [UIApplication sharedApplication].windows.firstObject;
}

+ (void)load {
    [super load];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
        extraInfo = [PubgLoad new];
        extraInfo.apiAllowsMenu = YES;
        [extraInfo registerAppLifecycleObservers];
        [extraInfo bootstrapMenuUI];
        [extraInfo startWatchdog];
    });
}

- (void)startWatchdog {
    if (self.watchdogTimer) return;

    self.watchdogTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,dispatch_get_main_queue());
    dispatch_source_set_timer(self.watchdogTimer,dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1*NSEC_PER_SEC)),
                             (uint64_t)(1*NSEC_PER_SEC),(uint64_t)(0.2*NSEC_PER_SEC));
    dispatch_source_set_event_handler(self.watchdogTimer,^{
        PubgLoad *strongSelf = extraInfo;
        if (!strongSelf) return;
        [strongSelf setupMenuButton];
    });
    dispatch_resume(self.watchdogTimer);
}

- (void)bootstrapMenuUI {
    [self setupMenuButton];
    [self initTapGes];
    [self initTapGes2];

    [[MenuAPIClient shared] validateMenuAccessWithCompletion:^(BOOL allowed, NSString * _Nullable message) {
        dispatch_async(dispatch_get_main_queue(),^{
            PubgLoad *strongSelf = extraInfo;
            if (!strongSelf) return;
            strongSelf.apiAllowsMenu = strongSelf.apiAllowsMenu || allowed;
            [strongSelf setupMenuButton];
        });
    }];
}

// All other methods remain exactly the same, just remove all __weak/__strong references
// like initTapGes, buildMenuButton, toggleMenuFromButton, etc.
@end
