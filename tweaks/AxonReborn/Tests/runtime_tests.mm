// SPDX-License-Identifier: GPL-3.0-only
// Runtime contract tests with a fake native controller, not SpringBoard emulation.
#define AXN_RUNTIME_TEST 1
#import "../Tweak/AXNRuntime.mm"
#include <cstdio>
#include <cstdlib>
static void Require(BOOL condition, const char *message) {
    if (!condition) { fprintf(stderr, "AXN_UI_TEST_FAIL: %s\n", message); fflush(stderr); exit(1); }
}
@interface TestRequest : NSObject
@property(nonatomic, copy) NSString *sectionIdentifier;
@property(nonatomic, copy) NSString *notificationIdentifier;
@property(nonatomic, strong) NSDate *timestamp;
@end
@implementation TestRequest @end
@interface TestSection : NSObject
@property(nonatomic, strong) NSMutableArray *allNotificationRequests;
@property(nonatomic, strong) NSDictionary *filteredNotificationRequests;
@property(nonatomic, strong) NSSet *hiddenNotificationRequests;
@end
@implementation TestSection @end
@interface TestRevealCoordinator : NSObject
@property(nonatomic) BOOL allowed;
@property(nonatomic) BOOL transitionAllowed;
@property(nonatomic, getter=isSectionRevealed) BOOL sectionRevealed;
@property(nonatomic, getter=isSectionRevealedStateLocked) BOOL sectionRevealedStateLocked;
@property(nonatomic) BOOL childRevealed;
@property(nonatomic) NSUInteger refetchCalls;
@end
@implementation TestRevealCoordinator
- (BOOL)_shouldAllowNotificationListReveal { return self.allowed; }
- (BOOL)_shouldAllowNotificationListRevealTransition { return self.transitionAllowed; }
- (void)_refetchSubListViews { ++self.refetchCalls; }
- (void)_performRevealForSubviewsIfNecessary { self.childRevealed = self.sectionRevealed; }
- (BOOL)isForceRevealed { return NO; }
- (NSArray *)subLists { return @[]; }
@end
static TestRevealCoordinator *Coordinator(void) {
    TestRevealCoordinator *coordinator = [TestRevealCoordinator new];
    coordinator.allowed = YES; coordinator.transitionAllowed = YES; return coordinator;
}
@interface TestMaster : NSObject
@property(nonatomic, strong) NSArray *notificationSections;
@property(nonatomic, strong) TestRevealCoordinator *revealCoordinator;
@end
@implementation TestMaster @end
@interface FilterOwner : UIViewController
@property(nonatomic, strong) TestMaster *masterList;
@property(nonatomic, strong) NSMutableSet *filteredApps;
@property(nonatomic, strong) NSMutableSet *nativeExcludedApps;
@property(nonatomic) NSUInteger insertCalls;
@property(nonatomic) NSUInteger removeCalls;
@property(nonatomic) NSUInteger toggleCalls;
@property(nonatomic) NSUInteger revealCalls;
@property(nonatomic, strong) NSMutableArray *operations;
@property(nonatomic) BOOL historyRevealed;
@property(nonatomic) BOOL failNextToggle;
@end
@implementation FilterOwner
- (void)toggleFilteringForSectionIdentifier:(NSString *)app shouldFilter:(BOOL)filter {
    ++self.toggleCalls;
    [self.operations addObject:[NSString stringWithFormat:@"%@:%d", app, filter]];
    if (filter) [self.filteredApps addObject:app]; else [self.filteredApps removeObject:app];
    if (self.failNextToggle) { self.failNextToggle = NO; [NSException raise:@"test" format:@"partial toggle failed"]; }
}
- (void)revealNotificationHistory:(BOOL)revealed animated:(BOOL)animated { (void)animated; ++self.revealCalls; self.historyRevealed = revealed; }
@end
static BOOL OriginalPolicy(id owner, SEL command, id master, id request) {
    (void)command; (void)master;
    return [((FilterOwner *)owner).nativeExcludedApps containsObject:((TestRequest *)request).sectionIdentifier];
}
static void OriginalInsert(id owner, SEL command, id request) {
    (void)command; FilterOwner *controller = owner; ++controller.insertCalls;
    [((TestSection *)controller.masterList.notificationSections.firstObject).allNotificationRequests addObject:request];
}
static void OriginalRemove(id owner, SEL command, id request) {
    (void)command; FilterOwner *controller = owner; ++controller.removeCalls;
    [((TestSection *)controller.masterList.notificationSections.firstObject).allNotificationRequests removeObject:request];
}
static void OriginalDisappear(id owner, SEL command, BOOL animated) { (void)owner; (void)command; (void)animated; }
static TestRequest *Request(NSString *app, NSString *identifier) {
    TestRequest *request = [TestRequest new]; request.sectionIdentifier = app;
    request.notificationIdentifier = identifier; request.timestamp = [NSDate date]; return request;
}
void AXNRunRuntimeTests(void (^completion)(void)) {
    enabled = true; useListMount = true; nativeFilterHookInstalled = true;
    nativeShouldFilterOriginal = OriginalPolicy;
    states = [NSHashTable weakObjectsHashTable]; rails = [NSHashTable weakObjectsHashTable];
    listOwners = [NSHashTable weakObjectsHashTable]; hostOwners = [NSHashTable weakObjectsHashTable];
    hooks[Insert] = {@selector(insertNotificationRequest:), (IMP)OriginalInsert, 'v'};
    hooks[Remove] = {@selector(removeNotificationRequest:), (IMP)OriginalRemove, 'v'};
    listWillDisappearOriginal = OriginalDisappear;
    FilterOwner *owner = [FilterOwner new]; owner.operations = [NSMutableArray new]; owner.filteredApps = [NSMutableSet new]; owner.nativeExcludedApps = [NSMutableSet new];
    TestSection *section = [TestSection new];
    TestRequest *a1 = Request(@"a", @"1"), *a2 = Request(@"a", @"2"), *b = Request(@"b", @"1");
    section.allNotificationRequests = [NSMutableArray arrayWithArray:@[a1, a2, b]];
    owner.masterList = [TestMaster new]; owner.masterList.notificationSections = @[section];
    owner.masterList.revealCoordinator = Coordinator();
    AXNAttachList(owner);
    AXNListState *state = objc_getAssociatedObject(owner, stateKey);
    Require(state.ready && state->index.size() == 3, "initial runtime snapshot failed");
    state->index.select(std::string("a"));
    Require(AXNReconcile(state) && [owner.filteredApps isEqualToSet:[NSSet setWithObject:@"b"]], "select A did not filter B");
    Require(owner.removeCalls == 0 && owner.insertCalls == 0, "selection mutated request lifecycle");
    Require([state.nativeFilter revealHistory] && owner.historyRevealed, "selection history reveal failed");
    Require(owner.masterList.revealCoordinator.childRevealed && owner.masterList.revealCoordinator.refetchCalls == 1, "child sections stayed collapsed after root history reveal");
    AXNAttachList(owner);
    Require(objc_getAssociatedObject(owner, stateKey) == state && state->index.selection() == std::optional<std::string>("a"), "repeated appearance reset selection");
    SEL predicate = NSSelectorFromString(@"notificationMasterList:shouldFilterNotificationRequest:");
    Require(AXNShouldFilter(owner, predicate, owner.masterList, b), "incoming nonselected app not filtered");
    Require(!AXNShouldFilter(owner, predicate, owner.masterList, a1), "selected app was filtered");
    [owner.nativeExcludedApps addObject:@"a"];
    Require(AXNShouldFilter(owner, predicate, owner.masterList, a1), "native exclusion was bypassed");
    [owner.nativeExcludedApps removeObject:@"a"];
    TestRequest *c = Request(@"c", @"1");
    Require(AXNHandle(owner, Insert, c) && owner.insertCalls == 1 && state->index.size() == 4, "hidden arrival skipped native insertion");
    Require([owner.filteredApps containsObject:@"c"], "new app did not acquire filter rule");
    Require(AXNHandle(owner, Remove, c) && owner.removeCalls == 1 && state->index.size() == 3, "hidden dismissal skipped native removal");
    [owner.operations removeAllObjects];
    state->index.select(std::string("b"));
    Require(AXNReconcile(state) && [owner.filteredApps isEqualToSet:[NSSet setWithObject:@"a"]], "switching app did not restore previous app");
    Require([owner.operations isEqualToArray:@[@"a:1", @"b:0"]], "selected app was restored before hiding other apps");
    section.filteredNotificationRequests = @{@"PRIVATE_APP_IDENTIFIER":@[b]};
    section.hiddenNotificationRequests = [NSSet setWithObject:a1];
    NSString *model = AXNModelReport(state);
    Require([model containsString:@"filtered[total=1 selected=1"] && [model containsString:@"hidden[total=1 selected=0"], "native cache report lost selected counts");
    Require(![model containsString:@"PRIVATE_APP_IDENTIFIER"], "native cache report leaked a dictionary key");
    Require(AXNRestore(state) && owner.filteredApps.count == 0 && section.allNotificationRequests.count == 3, "All failed to restore notifications");
    [owner.nativeExcludedApps addObject:@"b"]; [owner.filteredApps addObject:@"b"];
    state->index.select(std::string("a")); Require(AXNReconcile(state), "native-policy reconciliation failed");
    Require(state.nativeFilter.appliedCount == 0 && AXNRestore(state) && [owner.filteredApps containsObject:@"b"], "All removed a native filter");
    [owner.nativeExcludedApps removeObject:@"b"]; [owner.filteredApps removeObject:@"b"];
    state->index.select(std::string("a")); Require(AXNReconcile(state), "selection before disappearance failed");
    AXNListWillDisappear(owner, @selector(viewWillDisappear:), NO);
    Require(!activeState && owner.filteredApps.count == 0, "leaving list left Axon filters applied");
    Require(!owner.masterList.revealCoordinator.sectionRevealed && !owner.masterList.revealCoordinator.childRevealed, "leaving list did not restore section reveal state");
    AXNAttachList(owner); state = objc_getAssociatedObject(owner, stateKey);
    state->index.select(std::string("a")); owner.failNextToggle = YES;
    Require(!AXNReconcile(state) && !state.ready && owner.filteredApps.count == 0, "partial filter failure did not restore native list");
    AXNNativeFilter *unsupported = [[AXNNativeFilter alloc] initWithOwner:[NSObject new]];
    Require(!unsupported.available && ![unsupported revealHistory], "unsupported native signatures accepted");
    FilterOwner *policyOwner = [FilterOwner new]; policyOwner.masterList = [TestMaster new];
    TestRevealCoordinator *coordinator = Coordinator(); policyOwner.masterList.revealCoordinator = coordinator;
    AXNNativeFilter *policyFilter = [[AXNNativeFilter alloc] initWithOwner:policyOwner];
    coordinator.allowed = NO;
    Require(![policyFilter revealHistory] && policyOwner.revealCalls == 0 && coordinator.refetchCalls == 0, "native reveal policy bypassed");
    coordinator.allowed = YES; coordinator.transitionAllowed = NO;
    Require(![policyFilter revealHistory] && policyOwner.revealCalls == 0, "native transition policy bypassed");
    coordinator.transitionAllowed = YES; coordinator.sectionRevealedStateLocked = YES;
    Require(![policyFilter revealHistory] && policyOwner.revealCalls == 0, "native state lock bypassed");
    coordinator.sectionRevealedStateLocked = NO; coordinator.sectionRevealed = YES;
    Require([policyFilter revealHistory] && coordinator.childRevealed && [policyFilter restoreReveal] && coordinator.sectionRevealed, "pre-existing native reveal state was changed");
    coordinator.sectionRevealed = NO; coordinator.childRevealed = NO;
    Require([policyFilter revealHistory] && coordinator.childRevealed, "collapsed sections did not reveal");
    coordinator.allowed = NO;
    Require(![policyFilter revealHistory] && coordinator.childRevealed, "temporary reveal denial collapsed existing sections");
    coordinator.allowed = YES;
    TestRevealCoordinator *replacement = Coordinator(); policyOwner.masterList.revealCoordinator = replacement;
    Require([policyFilter revealHistory] && !coordinator.sectionRevealed && replacement.childRevealed, "coordinator replacement leaked old reveal state");
    Require([policyFilter restoreReveal] && !replacement.sectionRevealed, "reveal cleanup failed");
    policyOwner.masterList.revealCoordinator = nil;
    Require(![policyFilter revealHistory], "missing coordinator was accepted");
    // Exercise deferred reveal against rapid selection and leaving the list.
    state.ready = YES; activeState = state; state.selectionTaps = 1;
    NSUInteger priorReveals = owner.revealCalls;
    AXNRequestSelectionReveal(state);
    Require(owner.revealCalls == priorReveals, "history reveal ran inside the filter transaction");
    state.selectionTaps = 2;
    dispatch_async(dispatch_get_main_queue(), ^{
        Require(owner.revealCalls == priorReveals, "stale selection revealed history");
        AXNRequestSelectionReveal(state);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 600 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
            Require(owner.revealCalls == priorReveals + 1 && state.selectionSettled, "current selection failed to settle and reveal");
            ++state.selectionTaps; AXNRequestSelectionReveal(state); activeState = nil;
            dispatch_async(dispatch_get_main_queue(), ^{
                Require(owner.revealCalls == priorReveals + 1, "offscreen selection revealed history");
                enabled = false;
                puts("AXN_RUNTIME_TEST_PASS: filtering, hide-before-restore, deferred reveal, stale/offscreen cancellation, cache-count privacy, child reveal, native permission/lock guards, reveal restoration and rollback");
                completion();
            });
        });
    });
}
