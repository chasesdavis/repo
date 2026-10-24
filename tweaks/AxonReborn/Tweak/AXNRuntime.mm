// SPDX-License-Identifier: GPL-3.0-only
// Axon-derived experiment. Private selectors require validation on physical devices.
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <substrate.h>
#import "AXNRailView.h"
#import "../Shared/AXNPreferences.h"
#include "../Core/NotificationIndex.hpp"
#include <cstring>

enum AXNEvent { Insert, Remove, Modify };
struct AXNHook { SEL selector; IMP original; char result; };
static AXNHook hooks[3];
static bool enabled = false;
static const void *stateKey = &stateKey, *railKey = &railKey;

@interface AXNListState : NSObject {
@public
    axon::NotificationIndex index;
    std::set<axon::Key> visible;
}
@property(nonatomic, weak) UIViewController *owner;
@property(nonatomic, strong) NSMutableDictionary<NSArray<NSString *> *, id> *requests;
@property(nonatomic) BOOL ready;
@property(nonatomic) BOOL replaying;
@end
@implementation AXNListState
- (instancetype)init {
    if ((self = [super init])) _requests = [NSMutableDictionary new];
    return self;
}
@end

static NSHashTable<AXNListState *> *states;
static NSHashTable<AXNRailView *> *rails;
static __weak AXNListState *activeState;
static void AXNRefresh(void);

static const char *AXNUnqualified(const char *type) {
    while (*type && strchr("rnNoORV", *type)) ++type;
    return type;
}
static bool AXNMethodMatches(Class cls, SEL selector, const char *result, unsigned args) {
    Method method = class_getInstanceMethod(cls, selector);
    if (!method || method_getNumberOfArguments(method) != args) return false;
    char buffer[128] = {};
    method_getReturnType(method, buffer, sizeof(buffer));
    if (!strchr(result, *AXNUnqualified(buffer))) return false;
    for (unsigned i = 2; i < args; ++i) {
        method_getArgumentType(method, i, buffer, sizeof(buffer));
        if (*AXNUnqualified(buffer) != '@') return false;
    }
    return true;
}
// Read only an existing zero-argument object getter. No unchecked KVC or ivar casts.
static id AXNObject(id object, NSString *name) {
    if (!object) return nil;
    SEL selector = NSSelectorFromString(name);
    if (!AXNMethodMatches(object_getClass(object), selector, "@", 2)) return nil;
    @try { return ((id (*)(id, SEL))objc_msgSend)(object, selector); }
    @catch (NSException *exception) { (void)exception; return nil; }
}
static NSString *AXNString(id value) {
    return [value isKindOfClass:NSString.class] && [value length] ? value : nil;
}
static NSArray *AXNArray(id value) {
    if ([value isKindOfClass:NSArray.class]) return value;
    if ([value isKindOfClass:NSSet.class]) return [value allObjects];
    if ([value isKindOfClass:NSOrderedSet.class]) return [value array];
    return nil;
}
static bool AXNRecord(id request, axon::Record &record) {
    NSString *app = AXNString(AXNObject(request, @"sectionIdentifier"));
    if (!app) app = AXNString(AXNObject(AXNObject(request, @"bulletin"), @"sectionID"));
    NSString *identifier = AXNString(AXNObject(request, @"notificationIdentifier"));
    if (!app || !identifier) return false;
    record.key = {app.UTF8String, identifier.UTF8String};
    id date = AXNObject(request, @"timestamp");
    record.timestamp = [date isKindOfClass:NSDate.class] ? [date timeIntervalSince1970] : 0;
    return true;
}
static NSArray<NSString *> *AXNKey(const axon::Key &key) {
    return @[[NSString stringWithUTF8String:key.first.c_str()], [NSString stringWithUTF8String:key.second.c_str()]];
}
static bool AXNCallOriginal(id owner, AXNEvent event, id request) {
    const AXNHook &hook = hooks[event];
    if (hook.result == 'v') {
        ((void (*)(id, SEL, id))hook.original)(owner, hook.selector, request);
        return true;
    }
    return ((BOOL (*)(id, SEL, id))hook.original)(owner, hook.selector, request);
}
static bool AXNReplay(AXNListState *state, AXNEvent event, id request) {
    if (!state.owner || !request) return false;
    BOOL previous = state.replaying;
    state.replaying = YES;
    bool success = false;
    @try { success = AXNCallOriginal(state.owner, event, request); }
    @catch (NSException *exception) {
        (void)exception;
        NSLog(@"[Axon Reborn] Adapter replay failed; disabling filtering for this controller.");
    }
    @finally { state.replaying = previous; }
    return success;
}
static bool AXNRestore(AXNListState *state) {
    state->index.select(std::nullopt);
    bool success = true;
    for (const auto &key : state->index.visibleKeys()) {
        if (state->visible.count(key)) continue;
        if (AXNReplay(state, Insert, state.requests[AXNKey(key)])) state->visible.insert(key);
        else success = false;
    }
    if (!success) {
        state.ready = NO;
        NSLog(@"[Axon Reborn] Native restoration incomplete. Disable the tweak and respring.");
    }
    return success;
}
static bool AXNReconcile(AXNListState *state) {
    if (!state.ready) return false;
    std::set<axon::Key> desired = state->index.visibleKeys();
    auto current = state->visible;
    for (const auto &key : current) {
        if (desired.count(key)) continue;
        if (!AXNReplay(state, Remove, state.requests[AXNKey(key)])) {
            AXNRestore(state); state.ready = NO; return false;
        }
        state->visible.erase(key);
    }
    for (const auto &key : desired) {
        if (state->visible.count(key)) continue;
        if (!AXNReplay(state, Insert, state.requests[AXNKey(key)])) {
            AXNRestore(state); state.ready = NO; return false;
        }
        state->visible.insert(key);
    }
    return true;
}

// Initialize from the native list before offering filtering; an incomplete snapshot
// leaves the original presentation untouched. This is not a notification-store hook.
static NSArray *AXNSnapshot(UIViewController *owner) {
    NSArray *sections = AXNArray(AXNObject(AXNObject(owner, @"masterList"), @"notificationSections"));
    if (sections) {
        NSMutableArray *requests = [NSMutableArray new];
        for (id section in sections) {
            NSArray *items = AXNArray(AXNObject(section, @"allNotificationRequests"));
            if (!items) return nil;
            [requests addObjectsFromArray:items];
        }
        return requests;
    }
    return AXNArray(AXNObject(owner, @"allNotificationRequests"));
}
static void AXNAttachList(UIViewController *owner) {
    if (!enabled) return;
    AXNListState *state = objc_getAssociatedObject(owner, stateKey);
    // Re-read the native snapshot on every presentation; offscreen changes can
    // bypass this controller. Never revive a failed adapter without a respring.
    if (state) {
        if (!state.ready || !AXNRestore(state)) { AXNRefresh(); return; }
        objc_setAssociatedObject(owner, stateKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (activeState == state) activeState = nil;
    }
    NSArray *snapshot = AXNSnapshot(owner);
    if (!snapshot) { NSLog(@"[Axon Reborn] Snapshot interface unavailable; using native notifications."); return; }
    state = [AXNListState new]; state.owner = owner;
    for (id request in snapshot) {
        axon::Record record;
        if (!AXNRecord(request, record)) return;
        state->index.upsert(record);
        state->visible.insert(record.key);
        state.requests[AXNKey(record.key)] = request;
    }
    state.ready = YES;
    objc_setAssociatedObject(owner, stateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [states addObject:state]; activeState = state;
    AXNRefresh();
}
static bool AXNHandle(id owner, AXNEvent event, id request) {
    // Preserve the native calling thread; never mutate UIKit/model state off-main.
    if (!NSThread.isMainThread) {
        bool result = AXNCallOriginal(owner, event, request);
        dispatch_async(dispatch_get_main_queue(), ^{
            AXNListState *state = objc_getAssociatedObject(owner, stateKey);
            if (state) {
                axon::Record record;
                if (result && AXNRecord(request, record)) {
                    if (event == Remove) {
                        state->index.erase(record.key); state->visible.erase(record.key);
                        [state.requests removeObjectForKey:AXNKey(record.key)];
                    } else {
                        state->index.upsert(record); state->visible.insert(record.key);
                        state.requests[AXNKey(record.key)] = request;
                    }
                }
                AXNRestore(state); state.ready = NO; AXNRefresh();
            }
        });
        return result;
    }
    AXNListState *state = objc_getAssociatedObject(owner, stateKey);
    if (!enabled || !state || !state.ready || state.replaying) return AXNCallOriginal(owner, event, request);
    axon::Record record;
    if (!AXNRecord(request, record)) {
        AXNRestore(state); state.ready = NO; AXNRefresh();
        return AXNCallOriginal(owner, event, request);
    }
    bool shouldCall = event == Remove
        ? state->visible.count(record.key) || !state->index.contains(record.key)
        : state->index.includes(record.key);
    bool success = !shouldCall || AXNCallOriginal(owner, event, request);
    if (!success) return false;
    if (event == Remove) {
        state->index.erase(record.key); state->visible.erase(record.key);
        [state.requests removeObjectForKey:AXNKey(record.key)];
    } else {
        state->index.upsert(record); state.requests[AXNKey(record.key)] = request;
        if (shouldCall) state->visible.insert(record.key);
    }
    AXNReconcile(state); AXNRefresh();
    return success;
}
#define AXN_EVENT_CALLBACKS(Name, Event) \
static void Name##Void(id self, SEL command, id request) { (void)command; AXNHandle(self, Event, request); } \
static BOOL Name##Bool(id self, SEL command, id request) { (void)command; return AXNHandle(self, Event, request); }
AXN_EVENT_CALLBACKS(AXNInsert, Insert)
AXN_EVENT_CALLBACKS(AXNRemove, Remove)
AXN_EVENT_CALLBACKS(AXNModify, Modify)

static NSString *AXNAppName(NSString *bundleID) {
    id controller = AXNObject(NSClassFromString(@"SBApplicationController"), @"sharedInstance");
    SEL selector = NSSelectorFromString(@"applicationWithBundleIdentifier:");
    if (controller && AXNMethodMatches(object_getClass(controller), selector, "@", 3)) {
        id application = ((id (*)(id, SEL, id))objc_msgSend)(controller, selector, bundleID);
        NSString *name = AXNString(AXNObject(application, @"displayName"));
        if (name) return name;
    }
    // Do not use notification headers: these can contain a private sender name.
    return bundleID;
}
static void AXNRender(void) {
    AXNListState *state = activeState;
    NSMutableArray<AXNRailItem *> *items = [NSMutableArray new];
    NSString *selection = nil;
    if (enabled && state.ready) {
        NSInteger sorting = [AXNReadPreference(@"Sort", @0) integerValue];
        auto groups = state->index.groups(sorting == 1 ? axon::Sort::Count : axon::Sort::Recent);
        if (state->index.selection()) selection = [NSString stringWithUTF8String:state->index.selection()->c_str()];
        for (const auto &group : groups) {
            AXNRailItem *item = [AXNRailItem new];
            item.bundleID = [NSString stringWithUTF8String:group.app.c_str()];
            item.name = AXNAppName(item.bundleID); item.count = group.count;
            for (const auto &key : state->index.visibleKeys()) {
                if (key.first != group.app) continue;
                id icon = AXNObject(AXNObject(state.requests[AXNKey(key)], @"content"), @"icon");
                if ([icon isKindOfClass:UIImage.class]) { item.icon = icon; break; }
            }
            // Hidden apps still retain their icon without reading message text.
            if (!item.icon) for (NSArray<NSString *> *key in state.requests) {
                if (![key.firstObject isEqualToString:item.bundleID]) continue;
                id icon = AXNObject(AXNObject(state.requests[key], @"content"), @"icon");
                if ([icon isKindOfClass:UIImage.class]) { item.icon = icon; break; }
            }
            [items addObject:item];
        }
    }
    for (AXNRailView *rail in rails) [rail updateWithItems:items selected:selection];
}
static void AXNRefresh(void) {
    // Notification bursts produce one rail render per main-queue turn.
    static bool pending = false;
    if (pending) return;
    pending = true;
    dispatch_async(dispatch_get_main_queue(), ^{ pending = false; AXNRender(); });
}
static void AXNMount(UIViewController *owner) {
    if (!enabled) return;
    AXNRailView *rail = objc_getAssociatedObject(owner, railKey);
    if (rail) { AXNRefresh(); return; }
    Ivar ivar = class_getInstanceVariable(owner.class, "_stackView");
    if (!ivar || *AXNUnqualified(ivar_getTypeEncoding(ivar)) != '@') return;
    id container = object_getIvar(owner, ivar);
    if (![container isKindOfClass:UIStackView.class]) return;
    UIStackView *stack = container;
    rail = [[AXNRailView alloc] initWithFrame:CGRectZero];
    rail.hidden = YES;
    rail.onSelect = ^(NSString *bundleID) {
        AXNListState *state = activeState;
        if (!enabled || !state.ready) return;
        if (bundleID) state->index.select(std::string(bundleID.UTF8String));
        else state->index.select(std::nullopt);
        AXNReconcile(state); AXNRefresh();
    };
    [stack addArrangedSubview:rail];
    [rail.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;
    objc_setAssociatedObject(owner, railKey, rail, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [rails addObject:rail]; AXNRefresh();
}

static void (*listDidAppearOriginal)(id, SEL, BOOL);
static void (*listWillDisappearOriginal)(id, SEL, BOOL);
static void (*hostDidLoadOriginal)(id, SEL);
static void (*hostDidAppearOriginal)(id, SEL, BOOL);
static void (*hostWillDisappearOriginal)(id, SEL, BOOL);
static BOOL (*hostHasContentOriginal)(id, SEL);
static void AXNListDidAppear(id self, SEL command, BOOL animated) {
    listDidAppearOriginal(self, command, animated); AXNAttachList(self);
}
static void AXNListWillDisappear(id self, SEL command, BOOL animated) {
    AXNListState *state = objc_getAssociatedObject(self, stateKey);
    if (state) AXNRestore(state);
    if (activeState == state) activeState = nil;
    AXNRefresh(); listWillDisappearOriginal(self, command, animated);
}
static void AXNHostDidLoad(id self, SEL command) { hostDidLoadOriginal(self, command); AXNMount(self); }
static void AXNHostDidAppear(id self, SEL command, BOOL animated) { hostDidAppearOriginal(self, command, animated); AXNMount(self); }
static void AXNHostWillDisappear(id self, SEL command, BOOL animated) {
    if (activeState) AXNRestore(activeState);
    AXNRefresh(); hostWillDisappearOriginal(self, command, animated);
}
static BOOL AXNHostHasContent(id self, SEL command) {
    AXNRailView *rail = objc_getAssociatedObject(self, railKey);
    return hostHasContentOriginal(self, command) || (enabled && rail && !rail.hidden);
}
static void AXNPreferenceCallback(CFNotificationCenterRef center, void *observer, CFStringRef name,
                                  const void *object, CFDictionaryRef userInfo) {
    (void)center; (void)observer; (void)name; (void)object; (void)userInfo;
    dispatch_async(dispatch_get_main_queue(), ^{
        AXNSynchronizePreferences();
        bool nextEnabled = [AXNReadPreference(@"Enabled", @NO) boolValue];
        if (enabled && !nextEnabled) {
            for (AXNListState *state in states.allObjects) {
                if (AXNRestore(state)) {
                    objc_setAssociatedObject(state.owner, stateKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                }
            }
            activeState = nil;
        }
        enabled = nextEnabled;
        AXNRefresh();
    });
}
__attribute__((constructor)) static void AXNInitialize(void) {
    @autoreleasepool {
        if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.springboard"]) return;
        NSInteger major = NSProcessInfo.processInfo.operatingSystemVersion.majorVersion;
        if (major < 15 || major > 17) return;
        Class list = NSClassFromString(@"NCNotificationStructuredListViewController");
        Class host = NSClassFromString(@"CSNotificationAdjunctListViewController");
        if (!list || !host || ![list isSubclassOfClass:UIViewController.class] || ![host isSubclassOfClass:UIViewController.class]) return;
        const char *names[3] = {"insertNotificationRequest:", "removeNotificationRequest:", "modifyNotificationRequest:"};
        IMP voidCallbacks[3] = {(IMP)AXNInsertVoid, (IMP)AXNRemoveVoid, (IMP)AXNModifyVoid};
        IMP boolCallbacks[3] = {(IMP)AXNInsertBool, (IMP)AXNRemoveBool, (IMP)AXNModifyBool};
        for (int i = 0; i < 3; ++i) {
            hooks[i].selector = sel_registerName(names[i]);
            if (!AXNMethodMatches(list, hooks[i].selector, "vB", 3)) {
                NSLog(@"[Axon Reborn] Unknown notification method signature; leaving native notifications active."); return;
            }
            char type[16] = {};
            method_getReturnType(class_getInstanceMethod(list, hooks[i].selector), type, sizeof(type));
            hooks[i].result = *AXNUnqualified(type);
        }
        states = [NSHashTable weakObjectsHashTable]; rails = [NSHashTable weakObjectsHashTable];
        AXNSynchronizePreferences(); enabled = [AXNReadPreference(@"Enabled", @NO) boolValue];
        for (int i = 0; i < 3; ++i) MSHookMessageEx(list, hooks[i].selector,
            hooks[i].result == 'v' ? voidCallbacks[i] : boolCallbacks[i], &hooks[i].original);
        MSHookMessageEx(list, @selector(viewDidAppear:), (IMP)AXNListDidAppear, (IMP *)&listDidAppearOriginal);
        MSHookMessageEx(list, @selector(viewWillDisappear:), (IMP)AXNListWillDisappear, (IMP *)&listWillDisappearOriginal);
        MSHookMessageEx(host, @selector(viewDidLoad), (IMP)AXNHostDidLoad, (IMP *)&hostDidLoadOriginal);
        MSHookMessageEx(host, @selector(viewDidAppear:), (IMP)AXNHostDidAppear, (IMP *)&hostDidAppearOriginal);
        MSHookMessageEx(host, @selector(viewWillDisappear:), (IMP)AXNHostWillDisappear, (IMP *)&hostWillDisappearOriginal);
        if (AXNMethodMatches(host, @selector(isPresentingContent), "B", 2))
            MSHookMessageEx(host, @selector(isPresentingContent), (IMP)AXNHostHasContent, (IMP *)&hostHasContentOriginal);
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, AXNPreferenceCallback,
            (__bridge CFStringRef)AXNPreferencesChanged, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    }
}
