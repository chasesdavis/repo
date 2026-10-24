// SPDX-License-Identifier: GPL-3.0-only
#import "AXNPreferences.h"
#include <math.h>
NSString * const AXNPreferencesDomain = @"com.chasesdavis.axonreborn";
NSString * const AXNPreferencesChanged = @"com.chasesdavis.axonreborn/changed";
NSString * const AXNDiagnosticQuery = @"com.chasesdavis.axonreborn/diagnostics/query";
NSString *AXNDiagnosticReply(NSUInteger state) {
    return [NSString stringWithFormat:@"com.chasesdavis.axonreborn/diagnostics/%lu", (unsigned long)state];
}
NSString *AXNDiagnosticMessage(NSUInteger state) {
    NSArray<NSString *> *messages = @[
        @"Axon loaded in SpringBoard but has not attached to the notification list. Open the Lock Screen with a notification present, then check again.",
        @"SpringBoard sees Axon as disabled. If the switch is on, Settings and SpringBoard may not be sharing preferences. Toggle it off and on, respring, then check again.",
        @"Axon loaded, but a required notification controller is missing. This iOS layout needs an adapter update.",
        @"Axon loaded, but the notification method signatures do not match. Filtering is disabled; an adapter update is needed.",
        @"Axon could not read the native notification list. Filtering is disabled; the snapshot adapter needs an update.",
        @"Axon could not identify a native notification request. Filtering is disabled; the request adapter needs an update.",
        @"Axon attached to the list, but could not mount its selector in the Lock Screen layout. The view adapter needs an update.",
        @"Axon attached successfully, but its last notification snapshot was empty. Keep a notification in Notification Center and reopen the Lock Screen.",
        @"Axon attached to the notification list and mounted its selector during the last Lock Screen presentation. On iOS 17 the selector scrolls with the list; scroll to its top to see it. This confirms attachment, not complete device compatibility.",
        @"Axon stopped filtering after a native update failed. Disable Axon and respring before testing again.",
        @"This build supports testing on iOS 15 through 17 only.",
        @"Axon read the notifications, but could not identify the native notification scroll view. Tap Copy Layout Report and send it with your test result.",
        @"Axon found the notification scroll view, but its selector has not completed layout. Open Notification Center with a notification present, then check again. If it persists, tap Copy Layout Report.",
        @"The native app-filtering interface is unavailable. No selection filter was applied. Copy the layout report for diagnosis.",
        @"Axon applied its app filter, but the native reveal update did not complete. Copy Layout Report includes the coordinator result and the final state before leaving the Lock Screen."
    ];
    return state < messages.count ? messages[state] : @"Unknown diagnostic state.";
}
// Separate from settings so diagnostics do not trigger preference reloads.
static CFStringRef const DiagnosticDomain = CFSTR("com.chasesdavis.axonreborn.diagnostics");
static void SyncDiagnostic(void) {
    CFPreferencesSynchronize(DiagnosticDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
}
static id ReadDiagnostic(CFStringRef key) {
    return CFBridgingRelease(CFPreferencesCopyValue(key, DiagnosticDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost));
}
NSString *AXNBeginDiagnosticQuery(void) {
    NSString *request = NSUUID.UUID.UUIDString;
    CFPreferencesSetValue(CFSTR("request"), (__bridge CFStringRef)request, DiagnosticDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    CFPreferencesSetValue(CFSTR("response"), NULL, DiagnosticDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    SyncDiagnostic();
    return request;
}
void AXNPublishDiagnosticReport(NSUInteger state, NSString *report) {
    SyncDiagnostic();
    id request = ReadDiagnostic(CFSTR("request"));
    if (![request isKindOfClass:NSString.class] || [request length] > 64) return;
    NSDictionary *response = @{@"request":request, @"version":@"beta1", @"state":@(state),
        @"report":[report substringToIndex:MIN(report.length, (NSUInteger)8192)]};
    CFPreferencesSetValue(CFSTR("response"), (__bridge CFDictionaryRef)response, DiagnosticDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    SyncDiagnostic();
}
NSDictionary *AXNReadDiagnosticResponse(NSString *request) {
    SyncDiagnostic();
    id response = ReadDiagnostic(CFSTR("response"));
    if (![response isKindOfClass:NSDictionary.class]) return nil;
    if (![response[@"request"] isEqual:request] || ![response[@"version"] isEqual:@"beta1"] ||
        ![response[@"report"] isKindOfClass:NSString.class] || [response[@"report"] length] > 8192 ||
        ![response[@"state"] isKindOfClass:NSNumber.class] || [response[@"state"] unsignedIntegerValue] >= AXNDiagnosticStateCount) return nil;
    return response;
}
// A single schema protects SpringBoard from malformed settings and bounds work.
static NSDictionary<NSString *, id> *Defaults(void) {
    static NSDictionary *values; static dispatch_once_t once;
    dispatch_once(&once, ^{
        values = @{@"Enabled":@NO, @"Compact":@NO, @"ShowCounts":@YES,
            @"Haptics":@YES, @"Motion":@YES, @"TapSelectedToAll":@YES,
            @"RevealFocus":@YES, @"Accent":@0, @"Sort":@0, @"Density":@1, @"PinnedApps":@[]};
    });
    return values;
}
static id Validated(NSString *key, id value) {
    id fallback = Defaults()[key];
    if (!fallback) return nil;
    if ([key isEqualToString:@"PinnedApps"]) {
        if (![value isKindOfClass:NSArray.class]) return fallback;
        NSMutableArray *pins = [NSMutableArray new];
        NSCharacterSet *invalid = [[NSCharacterSet characterSetWithCharactersInString:
            @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_"] invertedSet];
        NSUInteger examined = 0;
        for (id app in value) {
            if (++examined > 128 || pins.count == 32) break;
            if ([app isKindOfClass:NSString.class] && [app length] > 0 && [app length] <= 255 &&
                [app rangeOfCharacterFromSet:invalid].location == NSNotFound && ![pins containsObject:app])
                [pins addObject:[app copy]];
        }
        return [pins copy];
    }
    if (![value isKindOfClass:NSNumber.class]) return fallback;
    double number = [value doubleValue];
    NSInteger maximum = [key isEqualToString:@"Accent"] ? 3 : ([key isEqualToString:@"Density"] ? 2 : 1);
    if (!isfinite(number) || number < 0 || number > maximum || floor(number) != number) return fallback;
    return @((NSInteger)number);
}
static NSDictionary<NSString *, id> *cachedPreferences;
static void ReloadPreferences(void) {
    NSMutableDictionary *values = [NSMutableDictionary new];
    for (NSString *key in Defaults()) {
        id value = CFBridgingRelease(CFPreferencesCopyValue((__bridge CFStringRef)key,
            (__bridge CFStringRef)AXNPreferencesDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost));
        values[key] = Validated(key, value);
    }
    cachedPreferences = [values copy];
}
id AXNReadPreference(NSString *key, id fallback) {
    @synchronized (AXNPreferencesDomain) {
        if (!cachedPreferences) ReloadPreferences();
        return cachedPreferences[key] ?: fallback;
    }
}
void AXNSynchronizePreferences(void) {
    @synchronized (AXNPreferencesDomain) {
        CFPreferencesSynchronize((__bridge CFStringRef)AXNPreferencesDomain,
            kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
        ReloadPreferences();
    }
}
static void NotifyPreferences(void) {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
        (__bridge CFStringRef)AXNPreferencesChanged, NULL, NULL, YES);
}
void AXNWritePreference(NSString *key, id value) {
    id validated = Validated(key, value);
    if (!validated) return;
    @synchronized (AXNPreferencesDomain) {
        CFPreferencesSetValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)validated,
            (__bridge CFStringRef)AXNPreferencesDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
        AXNSynchronizePreferences();
    }
    NotifyPreferences();
}
void AXNResetAppearance(void) {
    @synchronized (AXNPreferencesDomain) {
        for (NSString *key in @[@"Compact", @"ShowCounts", @"Haptics", @"Motion", @"TapSelectedToAll",
                               @"Accent", @"Sort", @"Density", @"PinnedApps"]) {
            CFPreferencesSetValue((__bridge CFStringRef)key, NULL,
                (__bridge CFStringRef)AXNPreferencesDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
        }
        AXNSynchronizePreferences();
    }
    NotifyPreferences();
}
