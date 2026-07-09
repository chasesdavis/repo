// LowerInstall 1.1 — iOS 15–17 rootless / RootHide Bootstrap
// Original: julioverne · modern UA spoof pattern from mineek/appstoretroller
//
// 1.1 fixes:
//  - Spoof "iOS/x.y.z" User-Agent tokens (1.0 used dead "/%@ " patterns)
//  - Default spoof version 18.4 (not the device's real OS)
//  - MSHookMessageEx soft-hooks for installd (missing selectors skipped)
//  - Foundation-only in installd path (no UIKit dependency for daemon)

#import <Foundation/Foundation.h>
#import <substrate.h>
#import <objc/runtime.h>
#import <sys/utsname.h>
#import <notify.h>
#import <string.h>

extern const char *__progname;

#define PLIST_PATH @"/var/mobile/Library/Preferences/com.julioverne.lowerinstall.plist"
#define PREFS_DOMAIN "com.julioverne.lowerinstall"
#define PREFS_CHANGED "com.julioverne.lowerinstall/SettingsChanged"
#define DEFAULT_SPOOF_VERSION @"18.4"

static BOOL gEnabled = YES;
static NSString *gSpoofDevice = nil;
static NSString *gSpoofVersion = nil;
static NSString *gCurrentDevice = nil;
static NSString *gCurrentVersion = nil;

#pragma mark - Prefs / identity

static NSString *LICurrentOSVersion(void) {
	NSOperatingSystemVersion v = [[NSProcessInfo processInfo] operatingSystemVersion];
	if (v.majorVersion == 0) return @"17.0";
	if (v.patchVersion > 0) {
		return [NSString stringWithFormat:@"%ld.%ld.%ld", (long)v.majorVersion, (long)v.minorVersion, (long)v.patchVersion];
	}
	return [NSString stringWithFormat:@"%ld.%ld", (long)v.majorVersion, (long)v.minorVersion];
}

static NSString *LICurrentMachine(void) {
	struct utsname info;
	uname(&info);
	return [NSString stringWithUTF8String:info.machine] ?: @"iPhone15,2";
}

static id LIPrefObject(NSString *key) {
	CFPropertyListRef cf = CFPreferencesCopyAppValue((__bridge CFStringRef)key, CFSTR(PREFS_DOMAIN));
	if (cf) return CFBridgingRelease(cf);
	NSDictionary *file = [NSDictionary dictionaryWithContentsOfFile:PLIST_PATH];
	return file[key];
}

static void LILoadPrefs(void) {
	@autoreleasepool {
		id en = LIPrefObject(@"Enabled");
		gEnabled = (en == nil) ? YES : [en boolValue];

		NSString *dev = LIPrefObject(@"SpoofDevice");
		gSpoofDevice = ([dev isKindOfClass:[NSString class]] && dev.length)
			? [dev copy]
			: [gCurrentDevice copy];

		NSString *ver = LIPrefObject(@"SpoofVersion");
		gSpoofVersion = ([ver isKindOfClass:[NSString class]] && ver.length)
			? [ver copy]
			: [DEFAULT_SPOOF_VERSION copy];
	}
}

static void LIPrefsCallback(CFNotificationCenterRef c, void *o, CFStringRef n, const void *obj, CFDictionaryRef u) {
	LILoadPrefs();
}

static NSString *LISpoofUserAgent(NSString *value) {
	if (!value.length || !gEnabled) return value;

	NSString *spoofVer = gSpoofVersion.length ? gSpoofVersion : DEFAULT_SPOOF_VERSION;
	if ([spoofVer rangeOfString:@"."].location == NSNotFound) {
		spoofVer = [spoofVer stringByAppendingString:@".0"];
	}

	NSMutableString *out = [value mutableCopy];
	NSArray *patterns = @[
		@"iOS/[0-9]+(?:\\.[0-9]+){0,3}",
		@"iPhone OS [0-9]+(?:_[0-9]+){0,3}",
		@"Version/[0-9]+(?:\\.[0-9]+){0,3}",
		@"/[0-9]+\\.[0-9]+(?:\\.[0-9]+)? ",
	];
	NSArray *replacements = @[
		[NSString stringWithFormat:@"iOS/%@", spoofVer],
		[NSString stringWithFormat:@"iPhone OS %@", [spoofVer stringByReplacingOccurrencesOfString:@"." withString:@"_"]],
		[NSString stringWithFormat:@"Version/%@", spoofVer],
		[NSString stringWithFormat:@"/%@ ", spoofVer],
	];

	for (NSUInteger i = 0; i < patterns.count; i++) {
		NSError *err = nil;
		NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:patterns[i] options:0 error:&err];
		if (!re) continue;
		[re replaceMatchesInString:out options:0 range:NSMakeRange(0, out.length) withTemplate:replacements[i]];
	}

	if (gCurrentDevice.length && gSpoofDevice.length && ![gCurrentDevice isEqualToString:gSpoofDevice]) {
		[out replaceOccurrencesOfString:gCurrentDevice withString:gSpoofDevice options:0 range:NSMakeRange(0, out.length)];
	}
	return [out copy];
}

#pragma mark - installd hooks (MSHookMessageEx)

static NSString *(*orig_minOS)(id, SEL) = NULL;
static NSString *hook_minOS(id self, SEL _cmd) {
	if (gEnabled) return @"2.0";
	return orig_minOS ? orig_minOS(self, _cmd) : @"2.0";
}

static NSArray *(*orig_devices)(id, SEL) = NULL;
static NSArray *hook_devices(id self, SEL _cmd) {
	NSArray *ret = orig_devices ? orig_devices(self, _cmd) : @[];
	if (!gEnabled) return ret;
	NSString *machine = gCurrentDevice ?: LICurrentMachine();
	if (machine && ![ret containsObject:machine]) {
		NSMutableArray *mut = [ret mutableCopy] ?: [NSMutableArray array];
		[mut addObject:machine];
		return [mut copy];
	}
	return ret;
}

static BOOL (*orig_famErr)(id, SEL, NSError **) = NULL;
static BOOL hook_famErr(id self, SEL _cmd, NSError **e) {
	if (gEnabled) { if (e) *e = nil; return YES; }
	return orig_famErr ? orig_famErr(self, _cmd, e) : YES;
}

static BOOL (*orig_osErr)(id, SEL, NSError **) = NULL;
static BOOL hook_osErr(id self, SEL _cmd, NSError **e) {
	if (gEnabled) { if (e) *e = nil; return YES; }
	return orig_osErr ? orig_osErr(self, _cmd, e) : YES;
}

static BOOL (*orig_osVerErr)(id, SEL, id, NSError **) = NULL;
static BOOL hook_osVerErr(id self, SEL _cmd, id a, NSError **e) {
	if (gEnabled) { if (e) *e = nil; return YES; }
	return orig_osVerErr ? orig_osVerErr(self, _cmd, a, e) : YES;
}

static BOOL (*orig_capErr)(id, SEL, NSError **) = NULL;
static BOOL hook_capErr(id self, SEL _cmd, NSError **e) {
	if (gEnabled) { if (e) *e = nil; return YES; }
	return orig_capErr ? orig_capErr(self, _cmd, e) : YES;
}

static BOOL (*orig_thinErr)(id, SEL, NSError **) = NULL;
static BOOL hook_thinErr(id self, SEL _cmd, NSError **e) {
	if (gEnabled) { if (e) *e = nil; return YES; }
	return orig_thinErr ? orig_thinErr(self, _cmd, e) : YES;
}

static BOOL (*orig_valApp)(id, SEL, NSError **) = NULL;
static BOOL hook_valApp(id self, SEL _cmd, NSError **e) {
	if (gEnabled) { if (e) *e = nil; return YES; }
	return orig_valApp ? orig_valApp(self, _cmd, e) : YES;
}

static BOOL (*orig_valPlug)(id, SEL, NSError **) = NULL;
static BOOL hook_valPlug(id self, SEL _cmd, NSError **e) {
	if (gEnabled) { if (e) *e = nil; return YES; }
	return orig_valPlug ? orig_valPlug(self, _cmd, e) : YES;
}

static BOOL (*orig_devErr)(id, SEL, NSError **) = NULL;
static BOOL hook_devErr(id self, SEL _cmd, NSError **e) {
	if (gEnabled) { if (e) *e = nil; return YES; }
	return orig_devErr ? orig_devErr(self, _cmd, e) : YES;
}

static BOOL (*orig_compatFam)(id, SEL, int) = NULL;
static BOOL hook_compatFam(id self, SEL _cmd, int f) {
	if (gEnabled) return YES;
	return orig_compatFam ? orig_compatFam(self, _cmd, f) : YES;
}

static BOOL (*orig_skipFam)(id, SEL) = NULL;
static BOOL hook_skipFam(id self, SEL _cmd) {
	if (gEnabled) return YES;
	return orig_skipFam ? orig_skipFam(self, _cmd) : NO;
}

static BOOL (*orig_skipThin)(id, SEL) = NULL;
static BOOL hook_skipThin(id self, SEL _cmd) {
	if (gEnabled) return YES;
	return orig_skipThin ? orig_skipThin(self, _cmd) : NO;
}

static BOOL (*orig_verifyMeta)(id, SEL, NSError **) = NULL;
static BOOL hook_verifyMeta(id self, SEL _cmd, NSError **e) {
	if (gEnabled) { if (e) *e = nil; return YES; }
	return orig_verifyMeta ? orig_verifyMeta(self, _cmd, e) : YES;
}

static BOOL (*orig_verifySub)(id, SEL, NSError **) = NULL;
static BOOL hook_verifySub(id self, SEL _cmd, NSError **e) {
	if (gEnabled) { if (e) *e = nil; return YES; }
	return orig_verifySub ? orig_verifySub(self, _cmd, e) : YES;
}

static BOOL (*orig_valIdent)(id, SEL, id, NSError **) = NULL;
static BOOL hook_valIdent(id self, SEL _cmd, id a, NSError **e) {
	if (gEnabled) { if (e) *e = nil; return YES; }
	return orig_valIdent ? orig_valIdent(self, _cmd, a, e) : YES;
}

static BOOL (*orig_wk)(id, SEL, id, NSError **) = NULL;
static BOOL hook_wk(id self, SEL _cmd, id a, NSError **e) {
	if (gEnabled) { if (e) *e = nil; return YES; }
	return orig_wk ? orig_wk(self, _cmd, a, e) : YES;
}

static BOOL (*orig_plugVal)(id, SEL, NSError **) = NULL;
static BOOL hook_plugVal(id self, SEL _cmd, NSError **e) {
	if (gEnabled) { if (e) *e = nil; return YES; }
	return orig_plugVal ? orig_plugVal(self, _cmd, e) : YES;
}

static void LITryHook(Class cls, SEL sel, IMP neu, IMP *orig) {
	if (!cls || !class_getInstanceMethod(cls, sel)) return;
	MSHookMessageEx(cls, sel, neu, orig);
}

static void LIInstallInstalldHooks(void) {
	Class miBundle = objc_getClass("MIBundle");
	Class miInstallable = objc_getClass("MIInstallableBundle");
	Class miExec = objc_getClass("MIExecutableBundle");
	Class miPlugin = objc_getClass("MIPluginKitPluginBundle");
	Class miCfg = objc_getClass("MIDaemonConfiguration");

	if (miCfg) {
		LITryHook(miCfg, @selector(skipDeviceFamilyCheck), (IMP)hook_skipFam, (IMP *)&orig_skipFam);
		LITryHook(miCfg, @selector(skipThinningCheck), (IMP)hook_skipThin, (IMP *)&orig_skipThin);
	}

	if (miBundle) {
		LITryHook(miBundle, @selector(minimumOSVersion), (IMP)hook_minOS, (IMP *)&orig_minOS);
		LITryHook(miBundle, @selector(supportedDevices), (IMP)hook_devices, (IMP *)&orig_devices);
		LITryHook(miBundle, @selector(isApplicableToCurrentDeviceFamilyWithError:), (IMP)hook_famErr, (IMP *)&orig_famErr);
		LITryHook(miBundle, @selector(isApplicableToCurrentOSVersionWithError:), (IMP)hook_osErr, (IMP *)&orig_osErr);
		LITryHook(miBundle, @selector(isApplicableToOSVersion:error:), (IMP)hook_osVerErr, (IMP *)&orig_osVerErr);
		LITryHook(miBundle, @selector(isApplicableToCurrentDeviceCapabilitiesWithError:), (IMP)hook_capErr, (IMP *)&orig_capErr);
		LITryHook(miBundle, @selector(thinningMatchesCurrentDeviceWithError:), (IMP)hook_thinErr, (IMP *)&orig_thinErr);
		LITryHook(miBundle, @selector(validateAppMetadataWithError:), (IMP)hook_valApp, (IMP *)&orig_valApp);
		LITryHook(miBundle, @selector(validatePluginMetadataWithError:), (IMP)hook_valPlug, (IMP *)&orig_valPlug);
		LITryHook(miBundle, @selector(isApplicableToCurrentDeviceWithError:), (IMP)hook_devErr, (IMP *)&orig_devErr);
		LITryHook(miBundle, @selector(isCompatibleWithDeviceFamily:), (IMP)hook_compatFam, (IMP *)&orig_compatFam);
	}

	if (miInstallable) {
		LITryHook(miInstallable, @selector(_verifyBundleMetadataWithError:), (IMP)hook_verifyMeta, (IMP *)&orig_verifyMeta);
		LITryHook(miInstallable, @selector(_verifySubBundleMetadataWithError:), (IMP)hook_verifySub, (IMP *)&orig_verifySub);
		LITryHook(miInstallable, @selector(_validateApplicationIdentifierForNewBundleSigningInfo:error:), (IMP)hook_valIdent, (IMP *)&orig_valIdent);
	}

	if (miExec) {
		LITryHook(miExec, @selector(hasOnlyAllowedWatchKitAppInfoPlistKeysForWatchKitVersion:error:), (IMP)hook_wk, (IMP *)&orig_wk);
	}

	if (miPlugin) {
		LITryHook(miPlugin, @selector(validateBundleMetadataWithError:), (IMP)hook_plugVal, (IMP *)&orig_plugVal);
	}
}

#pragma mark - Store UA (Logos)

%group StoreHooks

%hook NSMutableURLRequest

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
	if (gEnabled && field && value) {
		if ([field caseInsensitiveCompare:@"User-Agent"] == NSOrderedSame) {
			value = LISpoofUserAgent(value);
		}
	}
	%orig(value, field);
}

- (void)addValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
	if (gEnabled && field && value && [field caseInsensitiveCompare:@"User-Agent"] == NSOrderedSame) {
		value = LISpoofUserAgent(value);
	}
	%orig(value, field);
}

%end

%end

static NSString *(*orig_uiSysVer)(id, SEL) = NULL;
static NSString *hook_uiSysVer(id self, SEL _cmd) {
	if (gEnabled && gSpoofVersion.length) return gSpoofVersion;
	return orig_uiSysVer ? orig_uiSysVer(self, _cmd) : LICurrentOSVersion();
}

static void LIHookUIDeviceIfPresent(void) {
	Class uid = objc_getClass("UIDevice");
	if (!uid) return;
	LITryHook(uid, @selector(systemVersion), (IMP)hook_uiSysVer, (IMP *)&orig_uiSysVer);
}

#pragma mark - ctor

%ctor {
	@autoreleasepool {
		gCurrentDevice = [LICurrentMachine() copy];
		gCurrentVersion = [LICurrentOSVersion() copy];
		LILoadPrefs();

		CFNotificationCenterAddObserver(
			CFNotificationCenterGetDarwinNotifyCenter(),
			NULL,
			LIPrefsCallback,
			CFSTR(PREFS_CHANGED),
			NULL,
			CFNotificationSuspensionBehaviorCoalesce
		);

		const char *prog = __progname ?: "";

		if (strcmp(prog, "installd") == 0) {
			LIInstallInstalldHooks();
		} else {
			// appstored, itunesstored, AppStore, etc.
			%init(StoreHooks);
			LIHookUIDeviceIfPresent();
		}
	}
}
