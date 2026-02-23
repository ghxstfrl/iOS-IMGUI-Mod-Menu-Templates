#import "ModPanel.h"
#import "ModPanel+OPMods.h"
#import "ModPanel+Spawns.h"
#import "ModPanel+Utils.h"

@implementation ModPanel {
    BOOL _isVisible;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.3]; // semi-transparent
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    // Add your buttons here, placeholder example
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:@"Test Button" forState:UIControlStateNormal];
    button.frame = CGRectMake(20, 50, 120, 40);
    [button addTarget:self action:@selector(testButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:button];
}

- (void)testButtonTapped {
    NSLog(@"Test button pressed!");
}

- (void)show {
    self.hidden = NO;
    _isVisible = YES;
}

- (void)hide {
    self.hidden = YES;
    _isVisible = NO;
}

- (void)updatePanel {
    // This is where you call looped functions like ModPanel+Spawns
    [self updateSpawns];
}

@end
