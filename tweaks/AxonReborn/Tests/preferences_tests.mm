// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
#import "../Shared/AXNPreferences.h"
#include <cstdio>
#include <cstdlib>
static void Expect(BOOL value, const char *message) {
    if (!value) { fprintf(stderr, "AXN_UI_TEST_FAIL: %s\n", message); fflush(stderr); exit(1); }
}
void AXNRunPreferenceTests(void) {
    NSArray *keys = @[@"Enabled", @"Compact", @"ShowCounts", @"ShowAll", @"Haptics", @"Motion", @"TapSelectedToAll",
        @"RevealFocus", @"Accent", @"Sort", @"Density", @"PinnedApps"];
    NSMutableDictionary *saved = [NSMutableDictionary new];
    for (NSString *key in keys) {
        id value = CFBridgingRelease(CFPreferencesCopyValue((__bridge CFStringRef)key,
            (__bridge CFStringRef)AXNPreferencesDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost));
        if (value) saved[key] = value;
    }
    for (id bad in @[@[], @{}, @"1", @(-1), @99, @0.5]) {
        CFPreferencesSetValue(CFSTR("Enabled"), (__bridge CFPropertyListRef)bad,
            (__bridge CFStringRef)AXNPreferencesDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
        CFPreferencesSetValue(CFSTR("Density"), (__bridge CFPropertyListRef)bad,
            (__bridge CFStringRef)AXNPreferencesDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
        AXNSynchronizePreferences();
        Expect(![AXNReadPreference(@"Enabled", @YES) boolValue], "malformed boolean escaped schema");
        Expect([AXNReadPreference(@"Density", @0) integerValue] == 0, "malformed density escaped schema");
    }
    AXNWritePreference(@"Accent", @3);
    Expect([AXNReadPreference(@"Accent", @0) integerValue] == 3, "valid enum failed");
    AXNWritePreference(@"Accent", @{});
    Expect([AXNReadPreference(@"Accent", @9) integerValue] == 0, "malformed write failed");
    AXNWritePreference(@"AXNUnknownTestKey", @1);
    Expect([AXNReadPreference(@"AXNUnknownTestKey", @"fallback") isEqual:@"fallback"], "unknown preference accepted");
    NSMutableArray *pins = [NSMutableArray arrayWithArray:@[@"app.one", @"app.one", @12, @"", @"bad id", @"a\nb"]];
    for (NSUInteger i = 0; i < 80; ++i) [pins addObject:[NSString stringWithFormat:@"app.%lu", (unsigned long)i]];
    AXNWritePreference(@"PinnedApps", pins);
    NSArray *validated = AXNReadPreference(@"PinnedApps", @[]);
    Expect(validated.count == 32 && [validated.firstObject isEqual:@"app.one"] &&
        [NSSet setWithArray:validated].count == 32, "pin sanitization or capacity failed");
    AXNWritePreference(@"Enabled", @YES); AXNWritePreference(@"RevealFocus", @NO);
    AXNWritePreference(@"Density", @2); AXNWritePreference(@"Motion", @NO);
    AXNWritePreference(@"ShowAll", @NO);
    Expect(![AXNReadPreference(@"ShowAll", @YES) boolValue], "ShowAll switch failed");
    AXNResetAppearance();
    Expect([AXNReadPreference(@"Enabled", @NO) boolValue] && ![AXNReadPreference(@"RevealFocus", @YES) boolValue],
        "appearance reset changed enable or Focus policy");
    Expect([AXNReadPreference(@"Density", @0) integerValue] == 0 &&
        ![AXNReadPreference(@"Motion", @YES) boolValue] && [AXNReadPreference(@"ShowAll", @NO) boolValue] && [AXNReadPreference(@"PinnedApps", @[]) count] == 0,
        "appearance reset did not restore defaults");
    AXNWritePreference(@"Accent", @1);
    CFPreferencesSetValue(CFSTR("Accent"), (__bridge CFNumberRef)@2,
        (__bridge CFStringRef)AXNPreferencesDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    Expect([AXNReadPreference(@"Accent", @0) integerValue] == 1, "preference cache was not stable");
    AXNSynchronizePreferences();
    Expect([AXNReadPreference(@"Accent", @0) integerValue] == 2, "preference reload failed");
    for (NSString *key in keys) CFPreferencesSetValue((__bridge CFStringRef)key,
        (__bridge CFPropertyListRef)saved[key], (__bridge CFStringRef)AXNPreferencesDomain,
        kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    AXNSynchronizePreferences();
    puts("AXN_PREFERENCES_TEST_PASS: malformed values, enum bounds, favorite limits, cached reload and reset isolation");
}

