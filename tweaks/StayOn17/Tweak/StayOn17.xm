// StayOn17 — per-app OS spoof + store/installd helpers (RootHide)
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <substrate.h>
#import <objc/runtime.h>
#import <notify.h>
#import <string.h>
#import "../SO17Prefs.h"
#import "../SO17Spoof.h"

extern const char *__progname;

#ifdef __cplusplus
extern "C" {
#endif
CFTypeRef MGCopyAnswer(CFStringRef key);
#ifdef __cplusplus
}
#endif

static void SO17PrefsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    SO17ReloadSpoofState();
}

static void SO17RegisterPrefs(void) {
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
        SO17PrefsChanged, (__bridge CFStringRef)kSO17PrefsChangedNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);
    notify_register_dispatch([kSO17PrefsChangedNotification UTF8String], NULL, dispatch_get_main_queue(), ^(int token) {
        SO17ReloadSpoofState();
    });
}

#pragma mark Gestalt

%group GestaltHooks
%hookf(CFTypeRef, MGCopyAnswer, CFStringRef key) {
    if (SO17SpoofActive() && key && (CFEqual(key, CFSTR("ProductVersion")) || CFEqual(key, CFSTR("ProductVersionExtra")))) {
        NSString *v = SO17SpoofVersionString();
        return CFStringCreateWithCString(kCFAllocatorDefault, v.UTF8String, kCFStringEncodingUTF8);
    }
    return %orig;
}
%end

#pragma mark UIDevice / NSProcessInfo

%group RuntimeHooks
%hook UIDevice
- (NSString *)systemVersion {
    if (SO17SpoofActive()) return SO17SpoofVersionString();
    return %orig;
}
%end

%hook NSProcessInfo
- (NSOperatingSystemVersion)operatingSystemVersion {
    if (SO17SpoofActive()) return SO17SpoofedOSVersion();
    return %orig;
}
%end

%hook NSBundle
- (id)objectForInfoDictionaryKey:(NSString *)key {
    id val = %orig;
    if (SO17SpoofActive() && SO17IsMinimumOSKey(key)) {
        SO17Prefs *p = [SO17Prefs shared];
        if ([p patchMinimumOSOnDownload] || SO17IsInstallWhitelistProcess(SO17CurrentProcessBundleID(), __progname))
            return @"17.0";
    }
    return val;
}
%end

#pragma mark Store HTTP rewrite (NSURLSession)

%hook NSURLSession
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler {
    if (!SO17SpoofActive() || !handler) return %orig;
    void (^wrapped)(NSData *, NSURLResponse *, NSError *) = ^(NSData *d, NSURLResponse *r, NSError *e) {
        handler(SO17RewriteData(d), r, e);
    };
    NSMutableURLRequest *m = [request mutableCopy];
    if (m.allHTTPHeaderFields) {
        NSMutableDictionary *h = [m.allHTTPHeaderFields mutableCopy];
        for (NSString *k in h.allKeys) {
            id v = h[k];
            if ([v isKindOfClass:[NSString class]]) h[k] = SO17RewriteString(v);
        }
        m.allHTTPHeaderFields = h;
    }
    if (m.HTTPBody) m.HTTPBody = SO17RewriteData(m.HTTPBody);
    return %orig(m, wrapped);
}
%end

%end

#pragma mark installd MI hooks (simplified)

static NSString *(*orig_minOS)(id, SEL) = NULL;
static NSString *hook_minOS(id self, SEL _cmd) {
    if (SO17SpoofActive()) return @"2.0";
    return orig_minOS ? orig_minOS(self, _cmd) : @"2.0";
}

static void SO17HookInstalldClasses(void) {
    Class c = NSClassFromString(@"MIInstallableBundle");
    if (c) MSHookMessageEx(c, @selector(minimumOSVersion), (IMP)hook_minOS, (IMP *)&orig_minOS);
}

%ctor {
    @autoreleasepool {
        SO17RegisterPrefs();
        SO17ReloadSpoofState();
        if (!SO17SpoofActive()) return;

        %init(GestaltHooks);
        %init(RuntimeHooks);

        if (__progname && (!strcmp(__progname, "installd") || !strcmp(__progname, "installcoordinationd")))
            SO17HookInstalldClasses();
    }
}
