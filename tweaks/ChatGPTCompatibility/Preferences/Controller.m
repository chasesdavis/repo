#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>
#import "../Configuration.h"
#import "../CompatPolicy.h"
#import <notify.h>

@interface CGCPreferencesController : PSListController
@end

@implementation CGCPreferencesController
- (NSString *)runtimeStatusText {
    return [NSString stringWithFormat:
        @"Store process loaded: %@\nLate store hook installed: %@\nMatching ChatGPT request seen: %@\n\ninstalld loaded: %@\nInstaller hook installed: %@\nMatching 1.2026.272 bundle seen: %@",
        CGCReadStatus(CGC_STATUS_STORE_PROCESS_LOADED) ? @"YES" : @"NO",
        CGCReadStatus(CGC_STATUS_STORE_HOOKED) ? @"YES" : @"NO",
        CGCReadStatus(CGC_STATUS_STORE_MATCHED) ? @"YES" : @"NO",
        CGCReadStatus(CGC_STATUS_INSTALLD_LOADED) ? @"YES" : @"NO",
        CGCReadStatus(CGC_STATUS_INSTALLER_HOOKED) ? @"YES" : @"NO",
        CGCReadStatus(CGC_STATUS_INSTALLER_MATCHED) ? @"YES" : @"NO"];
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        PSSpecifier *group = [PSSpecifier groupSpecifierWithName:@"Experimental beta"];
        [group setProperty:@"Not device-tested. Limited to iPhone16,2 on iOS 17.0 and ChatGPT 1.2026.272. Installation, launch, and dot access are unverified. Missing iOS 18 frameworks are not supplied." forKey:@"footerText"];
        PSSpecifier *toggle = [PSSpecifier preferenceSpecifierNamed:@"Enable ChatGPT experiment" target:self set:@selector(setEnabled:specifier:) get:@selector(readEnabled:) detail:Nil cell:PSSwitchCell edit:Nil];
        [toggle setProperty:@NO forKey:@"default"];
        PSSpecifier *scope = [PSSpecifier emptyGroupSpecifier];
        [scope setProperty:@"OFF by default. Only identified single-ChatGPT store requests and the target bundle's minimum-OS comparison can change. Signatures, receipts, account access, other apps, and app files are untouched by this tweak. A normal App Store update still replaces the installed app." forKey:@"footerText"];
        PSSpecifier *status = [PSSpecifier groupSpecifierWithName:@"Runtime status"];
        [status setProperty:[self runtimeStatusText] forKey:@"footerText"];
        PSSpecifier *refresh = [PSSpecifier preferenceSpecifierNamed:@"Refresh runtime status" target:self set:nil get:nil detail:Nil cell:PSButtonCell edit:Nil];
        refresh->action = @selector(refreshRuntimeStatus);
        PSSpecifier *remove = [PSSpecifier emptyGroupSpecifier];
        [remove setProperty:@"Disable this switch to return loaded hooks to their original behavior. Remove ChatGPT Compatibility in Sileo to remove its package files. No process is restarted automatically. Removing this tweak does not roll back an App Store update. Existing Bootstrap daemon injection is required; do not enable injection into ChatGPT itself." forKey:@"footerText"];
        _specifiers = [@[group, toggle, scope, status, refresh, remove] mutableCopy];
    }
    return _specifiers;
}
- (void)refreshRuntimeStatus {
    _specifiers = nil;
    [self reloadSpecifiers];
}
- (id)readEnabled:(PSSpecifier *)specifier {
    return @(CGCPreferencesEnabled([NSDictionary dictionaryWithContentsOfFile:CGCPreferencesPath()]));
}
- (void)setEnabled:(id)value specifier:(PSSpecifier *)specifier {
    NSError *error = nil;
    NSDictionary *preferences = @{@"Enabled": @([value boolValue])};
    if (![preferences writeToURL:[NSURL fileURLWithPath:CGCPreferencesPath()] error:&error]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Setting not saved" message:@"The RootHide preferences location could not be written. The experiment has not been enabled by this action." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        [self reloadSpecifiers];
        return;
    }
    notify_post(CGC_SETTINGS_NOTIFICATION);
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"ChatGPT Compatibility";
}
@end
