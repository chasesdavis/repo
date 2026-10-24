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
@interface AXNNativeFilter ()
@property(nonatomic, weak) id owner;
@property(nonatomic, strong) NSMutableSet<NSString *> *applied;
@property(nonatomic) BOOL applying;
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
- (BOOL)revealHistory {
    SEL selector = NSSelectorFromString(@"revealNotificationHistory:animated:");
    if (!Matches(self.owner, selector, "Bc", "Bc")) return NO;
    @try { ((void (*)(id, SEL, BOOL, BOOL))objc_msgSend)(self.owner, selector, YES, YES); return YES; }
    @catch (NSException *exception) { (void)exception; return NO; }
}
@end
