// SPDX-License-Identifier: GPL-3.0-only
// Axon-derived experiment. Private selectors require validation on physical devices.
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#ifndef AXN_RUNTIME_TEST
#import <substrate.h>
#else
// The test harness supplies original methods directly; it does not inject hooks.
static void MSHookMessageEx(Class cls, SEL sel, IMP replacement, IMP *original) {
    (void)cls; (void)sel; (void)replacement; (void)original;
}
#endif
#import <notify.h>
#import "AXNRailView.h"
#import "AXNListMount.h"
#import "AXNListResolver.h"
#import "AXNNativeFilter.h"
#import "../Shared/AXNPreferences.h"
#include "../Core/NotificationIndex.hpp"
#include <cstring>

enum AXNEvent { Insert, Remove, Modify };
struct AXNHook { SEL selector; IMP original; char result; };
static AXNHook hooks[3];
static bool enabled = false;
static AXNDiagnosticState diagnostic = AXNDiagnosticWaiting;
static bool hooksInstalled = false, mountSucceeded = false, mountFailed = false;
static bool useListMount = false;
static NSString *lastLayoutReport, *lastFilterReport, *lastModelReport;
static BOOL (*nativeShouldFilterOriginal)(id, SEL, id, id);
static NSUInteger predicateCalls = 0, predicateExclusions = 0;
static bool nativeFilterHookInstalled = false;
static AXNDiagnosticState mountDiagnostic = AXNDiagnosticMount;
static bool presentedContent = false;
static const void *stateKey = &stateKey, *railKey = &railKey, *listMountKey = &listMountKey;

@interface AXNListState : NSObject {
@public
    axon::NotificationIndex index;
    std::set<axon::Key> visible;
}
@property(nonatomic, weak) UIViewController *owner;
@property(nonatomic, strong) NSMutableDictionary<NSArray<NSString *> *, id> *requests;
@property(nonatomic) BOOL ready;
@property(nonatomic) BOOL replaying;
@property(nonatomic, strong) AXNNativeFilter *nativeFilter;
@property(nonatomic) NSUInteger selectionTaps;
@property(nonatomic) BOOL revealedSelection;
@property(nonatomic) BOOL selectionSettled;
@property(nonatomic) BOOL nativeCountAvailable;
@property(nonatomic) NSUInteger nativeVisibleCount;
@end
@implementation AXNListState
- (instancetype)init {
    if ((self = [super init])) _requests = [NSMutableDictionary new];
    return self;
}
@end

static NSHashTable<AXNListState *> *states;
static NSHashTable<AXNRailView *> *rails;
static NSHashTable<UIViewController *> *listOwners, *hostOwners;
static __weak AXNListState *activeState;
static void AXNRefresh(void);
static void AXNMountList(UIViewController *owner);

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
// Read the original native policy directly, so Axon never takes ownership of
// exclusions already imposed by iOS. These identifiers remain in memory only.
static NSSet<NSString *> *AXNNativeExclusions(AXNListState *state) {
    NSMutableSet *excluded = [NSMutableSet new];
    if (!nativeShouldFilterOriginal) return excluded;
    id master = AXNObject(state.owner, @"masterList");
    for (NSArray<NSString *> *key in state.requests) {
        if (nativeShouldFilterOriginal(state.owner, NSSelectorFromString(@"notificationMasterList:shouldFilterNotificationRequest:"), master, state.requests[key]))
            [excluded addObject:key.firstObject];
    }
    return excluded;
}
static BOOL AXNShouldFilter(id owner, SEL command, id master, id request) {
    BOOL native = nativeShouldFilterOriginal(owner, command, master, request);
    if (native || !NSThread.isMainThread) return native;
    AXNListState *state = objc_getAssociatedObject(owner, stateKey);
    if (!enabled || !state.ready || state != activeState || !state->index.selection()) return native;
    ++predicateCalls;
    axon::Record record;
    BOOL excluded = AXNRecord(request, record) && !state->index.includes(record.key);
    if (excluded) ++predicateExclusions;
    return excluded;
}
static BOOL AXNApplyNativeFilter(AXNListState *state) {
    NSMutableSet<NSString *> *hidden = [NSMutableSet new];
    if (state->index.selection()) for (const auto &group : state->index.groups(axon::Sort::Identifier))
        if (group.app != *state->index.selection()) [hidden addObject:[NSString stringWithUTF8String:group.app.c_str()]];
    BOOL previous = state.replaying; state.replaying = YES;
    BOOL success = NO;
    @try { success = [state.nativeFilter applyHiddenApps:hidden preservingNativeApps:AXNNativeExclusions(state)]; }
    @catch (NSException *exception) { (void)exception; }
    @finally { state.replaying = previous; }
    return success;
}
static void AXNCaptureFilterReport(AXNListState *state) {
    if (!state.selectionTaps) return;
    NSUInteger nativeCount = 0;
    SEL count = NSSelectorFromString(@"visibleNotificationCount");
    BOOL hasCount = AXNMethodMatches(state.owner.class, count, "Q", 2);
    if (hasCount) {
        @try { nativeCount = ((NSUInteger (*)(id, SEL))objc_msgSend)(state.owner, count); }
        @catch (NSException *exception) { (void)exception; hasCount = NO; }
    }
    state.nativeCountAvailable = hasCount; state.nativeVisibleCount = nativeCount;
    lastFilterReport = [NSString stringWithFormat:@"Selection: taps=%lu appSelected=%d expectedRequests=%lu appliedAppRules=%lu predicateCalls=%lu predicateExclusions=%lu historyRevealRequested=%d nativeCountAvailable=%d nativeVisibleCount=%lu coordinator=%@",
        (unsigned long)state.selectionTaps, state->index.selection().has_value(),
        (unsigned long)state->index.visibleKeys().size(), (unsigned long)state.nativeFilter.appliedCount,
        (unsigned long)predicateCalls, (unsigned long)predicateExclusions, state.revealedSelection,
        hasCount, (unsigned long)nativeCount, state.nativeFilter.revealStatus ?: @"not-requested"];
}
// Read only checked scalar getters; report raw values without guessing enum meanings.
static NSString *AXNScalar(id object, NSString *name) {
    SEL selector = NSSelectorFromString(name);
    @try {
        if (AXNMethodMatches(object_getClass(object), selector, "B", 2))
            return ((BOOL (*)(id, SEL))objc_msgSend)(object, selector) ? @"1" : @"0";
        if (AXNMethodMatches(object_getClass(object), selector, "Q", 2))
            return [NSString stringWithFormat:@"%lu", (unsigned long)((NSUInteger (*)(id, SEL))objc_msgSend)(object, selector)];
    } @catch (NSException *exception) { (void)exception; }
    return @"unavailable";
}
// Traverse collection values only, never dictionary keys, text or descriptions.
static NSString *AXNRequestCounts(id container, AXNListState *state) {
    if (!container) return @"unavailable";
    NSMutableArray *pending = [NSMutableArray arrayWithObject:container];
    std::set<axon::Key> keys;
    NSUInteger visited = 0, unknown = 0, selected = 0;
    BOOL truncated = NO;
    NSHashTable *seen = [NSHashTable hashTableWithOptions:NSPointerFunctionsObjectPointerPersonality];
    while (pending.count && visited++ < 4096) {
        id value = pending.lastObject; [pending removeLastObject];
        if ([seen containsObject:value]) continue; [seen addObject:value];
        NSArray *children = [value isKindOfClass:NSDictionary.class] ? [value allValues] : AXNArray(value);
        if (children) {
            NSUInteger room = 4096 - MIN((NSUInteger)4096, pending.count + visited);
            if (children.count > room) { ++unknown; truncated = YES; }
            [pending addObjectsFromArray:[children subarrayWithRange:NSMakeRange(0, MIN(room, children.count))]];
        } else {
            axon::Record record;
            if (AXNRecord(value, record)) keys.insert(record.key); else ++unknown;
        }
    }
    for (const auto &key : keys) if (state->index.includes(key)) ++selected;
    return [NSString stringWithFormat:@"total=%lu selected=%lu unknown=%lu truncated=%d", (unsigned long)keys.size(), (unsigned long)selected, (unsigned long)unknown, truncated || pending.count > 0];
}
static NSString *AXNModelReport(AXNListState *state) {
    id master = AXNObject(state.owner, @"masterList");
    NSMutableString *report = [NSMutableString stringWithFormat:@"Native model: historyRevealed=%@ contentToReveal=%@ displayStyle=%@ totalCount=%@ visibleCount=%@\n",
        AXNScalar(master, @"isNotificationHistoryRevealed"), AXNScalar(master, @"hasVisibleContentToReveal"),
        AXNScalar(master, @"currentListDisplayStyleSetting"), AXNScalar(master, @"totalNotificationCount"), AXNScalar(master, @"visibleNotificationCount")];
    id coordinator = AXNObject(master, @"revealCoordinator");
    [report appendFormat:@"Coordinator: class=%@ sectionRevealed=%@ stateLocked=%@ forceRevealed=%@ allowsReveal=%@ allowsTransition=%@ sublists=%lu\n",
        coordinator ? NSStringFromClass([coordinator class]) : @"nil", AXNScalar(coordinator, @"isSectionRevealed"),
        AXNScalar(coordinator, @"isSectionRevealedStateLocked"), AXNScalar(coordinator, @"isForceRevealed"),
        AXNScalar(coordinator, @"_shouldAllowNotificationListReveal"), AXNScalar(coordinator, @"_shouldAllowNotificationListRevealTransition"),
        (unsigned long)AXNArray(AXNObject(coordinator, @"subLists")).count];
    NSMutableArray *pending = [NSMutableArray arrayWithArray:AXNArray(AXNObject(master, @"notificationSections")) ?: @[]];
    NSHashTable *seen = [NSHashTable hashTableWithOptions:NSPointerFunctionsObjectPointerPersonality];
    NSUInteger visited = 0;
    while (pending.count && visited++ < 16 && report.length < 4000) {
        id section = pending.firstObject; [pending removeObjectAtIndex:0];
        if ([seen containsObject:section]) continue; [seen addObject:section];
        [report appendFormat:@"section %lu %@: revealed=%@ visible=%@ groups=%@ notificationCount=%@\n all[%@] filtered[%@] hidden[%@]\n",
            (unsigned long)visited, NSStringFromClass([section class]), AXNScalar(section, @"isNotificationListViewRevealed"),
            AXNScalar(section, @"isSectionVisible"), AXNScalar(section, @"count"), AXNScalar(section, @"notificationCount"),
            AXNRequestCounts(AXNObject(section, @"allNotificationRequests"), state),
            AXNRequestCounts(AXNObject(section, @"filteredNotificationRequests"), state),
            AXNRequestCounts(AXNObject(section, @"hiddenNotificationRequests"), state)];
        NSArray *children = AXNArray(AXNObject(section, @"sectionLists"));
        NSUInteger room = 16 - MIN((NSUInteger)16, visited + pending.count);
        if (children) [pending addObjectsFromArray:[children subarrayWithRange:NSMakeRange(0, MIN(room, children.count))]];
    }
    return report;
}
static void AXNRequestSelectionReveal(AXNListState *state) {
    state.revealedSelection = NO; state.selectionSettled = NO;
    NSUInteger generation = state.selectionTaps;
    __weak AXNListState *weakState = state;
    // Native filter operations may queue section layout/visibility updates.
    // Let that turn finish before asking the controller to reveal history.
    dispatch_async(dispatch_get_main_queue(), ^{
        AXNListState *current = weakState;
        if (!enabled || !current.ready || current != activeState || current.selectionTaps != generation) return;
        [current.owner.viewIfLoaded layoutIfNeeded];
        current.revealedSelection = [current.nativeFilter revealHistory];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 350 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
            AXNListState *settled = weakState;
            if (!enabled || !settled.ready || settled != activeState || settled.selectionTaps != generation) return;
            settled.selectionSettled = YES;
            AXNCaptureFilterReport(settled);
            lastModelReport = AXNModelReport(settled);
            AXNRefresh();
        });
    });
}
static bool AXNRestore(AXNListState *state) {
    state->index.select(std::nullopt);
    bool success = true;
    if (useListMount) {
        success = AXNApplyNativeFilter(state);
        BOOL revealRestored = [state.nativeFilter restoreReveal];
        success = success && revealRestored;
        if (!success) { state.ready = NO; diagnostic = AXNDiagnosticReplay; }
        return success;
    }
    for (const auto &key : state->index.visibleKeys()) {
        if (state->visible.count(key)) continue;
        if (AXNReplay(state, Insert, state.requests[AXNKey(key)])) state->visible.insert(key);
        else success = false;
    }
    if (!success) {
        state.ready = NO;
        diagnostic = AXNDiagnosticReplay;
        NSLog(@"[Axon Reborn] Native restoration incomplete. Disable the tweak and respring.");
    }
    return success;
}
static bool AXNReconcile(AXNListState *state) {
    if (!state.ready) return false;
    if (useListMount) {
        if (AXNApplyNativeFilter(state)) return true;
        AXNRestore(state); state.ready = NO; diagnostic = AXNDiagnosticReplay; return false;
    }
    std::set<axon::Key> desired = state->index.visibleKeys();
    auto current = state->visible;
    for (const auto &key : current) {
        if (desired.count(key)) continue;
        if (!AXNReplay(state, Remove, state.requests[AXNKey(key)])) {
            AXNRestore(state); state.ready = NO; diagnostic = AXNDiagnosticReplay; return false;
        }
        state->visible.erase(key);
    }
    for (const auto &key : desired) {
        if (state->visible.count(key)) continue;
        if (!AXNReplay(state, Insert, state.requests[AXNKey(key)])) {
            AXNRestore(state); state.ready = NO; diagnostic = AXNDiagnosticReplay; return false;
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
    [listOwners addObject:owner];
    if (!enabled) return;
    AXNListState *state = objc_getAssociatedObject(owner, stateKey);
    // viewDidLoad, viewWillAppear and viewDidAppear can refer to the same
    // presentation. Do not reset a live selection when an appearance repeats.
    if (state && state == activeState) { AXNRefresh(); return; }
    // Re-read the native snapshot on every presentation; offscreen changes can
    // bypass this controller. Never revive a failed adapter without a respring.
    if (state) {
        if (!state.ready || !AXNRestore(state)) { AXNRefresh(); return; }
        objc_setAssociatedObject(owner, stateKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (activeState == state) activeState = nil;
    }
    NSArray *snapshot = AXNSnapshot(owner);
    if (!snapshot) { diagnostic = AXNDiagnosticSnapshot; NSLog(@"[Axon Reborn] Snapshot interface unavailable; using native notifications."); return; }
    state = [AXNListState new]; state.owner = owner;
    if (useListMount) state.nativeFilter = [[AXNNativeFilter alloc] initWithOwner:owner];
    for (id request in snapshot) {
        axon::Record record;
        if (!AXNRecord(request, record)) { diagnostic = AXNDiagnosticRequest; return; }
        state->index.upsert(record);
        state->visible.insert(record.key);
        state.requests[AXNKey(record.key)] = request;
    }
    state.ready = YES;
    objc_setAssociatedObject(owner, stateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [states addObject:state]; activeState = state;
    diagnostic = state->index.size() ? AXNDiagnosticReady : AXNDiagnosticEmpty;
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
                AXNRestore(state); state.ready = NO; diagnostic = AXNDiagnosticReplay; AXNRefresh();
            }
        });
        return result;
    }
    AXNListState *state = objc_getAssociatedObject(owner, stateKey);
    if (!enabled || !state || !state.ready || state.replaying) return AXNCallOriginal(owner, event, request);
    axon::Record record;
    if (!AXNRecord(request, record)) {
        AXNRestore(state); state.ready = NO; AXNRefresh();
        diagnostic = AXNDiagnosticRequest;
        return AXNCallOriginal(owner, event, request);
    }
    bool shouldCall = useListMount || (event == Remove
        ? state->visible.count(record.key) || !state->index.contains(record.key)
        : state->index.includes(record.key));
    bool success = !shouldCall || AXNCallOriginal(owner, event, request);
    if (!success) return false;
    if (event == Remove) {
        state->index.erase(record.key); state->visible.erase(record.key);
        [state.requests removeObjectForKey:AXNKey(record.key)];
    } else {
        state->index.upsert(record); state.requests[AXNKey(record.key)] = request;
        if (shouldCall) state->visible.insert(record.key);
    }
    AXNReconcile(state); AXNCaptureFilterReport(state); AXNRefresh();
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
    if (useListMount && enabled && state.ready) AXNMountList(state.owner);
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
    if (useListMount) {
        for (UIViewController *owner in listOwners.allObjects) {
            AXNListMount *mount = objc_getAssociatedObject(owner, listMountKey);
            BOOL visible = enabled && state.ready && owner == state.owner && items.count > 0 && owner.viewIfLoaded.window;
            if (mount && visible) {
                mountSucceeded = [mount updateVisible:YES];
                mountFailed = !mountSucceeded;
                mountDiagnostic = AXNDiagnosticGeometry;
                lastLayoutReport = AXNDescribeLayout(owner, mount.scrollView, mount.rail);
            } else [mount updateVisible:NO];
        }
    }
    if (enabled && state.ready) {
        diagnostic = items.count ? AXNDiagnosticReady : AXNDiagnosticEmpty;
        if (useListMount && (!nativeFilterHookInstalled || !state.nativeFilter.available)) diagnostic = AXNDiagnosticFiltering;
        else if (useListMount && state.selectionSettled && !state.revealedSelection) diagnostic = AXNDiagnosticReveal;
        else if (useListMount && state.selectionSettled && state.nativeCountAvailable && state.nativeVisibleCount == 0 && !state->index.visibleKeys().empty()) diagnostic = AXNDiagnosticZeroVisible;
        AXNCaptureFilterReport(state);
    }
    // Content must not depend on an already visible rail: UIKit may not load or
    // present the adjunct controller until isPresentingContent returns YES.
    bool hasContent = enabled && state.ready && items.count > 0;
    if (hasContent != presentedContent) {
        presentedContent = hasContent;
        for (UIViewController *host in hostOwners.allObjects) {
            SEL update = NSSelectorFromString(@"_updatePresentingContent");
            if (AXNMethodMatches(host.class, update, "v", 2))
                ((void (*)(id, SEL))objc_msgSend)(host, update);
            [host.viewIfLoaded setNeedsLayout];
        }
    }
}
static void AXNRefresh(void) {
    // Notification bursts produce one rail render per main-queue turn.
    static bool pending = false;
    if (pending) return;
    pending = true;
    dispatch_async(dispatch_get_main_queue(), ^{ pending = false; AXNRender(); });
}
static void AXNMountList(UIViewController *owner) {
    if (!useListMount || !enabled || !owner.viewIfLoaded.window) return;
    UIScrollView *list = AXNResolveList(owner);
    AXNListMount *mount = objc_getAssociatedObject(owner, listMountKey);
    if (mount && (mount.scrollView != list || mount.rail.superview != list)) {
        [rails removeObject:mount.rail]; [mount detach];
        objc_setAssociatedObject(owner, listMountKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        mount = nil;
    }
    lastLayoutReport = AXNDescribeLayout(owner, list, mount.rail);
    if (!list) {
        mountSucceeded = false; mountFailed = true; mountDiagnostic = AXNDiagnosticCollection;
        return;
    }
    if (mount) return;
    mount = [[AXNListMount alloc] initWithScrollView:list];
    __weak UIViewController *weakOwner = owner;
    mount.rail.onSelect = ^(NSString *bundleID) {
        AXNListState *state = objc_getAssociatedObject(weakOwner, stateKey);
        if (!enabled || !state.ready || state != activeState) return;
        ++state.selectionTaps;
        if (!nativeFilterHookInstalled || !state.nativeFilter.available) {
            diagnostic = AXNDiagnosticFiltering; AXNCaptureFilterReport(state); return;
        }
        if (bundleID) state->index.select(std::string(bundleID.UTF8String));
        else state->index.select(std::nullopt);
        if (AXNReconcile(state)) {
            AXNRequestSelectionReveal(state);
        }
        AXNCaptureFilterReport(state); AXNRefresh();
    };
    objc_setAssociatedObject(owner, listMountKey, mount, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [rails addObject:mount.rail];
}
static void AXNMount(UIViewController *owner) {
    if (useListMount) return;
    [hostOwners addObject:owner];
    if (!enabled) return;
    AXNRailView *rail = objc_getAssociatedObject(owner, railKey);
    if (rail) { AXNRefresh(); return; }
    Ivar ivar = class_getInstanceVariable(owner.class, "_stackView");
    if (!ivar || *AXNUnqualified(ivar_getTypeEncoding(ivar)) != '@') { mountFailed = true; return; }
    id container = object_getIvar(owner, ivar);
    if (![container isKindOfClass:UIStackView.class]) { mountFailed = true; return; }
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
    mountSucceeded = true; mountFailed = false;
}

static void (*listDidAppearOriginal)(id, SEL, BOOL);
static void (*listWillAppearOriginal)(id, SEL, BOOL);
static void (*listDidLoadOriginal)(id, SEL);
static void (*listDidLayoutOriginal)(id, SEL);
static void (*listWillDisappearOriginal)(id, SEL, BOOL);
static void (*hostDidLoadOriginal)(id, SEL);
static void (*hostDidAppearOriginal)(id, SEL, BOOL);
static void (*hostDidLayoutOriginal)(id, SEL);
static void (*hostWillDisappearOriginal)(id, SEL, BOOL);
static BOOL (*hostHasContentOriginal)(id, SEL);
static void AXNListDidLoad(id self, SEL command) {
    listDidLoadOriginal(self, command); AXNAttachList(self);
}
static void AXNListWillAppear(id self, SEL command, BOOL animated) {
    listWillAppearOriginal(self, command, animated); AXNAttachList(self);
}
static void AXNListDidAppear(id self, SEL command, BOOL animated) {
    listDidAppearOriginal(self, command, animated); AXNAttachList(self);
}
static void AXNListDidLayout(id self, SEL command) {
    listDidLayoutOriginal(self, command);
    if (!useListMount || !enabled) return;
    AXNListState *state = objc_getAssociatedObject(self, stateKey);
    if (!state.ready || state != activeState) return;
    AXNListMount *oldMount = objc_getAssociatedObject(self, listMountKey);
    AXNMountList(self);
    AXNListMount *mount = objc_getAssociatedObject(self, listMountKey);
    if (mount != oldMount) AXNRefresh();
    else if (mount && ((UIViewController *)self).viewIfLoaded.window && state->index.size()) {
        mountSucceeded = [mount updateVisible:YES]; mountFailed = !mountSucceeded;
        mountDiagnostic = AXNDiagnosticGeometry;
        lastLayoutReport = AXNDescribeLayout(self, mount.scrollView, mount.rail);
    }
}
static void AXNListWillDisappear(id self, SEL command, BOOL animated) {
    AXNListState *state = objc_getAssociatedObject(self, stateKey);
    // Mark inactive before changing insets: synchronous layout must not remount
    // a selector while the controller is disappearing.
    if (activeState == state) activeState = nil;
    AXNListMount *mount = objc_getAssociatedObject(self, listMountKey);
    [mount updateVisible:NO];
    if (state) AXNRestore(state);
    AXNRefresh(); listWillDisappearOriginal(self, command, animated);
}
static void AXNHostDidLoad(id self, SEL command) { hostDidLoadOriginal(self, command); AXNMount(self); }
static void AXNHostDidAppear(id self, SEL command, BOOL animated) { hostDidAppearOriginal(self, command, animated); AXNMount(self); }
static void AXNHostDidLayout(id self, SEL command) {
    hostDidLayoutOriginal(self, command);
    if (!objc_getAssociatedObject(self, railKey)) AXNMount(self);
}
static void AXNHostWillDisappear(id self, SEL command, BOOL animated) {
    if (activeState) AXNRestore(activeState);
    AXNRefresh(); hostWillDisappearOriginal(self, command, animated);
}
static BOOL AXNHostHasContent(id self, SEL command) {
    [hostOwners addObject:self];
    AXNListState *state = activeState;
    return hostHasContentOriginal(self, command) || (enabled && state.ready && state->index.size() > 0);
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
        bool justEnabled = !enabled && nextEnabled;
        enabled = nextEnabled;
        if (justEnabled) {
            for (UIViewController *owner in listOwners.allObjects)
                if (owner.viewIfLoaded.window) AXNAttachList(owner);
            for (UIViewController *owner in hostOwners.allObjects)
                if (owner.isViewLoaded) AXNMount(owner);
        }
        AXNRefresh();
    });
}
__attribute__((constructor)) static void AXNInitialize(void) {
    @autoreleasepool {
        if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.springboard"]) return;
        // Register before compatibility checks so a rejected adapter can explain
        // itself. Reports contain bounded view metadata, never notification data.
        static int diagnosticToken;
        notify_register_dispatch(AXNDiagnosticQuery.UTF8String, &diagnosticToken, dispatch_get_main_queue(), ^(int token) {
            (void)token;
            AXNDiagnosticState result = diagnostic;
            if (hooksInstalled && !enabled) result = AXNDiagnosticDisabled;
            else if (diagnostic == AXNDiagnosticReady && (!mountSucceeded || mountFailed)) result = mountDiagnostic;
            AXNPublishDiagnosticReport(result, [NSString stringWithFormat:@"%@\n%@\n%@", lastFilterReport ?: @"No capsule selection captured yet.", lastModelReport ?: @"No settled selection model captured yet.", lastLayoutReport ?: @"No visible list layout captured yet."]);
            notify_post(AXNDiagnosticReply(result).UTF8String);
        });
        NSInteger major = NSProcessInfo.processInfo.operatingSystemVersion.majorVersion;
        if (major < 15 || major > 17) { diagnostic = AXNDiagnosticOS; return; }
        useListMount = major >= 17;
        Class list = NSClassFromString(@"NCNotificationStructuredListViewController");
        Class host = NSClassFromString(@"CSNotificationAdjunctListViewController");
        if (!list || ![list isSubclassOfClass:UIViewController.class] ||
            (!useListMount && (!host || ![host isSubclassOfClass:UIViewController.class]))) { diagnostic = AXNDiagnosticClasses; return; }
        const char *names[3] = {"insertNotificationRequest:", "removeNotificationRequest:", "modifyNotificationRequest:"};
        IMP voidCallbacks[3] = {(IMP)AXNInsertVoid, (IMP)AXNRemoveVoid, (IMP)AXNModifyVoid};
        IMP boolCallbacks[3] = {(IMP)AXNInsertBool, (IMP)AXNRemoveBool, (IMP)AXNModifyBool};
        for (int i = 0; i < 3; ++i) {
            hooks[i].selector = sel_registerName(names[i]);
            if (!AXNMethodMatches(list, hooks[i].selector, "vB", 3)) {
                diagnostic = AXNDiagnosticSignatures;
                NSLog(@"[Axon Reborn] Unknown notification method signature; leaving native notifications active."); return;
            }
            char type[16] = {};
            method_getReturnType(class_getInstanceMethod(list, hooks[i].selector), type, sizeof(type));
            hooks[i].result = *AXNUnqualified(type);
        }
        SEL predicate = NSSelectorFromString(@"notificationMasterList:shouldFilterNotificationRequest:");
        if (useListMount && AXNMethodMatches(list, predicate, "B", 4)) {
            MSHookMessageEx(list, predicate, (IMP)AXNShouldFilter, (IMP *)&nativeShouldFilterOriginal);
            nativeFilterHookInstalled = true;
        }
        states = [NSHashTable weakObjectsHashTable]; rails = [NSHashTable weakObjectsHashTable];
        listOwners = [NSHashTable weakObjectsHashTable]; hostOwners = [NSHashTable weakObjectsHashTable];
        AXNSynchronizePreferences(); enabled = [AXNReadPreference(@"Enabled", @NO) boolValue];
        for (int i = 0; i < 3; ++i) MSHookMessageEx(list, hooks[i].selector,
            hooks[i].result == 'v' ? voidCallbacks[i] : boolCallbacks[i], &hooks[i].original);
        MSHookMessageEx(list, @selector(viewDidAppear:), (IMP)AXNListDidAppear, (IMP *)&listDidAppearOriginal);
        MSHookMessageEx(list, @selector(viewDidLoad), (IMP)AXNListDidLoad, (IMP *)&listDidLoadOriginal);
        MSHookMessageEx(list, @selector(viewWillAppear:), (IMP)AXNListWillAppear, (IMP *)&listWillAppearOriginal);
        MSHookMessageEx(list, @selector(viewWillDisappear:), (IMP)AXNListWillDisappear, (IMP *)&listWillDisappearOriginal);
        MSHookMessageEx(list, @selector(viewDidLayoutSubviews), (IMP)AXNListDidLayout, (IMP *)&listDidLayoutOriginal);
        if (!useListMount) {
        MSHookMessageEx(host, @selector(viewDidLoad), (IMP)AXNHostDidLoad, (IMP *)&hostDidLoadOriginal);
        MSHookMessageEx(host, @selector(viewDidAppear:), (IMP)AXNHostDidAppear, (IMP *)&hostDidAppearOriginal);
        MSHookMessageEx(host, @selector(viewDidLayoutSubviews), (IMP)AXNHostDidLayout, (IMP *)&hostDidLayoutOriginal);
        MSHookMessageEx(host, @selector(viewWillDisappear:), (IMP)AXNHostWillDisappear, (IMP *)&hostWillDisappearOriginal);
        if (AXNMethodMatches(host, @selector(isPresentingContent), "B", 2))
            MSHookMessageEx(host, @selector(isPresentingContent), (IMP)AXNHostHasContent, (IMP *)&hostHasContentOriginal);
        }
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, AXNPreferenceCallback,
            (__bridge CFStringRef)AXNPreferencesChanged, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
        hooksInstalled = true;
    }
}
