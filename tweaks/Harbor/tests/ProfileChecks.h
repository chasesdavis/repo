#import "HBProfileStore.h"
#import "HBTheme.h"

@interface HBDashboardController (TestStatus)
- (void)refreshStatus;
@end

static void HBRunProfileChecks(UIWindow *window, void (^check)(BOOL, NSString *)) {
    NSDictionary *saved = HBLoadProfileLibrary(); NSError *error = nil;
    NSDictionary *base = HBDefaultLibrary(@"sea");
    check(HBSaveProfileLibrary(base,saved[@"revision"],&error), @"Profile library persists through CFPreferences");
    NSDictionary *first = HBLoadProfileLibrary();
    check(!HBSaveProfileLibrary(base,saved[@"revision"],&error) && error.code == 1 && [HBLoadProfileLibrary() isEqual:first], @"Stale editor cannot overwrite a newer saved revision");
    CFPreferencesSetAppValue(CFSTR("profileLibrary"), CFSTR("corrupt test value"), (__bridge CFStringRef)HBPreferencesDomain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)HBPreferencesDomain);
    check([HBLoadProfileLibrary() isEqual:saved], @"Corrupt stored library recovers the prior valid backup");
    NSDictionary *invalid = @{@"schema":@1,@"profiles":@[@{@"name":@"No ID"}]};
    CFPreferencesSetAppValue(CFSTR("profileLibrary"), (__bridge CFPropertyListRef)invalid, (__bridge CFStringRef)HBPreferencesDomain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)HBPreferencesDomain);
    check([HBLoadProfileLibrary() isEqual:saved], @"Library with no valid profile IDs also recovers the backup");
    HBSaveProfileLibrary(base,nil,nil);
    UIViewController *host = window.rootViewController;
    HBDashboardController *view = [HBDashboardController new]; view.previewMode = YES;
    [host addChildViewController:view]; [host.view addSubview:view.view]; [view didMoveToParentViewController:host];
    NSMutableDictionary *profile = [base[@"profiles"][0] mutableCopy];
    for (NSString *key in HBThemePresets()) {
        profile[@"theme"] = HBThemePresets()[key];
        for (NSNumber *width in @[@300,@393]) {
            view.view.frame = CGRectMake(0,0,width.doubleValue,568); [view applyProfile:profile expanded:YES]; [view.view layoutIfNeeded];
            UIScrollView *scroll = [view valueForKey:@"scroll"]; [scroll setContentOffset:CGPointMake(0,MAX(0,scroll.contentSize.height-scroll.bounds.size.height))];
            UIView *last = HBFind(view.view,@"harbor.display"), *escape = HBFind(view.view,@"harbor.allControls");
            check(!HBHasAmbiguity(view.view) && last && CGRectContainsRect(scroll.bounds,[last convertRect:last.bounds toView:scroll]) && CGRectContainsRect(view.view.bounds,[escape convertRect:escape.bounds toView:view.view]), [NSString stringWithFormat:@"%@ theme preserves final control and recovery at %@pt",key,width]);
        }
    }
    for (NSString *only in HBSectionKeys()) {
        NSMutableArray *hidden = HBSectionKeys().mutableCopy; [hidden removeObject:only];
        profile[@"layouts"] = @{@"compact":@{@"order":HBSectionKeys(),@"hidden":hidden}, @"expanded":@{@"order":HBSectionKeys(),@"hidden":@[]}};
        [view applyProfile:profile expanded:NO]; [view.view layoutIfNeeded];
        check(((UIStackView *)[view valueForKey:@"stack"]).arrangedSubviews.count == 1 && !HBHasAmbiguity(view.view) && HBFind(view.view,@"harbor.allControls"),[NSString stringWithFormat:@"%@ alone remains usable with native escape",only]);
    }
    profile[@"theme"] = @{@"surface":@"#FFFFFF",@"accent":@"#000000",@"opacity":@0.55};
    [view applyProfile:profile expanded:YES]; UIColor *ink = [view valueForKey:@"ink"]; CGFloat alpha = CGColorGetAlpha(((UIView *)[view valueForKey:@"sheet"]).backgroundColor.CGColor);
    check([ink isEqual:UIColor.blackColor] && alpha == 1, @"Light custom surface uses opaque background and black text");
    [view setDashboardActive:YES];
    check([view valueForKey:@"clock"] == nil && [view valueForKey:@"media"] == nil && [view valueForKey:@"focusMonitor"] == nil, @"Preview never starts media, polling, or Focus services");
    NSMutableDictionary *work = [base[@"profiles"][0] mutableCopy]; work[@"id"]=@"work"; work[@"name"]=@"Work"; work[@"theme"]=HBThemePresets()[@"iris"];
    NSMutableDictionary *library = HBLibraryReplacingProfile(base,work).mutableCopy; library[@"automaticFocus"]=@YES; library[@"focusOptInVersion"]=@1; library[@"bindings"]=@{@"fixture.exact.work":@"work"};
    HBSaveProfileLibrary(library,nil,nil);
    [view willMoveToParentViewController:nil]; [view.view removeFromSuperview]; [view removeFromParentViewController];
    HBDashboardController *live = [HBFocusGateDashboard new]; [host addChildViewController:live]; live.view.frame = host.view.bounds; [host.view addSubview:live.view]; [live didMoveToParentViewController:host]; [live setDashboardActive:YES];
    NSDictionary *focus = @{@"available":@YES,@"active":@YES,@"identifier":@"fixture.exact.work",@"modes":@[],@"status":@"Simulated Work"};
    UIButton *button = (id)HBFind(live.view,@"harbor.rotation"); button.highlighted=YES; [live acceptFocusSnapshot:focus];
    check([live.profile[@"id"] isEqual:@"default"] && [[live valueForKey:@"pendingProfile"] boolValue], @"Focus change defers while a control is held");
    button.highlighted=NO; [live refreshStatus];
    check([live.profile[@"id"] isEqual:@"work"], @"Deferred Focus profile applies when interaction ends");
    [live acceptFocusSnapshot:@{@"available":@NO,@"active":@YES,@"identifier":@"fixture.exact.work"}];
    check([live.profile[@"id"] isEqual:@"default"], @"Unavailable Focus immediately recovers the chosen default");
    [live setDashboardActive:NO];
    check([live valueForKey:@"clock"] == nil, @"Closing Harbor stops polling with profile support enabled");
    [live willMoveToParentViewController:nil]; [live.view removeFromSuperview]; [live removeFromParentViewController];
    HBSaveProfileLibrary(saved,nil,nil);
}
