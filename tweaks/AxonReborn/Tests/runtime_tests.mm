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
@property(nonatomic, copy) NSMutableArray *(^snapshotProvider)(void);
@property(nonatomic, strong) NSDictionary *filteredNotificationRequests;
@property(nonatomic, strong) NSSet *hiddenNotificationRequests;
@property(nonatomic, strong) NSArray *chronologicalSectionLists;
@end
@implementation TestSection
@synthesize allNotificationRequests = _allNotificationRequests;
- (NSMutableArray *)allNotificationRequests { return self.snapshotProvider ? self.snapshotProvider() : _allNotificationRequests; }
@end
@interface TestFocusView : NSObject
@property(nonatomic, getter=isGrouped) BOOL grouped;
@end
@implementation TestFocusView @end
@interface TestFocusSection : TestSection
@property(nonatomic, strong) TestFocusView *sectionListView;
@property(nonatomic) BOOL authenticationAllowed;
@property(nonatomic) NSUInteger expandCalls;
@end
@implementation TestFocusSection
- (void)_expandSection {
    ++self.expandCalls;
    if (self.authenticationAllowed) self.sectionListView.grouped = NO;
}
@end
@interface TestRevealCoordinator : NSObject
@property(nonatomic) BOOL allowed;
@property(nonatomic) BOOL transitionAllowed;
@property(nonatomic, getter=isSectionRevealed) BOOL sectionRevealed;
@property(nonatomic, getter=isSectionRevealedStateLocked) BOOL sectionRevealedStateLocked;
@property(nonatomic) BOOL childRevealed;
@property(nonatomic) NSUInteger refetchCalls;
@property(nonatomic) NSUInteger revealWrites;
@property(nonatomic) int revealState;
@property(nonatomic) double revealPercentage;
@property(nonatomic) BOOL emptySublists;
@end
@implementation TestRevealCoordinator
@synthesize sectionRevealed = _sectionRevealed;
- (void)setSectionRevealed:(BOOL)value { ++self.revealWrites; _sectionRevealed = value; }
- (BOOL)_shouldAllowNotificationListReveal { return self.allowed; }
- (BOOL)_shouldAllowNotificationListRevealTransition { return self.transitionAllowed; }
- (void)_refetchSubListViews { ++self.refetchCalls; }
- (void)_performRevealForSubviewsIfNecessary { self.childRevealed = self.revealState != 0 && self.revealPercentage >= 1.0; }
- (BOOL)_isRevealed { return self.revealState == 2; }
- (BOOL)isForceRevealed { return NO; }
- (NSArray *)subLists { return self.emptySublists ? @[] : @[[NSObject new]]; }
@end
static TestRevealCoordinator *Coordinator(void) {
    TestRevealCoordinator *coordinator = [TestRevealCoordinator new];
    coordinator.allowed = YES; coordinator.transitionAllowed = YES; return coordinator;
}
@interface TestMaster : NSObject
@property(nonatomic, strong) NSArray *notificationSections;
@property(nonatomic, strong) TestRevealCoordinator *revealCoordinator;
@property(nonatomic) BOOL historyRevealed;
@property(nonatomic, getter=isMissedSectionActive) BOOL missedSectionActive;
@property(nonatomic, strong) TestFocusSection *upcomingMissedSectionList;
@end
@implementation TestMaster
// Model the observed distinction: programmatic reveal sets state/percentage
// and the interaction lock, but does not set the gesture's sectionRevealed bit.
- (void)requestHistory:(BOOL)revealed {
    if (self.historyRevealed == revealed && revealed) return;
    self.historyRevealed = revealed;
    self.revealCoordinator.revealState = revealed ? 2 : 0;
    self.revealCoordinator.revealPercentage = revealed ? 1.0 : 0.0;
    self.revealCoordinator.sectionRevealedStateLocked = revealed;
    [self.revealCoordinator _performRevealForSubviewsIfNecessary];
}
@end
@interface ReportList : UIScrollView
@property(nonatomic) CGRect visibleRect;
@property(nonatomic, strong) NSDictionary *visibleViews;
@end
@implementation ReportList @end
@interface WrongRectList : UIScrollView @end
@implementation WrongRectList
- (id)visibleRect { return @"PRIVATE_VALUE"; }
@end
@interface FilterOwner : UIViewController
@property(nonatomic, strong) TestMaster *masterList;
@property(nonatomic, strong) NSMutableSet *filteredApps;
@property(nonatomic, strong) NSMutableSet *nativeExcludedApps;
@property(nonatomic) NSUInteger insertCalls;
@property(nonatomic) NSUInteger removeCalls;
@property(nonatomic) NSUInteger toggleCalls;
@property(nonatomic) NSUInteger revealCalls;
@property(nonatomic) NSUInteger aboveHistoryCount;
@property(nonatomic, strong) NSMutableArray *operations;
@property(nonatomic) BOOL historyRevealed;
@property(nonatomic) BOOL failNextToggle;
@property(nonatomic, copy) void (^revealEffect)(void);
@property(nonatomic, strong) NSArray *clearRequests;
@property(nonatomic) BOOL clearUnavailable;
@property(nonatomic) BOOL throwOnClear;
@end
@implementation FilterOwner
- (id)delegate { return self.clearUnavailable ? nil : self; }
- (void)notificationStructuredListViewController:(id)owner requestsClearingNotificationRequests:(NSArray *)requests {
    (void)owner; self.clearRequests = requests;
}
- (void)notificationListBaseComponent:(id)component requestsClearingPresentables:(NSArray *)requests {
    (void)component;
    if (self.throwOnClear) [NSException raise:@"test" format:@"native clear refused"];
    [self notificationStructuredListViewController:self requestsClearingNotificationRequests:requests];
}
- (NSUInteger)visibleNotificationCount { return self.aboveHistoryCount; }
- (void)toggleFilteringForSectionIdentifier:(NSString *)app shouldFilter:(BOOL)filter {
    ++self.toggleCalls;
    [self.operations addObject:[NSString stringWithFormat:@"%@:%d", app, filter]];
    if (filter) [self.filteredApps addObject:app]; else [self.filteredApps removeObject:app];
    if (self.failNextToggle) { self.failNextToggle = NO; [NSException raise:@"test" format:@"partial toggle failed"]; }
}
- (void)revealNotificationHistory:(BOOL)revealed animated:(BOOL)animated {
    (void)animated; ++self.revealCalls; self.historyRevealed = revealed;
    [self.masterList requestHistory:revealed];
    if (self.revealEffect) self.revealEffect();
}
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
static void RunClearTests(void) {
    FilterOwner *owner = [FilterOwner new];
    owner.operations = [NSMutableArray new]; owner.filteredApps = [NSMutableSet new]; owner.nativeExcludedApps = [NSMutableSet new];
    owner.masterList = [TestMaster new]; owner.masterList.revealCoordinator = Coordinator();
    TestRequest *a = Request(@"a", @"1"), *b = Request(@"b", @"1"), *c = Request(@"c", @"1");
    TestSection *section = [TestSection new]; section.allNotificationRequests = [NSMutableArray arrayWithArray:@[a, b, c]];
    owner.masterList.notificationSections = @[section]; AXNAttachList(owner);
    AXNListState *state = objc_getAssociatedObject(owner, stateKey);
    state->index.select(std::string("c")); Require(AXNReconcile(state), "clear fixture filter failed");
    NSArray *snapshot = AXNClearSnapshotForApp(state, @"c");
    Require(snapshot.count == 1 && snapshot.firstObject == c, "clear snapshot crossed apps");
    Require(AXNClearSnapshot(state, @"c", snapshot, @[@"b", @"a"]) && state->index.size() == 3 &&
        owner.clearRequests.count == 1 && owner.clearRequests.firstObject == c,
        "clear did not dispatch exact native requests or optimistically removed counts");
    Require(AXNHandle(owner, Remove, c) && state->index.selection() == std::optional<std::string>("b"),
        "clearing final app selected All instead of previous neighbor");
    Require(![owner.filteredApps containsObject:@"b"], "clear neighbor remained filtered");
    AXNHandle(owner, Insert, c);
    Require(AXNClearSnapshot(state, @"b", @[b], @[@"c", @"a"]), "middle clear failed");
    AXNHandle(owner, Remove, b);
    Require(state->index.selection() == std::optional<std::string>("c"), "middle clear did not select right neighbor");
    snapshot = AXNClearSnapshotForApp(state, @"c");
    TestRequest *newArrival = Request(@"c", @"2"); AXNHandle(owner, Insert, newArrival);
    Require(AXNClearSnapshot(state, @"c", @[c, c, a], @[@"a"]) && owner.clearRequests.count == 1 &&
        owner.clearRequests.firstObject == c, "clear included another app, duplicate or post-confirmation arrival");
    TestRequest *replacement = Request(@"c", @"1"); state.requests[@[@"c", @"1"]] = replacement;
    Require(!AXNClearSnapshot(state, @"c", snapshot, @[@"a"]), "stale request identity cleared a replacement");
    state.requests[@[@"c", @"1"]] = c;
    AXNHandle(owner, Remove, c);
    Require(state->index.selection() == std::optional<std::string>("c") && state->index.contains({"c", "2"}),
        "new arrival was removed or clear moved away from a surviving capsule");
    owner.clearUnavailable = YES;
    Require(!AXNClearSnapshot(state, @"c", @[newArrival], @[@"a"]), "unsupported clear route accepted");
    owner.clearUnavailable = NO; owner.throwOnClear = YES;
    Require(!AXNClearSnapshot(state, @"c", @[newArrival], @[@"a"]) && !state.clearingSelectedApp,
        "native clear failure left a pending selection");
    owner.throwOnClear = NO;
    Require(AXNClearSnapshot(state, @"a", @[a], @[@"c"]), "unselected clear failed");
    AXNHandle(owner, Remove, a);
    Require(state->index.selection() == std::optional<std::string>("c"), "unselected clear changed selection");
    Require(AXNClearSnapshot(state, @"c", @[newArrival], @[]), "last clear failed");
    AXNHandle(owner, Remove, newArrival);
    Require(state->index.size() == 0 && !state->index.selection(), "last clear failed empty fallback");
    AXNHandle(owner, Insert, c); state->index.select(std::string("c"));
    Require(AXNClearSnapshot(state, @"c", @[c], @[]), "new neighbor fixture clear failed");
    AXNHandle(owner, Insert, a); AXNHandle(owner, Remove, c);
    Require(state->index.selection() == std::optional<std::string>("a"), "newly arriving neighbor fell back to All");
    AXNHandle(owner, Insert, c);
    Require(AXNClearSnapshot(state, @"a", @[a], @[@"c"]), "explicit selection fixture clear failed");
    AXNSelectApp(state, nil); AXNHandle(owner, Remove, a);
    Require(!state->index.selection(), "clear completion overrode user's later selection");
    activeState = nil;
    Require(!AXNClearSnapshot(state, @"c", snapshot, @[]), "stale controller cleared requests");
    puts("AXN_CLEAR_TEST_PASS: exact app snapshot, new arrivals, stale identity, native failure, neighbors and empty fallback");
}
void AXNRunRuntimeTests(void (^completion)(void)) {
    enabled = true; useListMount = true; nativeFilterHookInstalled = true;
    nativeShouldFilterOriginal = OriginalPolicy;
    states = [NSHashTable weakObjectsHashTable]; rails = [NSHashTable weakObjectsHashTable];
    listOwners = [NSHashTable weakObjectsHashTable]; hostOwners = [NSHashTable weakObjectsHashTable];
    hooks[Insert] = {@selector(insertNotificationRequest:), (IMP)OriginalInsert, 'v'};
    hooks[Remove] = {@selector(removeNotificationRequest:), (IMP)OriginalRemove, 'v'};
    listWillDisappearOriginal = OriginalDisappear;
    RunClearTests();
    // Handoff and mount-loss must not strand the previous selection's rules.
    FilterOwner *firstOwner = [FilterOwner new], *secondOwner = [FilterOwner new];
    for (FilterOwner *candidate in @[firstOwner, secondOwner]) {
        candidate.operations = [NSMutableArray new]; candidate.filteredApps = [NSMutableSet new];
        candidate.nativeExcludedApps = [NSMutableSet new]; candidate.masterList = [TestMaster new];
        candidate.masterList.revealCoordinator = Coordinator();
        TestSection *fixture = [TestSection new];
        fixture.allNotificationRequests = [NSMutableArray arrayWithArray:@[Request(@"a", @"1"), Request(@"b", @"1")]];
        candidate.masterList.notificationSections = @[fixture];
    }
    AXNAttachList(firstOwner);
    AXNListState *firstState = objc_getAssociatedObject(firstOwner, stateKey);
    firstState->index.select(std::string("a")); Require(AXNReconcile(firstState), "handoff fixture failed");
    TestSection *handoffSection = secondOwner.masterList.notificationSections.firstObject;
    NSMutableArray *fullSnapshot = handoffSection.allNotificationRequests;
    handoffSection.snapshotProvider = ^NSMutableArray *{
        return firstOwner.filteredApps.count ? [NSMutableArray arrayWithObject:fullSnapshot.firstObject] : fullSnapshot;
    };
    AXNAttachList(secondOwner);
    handoffSection.snapshotProvider = nil;
    Require(!firstState->index.selection() && firstOwner.filteredApps.count == 0,
        "controller handoff left old app rules active");
    AXNListState *secondState = objc_getAssociatedObject(secondOwner, stateKey);
    Require(secondState->index.size() == 2, "handoff snapshot inherited the previous app filter");
    secondState->index.select(std::string("b")); Require(AXNReconcile(secondState), "missing-mount fixture failed");
    UIViewController *root = UIApplication.sharedApplication.windows.firstObject.rootViewController;
    [root addChildViewController:secondOwner]; secondOwner.view.frame = root.view.bounds;
    [root.view addSubview:secondOwner.view]; [secondOwner didMoveToParentViewController:root];
    AXNMountList(secondOwner);
    Require(secondState->index.selection() == std::nullopt && secondOwner.filteredApps.count == 0,
        "unresolvable selector left notifications filtered");
    [secondOwner willMoveToParentViewController:nil]; [secondOwner.view removeFromSuperview];
    [secondOwner removeFromParentViewController];
    FilterOwner *oversized = [FilterOwner new]; oversized.masterList = [TestMaster new];
    TestSection *oversizedSection = [TestSection new]; oversizedSection.allNotificationRequests = [NSMutableArray new];
    TestRequest *same = Request(@"a", @"large");
    for (NSUInteger i = 0; i < 8193; ++i) [oversizedSection.allNotificationRequests addObject:same];
    oversized.masterList.notificationSections = @[oversizedSection];
    Require(AXNSnapshot(oversized) == nil, "oversized snapshot accepted");
    activeState = nil;
    FilterOwner *owner = [FilterOwner new]; owner.operations = [NSMutableArray new]; owner.filteredApps = [NSMutableSet new]; owner.nativeExcludedApps = [NSMutableSet new];
    TestSection *section = [TestSection new];
    TestRequest *a1 = Request(@"a", @"1"), *a2 = Request(@"a", @"2"), *b = Request(@"b", @"1");
    section.allNotificationRequests = [NSMutableArray arrayWithArray:@[a1, a2, b]];
    owner.masterList = [TestMaster new]; owner.masterList.notificationSections = @[section];
    owner.masterList.revealCoordinator = Coordinator();
    AXNAttachList(owner);
    AXNListState *state = objc_getAssociatedObject(owner, stateKey);
    Require(state.ready && state->index.size() == 3, "initial runtime snapshot failed");
    AXNSelectApp(state, @"a");
    Require(state->index.selection() == std::optional<std::string>("a"), "capsule selection failed");
    AXNSelectApp(state, @"a");
    Require(!state->index.selection(), "repeat capsule tap did not return to All");
    state->index.select(std::string("a"));
    Require(AXNReconcile(state) && [owner.filteredApps isEqualToSet:[NSSet setWithObject:@"b"]], "select A did not filter B");
    Require(owner.removeCalls == 0 && owner.insertCalls == 0, "selection mutated request lifecycle");
    Require([state.nativeFilter revealHistory] && owner.historyRevealed, "selection history reveal failed");
    TestFocusSection *focus = [TestFocusSection new]; focus.sectionListView = [TestFocusView new];
    focus.sectionListView.grouped = YES; focus.allNotificationRequests = [NSMutableArray arrayWithObject:a1];
    owner.masterList.upcomingMissedSectionList = focus;
    [state.nativeFilter revealFocusForApp:@"a"];
    Require(focus.expandCalls == 0, "inactive Focus was expanded");
    owner.masterList.missedSectionActive = YES;
    [state.nativeFilter revealFocusForApp:@"b"];
    [state.nativeFilter revealFocusForApp:nil];
    Require(focus.expandCalls == 0, "Focus expanded without an explicit matching app");
    [state.nativeFilter revealFocusForApp:@"a"];
    Require(focus.expandCalls == 1 && focus.sectionListView.grouped && owner.masterList.missedSectionActive,
        "Focus reveal bypassed native authentication or disabled Focus");
    focus.authenticationAllowed = YES;
    [state.nativeFilter revealFocusForApp:@"a"];
    Require(focus.expandCalls == 2 && !focus.sectionListView.grouped && owner.masterList.missedSectionActive,
        "authorized Focus section did not expand through native action");
    [state.nativeFilter revealFocusForApp:@"a"];
    Require(focus.expandCalls == 2, "already expanded Focus section was expanded again");
    owner.masterList.missedSectionActive = NO;
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
    TestSection *chronological = [TestSection new]; chronological.allNotificationRequests = [NSMutableArray arrayWithObject:b];
    section.chronologicalSectionLists = @[chronological];
    Require([AXNModelReport(state) containsString:@"section 2 TestSection"], "chronological history sections missing from report");
    ReportList *reportList = [ReportList new]; reportList.visibleRect = CGRectMake(1, 2, 300, 400);
    reportList.visibleViews = @{@"PRIVATE_VIEW_KEY":@"PRIVATE_CARD_TEXT"};
    NSString *viewReport = AXNListPresentation(reportList);
    Require([viewReport containsString:@"visibleRect=(1,2,300,400)"] && [viewReport containsString:@"cachedChildViews=1"] && ![viewReport containsString:@"PRIVATE"], "view report lost geometry or leaked content");
    Require([AXNVisibleRect([WrongRectList new]) isEqual:@"unavailable"], "wrong rectangle getter signature accepted");
    UIScrollView *viewport = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, 375, 812)];
    viewport.bounds = CGRectMake(0, -302, 375, 812);
    reportList.frame = CGRectMake(10, 700, 300, 80); [viewport addSubview:reportList];
    Require([AXNListPresentation(reportList, viewport) containsString:@"intersectsViewport=0"], "offscreen native list reported in viewport");
    reportList.frame = CGRectMake(10, 0, 300, 80);
    Require([AXNListPresentation(reportList, viewport) containsString:@"intersectsViewport=1"], "onscreen native list reported outside viewport");
    Require(AXNRestore(state) && owner.filteredApps.count == 0 && section.allNotificationRequests.count == 3, "All failed to restore notifications");
    [owner.nativeExcludedApps addObject:@"b"]; [owner.filteredApps addObject:@"b"];
    state->index.select(std::string("a")); Require(AXNReconcile(state), "native-policy reconciliation failed");
    Require(state.nativeFilter.appliedCount == 0 && AXNRestore(state) && [owner.filteredApps containsObject:@"b"], "All removed a native filter");
    [owner.nativeExcludedApps removeObject:@"b"]; [owner.filteredApps removeObject:@"b"];
    state->index.select(std::string("a")); Require(AXNReconcile(state), "selection before disappearance failed");
    state.selectionTaps = 1;
    AXNListWillDisappear(owner, @selector(viewWillDisappear:), NO);
    Require([lastModelReport containsString:@"Sample: before-disappearance"] && [lastFilterReport containsString:@"appSelected=1"], "final presentation was not sampled before filter cleanup");
    Require(!activeState && owner.filteredApps.count == 0, "leaving list left Axon filters applied");
    Require(owner.masterList.revealCoordinator.revealWrites == 0 && owner.masterList.revealCoordinator.childRevealed, "filter cleanup changed native presentation state");
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
    Require([policyFilter revealHistory] && [policyFilter.revealStatus isEqual:@"native-no-history"] && policyOwner.revealCalls == 0, "incoming-only selection treated as reveal failure");
    coordinator.transitionAllowed = YES;
    Require([policyFilter revealHistory] && coordinator.childRevealed, "native programmatic reveal failed");
    Require(coordinator.sectionRevealedStateLocked && !coordinator.sectionRevealed && coordinator.revealWrites == 0, "programmatic state was confused with gesture bookkeeping");
    coordinator.childRevealed = NO;
    Require([policyFilter revealHistory] && coordinator.childRevealed && [policyFilter.revealStatus isEqual:@"native-reveal-refreshed"], "locked programmatic state incorrectly rejected or new child views not refreshed");
    NSString *coordinatorReport = AXNModelReport(state);
    Require([coordinatorReport containsString:@"actualRevealed=1 revealState=2 revealPercentage=1.00 gestureSectionRevealed=0"], "report did not distinguish actual state from gesture flag");
    state.ready = YES; state.selectionTaps = 1;
    state.selectionSettled = YES; state.revealedSelection = YES;
    state.nativeCountAvailable = YES; state.nativeAboveHistoryCount = 0;
    AXNCapturePresentation(state, @"test");
    Require(diagnostic == AXNDiagnosticReady, "zero incoming count was treated as missing history cards");
    state.revealedSelection = NO; owner.aboveHistoryCount = 1;
    AXNCapturePresentation(state, @"test");
    Require(diagnostic == AXNDiagnosticReveal, "failed history request reported ready");
    state.selectionSettled = NO; owner.aboveHistoryCount = 0;
    coordinator.allowed = NO;
    NSUInteger calls = policyOwner.revealCalls;
    Require(![policyFilter revealHistory] && policyOwner.revealCalls == calls && coordinator.childRevealed, "temporary native denial mutated existing presentation");
    coordinator.allowed = YES;
    // A stale root history flag can make the normal request a no-op. Report
    // that condition; never manufacture a state or change authentication.
    coordinator.revealState = 0; coordinator.revealPercentage = 0; coordinator.childRevealed = NO;
    Require(![policyFilter revealHistory] && [policyFilter.revealStatus isEqual:@"native-request-pending"] && !coordinator.childRevealed, "uncompleted native request was reported as revealed");
    policyOwner.masterList.historyRevealed = NO;
    Require([policyFilter revealHistory], "native history reset did not recover");
    coordinator.emptySublists = YES;
    Require(![policyFilter revealHistory] && [policyFilter.revealStatus isEqual:@"native-no-sublists"], "empty native sublists were accepted");
    coordinator.emptySublists = NO;
    policyOwner.revealEffect = ^{ coordinator.allowed = NO; };
    calls = coordinator.refetchCalls;
    Require(![policyFilter revealHistory] && coordinator.refetchCalls == calls, "changed native policy was ignored after request");
    policyOwner.revealEffect = nil; coordinator.allowed = YES;
    TestMaster *policyMaster = policyOwner.masterList;
    policyOwner.revealEffect = ^{ policyMaster.revealCoordinator = Coordinator(); };
    Require(![policyFilter revealHistory] && [policyFilter.revealStatus isEqual:@"native-coordinator-changed"], "request used a replaced coordinator");
    policyOwner.revealEffect = nil;
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
            NSString *selectionSample = lastSelectionReport;
            Require([selectionSample containsString:@"actualRevealed=1"], "settled reveal sample missing");
            AXNCapturePresentation(state, @"before-disappearance");
            Require([lastSelectionReport isEqual:selectionSample], "final sample overwrote selection sample");
            ++state.selectionTaps; AXNRequestSelectionReveal(state); activeState = nil;
            dispatch_async(dispatch_get_main_queue(), ^{
                Require(owner.revealCalls == priorReveals + 1, "offscreen selection revealed history");
                enabled = false;
                puts("AXN_RUNTIME_TEST_PASS: controller handoff, missing mount restoration, snapshot bound; Focus expansion with native authentication preserved; tap-again reset; filtering, native programmatic reveal independent of gesture flags, incoming-only selection, native policy and identity checks, accurate reveal diagnostics, report privacy, restore and rollback");
                completion();
            });
        });
    });
}

