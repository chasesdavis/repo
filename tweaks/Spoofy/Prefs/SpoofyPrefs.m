#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>
#import <roothide.h>
#import "SpoofyConfig.h"

@interface SpoofyPrefsController : PSListController
@end

@implementation SpoofyPrefsController
- (NSString *)configPath {
    return jbroot(SPOOFY_CONFIG_PATH);
}
- (NSArray *)specifiers {
    if (!_specifiers) {
        PSSpecifier *group = [PSSpecifier groupSpecifierWithName:@"App Store display experiment"];
        [group setProperty:@"Experimental: only reports iOS 18.0 through one App Store API. It does not install updates or add missing iOS features. Close and reopen the App Store after changing this switch." forKey:@"footerText"];
        PSSpecifier *toggle = [PSSpecifier preferenceSpecifierNamed:@"Enabled" target:self
            set:@selector(setEnabled:specifier:) get:@selector(readEnabled:)
            detail:nil cell:PSSwitchCell edit:nil];
        _specifiers = [@[group, toggle] mutableCopy];
    }
    return _specifiers;
}
- (id)readEnabled:(PSSpecifier *)specifier {
    (void)specifier;
    NSDictionary *config = SpoofyReadConfig(self.configPath);
    id enabled = config[@"Enabled"];
    return @([enabled isKindOfClass:NSNumber.class] && [enabled boolValue]);
}
- (void)setEnabled:(id)value specifier:(PSSpecifier *)specifier {
    (void)specifier;
    BOOL ok = SpoofySaveEnabled(self.configPath, [value boolValue]);
    if (!ok) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Could not save spoofy settings"
            message:@"The experiment is unchanged. Check RootHide storage access before trying again."
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
    [self reloadSpecifiers];
}
@end
