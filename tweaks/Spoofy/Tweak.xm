#import <UIKit/UIKit.h>
#import <os/log.h>
#import <roothide.h>
#import <objc/runtime.h>
#include <atomic>
#import "SpoofyPolicy.h"
#import "SpoofyConfig.h"
#import "SpoofyDiagnosticGuard.h"
#include "SpoofyCategoryBudget.hpp"

static NSString *replacement;
static BOOL diagnostics;
static BOOL callCategories;
static NSString *diagnosticPath;
static dispatch_queue_t diagnosticQueue;
static SpoofyCategoryBudget categoryBudget;
// These values are read and changed only on diagnosticQueue.
static SpoofyObservations savedObserved;
static SpoofyHookChecks savedHooks;
static SpoofyCallCategories savedCategories;
static NSString *savedState;
static std::atomic_bool getterCalled(false);
static std::atomic_bool processVersionSeen(false);
static std::atomic_bool processMinimumSeen(false);
static void saveReportOnQueue(void) {
    if (!savedState) savedState = @"loaded_passthrough";
    if (!SpoofyWriteDiagnosticWithCategories(diagnosticPath, savedState, savedObserved, savedHooks, callCategories, savedCategories))
        os_log_error(OS_LOG_DEFAULT, "[spoofy] unable to write diagnostic status");
}
static void recordState(NSString *state, SpoofyObservations observation, SpoofyHookChecks hookChecks) {
    if (!diagnostics || !diagnosticPath || !diagnosticQueue) return;
    SpoofyGuardEnter();
    dispatch_async(diagnosticQueue, ^{
        SpoofyGuardEnter();
        @try {
            savedObserved = (SpoofyObservations)(savedObserved | observation);
            if (hookChecks & SpoofyHookChecksMeasured) savedHooks = hookChecks;
            if (state) savedState = state;
            if (savedObserved & SpoofyObservedDeviceVersion) savedState = @"getter_called";
            saveReportOnQueue();
        } @finally { SpoofyGuardLeave(); }
    });
    SpoofyGuardLeave();
}
static void recordCategory(unsigned diagnosticBit, unsigned unknownBit) {
    if (!diagnostics || !callCategories || !diagnosticQueue) return;
    unsigned bit = SpoofyGuardIsActive() ? diagnosticBit : unknownBit;
    if (!categoryBudget.claim(bit)) return;
    SpoofyGuardEnter();
    dispatch_async(diagnosticQueue, ^{
        SpoofyGuardEnter();
        @try {
            savedCategories = (SpoofyCallCategories)(savedCategories | bit);
            saveReportOnQueue();
        } @finally { SpoofyGuardLeave(); }
    });
    SpoofyGuardLeave();
}

%group VersionExperiment
%hook UIDevice
- (NSString *)systemVersion {
    recordCategory(SpoofyDeviceDiagnostic, SpoofyDeviceUnknown);
    NSString *actual = %orig;
    // A hook can be re-entered while diagnostic work runs. Unlike dispatch_once,
    // an atomic one-shot does not wait on itself in that case.
    if (!getterCalled.exchange(true)) {
        SpoofyGuardEnter();
        os_log(OS_LOG_DEFAULT, "[spoofy] UIDevice.systemVersion reached; experiment active");
        recordState(@"getter_called", SpoofyObservedDeviceVersion, 0);
        SpoofyGuardLeave();
    }
    return replacement ?: actual;
}
%end
%end

// Read-only diagnostics. Do not log the requested version or alter return values.
%group PassiveVersionObservers
%hook NSProcessInfo
- (NSOperatingSystemVersion)operatingSystemVersion {
    recordCategory(SpoofyProcessDiagnostic, SpoofyProcessUnknown);
    if (!processVersionSeen.exchange(true)) {
        SpoofyGuardEnter();
        os_log(OS_LOG_DEFAULT, "[spoofy] observed NSProcessInfo operatingSystemVersion");
        recordState(nil, SpoofyObservedProcessVersion, 0);
        SpoofyGuardLeave();
    }
    return %orig;
}
- (BOOL)isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion)version {
    recordCategory(SpoofyMinimumDiagnostic, SpoofyMinimumUnknown);
    if (!processMinimumSeen.exchange(true)) {
        SpoofyGuardEnter();
        os_log(OS_LOG_DEFAULT, "[spoofy] observed NSProcessInfo isOperatingSystemAtLeastVersion");
        recordState(nil, SpoofyObservedProcessMinimum, 0);
        SpoofyGuardLeave();
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
        diagnosticPath = jbroot(SPOOFY_DIAGNOSTIC_PATH);
        BOOL requested = SpoofyDiagnosticsEnabled(config);
        if (requested) {
            BOOL exists = NO;
            BOOL known = SpoofyDiagnosticReportExists(diagnosticPath, &exists);
            diagnostics = SpoofyDiagnosticMayStart(requested, exists, known);
        }
        callCategories = SpoofyShouldCollectCallCategories(config, diagnostics);
        if (diagnostics) diagnosticQueue = dispatch_queue_create("com.chasedavis.spoofy.diagnostics", DISPATCH_QUEUE_SERIAL);
        replacement = SpoofyReplacement(config, NSBundle.mainBundle.bundleIdentifier, actual);
        SpoofyGuardEnter();
        recordState(replacement ? @"loaded_enabled" : @"loaded_passthrough", 0, 0);
        NSProcessInfo *info = diagnostics ? NSProcessInfo.processInfo : nil;
        Class actualClass = info ? object_getClass(info) : Nil;
        Method pvBeforeMethod = diagnostics ? class_getInstanceMethod(actualClass, @selector(operatingSystemVersion)) : NULL;
        Method pmBeforeMethod = diagnostics ? class_getInstanceMethod(actualClass, @selector(isOperatingSystemAtLeastVersion:)) : NULL;
        IMP pvBefore = pvBeforeMethod ? method_getImplementation(pvBeforeMethod) : NULL;
        IMP pmBefore = pmBeforeMethod ? method_getImplementation(pmBeforeMethod) : NULL;
        if (diagnostics) %init(PassiveVersionObservers);
        if (diagnostics) {
            Method pvAfterMethod = class_getInstanceMethod(actualClass, @selector(operatingSystemVersion));
            Method pmAfterMethod = class_getInstanceMethod(actualClass, @selector(isOperatingSystemAtLeastVersion:));
            IMP pvAfter = pvAfterMethod ? method_getImplementation(pvAfterMethod) : NULL;
            IMP pmAfter = pmAfterMethod ? method_getImplementation(pmAfterMethod) : NULL;
            SpoofyHookChecks checks = SpoofyHookChecksMeasured;
            if (pvBefore && pvAfter && pvBefore != pvAfter) checks = (SpoofyHookChecks)(checks | SpoofyProcessVersionHookChanged);
            if (pmBefore && pmAfter && pmBefore != pmAfter) checks = (SpoofyHookChecks)(checks | SpoofyProcessMinimumHookChanged);
            recordState(nil, 0, checks);
        }
        if (!replacement) {
            os_log(OS_LOG_DEFAULT, "[spoofy] loaded; pass-through (disabled, invalid config, or unsupported OS)");
            SpoofyGuardLeave();
            return;
        }
        os_log(OS_LOG_DEFAULT, "[spoofy] loaded; UIDevice version experiment enabled");
        Method method = class_getInstanceMethod(UIDevice.class, @selector(systemVersion));
        IMP before = method ? method_getImplementation(method) : NULL;
        %init(VersionExperiment);
        Method hookedMethod = class_getInstanceMethod(UIDevice.class, @selector(systemVersion));
        IMP after = hookedMethod ? method_getImplementation(hookedMethod) : NULL;
        if (!getterCalled.load())
            recordState(before && after && before != after ? @"hook_change_observed" : @"hook_not_confirmed", 0, 0);
        SpoofyGuardLeave();
    }
}
