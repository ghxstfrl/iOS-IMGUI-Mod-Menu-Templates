#import <UIKit/UIKit.h>
#import <MetalKit/MetalKit.h>

@interface ImGuiDrawView : UIViewController <MTKViewDelegate>

// This must be declared so PubgLoad.mm sees it
+ (void)showChange:(BOOL)open;

@end
