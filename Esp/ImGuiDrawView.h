#import <UIKit/UIKit.h>
#import <MetalKit/MetalKit.h>

@interface ImGuiDrawView : MTKView <MTKViewDelegate>
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, assign) BOOL isMenuVisible;

+ (instancetype)sharedInstance;
+ (void)showMenu;
@end
