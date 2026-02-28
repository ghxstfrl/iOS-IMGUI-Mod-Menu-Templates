//
//  ImGuiLoad.m
//  ImGuiTest
//
//  Created by yiming on 2021/6/2.
//

#import "ImGuiLoad.h"
#import "ImGuiDrawView.h"
#import "modpanel/ModPanel.h"
@implementation ImGuiLoad

+ (instancetype)share
{
    static ImGuiLoad *tool;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        tool = [[ImGuiLoad alloc] init];
    });
    return tool;
}

- (void)show
{
    // simply request the ImGuiDrawView to appear
    [ImGuiDrawView showMenu];
}

- (void)hide
{
    // remove the view if it exists
    ImGuiDrawView *view = [ImGuiDrawView sharedInstance];
    if (view && view.superview) {
        [view removeFromSuperview];
    }
    // no additional state required; ImGuiDrawView handles visibility itself
}

@end
