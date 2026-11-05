// Simulator-only audit harness. Replaces Harbor's own reader methods before UI
// creation. No DND framework call, native Focus setting or permission is used.
#define main HBGestureAuditMain
#import "GestureMain.m"
#undef main
#import "HBProfileStore.h"
#import <objc/runtime.h>

static NSUInteger stateReads, modeReads, registrations, removals, cancellations;
static void (^observerUpdate)(void);
static NSDictionary *AuditState(void) { return @{@"available":@YES,@"active":@YES,@"identifier":@"fixture.work",@"name":@"Simulated Work"}; }
static void AuditRead(id reader,SEL sel,void (^completion)(NSDictionary *)) { stateReads++; dispatch_async(dispatch_get_main_queue(), ^{ completion(AuditState()); }); }
static void AuditModes(id reader,SEL sel,void (^completion)(NSDictionary *)) { modeReads++; dispatch_async(dispatch_get_main_queue(), ^{ completion(@{@"modes":@[@{@"id":@"fixture.work",@"name":@"Simulated Work"}]}); }); }
static void AuditUpdates(id reader,SEL sel,void (^update)(void),void (^completion)(NSDictionary *)) { registrations++; observerUpdate=[update copy]; dispatch_async(dispatch_get_main_queue(), ^{ completion(@{@"liveUpdates":@YES}); }); }
static void AuditEnd(id reader,SEL sel) { removals++; observerUpdate=nil; }
static void AuditCancel(id reader,SEL sel) { cancellations++; }
static void AuditReplace(NSString *name,IMP implementation) {
    Method method=class_getInstanceMethod(NSClassFromString(@"HBDNDFocusReader"),NSSelectorFromString(name));
    if (method) method_setImplementation(method,implementation);
}

@interface HBFocusPrivacyHost : HBFixtureHost @end
@implementation HBFocusPrivacyHost
- (void)saveMetrics {
    [super saveMetrics]; if (!self.dashboard) return;
    id editor=[self.dashboard valueForKey:@"editor"];
    NSDictionary *report=@{@"scope":@"Actual UIKit and HID interactions with counted, replaced Harbor reader boundaries. All successful Focus values are simulated; no real Focus API is called.",
        @"library":HBLoadProfileLibrary(),@"displayedProfile":self.dashboard.profile ?: @{},@"focus":self.dashboard.focusSnapshot ?: @{},
        @"readerCalls":@{@"state":@(stateReads),@"modes":@(modeReads),@"registrations":@(registrations),@"removals":@(removals),@"cancellations":@(cancellations)},
        @"monitorCreated":@([self.dashboard valueForKey:@"focusMonitor"]!=nil),@"editing":@(editor!=nil),@"draft":editor ? [editor valueForKey:@"library"] : @{},@"pausedForEditor":[self.dashboard valueForKey:@"focusPausedForEditor"] ?: @NO};
    NSString *path=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"focus-privacy.json"];
    [[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:nil] writeToFile:path atomically:YES];
}
@end
@interface HBFocusPrivacyApp : HBFixtureApp @end
@implementation HBFocusPrivacyApp
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    AuditReplace(@"readState:",(IMP)AuditRead); AuditReplace(@"readModes:",(IMP)AuditModes); AuditReplace(@"beginUpdates:completion:",(IMP)AuditUpdates); AuditReplace(@"endUpdates",(IMP)AuditEnd); AuditReplace(@"cancelPendingReads",(IMP)AuditCancel);
    if ([NSProcessInfo.processInfo.arguments containsObject:@"--seed-legacy"]) {
        NSMutableDictionary *library=HBLibraryReplacingProfile(HBDefaultLibrary(@"sea"),HBNormalizeProfile(@{@"id":@"work",@"name":@"Work",@"theme":HBThemePresets()[@"iris"]})).mutableCopy;
        library[@"automaticFocus"]=@YES; [library removeObjectForKey:@"focusOptInVersion"]; library[@"bindings"]=@{@"fixture.work":@"work"}; library[@"focusLabels"]=@{@"fixture.work":@"Simulated Work"};
        CFPreferencesSetAppValue(CFSTR("profileLibrary"),(__bridge CFPropertyListRef)library,(__bridge CFStringRef)HBPreferencesDomain);
        CFPreferencesSetAppValue(CFSTR("profileBackup"),NULL,(__bridge CFStringRef)HBPreferencesDomain); CFPreferencesAppSynchronize((__bridge CFStringRef)HBPreferencesDomain);
    }
    self.window=[[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds]; self.window.rootViewController=[HBFocusPrivacyHost new]; [self.window makeKeyAndVisible]; return YES;
}
@end
int main(int argc,char *argv[]) { @autoreleasepool { return UIApplicationMain(argc,argv,nil,NSStringFromClass(HBFocusPrivacyApp.class)); } }
