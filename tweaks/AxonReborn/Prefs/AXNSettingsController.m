// SPDX-License-Identifier: GPL-3.0-only
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <notify.h>
#import "../Shared/AXNPreferences.h"
@interface AXNSettingsController : PSListController
@property(nonatomic, strong) NSMutableArray<NSNumber *> *diagnosticTokens;
@property(nonatomic) BOOL waitingForDiagnostic;
@property(nonatomic) NSUInteger diagnosticGeneration;
@end
@implementation AXNSettingsController
- (NSArray *)specifiers {
    if (!_specifiers) _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    return _specifiers;
}
- (id)readPreferenceValue:(PSSpecifier *)specifier {
    AXNSynchronizePreferences();
    return AXNReadPreference([specifier propertyForKey:@"key"], [specifier propertyForKey:@"default"]);
}
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    AXNWritePreference([specifier propertyForKey:@"key"], value);
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Axon Reborn";
    self.diagnosticTokens = [NSMutableArray new];
    __weak typeof(self) weakSelf = self;
    for (NSUInteger state = 0; state < AXNDiagnosticStateCount; ++state) {
        int token = 0;
        if (notify_register_dispatch(AXNDiagnosticReply(state).UTF8String, &token, dispatch_get_main_queue(), ^(int t) {
            (void)t;
            AXNSettingsController *controller = weakSelf;
            if (controller.waitingForDiagnostic) [controller showDiagnostic:AXNDiagnosticMessage(state)];
        }) == NOTIFY_STATUS_OK) [self.diagnosticTokens addObject:@(token)];
    }
}
- (void)checkSpringBoard {
    if (self.waitingForDiagnostic) return;
    self.waitingForDiagnostic = YES;
    NSUInteger generation = ++self.diagnosticGeneration;
    notify_post(AXNDiagnosticQuery.UTF8String);
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        AXNSettingsController *controller = weakSelf;
        if (controller.waitingForDiagnostic && controller.diagnosticGeneration == generation)
            [controller showDiagnostic:@"No response from Axon in SpringBoard. Confirm alpha2 is installed, respring, and check that your Bootstrap configuration allows this tweak in SpringBoard. A blocked diagnostic notification can also cause this result."];
    });
}
- (void)showDiagnostic:(NSString *)message {
    self.waitingForDiagnostic = NO;
    if (!self.view.window) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Axon alpha2 — SpringBoard" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)dealloc {
    for (NSNumber *token in _diagnosticTokens) notify_cancel(token.intValue);
}
@end
