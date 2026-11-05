#import "HBProfileStore.h"
#import "HBPreferences.h"

static BOOL UsableLibrary(id value) {
    if (![value isKindOfClass:NSDictionary.class] || ![value[@"schema"] isEqual:@1] || ![value[@"profiles"] isKindOfClass:NSArray.class]) return NO;
    for (id p in value[@"profiles"]) if ([p isKindOfClass:NSDictionary.class] && [p[@"id"] isKindOfClass:NSString.class]) {
        NSString *identifier = [p[@"id"] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (identifier.length && identifier.length <= 80) return YES;
    }
    return NO;
}
NSDictionary *HBLoadProfileLibrary(void) {
    CFPreferencesAppSynchronize((__bridge CFStringRef)HBPreferencesDomain);
    id value = CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("profileLibrary"), (__bridge CFStringRef)HBPreferencesDomain));
    if (!value) return HBDefaultLibrary(HBPalette());
    if (!UsableLibrary(value)) {
        value = CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("profileBackup"), (__bridge CFStringRef)HBPreferencesDomain));
        // Recovery restores layouts, never permission to resume system reads.
        NSMutableDictionary *recovered = HBNormalizeLibrary(value).mutableCopy;
        recovered[@"automaticFocus"] = @NO; recovered[@"focusOptInVersion"] = @0;
        return recovered;
    }
    return HBNormalizeLibrary(value);
}
BOOL HBSaveProfileLibrary(NSDictionary *library, NSNumber *expectedRevision, NSError **error) {
    NSCAssert(NSThread.isMainThread, @"Profile writes are serialized on the main thread");
    NSDictionary *current = HBLoadProfileLibrary(); NSString *failure = nil;
    if (expectedRevision && ![current[@"revision"] isEqual:expectedRevision]) failure = @"Profiles changed while this editor was open. Cancel and reopen to use the latest version.";
    if (failure) { if (error) *error = [NSError errorWithDomain:@"HarborProfiles" code:1 userInfo:@{NSLocalizedDescriptionKey:failure}]; return NO; }
    NSMutableDictionary *next = HBNormalizeLibrary(library).mutableCopy; next[@"revision"] = @([current[@"revision"] unsignedIntegerValue] + 1);
    CFPreferencesSetAppValue(CFSTR("profileBackup"), (__bridge CFPropertyListRef)current, (__bridge CFStringRef)HBPreferencesDomain);
    CFPreferencesSetAppValue(CFSTR("profileLibrary"), (__bridge CFPropertyListRef)next, (__bridge CFStringRef)HBPreferencesDomain);
    if (!CFPreferencesAppSynchronize((__bridge CFStringRef)HBPreferencesDomain)) {
        CFPreferencesSetAppValue(CFSTR("profileLibrary"), (__bridge CFPropertyListRef)current, (__bridge CFStringRef)HBPreferencesDomain);
        CFPreferencesAppSynchronize((__bridge CFStringRef)HBPreferencesDomain);
        if (error) *error = [NSError errorWithDomain:@"HarborProfiles" code:2 userInfo:@{NSLocalizedDescriptionKey:@"Harbor could not save the profile. Your previous settings are still selected."}]; return NO;
    }
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge CFStringRef)HBPreferencesChanged, NULL, NULL, true);
    return YES;
}
