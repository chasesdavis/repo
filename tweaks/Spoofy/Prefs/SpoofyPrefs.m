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
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    _specifiers = nil;
    [self reloadSpecifiers];
}
- (NSArray *)specifiers {
    if (!_specifiers) {
        PSSpecifier *group = [PSSpecifier groupSpecifierWithName:@"App Store display experiment"];
        [group setProperty:@"Experimental: only reports iOS 18.0 through one App Store API. It does not install updates or add missing iOS features. Close and reopen the App Store after changing this switch." forKey:@"footerText"];
        PSSpecifier *toggle = [PSSpecifier preferenceSpecifierNamed:@"Enabled" target:self
            set:@selector(setEnabled:specifier:) get:@selector(readEnabled:)
            detail:nil cell:PSSwitchCell edit:nil];
        PSSpecifier *diagGroup = [PSSpecifier groupSpecifierWithName:@"Diagnostics (optional)"];
        [diagGroup setProperty:@"Records a status, time and three call indicators in the jailbreak data area. A call may come from any App Store code, including diagnostics. No report or an old report is inconclusive. Close App Store before clearing the report and relaunch it to start a new observation." forKey:@"footerText"];
        PSSpecifier *diagToggle = [PSSpecifier preferenceSpecifierNamed:@"Record App Store status" target:self
            set:@selector(setDiagnostics:specifier:) get:@selector(readDiagnostics:)
            detail:nil cell:PSSwitchCell edit:nil];
        NSDictionary *report = SpoofyReadConfig(jbroot(SPOOFY_DIAGNOSTIC_PATH));
        NSString *state = [report[@"state"] isKindOfClass:NSString.class] ? report[@"state"] : @"none";
        NSDate *date = [report[@"timestamp"] isKindOfClass:NSDate.class] ? report[@"timestamp"] : nil;
        NSDictionary *labels = @{@"loaded_passthrough": @"Loaded: pass-through", @"loaded_enabled": @"Loaded: enabled", @"hook_change_observed": @"Hook change observed", @"hook_not_confirmed": @"Hook not confirmed", @"getter_called": @"Version getter called"};
        NSString *label = date ? (labels[state] ?: @"Unknown status") : @"No status recorded";
        PSSpecifier *status = [PSSpecifier preferenceSpecifierNamed:label target:self set:nil get:nil detail:nil cell:PSStaticTextCell edit:nil];
        NSString *time = date ? [NSDateFormatter localizedStringFromDate:date dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterMediumStyle] : @"Time: —";
        PSSpecifier *stamp = [PSSpecifier preferenceSpecifierNamed:time target:self set:nil get:nil detail:nil cell:PSStaticTextCell edit:nil];
        NSMutableArray *rows = [@[group, toggle, diagGroup, diagToggle, status, stamp] mutableCopy];
        for (NSArray *pair in @[@[@"deviceVersion", @"Device version"], @[@"processVersion", @"Process version"], @[@"processMinimum", @"Minimum-version check"]]) {
            id value = report[pair[0]];
            BOOL valid = value && CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID();
            NSString *result = valid && [value boolValue] ? @"seen" : @"not recorded";
            NSString *text = [NSString stringWithFormat:@"%@: %@", pair[1], result];
            [rows addObject:[PSSpecifier preferenceSpecifierNamed:text target:self set:nil get:nil detail:nil cell:PSStaticTextCell edit:nil]];
        }
        PSSpecifier *clear = [PSSpecifier preferenceSpecifierNamed:@"Clear diagnostic report" target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
        clear.buttonAction = @selector(clearDiagnostic:);
        [rows addObject:clear];
        _specifiers = rows;
    }
    return _specifiers;
}
- (void)clearDiagnostic:(PSSpecifier *)specifier {
    (void)specifier;
    if (!SpoofyClearDiagnostic(jbroot(SPOOFY_DIAGNOSTIC_PATH))) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Could not clear report" message:@"The report was not removed." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
    _specifiers = nil;
    [self reloadSpecifiers];
}
- (id)readDiagnostics:(PSSpecifier *)specifier {
    (void)specifier;
    return @(SpoofyDiagnosticsEnabled(SpoofyReadConfig(self.configPath)));
}
- (void)setDiagnostics:(id)value specifier:(PSSpecifier *)specifier {
    (void)specifier;
    if (!SpoofySaveDiagnostics(self.configPath, [value boolValue])) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Could not save diagnostics setting" message:@"The setting is unchanged." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
    _specifiers = nil;
    [self reloadSpecifiers];
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
