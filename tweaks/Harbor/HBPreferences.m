#import "HBPreferences.h"
#import "HBVersion.h"

NSString *const HBPreferencesDomain = @"com.chasedavis.harbor";
NSString *const HBPreferencesChanged = @"com.chasedavis.harbor/preferences-changed";
static BOOL enabled = YES, haptics = YES;
static NSString *palette = @"sea";

static id HBRead(NSString *key) {
    return CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key,
                                                     (__bridge CFStringRef)HBPreferencesDomain));
}
void HBReloadPreferences(void) {
    CFPreferencesAppSynchronize((__bridge CFStringRef)HBPreferencesDomain);
    id e = HBRead(@"enabled"), h = HBRead(@"haptics"), p = HBRead(@"palette");
    enabled = [e isKindOfClass:NSNumber.class] ? [e boolValue] : YES;
    haptics = [h isKindOfClass:NSNumber.class] ? [h boolValue] : YES;
    palette = [p isKindOfClass:NSString.class] && [@[@"sea", @"ember", @"iris"] containsObject:p] ? [p copy] : @"sea";
}
BOOL HBEnabled(void) { return enabled; }
BOOL HBHapticsEnabled(void) { return haptics; }
NSString *HBPalette(void) { return palette; }
UIColor *HBAccentColor(void) {
    if ([palette isEqualToString:@"ember"]) return [UIColor colorWithRed:1 green:0.73 blue:0.46 alpha:1];
    if ([palette isEqualToString:@"iris"]) return [UIColor colorWithRed:0.76 green:0.72 blue:1 alpha:1];
    return [UIColor colorWithRed:0.64 green:0.91 blue:0.84 alpha:1];
}
void HBSetPreference(NSString *key, id value) {
    if (![@[@"enabled", @"haptics", @"palette"] containsObject:key]) return;
    CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)value,
                            (__bridge CFStringRef)HBPreferencesDomain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)HBPreferencesDomain);
    HBReloadPreferences();
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
        (__bridge CFStringRef)HBPreferencesChanged, NULL, NULL, true);
}
void HBReportRuntimeStatus(NSString *status) {
    // UI sessions and hook discovery run on the main queue. Only persist changes;
    // do not emit the user-preference notification and recursively relayout CC.
    static NSString *lastStatus;
    if ([lastStatus isEqualToString:status]) return;
    lastStatus = [status copy];
    NSDictionary *report = @{ @"message": status, @"version": @HARBOR_VERSION, @"date": NSDate.date };
    CFPreferencesSetAppValue(CFSTR("runtimeReport"), (__bridge CFPropertyListRef)report,
                            (__bridge CFStringRef)HBPreferencesDomain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)HBPreferencesDomain);
    NSLog(@"[Harbor %s] %@", HARBOR_VERSION, status);
}
NSString *HBRuntimeStatusSummary(void) {
    CFPreferencesAppSynchronize((__bridge CFStringRef)HBPreferencesDomain);
    id value = HBRead(@"runtimeReport");
    if (![value isKindOfClass:NSDictionary.class] ||
        ![value[@"message"] isKindOfClass:NSString.class] ||
        ![value[@"version"] isKindOfClass:NSString.class] ||
        ![value[@"date"] isKindOfClass:NSDate.class]) {
        return @"No report from SpringBoard. After installing this build, restart SpringBoard through Bootstrap. Check that SpringBoard injection is enabled; TrollStore alone cannot load Harbor.";
    }
    NSString *date = [NSDateFormatter localizedStringFromDate:value[@"date"]
        dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterMediumStyle];
    return [NSString stringWithFormat:@"Last report · %@ · Harbor %@\n%@\nRefresh after opening Control Center. This is the last recorded event, not a live connection check.",
        date, value[@"version"], value[@"message"]];
}
