#import <UIKit/UIKit.h>
#import <MetalKit/MetalKit.h>

@interface ImGuiDrawView : UIViewController <MTKViewDelegate>

// Needed for PubgLoad.mm toggle
+ (void)showChange:(BOOL)open;

@end
