#import "HBPreferences.h"

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
