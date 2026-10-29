#import "LumenPrefs.h"
#import <notify.h>

extern uint32_t notify_post(const char *name) __attribute__((weak_import));

NSString *const LumenDomain = @"com.chasedavis.lumen";
NSString *const LumenPrefsChangedNotification = @"com.chasedavis.lumen/prefschanged";

static NSArray<NSString *> *LumenAllPills(void) {
    static NSArray<NSString *> *pills;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        pills = @[ @"time", @"date", @"battery", @"playing", @"event",
                   @"alarm", @"weather", @"network", @"storage", @"unlocks",
                   @"cpu", @"uptime", @"data", @"volume", @"brightness",
                   @"countdown", @"message" ];
    });
    return pills;
}

static id LumenPref(NSString *key) {
    CFPropertyListRef value = CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)LumenDomain);
    return value ? (__bridge_transfer id)value : nil;
}

static BOOL LumenBoolPref(NSString *key, BOOL fallback) {
    id value = LumenPref(key);
    return [value isKindOfClass:[NSNumber class]] ? [value boolValue] : fallback;
}

void LumenSetPref(NSString *key, id value) {
    CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)value, (__bridge CFStringRef)LumenDomain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)LumenDomain);
}

void LumenReloadPrefs(void) {
    CFPreferencesAppSynchronize((__bridge CFStringRef)LumenDomain);
    if (notify_post) {
        notify_post(LumenPrefsChangedNotification.UTF8String);
    }
}

BOOL LumenEnabled(void) { return LumenBoolPref(@"enabled", YES); }
BOOL LumenHideClock(void) { return LumenBoolPref(@"hideClock", YES); }
BOOL LumenHideFocus(void) { return LumenBoolPref(@"hideFocus", YES); }

NSArray<NSString *> *LumenEnabledPills(void) {
    NSMutableArray<NSString *> *result = [NSMutableArray array];
    for (NSString *pill in LumenAllPills()) {
        if (LumenPillEnabled(pill)) {
            [result addObject:pill];
        }
    }
    if (result.count == 0) {
        [result addObject:@"time"];
    }
    return result;
}

BOOL LumenPillEnabled(NSString *pill) {
    BOOL fallback = ![pill isEqualToString:@"message"] && ![pill isEqualToString:@"countdown"];
    return LumenBoolPref([@"pill." stringByAppendingString:pill], fallback);
}

NSString *LumenDefaultPill(void) {
    id value = LumenPref(@"defaultPill");
    return [value isKindOfClass:[NSString class]] ? value : @"time";
}

BOOL LumenUseCustomColor(void) { return LumenBoolPref(@"customColor", NO); }

static UIColor *LumenColorFromHex(NSString *hex, UIColor *fallback) {
    if (![hex isKindOfClass:[NSString class]] || hex.length < 7) return fallback;
    unsigned int rgba = 0;
    NSScanner *scanner = [NSScanner scannerWithString:[hex substringFromIndex:1]];
    if (![scanner scanHexInt:&rgba]) return fallback;
    return [UIColor colorWithRed:((rgba >> 16) & 0xFF) / 255.0
                           green:((rgba >> 8) & 0xFF) / 255.0
                            blue:(rgba & 0xFF) / 255.0
                           alpha:1.0];
}

UIColor *LumenAccentColor(void) {
    UIColor *fallback = [UIColor colorWithRed:0.36 green:0.78 blue:0.98 alpha:1.0];
    if (!LumenUseCustomColor()) return fallback;
    id hex = LumenPref(@"accentHex");
    return [hex isKindOfClass:[NSString class]] ? LumenColorFromHex(hex, fallback) : fallback;
}

CGFloat LumenFontScale(void) {
    id value = LumenPref(@"fontScale");
    CGFloat scale = [value isKindOfClass:[NSNumber class]] ? [value doubleValue] : 1.0;
    return MIN(MAX(scale, 0.8), 1.4);
}

CGFloat LumenPillOpacity(void) {
    id value = LumenPref(@"pillOpacity");
    CGFloat opacity = [value isKindOfClass:[NSNumber class]] ? [value doubleValue] : 0.34;
    return MIN(MAX(opacity, 0.0), 0.9);
}

CGFloat LumenPillHeight(void) {
    id value = LumenPref(@"pillHeight");
    CGFloat height = [value isKindOfClass:[NSNumber class]] ? [value doubleValue] : 26.0;
    return MIN(MAX(height, 20.0), 36.0);
}

NSDate *LumenCountdownDate(void) {
    id value = LumenPref(@"countdownDate");
    if (![value isKindOfClass:[NSNumber class]]) return nil;
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:[value doubleValue]];
    return [date timeIntervalSinceNow] > 0 ? date : nil;
}
