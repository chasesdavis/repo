#import "HBNativeControls.h"
#import <objc/message.h>

static id HBReadObject(id object, NSString *name) {
    SEL selector = NSSelectorFromString(name);
    NSMethodSignature *s = [object methodSignatureForSelector:selector];
    return s && s.numberOfArguments == 2 && s.methodReturnType[0] == '@' ? ((id (*)(id, SEL))objc_msgSend)(object, selector) : nil;
}
static UIControlEvents HBActionEvent(UIControl *button) {
    if (button.allControlEvents & UIControlEventTouchUpInside) return UIControlEventTouchUpInside;
    if (button.allControlEvents & UIControlEventPrimaryActionTriggered) return UIControlEventPrimaryActionTriggered;
    return 0;
}
static UIControl *HBActionButton(UIView *view, NSUInteger depth) {
    if (!view || depth > 8 || view.hidden || view.alpha < 0.01) return nil;
    if ([view isKindOfClass:UIControl.class] && ![view isKindOfClass:UISlider.class] && HBActionEvent((id)view)) return (id)view;
    for (UIView *child in view.subviews) {
        UIControl *button = HBActionButton(child, depth + 1);
        if (button) return button;
    }
    return nil;
}
static UIViewController *HBControllerNamed(UIViewController *root, NSString *fragment, NSUInteger depth) {
    if (depth > 6) return nil;
    if ([NSStringFromClass(root.class).lowercaseString containsString:fragment]) return root;
    for (UIViewController *child in root.childViewControllers) {
        UIViewController *result = HBControllerNamed(child, fragment, depth + 1);
        if (result) return result;
    }
    return nil;
}
static UIViewController *HBModuleNamed(UIViewController *root, NSArray<NSString *> *names, NSUInteger depth) {
    if (depth > 4) return nil;
    id identifier = HBReadObject(root, @"moduleIdentifier");
    if ([identifier isKindOfClass:NSString.class]) {
        for (NSString *name in names) if ([[identifier lowercaseString] containsString:name]) return root;
    }
    for (UIViewController *child in root.childViewControllers) {
        UIViewController *result = HBModuleNamed(child, names, depth + 1);
        if (result) return result;
    }
    return nil;
}
@implementation HBNativeControls
- (UIControl *)buttonForKey:(NSString *)key {
    @try {
        NSDictionary *radio = @{@"wifi": @"wifi", @"bluetooth": @"bluetooth", @"airplane": @"airplane", @"cellular": @"cellular"};
        UIViewController *controller;
        if (radio[key]) {
            UIViewController *module = HBModuleNamed(self.collection, @[@"connectivity"], 0);
            controller = HBControllerNamed(module, radio[key], 0);
        } else {
            // Only simple, non-authenticating toggles are forwarded. Launchers, Focus,
            // recording, and expanded panels remain on Apple's native presentation path.
            NSDictionary *modules = @{@"rotation": @[@"orientationlock"], @"power": @[@"lowpower"]};
            if (!modules[key]) return nil;
            UIViewController *module = HBModuleNamed(self.collection, modules[key], 0);
            id content = HBReadObject(module, @"contentViewController");
            controller = [content isKindOfClass:UIViewController.class] ? content : nil;
        }
        if (!controller.isViewLoaded) return nil;
        id button = HBReadObject(controller, @"buttonView");
        if ([button isKindOfClass:UIControl.class] && HBActionEvent(button) && ![(UIView *)button isHidden]) return button;
        // Uses UIView/UIControl APIs, never guessed private selector signatures or KVC.
        return HBActionButton(controller.view, 0);
    } @catch (__unused NSException *exception) { return nil; }
}
- (BOOL)activateKey:(NSString *)key {
    @try {
    UIControl *button = [self buttonForKey:key];
    if (!button || !button.enabled || !button.userInteractionEnabled) return NO;
    UIControlEvents event = HBActionEvent(button);
    if (!event) return NO;
    [button sendActionsForControlEvents:event];
    return YES;
    } @catch (__unused NSException *exception) { return NO; }
}
@end
