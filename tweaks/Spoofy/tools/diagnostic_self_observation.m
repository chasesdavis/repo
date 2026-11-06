// Host-only research: probe whether the same Foundation operations used by the
// diagnostic report call NSProcessInfo in this process. Never connects to iOS.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <os/log.h>
#import <stdatomic.h>
#import "../SpoofyConfig.h"

static atomic_uint versionCalls;
static atomic_uint minimumCalls;
static NSOperatingSystemVersion (*originalVersion)(id, SEL);
static BOOL (*originalMinimum)(id, SEL, NSOperatingSystemVersion);

static NSOperatingSystemVersion observedVersion(id self, SEL selector) {
    atomic_fetch_add(&versionCalls, 1);
    return originalVersion(self, selector);
}
static BOOL observedMinimum(id self, SEL selector, NSOperatingSystemVersion required) {
    atomic_fetch_add(&minimumCalls, 1);
    return originalMinimum(self, selector, required);
}

int main(void) { @autoreleasepool {
    NSProcessInfo *process = NSProcessInfo.processInfo;
    Class actual = object_getClass(process);
    Method version = class_getInstanceMethod(actual, @selector(operatingSystemVersion));
    Method minimum = class_getInstanceMethod(actual, @selector(isOperatingSystemAtLeastVersion:));
    if (!version || !minimum) { fprintf(stderr, "Required host methods unavailable\n"); return 1; }
    originalVersion = (NSOperatingSystemVersion (*)(id, SEL))method_getImplementation(version);
    originalMinimum = (BOOL (*)(id, SEL, NSOperatingSystemVersion))method_getImplementation(minimum);
    method_setImplementation(version, (IMP)observedVersion);
    method_setImplementation(minimum, (IMP)observedMinimum);
    NSOperatingSystemVersion current = process.operatingSystemVersion;
    BOOL supported = [process isOperatingSystemAtLeastVersion:current];
    if (!supported || !atomic_load(&versionCalls) || !atomic_load(&minimumCalls)) {
        fprintf(stderr, "Host positive control failed\n"); return 1;
    }
    atomic_store(&versionCalls, 0);
    atomic_store(&minimumCalls, 0);
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID.UUID.UUIDString stringByAppendingString:@".plist"]];
    os_log(OS_LOG_DEFAULT, "[spoofy host probe] fixed diagnostic message");
    BOOL written = SpoofyWriteDiagnosticWithHooks(path, @"hook_change_observed", 0, SpoofyHookChecksMeasured);
    unsigned observedVersionCalls = atomic_load(&versionCalls);
    unsigned observedMinimumCalls = atomic_load(&minimumCalls);
    method_setImplementation(version, (IMP)originalVersion);
    method_setImplementation(minimum, (IMP)originalMinimum);
    [NSFileManager.defaultManager removeItemAtPath:path error:NULL];
    if (!written) { fprintf(stderr, "Host report write failed\n"); return 1; }
    printf("Host diagnostic operations observed process-version calls: %u; minimum-check calls: %u\n", observedVersionCalls, observedMinimumCalls);
    puts("Host-only result; it does not identify callers or determine iOS behavior.");
} return 0; }
