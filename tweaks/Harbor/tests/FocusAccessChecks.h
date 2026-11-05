#import "HBProfileStore.h"
#import "HBProfileEditorController.h"
#import "FocusChecks.h"

@interface HBDashboardController (FocusAccessTest)
- (HBFocusMonitor *)createFocusMonitor;
- (void)refreshFocus;
- (void)reloadSelectedProfile:(BOOL)opening;
- (void)refreshStatus;
@end
@interface HBFocusGateDashboard : HBDashboardController
@property (nonatomic) NSUInteger monitorCreations;
@property (nonatomic, strong) HBTestFocusReader *testReader;
@end
@implementation HBFocusGateDashboard
- (HBFocusMonitor *)createFocusMonitor {
    self.monitorCreations++; self.testReader=[HBTestFocusReader new];
    return [[HBFocusMonitor alloc] initWithReader:self.testReader deadline:2 scheduler:^(NSTimeInterval delay,dispatch_block_t block) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(delay*NSEC_PER_SEC)),dispatch_get_main_queue(),block);
    }];
}
@end

static void HBRunFocusAccessChecks(UIWindow *window,void (^check)(BOOL,NSString *)) {
    NSDictionary *saved=HBLoadProfileLibrary(), *base=HBDefaultLibrary(@"sea"); HBSaveProfileLibrary(base,nil,nil);
    UIViewController *host=window.rootViewController;
    HBFocusGateDashboard *view=[HBFocusGateDashboard new]; [host addChildViewController:view];
    view.view.frame=host.view.bounds; [host.view addSubview:view.view]; [view didMoveToParentViewController:host]; [view setDashboardActive:YES];
    check(view.monitorCreations==0 && [view.focusSnapshot[@"disabled"] boolValue],@"Default-off dashboard creates no Focus monitor or reader");
    [view refreshFocus]; [view applyAppearance]; [view refreshStatus]; [view setDashboardActive:NO]; [view setDashboardActive:YES];
    check(view.monitorCreations==0,@"Refresh, appearance, status and reopening cannot bypass default-off access");
    NSMutableDictionary *work=HBNormalizeProfile(@{@"id":@"work",@"name":@"Work"}).mutableCopy;
    NSMutableDictionary *library=HBLibraryReplacingProfile(base,work).mutableCopy;
    library[@"automaticFocus"]=@YES; library[@"bindings"]=@{@"fixture.work":@"work"};
    HBSaveProfileLibrary(library,nil,nil); [view applyAppearance];
    check(view.monitorCreations==0 && !HBFocusAccessEnabled(HBLoadProfileLibrary()),@"A legacy enabled matching flag cannot start service access");
    library=HBLoadProfileLibrary().mutableCopy; library[@"activeID"]=@"work"; HBSaveProfileLibrary(library,nil,nil); [view reloadSelectedProfile:YES];
    check([view.profile[@"id"] isEqual:@"work"] && view.monitorCreations==0,@"Manual profile selection works without a Focus monitor");
    library[@"activeID"]=@"default"; library[@"automaticFocus"]=@YES; library[@"focusOptInVersion"]=@1;
    HBSaveProfileLibrary(library,nil,nil); [view reloadSelectedProfile:YES];
    check(view.monitorCreations==1 && view.testReader.states.count==1,@"Saved current opt-in starts exactly one initial Focus read");
    HBDeliver(view.testReader.states,0,HBTestFocus(@"fixture.work"));
    HBDeliver(view.testReader.registrations,0,@{@"liveUpdates":@YES});
    check([view.profile[@"id"] isEqual:@"work"] && view.testReader.states.count==2,@"An enabled read can select the linked profile and subscribe");
    UIButton *button=(id)HBFind(view.view,@"harbor.rotation"); button.highlighted=YES;
    library=HBLoadProfileLibrary().mutableCopy; library[@"automaticFocus"]=@NO; HBSaveProfileLibrary(library,nil,nil); [view applyAppearance];
    NSUInteger calls=view.testReader.states.count;
    check([view.focusSnapshot[@"disabled"] boolValue] && view.testReader.cancellations>0 && view.testReader.stops>0,@"Disabling cancels reads and removes listeners even while a control is held");
    [view refreshFocus]; HBFire(view.testReader.updates,0); HBDeliver(view.testReader.states,1,HBTestFocus(@"fixture.work"));
    check(view.testReader.states.count==calls && [view.focusSnapshot[@"disabled"] boolValue],@"Refresh and late state/listener callbacks cannot restart disabled access");
    button.highlighted=NO; [view refreshStatus];
    check([view.profile[@"id"] isEqual:@"default"] && [HBLoadProfileLibrary()[@"bindings"] count]==1,@"Disabled access returns to the manual default and preserves links");
    // The previous backup is enabled here. Recovery must not restore that consent.
    CFPreferencesSetAppValue(CFSTR("profileLibrary"),CFSTR("corrupt"),(__bridge CFStringRef)HBPreferencesDomain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)HBPreferencesDomain);
    NSDictionary *recovered=HBLoadProfileLibrary(); [view applyAppearance];
    check(!HBFocusAccessEnabled(recovered) && [recovered[@"profiles"] count]==2 && [recovered[@"bindings"] count]==1 && view.testReader.states.count==calls,@"Backup recovery restores profiles but cannot restore Focus access");
    check([HBFocusDiagnosticSummary(view.focusSnapshot) containsString:@"no new Focus reads"] && ![HBFocusDiagnosticSummary(view.focusSnapshot) containsString:@"Focus is off"],@"Disabled diagnostics do not pretend to know the system Focus state");
    [view setDashboardActive:NO]; [view willMoveToParentViewController:nil]; [view.view removeFromSuperview]; [view removeFromParentViewController];
    HBSaveProfileLibrary(saved,nil,nil);
}
