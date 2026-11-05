#import <UIKit/UIKit.h>
#import <os/log.h>
#import <roothide.h>
#import "SpoofyPolicy.h"
#import "SpoofyConfig.h"

static NSString *replacement;

%group VersionExperiment
%hook UIDevice
- (NSString *)systemVersion {
    NSString *actual = %orig;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        os_log(OS_LOG_DEFAULT, "[spoofy] UIDevice.systemVersion reached; experiment active");
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
        replacement = SpoofyReplacement(config, NSBundle.mainBundle.bundleIdentifier, actual);
        if (!replacement) {
            os_log(OS_LOG_DEFAULT, "[spoofy] loaded; pass-through (disabled, invalid config, or unsupported OS)");
            return;
        }
        os_log(OS_LOG_DEFAULT, "[spoofy] loaded; UIDevice version experiment enabled");
        %init(VersionExperiment);
    }
}
