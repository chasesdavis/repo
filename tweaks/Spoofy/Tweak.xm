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
static std::atomic_bool getterCalled(false);
static void recordState(NSString *state) {
    if (!diagnostics || !diagnosticPath) return;
    @synchronized(diagnosticPath) {
        if (![state isEqualToString:@"getter_called"] && getterCalled.load()) return;
        if (!SpoofyWriteDiagnostic(diagnosticPath, state))
            os_log_error(OS_LOG_DEFAULT, "[spoofy] unable to write diagnostic status");
    }
}

%group VersionExperiment
%hook UIDevice
- (NSString *)systemVersion {
    NSString *actual = %orig;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        getterCalled.store(true);
        os_log(OS_LOG_DEFAULT, "[spoofy] UIDevice.systemVersion reached; experiment active");
        recordState(@"getter_called");
    });
    return replacement ?: actual;
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
        replacement = SpoofyReplacement(config, NSBundle.mainBundle.bundleIdentifier, actual);
        if (!replacement) {
            os_log(OS_LOG_DEFAULT, "[spoofy] loaded; pass-through (disabled, invalid config, or unsupported OS)");
            recordState(@"loaded_passthrough");
            return;
        }
        os_log(OS_LOG_DEFAULT, "[spoofy] loaded; UIDevice version experiment enabled");
        recordState(@"loaded_enabled");
        Method method = class_getInstanceMethod(UIDevice.class, @selector(systemVersion));
        IMP before = method ? method_getImplementation(method) : NULL;
        %init(VersionExperiment);
        Method hookedMethod = class_getInstanceMethod(UIDevice.class, @selector(systemVersion));
        IMP after = hookedMethod ? method_getImplementation(hookedMethod) : NULL;
        if (!getterCalled.load())
            recordState(before && after && before != after ? @"hook_change_observed" : @"hook_not_confirmed");
    }
}
