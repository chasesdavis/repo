// SPDX-License-Identifier: GPL-3.0-only
#import "AXNPreferences.h"
NSString * const AXNPreferencesDomain = @"com.chasesdavis.axonreborn";
NSString * const AXNPreferencesChanged = @"com.chasesdavis.axonreborn/changed";
id AXNReadPreference(NSString *key, id fallback) {
    id value = CFBridgingRelease(CFPreferencesCopyValue((__bridge CFStringRef)key,
        (__bridge CFStringRef)AXNPreferencesDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost));
    return value ?: fallback;
}
void AXNSynchronizePreferences(void) {
    CFPreferencesSynchronize((__bridge CFStringRef)AXNPreferencesDomain,
        kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
}
void AXNWritePreference(NSString *key, id value) {
    CFPreferencesSetValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)value,
        (__bridge CFStringRef)AXNPreferencesDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    AXNSynchronizePreferences();
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
        (__bridge CFStringRef)AXNPreferencesChanged, NULL, NULL, YES);
}
