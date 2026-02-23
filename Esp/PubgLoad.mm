#import "PubgLoad.h"
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "ImGuiDrawView.h"

@interface PubgLoad ()
@property (nonatomic, strong) UIButton *menuButton;
@property (nonatomic, strong) UIWindow *overlayWindow;
@property (nonatomic, strong) ImGuiDrawView *menuViewController;
@property (nonatomic, assign) BOOL menuVisible;
@end

@implementation PubgLoad

static PubgLoad *sharedInstance;
static NSInteger const kM1ButtonTag = 1337;

#pragma mark - Load

+ (void)load {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        sharedInstance = [PubgLoad new];
        [sharedInstance setupOverlay];
    });
}

#pragma mark - Overlay Setup

- (void)setupOverlay {

    UIWindow *mainWindow = [UIApplication sharedApplication].keyWindow;
    if (!mainWindow) return;

    self.overlayWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.overlayWindow.backgroundColor = [UIColor clearColor];
    self.overlayWindow.windowLevel = UIWindowLevelNormal + 1000;
    self.overlayWindow.hidden = NO;

    UIViewController *rootVC = [UIViewController new];
    rootVC.view.backgroundColor = [UIColor clearColor];
    self.overlayWindow.rootViewController = rootVC;

    [self addMenuButtonToView:rootVC.view];
}

#pragma mark - Button

- (void)addMenuButtonToView:(UIView *)view {

    if ([view viewWithTag:kM1ButtonTag]) return;

    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectMake(20, 120, 75, 36);
    button.layer.cornerRadius = 10;
    button.clipsToBounds = YES;
    button.tag = kM1ButtonTag;

    // Gradient Blue → Purple
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = button.bounds;
    gradient.colors = @[
        (id)[UIColor colorWithRed:0.20 green:0.45 blue:1.0 alpha:0.85].CGColor,
        (id)[UIColor colorWithRed:0.55 green:0.20 blue:0.95 alpha:0.85].CGColor
    ];
    gradient.startPoint = CGPointMake(0, 0);
    gradient.endPoint = CGPointMake(1, 1);
    gradient.cornerRadius = 10;

    [button.layer insertSublayer:gradient atIndex:0];

    [button setTitle:@"M1" forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];

    button.layer.borderWidth = 1;
    button.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.25].CGColor;

    [button addTarget:self
               action:@selector(toggleMenu)
     forControlEvents:UIControlEventTouchUpInside];

    [view addSubview:button];
    self.menuButton = button;
}

#pragma mark - Toggle Menu

- (void)toggleMenu {

    self.menuVisible = !self.menuVisible;

    if (self.menuVisible) {
        [self showMenu];
    } else {
        [self hideMenu];
    }
}

#pragma mark - Show / Hide

- (void)showMenu {

    if (!self.menuViewController) {
        self.menuViewController = [[ImGuiDrawView alloc] init];
        self.menuViewController.view.frame = [UIScreen mainScreen].bounds;
    }

    UIView *rootView = self.overlayWindow.rootViewController.view;

    if (self.menuViewController.view.superview != rootView) {
        [rootView addSubview:self.menuViewController.view];
    }

    self.menuViewController.view.hidden = NO;
    [ImGuiDrawView showChange:YES];
}

- (void)hideMenu {

    self.menuViewController.view.hidden = YES;
    [ImGuiDrawView showChange:NO];
}

@end
