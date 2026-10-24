// SPDX-License-Identifier: GPL-3.0-only
#import "AXNNativeFilter.h"
#import <objc/message.h>
#import <objc/runtime.h>
#include <string.h>

static BOOL Matches(id owner, SEL selector, const char *first, const char *second) {
    Method method = class_getInstanceMethod(object_getClass(owner), selector);
    if (!method || method_getNumberOfArguments(method) != 4) return NO;
    char type[128] = {}; method_getReturnType(method, type, sizeof(type));
    if (type[0] != 'v') return NO;
    method_getArgumentType(method, 2, type, sizeof(type));
    if (!type[0] || !strchr(first, type[0])) return NO;
    method_getArgumentType(method, 3, type, sizeof(type));
    return type[0] && strchr(second, type[0]);
}
static BOOL Signature(id object, NSString *name, const char *result, const char *argument) {
    Method method = class_getInstanceMethod(object_getClass(object), NSSelectorFromString(name));
    unsigned count = argument ? 3 : 2;
    if (!method || method_getNumberOfArguments(method) != count) return NO;
    char type[128] = {}; method_getReturnType(method, type, sizeof(type));
    if (!type[0] || !strchr(result, type[0])) return NO;
    if (argument) { method_getArgumentType(method, 2, type, sizeof(type)); return type[0] && strchr(argument, type[0]); }
    return YES;
}
static id ObjectGetter(id object, NSString *name) {
    if (!Signature(object, name, "@", NULL)) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(object, NSSelectorFromString(name));
}
static BOOL BoolGetter(id object, NSString *name) {
    return ((BOOL (*)(id, SEL))objc_msgSend)(object, NSSelectorFromString(name));
}
static void VoidCall(id object, NSString *name) {
    ((void (*)(id, SEL))objc_msgSend)(object, NSSelectorFromString(name));
}
@interface AXNNativeFilter ()
@property(nonatomic, weak) id owner;
@property(nonatomic, strong) NSMutableSet<NSString *> *applied;
@property(nonatomic) BOOL applying;
@property(nonatomic, weak) id revealCoordinator;
@property(nonatomic) BOOL ownsReveal;
@property(nonatomic) BOOL previousReveal;
@property(nonatomic, readwrite, copy) NSString *revealStatus;
@end
@implementation AXNNativeFilter
- (instancetype)initWithOwner:(id)owner {
    if ((self = [super init])) { _owner = owner; _applied = [NSMutableSet new]; }
    return self;
}
- (BOOL)available {
    return Matches(self.owner, NSSelectorFromString(@"toggleFilteringForSectionIdentifier:shouldFilter:"), "@", "Bc");
}
- (NSUInteger)appliedCount { return self.applied.count; }
- (BOOL)applyHiddenApps:(NSSet<NSString *> *)apps preservingNativeApps:(NSSet<NSString *> *)nativeApps {
    if (self.applying) return NO;
    if (!self.available) return !apps.count && !self.applied.count;
    self.applying = YES;
    SEL selector = NSSelectorFromString(@"toggleFilteringForSectionIdentifier:shouldFilter:");
    BOOL success = YES;
    @try {
        // Hide other apps first; restore the newly selected app last.
        for (NSString *app in apps) {
            if ([nativeApps containsObject:app] || [self.applied containsObject:app]) continue;
            // Record before calling so partial native mutation can be restored.
            [self.applied addObject:app];
            ((void (*)(id, SEL, id, BOOL))objc_msgSend)(self.owner, selector, app, YES);
        }
        for (NSString *app in self.applied.copy) {
            if ([nativeApps containsObject:app]) {
                // A native rule now owns this exclusion; do not undo it.
                [self.applied removeObject:app];
            } else if (![apps containsObject:app]) {
                ((void (*)(id, SEL, id, BOOL))objc_msgSend)(self.owner, selector, app, NO);
                [self.applied removeObject:app];
            }
        }
    } @catch (NSException *exception) { (void)exception; success = NO; }
    @finally { self.applying = NO; }
    return success;
}
- (BOOL)restoreReveal {
    id coordinator = self.revealCoordinator;
    if (!self.ownsReveal || !coordinator) { self.ownsReveal = NO; return YES; }
    @try {
        if (!Signature(coordinator, @"isSectionRevealed", "Bc", NULL) ||
            !Signature(coordinator, @"setSectionRevealed:", "v", "Bc") ||
            !Signature(coordinator, @"_performRevealForSubviewsIfNecessary", "v", NULL)) return NO;
        // Restore only the state we set. A later native collapse already wins.
        if (BoolGetter(coordinator, @"isSectionRevealed")) {
            ((void (*)(id, SEL, BOOL))objc_msgSend)(coordinator, NSSelectorFromString(@"setSectionRevealed:"), self.previousReveal);
            VoidCall(coordinator, @"_performRevealForSubviewsIfNecessary");
        }
        self.ownsReveal = NO; self.revealCoordinator = nil;
        return YES;
    } @catch (NSException *exception) { (void)exception; return NO; }
}
- (BOOL)revealHistory {
    self.revealStatus = @"unavailable";
    SEL selector = NSSelectorFromString(@"revealNotificationHistory:animated:");
    if (!Matches(self.owner, selector, "Bc", "Bc")) return NO;
    @try {
        id master = ObjectGetter(self.owner, @"masterList");
        id coordinator = ObjectGetter(master, @"revealCoordinator");
        if (self.revealCoordinator != coordinator && ![self restoreReveal]) { self.revealStatus = @"restore-failed"; return NO; }
        for (NSString *name in @[@"_shouldAllowNotificationListReveal", @"_shouldAllowNotificationListRevealTransition", @"isSectionRevealed", @"isSectionRevealedStateLocked"])
            if (!Signature(coordinator, name, "Bc", NULL)) return NO;
        for (NSString *name in @[@"_refetchSubListViews", @"_performRevealForSubviewsIfNecessary"])
            if (!Signature(coordinator, name, "v", NULL)) return NO;
        if (!Signature(coordinator, @"setSectionRevealed:", "v", "Bc")) return NO;
        // Native policy and interaction locks take precedence. Never set forceRevealed,
        // authentication, preview permissions or an inferred display-style enum.
        if (!BoolGetter(coordinator, @"_shouldAllowNotificationListReveal") ||
            !BoolGetter(coordinator, @"_shouldAllowNotificationListRevealTransition")) {
            self.revealStatus = @"native-policy-denied"; return NO;
        }
        if (BoolGetter(coordinator, @"isSectionRevealedStateLocked")) { self.revealStatus = @"native-state-locked"; return NO; }
        ((void (*)(id, SEL, BOOL, BOOL))objc_msgSend)(self.owner, selector, YES, YES);
        VoidCall(coordinator, @"_refetchSubListViews");
        if (!self.ownsReveal) {
            self.previousReveal = BoolGetter(coordinator, @"isSectionRevealed");
            self.revealCoordinator = coordinator;
            self.ownsReveal = YES;
        }
        ((void (*)(id, SEL, BOOL))objc_msgSend)(coordinator, NSSelectorFromString(@"setSectionRevealed:"), YES);
        VoidCall(coordinator, @"_performRevealForSubviewsIfNecessary");
        self.revealStatus = @"section-update-sent";
        return YES;
    } @catch (NSException *exception) {
        (void)exception; self.revealStatus = @"exception"; [self restoreReveal]; return NO;
    }
}
@end
