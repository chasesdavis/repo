#import "SpoofyConfig.h"

NSDictionary *SpoofyReadConfig(NSString *path) {
    return [NSDictionary dictionaryWithContentsOfFile:path];
}

BOOL SpoofySaveEnabled(NSString *path, BOOL enabled) {
    if (!path.length) return NO;
    NSString *directory = [path stringByDeletingLastPathComponent];
    if (![[NSFileManager defaultManager] createDirectoryAtPath:directory
        withIntermediateDirectories:YES attributes:nil error:NULL]) return NO;
    NSDictionary *current = SpoofyReadConfig(path);
    NSDictionary *config = @{@"Enabled": @(enabled), @"ReportedVersion": @"18.0",
                             @"Diagnostics": @(SpoofyDiagnosticsEnabled(current))};
    return [config writeToFile:path atomically:YES];
}

BOOL SpoofyDiagnosticsEnabled(id config) {
    if (![config isKindOfClass:NSDictionary.class]) return NO;
    id value = config[@"Diagnostics"];
    return value && CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID() && [value boolValue];
}

BOOL SpoofySaveDiagnostics(NSString *path, BOOL enabled) {
    if (!path.length) return NO;
    NSString *directory = [path stringByDeletingLastPathComponent];
    if (![[NSFileManager defaultManager] createDirectoryAtPath:directory
        withIntermediateDirectories:YES attributes:nil error:NULL]) return NO;
    NSDictionary *current = SpoofyReadConfig(path);
    id value = current[@"Enabled"];
    BOOL experiment = value && CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID() && [value boolValue];
    NSDictionary *config = @{@"Enabled": @(experiment), @"ReportedVersion": @"18.0", @"Diagnostics": @(enabled)};
    return [config writeToFile:path atomically:YES];
}

BOOL SpoofyWriteDiagnostic(NSString *path, NSString *state) {
    return SpoofyWriteDiagnosticSnapshot(path, state, 0);
}

BOOL SpoofyWriteDiagnosticSnapshot(NSString *path, NSString *state, SpoofyObservations observations) {
    return SpoofyWriteDiagnosticWithHooks(path, state, observations, 0);
}

BOOL SpoofyWriteDiagnosticWithHooks(NSString *path, NSString *state, SpoofyObservations observations, SpoofyHookChecks hooks) {
    NSSet *allowed = [NSSet setWithArray:@[@"loaded_passthrough", @"loaded_enabled", @"hook_change_observed", @"hook_not_confirmed", @"getter_called"]];
    NSUInteger known = SpoofyObservedDeviceVersion | SpoofyObservedProcessVersion | SpoofyObservedProcessMinimum;
    NSUInteger knownHooks = SpoofyHookChecksMeasured | SpoofyProcessVersionHookChanged | SpoofyProcessMinimumHookChanged;
    if (!path.length || ![allowed containsObject:state] || (observations & ~known) || (hooks & ~knownHooks) ||
        ((hooks & (SpoofyProcessVersionHookChanged | SpoofyProcessMinimumHookChanged)) && !(hooks & SpoofyHookChecksMeasured))) return NO;
    // Fixed state, booleans, timestamp; no account, class names, device ID, arguments, or network data.
    return [@{@"state":state, @"timestamp":[NSDate date],
        @"deviceVersion": @((observations & SpoofyObservedDeviceVersion) != 0),
        @"processVersion": @((observations & SpoofyObservedProcessVersion) != 0),
        @"processMinimum": @((observations & SpoofyObservedProcessMinimum) != 0),
        @"processHooksMeasured": @((hooks & SpoofyHookChecksMeasured) != 0),
        @"processVersionHookChanged": @((hooks & SpoofyProcessVersionHookChanged) != 0),
        @"processMinimumHookChanged": @((hooks & SpoofyProcessMinimumHookChanged) != 0)} writeToFile:path atomically:YES];
}

BOOL SpoofyClearDiagnostic(NSString *path) {
    if (!path.length) return NO;
    NSError *error = nil;
    if ([NSFileManager.defaultManager removeItemAtPath:path error:&error]) return YES;
    return [error.domain isEqualToString:NSCocoaErrorDomain] && error.code == NSFileNoSuchFileError;
}
