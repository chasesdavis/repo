// LowerInstall 1.2 — iOS 15–17 RootHide / rootless
//
// Why 1.1 still failed for "requires iOS 18" updates:
//  - Injecting App Store.app is not enough; compatibility is decided in
//    appstored + MobileGestalt ProductVersion, not only User-Agent.
//  - Modern store UA is "iOS/x.y.z"; we now also spoof Gestalt / UIDevice /
//    NSProcessInfo so AMS + appstored agree you're on a newer OS.
//
// Scope: spoof identity for store/install only — not a full system fake.

#import <Foundation/Foundation.h>
#import <substrate.h>
#import <objc/runtime.h>
#import <sys/utsname.h>
#import <notify.h>
#import <string.h>
#import <dlfcn.h>
#import <os/log.h>

extern const char *__progname;

#define PLIST_PATH @"/var/mobile/Library/Preferences/com.julioverne.lowerinstall.plist"
#define PREFS_DOMAIN "com.julioverne.lowerinstall"
#define PREFS_CHANGED "com.julioverne.lowerinstall/SettingsChanged"
// High default: AppStoreTroller uses 99.0.0 for purchase; 18.5 is enough for iOS-18-min apps
#define DEFAULT_SPOOF_VERSION @"18.5"

static BOOL gEnabled = YES;
static NSString *gSpoofDevice = nil;
static NSString *gSpoofVersion = nil;
static NSString *gCurrentDevice = nil;
static NSString *gCurrentVersion = nil;

static os_log_t LILog(void) {
	static os_log_t log;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ log = os_log_create("com.chasedavis.lowerinstall", "spoof"); });
	return log;
}

#pragma mark - Identity / prefs

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
			? [dev copy] : [gCurrentDevice copy];

		NSString *ver = LIPrefObject(@"SpoofVersion");
		// If user left real version saved from 1.0 defaults, bump them
		if ([ver isKindOfClass:[NSString class]] && ver.length) {
			if ([ver isEqualToString:gCurrentVersion] || [ver compare:@"18.0" options:NSNumericSearch] == NSOrderedAscending) {
				gSpoofVersion = [DEFAULT_SPOOF_VERSION copy];
			} else {
				gSpoofVersion = [ver copy];
			}
		} else {
			gSpoofVersion = [DEFAULT_SPOOF_VERSION copy];
		}

		os_log(LILog(), "prefs enabled=%{public}d spoof=%{public}@ device=%{public}@ real=%{public}@ prog=%{public}s",
			gEnabled, gSpoofVersion, gSpoofDevice, gCurrentVersion, __progname ?: "?");
	}
}

static void LIPrefsCallback(CFNotificationCenterRef c, void *o, CFStringRef n, const void *obj, CFDictionaryRef u) {
	LILoadPrefs();
}

static NSString *LIActiveSpoofVersion(void) {
	if (!gEnabled) return gCurrentVersion ?: LICurrentOSVersion();
	NSString *v = gSpoofVersion.length ? gSpoofVersion : DEFAULT_SPOOF_VERSION;
	if ([v rangeOfString:@"."].location == NSNotFound) v = [v stringByAppendingString:@".0"];
	return v;
}

#pragma mark - User-Agent rewrite

static NSString *LISpoofUserAgent(NSString *value) {
	if (!value.length || !gEnabled) return value;
	NSString *spoofVer = LIActiveSpoofVersion();
	NSMutableString *out = [value mutableCopy];

	NSArray *patterns = @[
		@"iOS/[0-9]+(?:\\.[0-9]+){0,3}",
		@"CPU (?:iPhone )?OS [0-9]+(?:_[0-9]+){0,3}",
		@"iPhone OS [0-9]+(?:_[0-9]+){0,3}",
		@"Version/[0-9]+(?:\\.[0-9]+){0,3}",
		@"/[0-9]+\\.[0-9]+(?:\\.[0-9]+)? ",
	];
	NSString *under = [spoofVer stringByReplacingOccurrencesOfString:@"." withString:@"_"];
	NSArray *replacements = @[
		[NSString stringWithFormat:@"iOS/%@", spoofVer],
		[NSString stringWithFormat:@"CPU iPhone OS %@", under],
		[NSString stringWithFormat:@"iPhone OS %@", under],
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

#pragma mark - MobileGestalt ProductVersion (critical for AMS / appstored)

typedef CFTypeRef (*MGCopyAnswer_t)(CFStringRef);
static MGCopyAnswer_t orig_MGCopyAnswer = NULL;

static CFTypeRef hook_MGCopyAnswer(CFStringRef key) {
	if (gEnabled && key) {
		NSString *k = (__bridge NSString *)key;
		// ProductVersion is what store services trust for "requires iOS X"
		if ([k isEqualToString:@"ProductVersion"] || [k isEqualToString:@"ProductVersionExtra"]) {
			NSString *v = LIActiveSpoofVersion();
			return (__bridge_retained CFTypeRef)v;
		}
		// Optional: claim a generic modern build
		if ([k isEqualToString:@"BuildVersion"] && LIPrefObject(@"SpoofBuild")) {
			id b = LIPrefObject(@"SpoofBuild");
			if ([b isKindOfClass:[NSString class]] && [b length]) {
				return (__bridge_retained CFTypeRef)(NSString *)b;
			}
		}
	}
	return orig_MGCopyAnswer ? orig_MGCopyAnswer(key) : NULL;
}

// Some firmwares use the 2-arg variant
typedef CFTypeRef (*MGCopyAnswerWithError_t)(CFStringRef, int *);
static MGCopyAnswerWithError_t orig_MGCopyAnswerWithError = NULL;

static CFTypeRef hook_MGCopyAnswerWithError(CFStringRef key, int *err) {
	if (gEnabled && key) {
		NSString *k = (__bridge NSString *)key;
		if ([k isEqualToString:@"ProductVersion"] || [k isEqualToString:@"ProductVersionExtra"]) {
			if (err) *err = 0;
			return (__bridge_retained CFTypeRef)LIActiveSpoofVersion();
		}
	}
	return orig_MGCopyAnswerWithError ? orig_MGCopyAnswerWithError(key, err) : NULL;
}

static void LIHookMobileGestalt(void) {
	void *handle = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_LAZY);
	if (!handle) handle = dlopen("/System/Library/PrivateFrameworks/MobileGestalt.framework/MobileGestalt", RTLD_LAZY);
	if (!handle) {
		os_log_error(LILog(), "MobileGestalt dlopen failed");
		return;
	}

	void *sym = dlsym(handle, "MGCopyAnswer");
	if (sym) {
		MSHookFunction(sym, (void *)hook_MGCopyAnswer, (void **)&orig_MGCopyAnswer);
		os_log(LILog(), "hooked MGCopyAnswer");
	}

	void *sym2 = dlsym(handle, "MGCopyAnswerWithError");
	if (sym2) {
		MSHookFunction(sym2, (void *)hook_MGCopyAnswerWithError, (void **)&orig_MGCopyAnswerWithError);
		os_log(LILog(), "hooked MGCopyAnswerWithError");
	}
}

#pragma mark - UIDevice / NSProcessInfo

static NSString *(*orig_uiSysVer)(id, SEL) = NULL;
static NSString *hook_uiSysVer(id self, SEL _cmd) {
	if (gEnabled) return LIActiveSpoofVersion();
	return orig_uiSysVer ? orig_uiSysVer(self, _cmd) : LICurrentOSVersion();
}

static NSString *(*orig_procVerStr)(id, SEL) = NULL;
static NSString *hook_procVerStr(id self, SEL _cmd) {
	if (gEnabled) {
		// "Version 18.5 (Build 22F76)" style — build optional
		return [NSString stringWithFormat:@"Version %@ (Build 22F76)", LIActiveSpoofVersion()];
	}
	return orig_procVerStr ? orig_procVerStr(self, _cmd) : @"Version 17.0";
}

// operatingSystemVersion returns NSOperatingSystemVersion by value — use objc_msgSend style hook carefully
static NSOperatingSystemVersion (*orig_osVerStruct)(id, SEL) = NULL;
static NSOperatingSystemVersion hook_osVerStruct(id self, SEL _cmd) {
	if (gEnabled) {
		NSString *v = LIActiveSpoofVersion();
		NSArray *parts = [v componentsSeparatedByString:@"."];
		NSOperatingSystemVersion ov = {0, 0, 0};
		if (parts.count > 0) ov.majorVersion = [parts[0] integerValue];
		if (parts.count > 1) ov.minorVersion = [parts[1] integerValue];
		if (parts.count > 2) ov.patchVersion = [parts[2] integerValue];
		return ov;
	}
	if (orig_osVerStruct) return orig_osVerStruct(self, _cmd);
	return (NSOperatingSystemVersion){17, 0, 0};
}

static void LITryHook(Class cls, SEL sel, IMP neu, IMP *orig) {
	if (!cls || !class_getInstanceMethod(cls, sel)) return;
	MSHookMessageEx(cls, sel, neu, orig);
}

static void LIHookSystemVersionAPIs(void) {
	Class uid = objc_getClass("UIDevice");
	if (uid) LITryHook(uid, @selector(systemVersion), (IMP)hook_uiSysVer, (IMP *)&orig_uiSysVer);

	Class nspi = objc_getClass("NSProcessInfo");
	if (nspi) {
		LITryHook(nspi, @selector(operatingSystemVersionString), (IMP)hook_procVerStr, (IMP *)&orig_procVerStr);
		// struct return: still try — works on arm64 with MSHookMessageEx for most cases
		Method m = class_getInstanceMethod(nspi, @selector(operatingSystemVersion));
		if (m) {
			MSHookMessageEx(nspi, @selector(operatingSystemVersion), (IMP)hook_osVerStruct, (IMP *)&orig_osVerStruct);
		}
	}
}

#pragma mark - installd soft hooks

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

#define LI_BOOL_ERR(name) \
static BOOL (*orig_##name)(id, SEL, NSError **) = NULL; \
static BOOL hook_##name(id self, SEL _cmd, NSError **e) { \
	if (gEnabled) { if (e) *e = nil; return YES; } \
	return orig_##name ? orig_##name(self, _cmd, e) : YES; \
}

LI_BOOL_ERR(famErr)
LI_BOOL_ERR(osErr)
LI_BOOL_ERR(capErr)
LI_BOOL_ERR(thinErr)
LI_BOOL_ERR(valApp)
LI_BOOL_ERR(valPlug)
LI_BOOL_ERR(devErr)
LI_BOOL_ERR(verifyMeta)
LI_BOOL_ERR(verifySub)
LI_BOOL_ERR(plugVal)

static BOOL (*orig_osVerErr)(id, SEL, id, NSError **) = NULL;
static BOOL hook_osVerErr(id self, SEL _cmd, id a, NSError **e) {
	if (gEnabled) { if (e) *e = nil; return YES; }
	return orig_osVerErr ? orig_osVerErr(self, _cmd, a, e) : YES;
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

static BOOL (*orig_valIdent)(id, SEL, id, NSError **) = NULL;
static BOOL hook_valIdent(id self, SEL _cmd, id a, NSError **e) {
	if (gEnabled) { if (e) *e = nil; return YES; }
	return orig_valIdent ? orig_valIdent(self, _cmd, a, e) : YES;
}

static void LIInstallInstalldHooks(void) {
	Class miBundle = objc_getClass("MIBundle");
	Class miInstallable = objc_getClass("MIInstallableBundle");
	Class miCfg = objc_getClass("MIDaemonConfiguration");
	Class miPlugin = objc_getClass("MIPluginKitPluginBundle");

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
	if (miPlugin) {
		LITryHook(miPlugin, @selector(validateBundleMetadataWithError:), (IMP)hook_plugVal, (IMP *)&orig_plugVal);
	}
	os_log(LILog(), "installd hooks installed miBundle=%{public}d", miBundle != nil);
}

#pragma mark - Store request hooks

%group StoreHooks

%hook NSMutableURLRequest

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
	if (gEnabled && field && value && [field caseInsensitiveCompare:@"User-Agent"] == NSOrderedSame) {
		NSString *spoofed = LISpoofUserAgent(value);
		if (![spoofed isEqualToString:value]) {
			os_log_debug(LILog(), "UA spoofed");
		}
		value = spoofed;
	}
	%orig(value, field);
}

- (void)addValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
	if (gEnabled && field && value && [field caseInsensitiveCompare:@"User-Agent"] == NSOrderedSame) {
		value = LISpoofUserAgent(value);
	}
	%orig(value, field);
}

// Whole header dictionary path used by some AMS clients
- (void)setAllHTTPHeaderFields:(NSDictionary *)headerFields {
	if (gEnabled && headerFields) {
		NSMutableDictionary *mut = [headerFields mutableCopy];
		for (NSString *key in headerFields) {
			if ([key caseInsensitiveCompare:@"User-Agent"] == NSOrderedSame) {
				id v = headerFields[key];
				if ([v isKindOfClass:[NSString class]]) mut[key] = LISpoofUserAgent(v);
			}
		}
		headerFields = mut;
	}
	%orig(headerFields);
}

%end

%end

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
		os_log(LILog(), "loaded into %{public}s", prog);

		// Identity spoof everywhere we inject (App Store UI + appstored + installd)
		// installd also benefits from Gestalt when validating metadata against "current OS"
		LIHookMobileGestalt();
		LIHookSystemVersionAPIs();

		if (strcmp(prog, "installd") == 0) {
			LIInstallInstalldHooks();
		} else {
			// appstored / itunesstored / AppStore / any other filtered target
			%init(StoreHooks);
		}
	}
}
