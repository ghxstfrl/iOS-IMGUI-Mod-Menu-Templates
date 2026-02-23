#import <UIKit/UIKit.h>
#import <MetalKit/MetalKit.h>
#import "modpanel/ModPanel.h"

@interface ImGuiDrawView : UIViewController <MTKViewDelegate>

// Needed for PubgLoad.mm toggle
+ (void)showChange:(BOOL)open;

@end
