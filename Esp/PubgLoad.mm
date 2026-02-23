#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "ImGuiDrawView.h"
#import "CaptainHook.h"

// 2. Wait for the app to finish launching, then show the ImGui menu
static void didFinishLaunching(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef info) {
    
    // Wait 3 seconds to ensure the game has created the main window
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [ImGuiDrawView showMenu];
    });
}

// 1. This constructor runs instantly when the tweak is injected
__attribute__((constructor)) static void initialize() {
    // Listen for app launch
    CFNotificationCenterAddObserver(CFNotificationCenterGetLocalCenter(), NULL, &didFinishLaunching, (CFStringRef)UIApplicationDidFinishLaunchingNotification, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}
