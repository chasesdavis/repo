// SPDX-License-Identifier: GPL-3.0-only
#import "AXNPreferences.h"
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
        @"Axon found the notification scroll view, but its selector has not completed layout. Open Notification Center with a notification present, then check again. If it persists, tap Copy Layout Report."
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
    NSDictionary *response = @{@"request":request, @"version":@"alpha4", @"state":@(state),
        @"report":[report substringToIndex:MIN(report.length, (NSUInteger)8192)]};
    CFPreferencesSetValue(CFSTR("response"), (__bridge CFDictionaryRef)response, DiagnosticDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    SyncDiagnostic();
}
NSDictionary *AXNReadDiagnosticResponse(NSString *request) {
    SyncDiagnostic();
    id response = ReadDiagnostic(CFSTR("response"));
    if (![response isKindOfClass:NSDictionary.class]) return nil;
    if (![response[@"request"] isEqual:request] || ![response[@"version"] isEqual:@"alpha4"] ||
        ![response[@"report"] isKindOfClass:NSString.class] || [response[@"report"] length] > 8192 ||
        ![response[@"state"] isKindOfClass:NSNumber.class] || [response[@"state"] unsignedIntegerValue] >= AXNDiagnosticStateCount) return nil;
    return response;
}
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
