#import "CompatPolicy.h"
#import "Configuration.h"
#import "MethodTypes.h"
#import <substrate.h>
#import <objc/message.h>
#import <mach-o/dyld.h>
#import <os/log.h>
#include <stdatomic.h>
#include <sys/utsname.h>

static atomic_bool CGCEnabled;
static atomic_bool CGCHookCheckPending;
static BOOL CGCIsStore;
static BOOL CGCInstallerHooked;
static BOOL CGCSessionHooked[5];
static BOOL CGCHeaderHooked;

static void CGCLoadPreferences(void) {
    @autoreleasepool {
        atomic_store(&CGCEnabled, CGCPreferencesEnabled([NSDictionary dictionaryWithContentsOfFile:CGCPreferencesPath()]));
    }
}

static void CGCSettingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef info) {
    CGCLoadPreferences();
}

typedef id (*CGCSessionOne)(id, SEL, NSURLRequest *);
typedef id (*CGCSessionTwo)(id, SEL, NSURLRequest *, id);
typedef id (*CGCSessionThree)(id, SEL, NSURLRequest *, unsigned long long, id);
static CGCSessionOne CGCOriginalNSOne, CGCOriginalAMSOne;
static CGCSessionTwo CGCOriginalNSTwo, CGCOriginalAMSTwo;
static CGCSessionThree CGCOriginalAMSThree;

static id CGCNSOne(id self, SEL command, NSURLRequest *request) {
    return CGCOriginalNSOne(self, command, CGCPreparedRequest(request, atomic_load(&CGCEnabled)));
}
static id CGCNSTwo(id self, SEL command, NSURLRequest *request, id completion) {
    return CGCOriginalNSTwo(self, command, CGCPreparedRequest(request, atomic_load(&CGCEnabled)), completion);
}
static id CGCAMSOne(id self, SEL command, NSURLRequest *request) {
    return CGCOriginalAMSOne(self, command, CGCPreparedRequest(request, atomic_load(&CGCEnabled)));
}
static id CGCAMSTwo(id self, SEL command, NSURLRequest *request, id completion) {
    return CGCOriginalAMSTwo(self, command, CGCPreparedRequest(request, atomic_load(&CGCEnabled)), completion);
}
static id CGCAMSThree(id self, SEL command, NSURLRequest *request, unsigned long long signpost, id completion) {
    return CGCOriginalAMSThree(self, command, CGCPreparedRequest(request, atomic_load(&CGCEnabled)), signpost, completion);
}

typedef void (*CGCHeaderSetter)(id, SEL, NSString *, NSString *);
static CGCHeaderSetter CGCOriginalHeaderSetter;

static id CGCObjectValue(id object, const char *selectorName) {
    if (!object) return nil;
    SEL selector = sel_registerName(selectorName);
    if (!CGCMethodMatches(class_getInstanceMethod(object_getClass(object), selector), "@", @[@"@", @":"])) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(object, selector);
}

static NSDictionary *CGCPurchaseParametersFromRequest(id request) {
    id properties = CGCObjectValue(request, "properties");
    id purchaseInfo = CGCObjectValue(properties, "purchaseInfo");
    id buyParams = CGCObjectValue(purchaseInfo, "buyParams");
    id dictionary = CGCObjectValue(buyParams, "dictionary");
    return [dictionary isKindOfClass:NSDictionary.class] ? dictionary : nil;
}

static void CGCSetHeaderValue(id self, SEL command, NSString *value, NSString *field) {
    NSString *prepared = CGCPreparedHeaderValue(self, CGCPurchaseParametersFromRequest(self), field, value, atomic_load(&CGCEnabled));
    if (prepared != value && ![prepared isEqualToString:value]) CGCMarkStatus(CGC_STATUS_STORE_MATCHED);
    CGCOriginalHeaderSetter(self, command, prepared, field);
}

static BOOL (*CGCOriginalMinimumOS)(id, SEL, id, id, unsigned long long, NSError *__autoreleasing *);

static BOOL CGCMinimumOS(id self, SEL command, id minimum, id originalVersion, unsigned long long requiredOS, NSError *__autoreleasing *error) {
    id version = originalVersion;
    if (atomic_load(&CGCEnabled)) {
        Class cls = object_getClass(self);
        SEL identitySelector = sel_registerName("identifier");
        SEL urlSelector = sel_registerName("bundleURL");
        if (CGCMethodMatches(class_getInstanceMethod(cls, identitySelector), "@", @[@"@", @":"])
            && CGCMethodMatches(class_getInstanceMethod(cls, urlSelector), "@", @[@"@", @":"])) {
            id identifier = ((id (*)(id, SEL))objc_msgSend)(self, identitySelector);
            id url = ((id (*)(id, SEL))objc_msgSend)(self, urlSelector);
            version = CGCInstallerVersion(minimum, originalVersion, identifier, url, YES);
            if (version != originalVersion && ![version isEqual:originalVersion]) CGCMarkStatus(CGC_STATUS_INSTALLER_MATCHED);
        }
    }
    // Keep the original decision, required-OS value, and error-out parameter intact.
    return CGCOriginalMinimumOS(self, command, minimum, version, requiredOS, error);
}

static BOOL CGCInstallHook(Class cls, SEL selector, const char *returnType, NSArray *types, IMP replacement, IMP *original) {
    if (!CGCMethodMatches(class_getInstanceMethod(cls, selector), returnType, types)) return NO;
    MSHookMessageEx(cls, selector, replacement, original);
    return *original != NULL;
}

static void CGCTryHooks(void) {
    @autoreleasepool {
        if (CGCIsStore) {
            Class ns = objc_getClass("NSURLSession");
            Class ams = objc_getClass("AMSURLSession");
            Class amsRequest = objc_getClass("AMSURLRequest");
            SEL one = sel_registerName("dataTaskWithRequest:");
            SEL two = sel_registerName("dataTaskWithRequest:completionHandler:");
            SEL three = sel_registerName("dataTaskWithRequest:signpostID:completionHandler:");
            if (!CGCSessionHooked[0]) CGCSessionHooked[0] = CGCInstallHook(ns, one, "@", @[@"@", @":", @"@"], (IMP)CGCNSOne, (IMP *)&CGCOriginalNSOne);
            if (!CGCSessionHooked[1]) CGCSessionHooked[1] = CGCInstallHook(ns, two, "@", @[@"@", @":", @"@", @"@?"], (IMP)CGCNSTwo, (IMP *)&CGCOriginalNSTwo);
            if (!CGCSessionHooked[2]) CGCSessionHooked[2] = CGCInstallHook(ams, one, "@", @[@"@", @":", @"@"], (IMP)CGCAMSOne, (IMP *)&CGCOriginalAMSOne);
            if (!CGCSessionHooked[3]) CGCSessionHooked[3] = CGCInstallHook(ams, two, "@", @[@"@", @":", @"@", @"@?"], (IMP)CGCAMSTwo, (IMP *)&CGCOriginalAMSTwo);
            if (!CGCSessionHooked[4]) CGCSessionHooked[4] = CGCInstallHook(ams, three, "@", @[@"@", @":", @"@", @"Q", @"@?"], (IMP)CGCAMSThree, (IMP *)&CGCOriginalAMSThree);
            if (!CGCHeaderHooked) {
                SEL setter = sel_registerName("setValue:forHTTPHeaderField:");
                CGCHeaderHooked = CGCInstallHook(amsRequest, setter, "v", @[@"@", @":", @"@", @"@"], (IMP)CGCSetHeaderValue, (IMP *)&CGCOriginalHeaderSetter);
            }
            if (CGCHeaderHooked) CGCMarkStatus(CGC_STATUS_STORE_HOOKED);
        } else if (!CGCInstallerHooked) {
            Class cls = objc_getClass("MIBundle");
            if (!CGCMethodMatches(class_getInstanceMethod(cls, sel_registerName("identifier")), "@", @[@"@", @":"])
                || !CGCMethodMatches(class_getInstanceMethod(cls, sel_registerName("bundleURL")), "@", @[@"@", @":"])) return;
            SEL selector = sel_registerName("_isMinimumOSVersion:applicableToOSVersion:requiredOS:error:");
            CGCInstallerHooked = CGCInstallHook(cls, selector, @encode(BOOL), @[@"@", @":", @"@", @"@", @"Q", @"^@"], (IMP)CGCMinimumOS, (IMP *)&CGCOriginalMinimumOS);
            if (CGCInstallerHooked) {
                CGCMarkStatus(CGC_STATUS_INSTALLER_HOOKED);
                os_log(OS_LOG_DEFAULT, "ChatGPTCompatibility: installer hook registered; device compatibility unverified");
            }
        }
    }
}

static void CGCImageAdded(const struct mach_header *header, intptr_t slide) {
    // Avoid Objective-C class discovery while dyld holds its loader lock.
    if (atomic_exchange(&CGCHookCheckPending, true)) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        atomic_store(&CGCHookCheckPending, false);
        CGCTryHooks();
    });
}

__attribute__((constructor)) static void CGCInitialize(void) {
    @autoreleasepool {
        NSProcessInfo *process = NSProcessInfo.processInfo;
        struct utsname machine;
        if (uname(&machine) != 0 || !CGCRuntimeAllowed(process.processName, [NSString stringWithUTF8String:machine.machine], process.operatingSystemVersion)) return;
        CGCIsStore = [process.processName isEqualToString:@"appstored"];
        CGCMarkStatus(CGCIsStore ? CGC_STATUS_APPSTORED_LOADED : CGC_STATUS_INSTALLD_LOADED);
        CGCLoadPreferences();
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, CGCSettingsChanged, CFSTR(CGC_SETTINGS_NOTIFICATION), NULL, CFNotificationSuspensionBehaviorCoalesce);
        CGCTryHooks();
        _dyld_register_func_for_add_image(CGCImageAdded);
        os_log(OS_LOG_DEFAULT, "ChatGPTCompatibility: loaded, enabled=%{public}d; no request data logged", atomic_load(&CGCEnabled));
    }
}
