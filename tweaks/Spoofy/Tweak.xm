#import <UIKit/UIKit.h>
#import <os/log.h>
#import <roothide.h>
#import <objc/runtime.h>
#include <atomic>
#import "SpoofyPolicy.h"
#import "SpoofyConfig.h"

static NSString *replacement;
static BOOL diagnostics;
static NSString *diagnosticPath;
static dispatch_queue_t diagnosticQueue;
static std::atomic_bool getterCalled(false);
static std::atomic_bool processVersionSeen(false);
static std::atomic_bool processMinimumSeen(false);
static void recordState(NSString *state, SpoofyObservations observation) {
    if (!diagnostics || !diagnosticPath || !diagnosticQueue) return;
    dispatch_async(diagnosticQueue, ^{
        static SpoofyObservations observed = 0;
        static NSString *latestState;
        observed = (SpoofyObservations)(observed | observation);
        if (state) latestState = state;
        if (observed & SpoofyObservedDeviceVersion) latestState = @"getter_called";
        if (!latestState) latestState = @"loaded_passthrough";
        if (!SpoofyWriteDiagnosticSnapshot(diagnosticPath, latestState, observed))
            os_log_error(OS_LOG_DEFAULT, "[spoofy] unable to write diagnostic status");
    });
}

%group VersionExperiment
%hook UIDevice
- (NSString *)systemVersion {
    NSString *actual = %orig;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        getterCalled.store(true);
        os_log(OS_LOG_DEFAULT, "[spoofy] UIDevice.systemVersion reached; experiment active");
        recordState(@"getter_called", SpoofyObservedDeviceVersion);
    });
    return replacement ?: actual;
}
%end
%end

// Read-only diagnostics. Do not log the requested version or alter return values.
%group PassiveVersionObservers
%hook NSProcessInfo
- (NSOperatingSystemVersion)operatingSystemVersion {
    if (!processVersionSeen.exchange(true)) {
        os_log(OS_LOG_DEFAULT, "[spoofy] observed NSProcessInfo operatingSystemVersion");
        recordState(nil, SpoofyObservedProcessVersion);
    }
    return %orig;
}
- (BOOL)isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion)version {
    if (!processMinimumSeen.exchange(true)) {
        os_log(OS_LOG_DEFAULT, "[spoofy] observed NSProcessInfo isOperatingSystemAtLeastVersion");
        recordState(nil, SpoofyObservedProcessMinimum);
    }
    return %orig(version);
}
%end
%end

%ctor {
    @autoreleasepool {
        if (![[NSBundle mainBundle].bundleIdentifier isEqualToString:@"com.apple.AppStore"]) return;
        // Capture real version before installing any hook. Do not spoof availability checks.
        NSOperatingSystemVersion actual = NSProcessInfo.processInfo.operatingSystemVersion;
        NSString *path = jbroot(SPOOFY_CONFIG_PATH);
        NSDictionary *config = SpoofyReadConfig(path);
        diagnostics = SpoofyDiagnosticsEnabled(config);
        diagnosticPath = jbroot(SPOOFY_DIAGNOSTIC_PATH);
        if (diagnostics) diagnosticQueue = dispatch_queue_create("com.chasedavis.spoofy.diagnostics", DISPATCH_QUEUE_SERIAL);
        replacement = SpoofyReplacement(config, NSBundle.mainBundle.bundleIdentifier, actual);
        recordState(replacement ? @"loaded_enabled" : @"loaded_passthrough", 0);
        if (diagnostics) %init(PassiveVersionObservers);
        if (!replacement) {
            os_log(OS_LOG_DEFAULT, "[spoofy] loaded; pass-through (disabled, invalid config, or unsupported OS)");
            return;
        }
        os_log(OS_LOG_DEFAULT, "[spoofy] loaded; UIDevice version experiment enabled");
        Method method = class_getInstanceMethod(UIDevice.class, @selector(systemVersion));
        IMP before = method ? method_getImplementation(method) : NULL;
        %init(VersionExperiment);
        Method hookedMethod = class_getInstanceMethod(UIDevice.class, @selector(systemVersion));
        IMP after = hookedMethod ? method_getImplementation(hookedMethod) : NULL;
        if (!getterCalled.load())
            recordState(before && after && before != after ? @"hook_change_observed" : @"hook_not_confirmed", 0);
    }
}
