// LowerInstall 1.2.1 — Safe Mode fix
//
// 1.2 could crash SpringBoard when Bootstrap injected the dylib too broadly:
//   - MSHookFunction(MGCopyAnswer) + NSProcessInfo struct-return hooks
//     are unsafe outside appstored/installd.
//
// 1.2.1:
//   - Hard process allowlist (bail immediately on SpringBoard / system UI)
//   - No struct-return hooks
//   - Gestalt spoof only inside appstored / installd / AppStore
//   - UA spoof only in store processes
//   - installd hooks only in installd

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

#pragma mark - Process gate (Safe Mode prevention)

static BOOL LIIsDeniedProcess(const char *prog) {
	if (!prog || !prog[0]) return YES;
	// Never touch SpringBoard / UI services — Safe Mode territory
	static const char *denied[] = {
		"SpringBoard",
		"backboardd",
		"UserEventAgent",
		"Preferences",
		"preferencebundled",
		"ReportCrash",
		"mediaserverd",
		"runningboardd",
		"launchd",
		NULL
	};
	for (int i = 0; denied[i]; i++) {
		if (strcmp(prog, denied[i]) == 0) return YES;
	}
	return NO;
}

static BOOL LIIsInstalld(const char *prog) {
	return prog && strcmp(prog, "installd") == 0;
}

static BOOL LIIsStoreDaemon(const char *prog) {
	if (!prog) return NO;
	return strcmp(prog, "appstored") == 0
		|| strcmp(prog, "itunesstored") == 0
		|| strcmp(prog, "AppStore") == 0;
}

static BOOL LIIsAllowedProcess(const char *prog) {
	return LIIsInstalld(prog) || LIIsStoreDaemon(prog);
}

#pragma mark - Prefs

static NSString *LICurrentOSVersion(void) {
	// Prefer Gestalt-free path so we never depend on hooked APIs during init
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
		if ([ver isKindOfClass:[NSString class]] && ver.length) {
			// If prefs still hold real OS from old defaults, bump
			if (gCurrentVersion && [ver isEqualToString:gCurrentVersion]) {
				gSpoofVersion = [DEFAULT_SPOOF_VERSION copy];
			} else if ([ver compare:@"18.0" options:NSNumericSearch] == NSOrderedAscending) {
				gSpoofVersion = [DEFAULT_SPOOF_VERSION copy];
			} else {
				gSpoofVersion = [ver copy];
			}
		} else {
			gSpoofVersion = [DEFAULT_SPOOF_VERSION copy];
		}
	}
}

static void LIPrefsCallback(CFNotificationCenterRef c, void *o, CFStringRef n, const void *obj, CFDictionaryRef u) {
	LILoadPrefs();
}

static NSString *LIActiveSpoofVersion(void) {
	if (!gEnabled) return gCurrentVersion ?: @"17.0";
	NSString *v = gSpoofVersion.length ? gSpoofVersion : DEFAULT_SPOOF_VERSION;
	if ([v rangeOfString:@"."].location == NSNotFound) v = [v stringByAppendingString:@".0"];
	return v;
}

#pragma mark - User-Agent

static NSString *LISpoofUserAgent(NSString *value) {
	if (!value.length || !gEnabled) return value;
	NSString *spoofVer = LIActiveSpoofVersion();
	NSMutableString *out = [value mutableCopy];
	NSString *under = [spoofVer stringByReplacingOccurrencesOfString:@"." withString:@"_"];

	NSArray *patterns = @[
		@"iOS/[0-9]+(?:\\.[0-9]+){0,3}",
		@"CPU (?:iPhone )?OS [0-9]+(?:_[0-9]+){0,3}",
		@"iPhone OS [0-9]+(?:_[0-9]+){0,3}",
		@"Version/[0-9]+(?:\\.[0-9]+){0,3}",
	];
	NSArray *replacements = @[
		[NSString stringWithFormat:@"iOS/%@", spoofVer],
		[NSString stringWithFormat:@"CPU iPhone OS %@", under],
		[NSString stringWithFormat:@"iPhone OS %@", under],
		[NSString stringWithFormat:@"Version/%@", spoofVer],
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

#pragma mark - MobileGestalt (store + installd only)

typedef CFTypeRef (*MGCopyAnswer_t)(CFStringRef);
static MGCopyAnswer_t orig_MGCopyAnswer = NULL;

static CFTypeRef hook_MGCopyAnswer(CFStringRef key) {
	if (gEnabled && key) {
		CFStringRef productVersion = CFSTR("ProductVersion");
		CFStringRef productVersionExtra = CFSTR("ProductVersionExtra");
		if (CFEqual(key, productVersion) || CFEqual(key, productVersionExtra)) {
			NSString *v = LIActiveSpoofVersion();
			// Caller owns return (Create rule) — use CFStringCreate*
			return CFStringCreateWithCString(kCFAllocatorDefault, v.UTF8String, kCFStringEncodingUTF8);
		}
	}
	return orig_MGCopyAnswer ? orig_MGCopyAnswer(key) : NULL;
}

static void LIHookMobileGestalt(void) {
	void *handle = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_LAZY);
	if (!handle) return;
	void *sym = dlsym(handle, "MGCopyAnswer");
	if (!sym) return;
	// ElleKit may not implement MSHookFunction on all builds — guard
	@try {
		MSHookFunction(sym, (void *)hook_MGCopyAnswer, (void **)&orig_MGCopyAnswer);
		os_log(LILog(), "MGCopyAnswer hooked");
	} @catch (__unused id e) {
		os_log_error(LILog(), "MGCopyAnswer hook failed");
	}
}

#pragma mark - UIDevice systemVersion only (no struct returns)

static NSString *(*orig_uiSysVer)(id, SEL) = NULL;
static NSString *hook_uiSysVer(id self, SEL _cmd) {
	if (gEnabled) return LIActiveSpoofVersion();
	return orig_uiSysVer ? orig_uiSysVer(self, _cmd) : LICurrentOSVersion();
}

static void LITryHook(Class cls, SEL sel, IMP neu, IMP *orig) {
	if (!cls || !class_getInstanceMethod(cls, sel)) return;
	MSHookMessageEx(cls, sel, neu, orig);
}

static void LIHookUIDeviceVersion(void) {
	Class uid = objc_getClass("UIDevice");
	if (!uid) return;
	LITryHook(uid, @selector(systemVersion), (IMP)hook_uiSysVer, (IMP *)&orig_uiSysVer);
}

#pragma mark - installd

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

static void LIInstallInstalldHooks(void) {
	Class miBundle = objc_getClass("MIBundle");
	Class miInstallable = objc_getClass("MIInstallableBundle");
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
	}
}

#pragma mark - Store UA hooks

%group StoreHooks

%hook NSMutableURLRequest

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
	if (gEnabled && field && value && [field caseInsensitiveCompare:@"User-Agent"] == NSOrderedSame) {
		value = LISpoofUserAgent(value);
	}
	%orig(value, field);
}

- (void)addValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
	if (gEnabled && field && value && [field caseInsensitiveCompare:@"User-Agent"] == NSOrderedSame) {
		value = LISpoofUserAgent(value);
	}
	%orig(value, field);
}

- (void)setAllHTTPHeaderFields:(NSDictionary *)headerFields {
	if (gEnabled && headerFields.count) {
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
		const char *prog = __progname ?: "";

		// 1) Absolute deny — never run in SpringBoard / system UI (Safe Mode fix)
		if (LIIsDeniedProcess(prog)) {
			return;
		}

		// 2) Allowlist only
		if (!LIIsAllowedProcess(prog)) {
			return;
		}

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

		os_log(LILog(), "active in %{public}s spoof=%{public}@", prog, LIActiveSpoofVersion());

		if (LIIsInstalld(prog)) {
			// installd: version checks on packages + light Gestalt
			LIHookMobileGestalt();
			LIInstallInstalldHooks();
			return;
		}

		if (LIIsStoreDaemon(prog)) {
			// appstored / AppStore: UA + Gestalt + UIDevice (AppStore UI only has UIDevice)
			LIHookMobileGestalt();
			LIHookUIDeviceVersion();
			%init(StoreHooks);
			return;
		}
	}
}
