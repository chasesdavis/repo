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
@property(nonatomic, readwrite, copy) NSString *revealStatus;
@property(nonatomic, readwrite, copy) NSString *focusStatus;
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
// The coordinator's sectionRevealed flag is gesture bookkeeping. Its native
// programmatic reveal path instead updates revealState and revealPercentage.
// Let the controller own that path and its normal dismissal/reset lifecycle.
- (void)revealFocusForApp:(NSString *)app {
    self.focusStatus = @"not-requested";
    if (!app.length) return;
    @try {
        id master = ObjectGetter(self.owner, @"masterList");
        if (!Signature(master, @"isMissedSectionActive", "Bc", NULL)) { self.focusStatus = @"unavailable"; return; }
        if (!BoolGetter(master, @"isMissedSectionActive")) { self.focusStatus = @"inactive"; return; }
        id section = ObjectGetter(master, @"upcomingMissedSectionList");
        id items = ObjectGetter(section, @"allNotificationRequests");
        if ([items isKindOfClass:NSSet.class]) items = [items allObjects];
        if (![items isKindOfClass:NSArray.class] || [items count] > 4096) { self.focusStatus = @"unavailable"; return; }
        BOOL matched = NO;
        for (id request in items) {
            id identifier = ObjectGetter(request, @"sectionIdentifier");
            if ([identifier isKindOfClass:NSString.class] && [identifier isEqualToString:app]) { matched = YES; break; }
        }
        if (!matched) { self.focusStatus = @"no-matching-requests"; return; }
        id view = ObjectGetter(section, @"sectionListView");
        if (!Signature(view, @"isGrouped", "Bc", NULL) || !Signature(section, @"_expandSection", "v", NULL)) {
            self.focusStatus = @"unavailable"; return;
        }
        if (!BoolGetter(view, @"isGrouped")) { self.focusStatus = @"already-expanded"; return; }
        // Use the same section action as tapping the native Focus platter.
        // It requests authentication itself before exposing its content.
        // Never change DND configuration, device authentication or caches.
        VoidCall(section, @"_expandSection");
        self.focusStatus = @"native-expand-requested";
    } @catch (NSException *exception) { (void)exception; self.focusStatus = @"exception"; }
}
- (BOOL)revealHistory {
    self.focusStatus = @"not-requested";
    self.revealStatus = @"unavailable";
    SEL selector = NSSelectorFromString(@"revealNotificationHistory:animated:");
    if (!Matches(self.owner, selector, "Bc", "Bc")) return NO;
    @try {
        id master = ObjectGetter(self.owner, @"masterList");
        id coordinator = ObjectGetter(master, @"revealCoordinator");
        for (NSString *name in @[@"_shouldAllowNotificationListReveal", @"_shouldAllowNotificationListRevealTransition", @"_isRevealed"])
            if (!Signature(coordinator, name, "Bc", NULL)) return NO;
        for (NSString *name in @[@"_refetchSubListViews", @"_performRevealForSubviewsIfNecessary"])
            if (!Signature(coordinator, name, "v", NULL)) return NO;
        if (!BoolGetter(coordinator, @"_shouldAllowNotificationListReveal")) {
            self.revealStatus = @"native-policy-denied"; return NO;
        }
        // The native transition gate checks whether history has any requests.
        // An app with only incoming notifications needs no history transition.
        if (!BoolGetter(coordinator, @"_shouldAllowNotificationListRevealTransition")) {
            self.revealStatus = @"native-no-history"; return YES;
        }
        ((void (*)(id, SEL, BOOL, BOOL))objc_msgSend)(self.owner, selector, YES, NO);
        if (ObjectGetter(self.owner, @"masterList") != master || ObjectGetter(master, @"revealCoordinator") != coordinator) {
            self.revealStatus = @"native-coordinator-changed"; return NO;
        }
        if (!BoolGetter(coordinator, @"_shouldAllowNotificationListReveal")) {
            self.revealStatus = @"native-policy-denied"; return NO;
        }
        if (!BoolGetter(coordinator, @"_shouldAllowNotificationListRevealTransition")) {
            self.revealStatus = @"native-no-history"; return YES;
        }
        if (!BoolGetter(coordinator, @"_isRevealed")) {
            self.revealStatus = @"native-request-pending"; return NO;
        }
        // Filtering can create new sublist views after the native reveal state
        // was entered. Refresh those views using the existing native state.
        VoidCall(coordinator, @"_refetchSubListViews");
        NSArray *sublists = ObjectGetter(coordinator, @"subLists");
        if (![sublists isKindOfClass:NSArray.class] || !sublists.count) {
            self.revealStatus = @"native-no-sublists"; return NO;
        }
        VoidCall(coordinator, @"_performRevealForSubviewsIfNecessary");
        self.revealStatus = @"native-reveal-refreshed";
        return YES;
    } @catch (NSException *exception) {
        (void)exception; self.revealStatus = @"exception"; return NO;
    }
}
@end
