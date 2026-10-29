#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import "../LumenPrefs.h"

static NSString *const kLumenPayPalURL = @"https://paypal.me/chasesdavis97";
static NSString *const kLumenCashAppURL = @"https://cash.app/$driipbiz";
static NSString *const kLumenDonateEmail = @"chasesdavis97@gmail.com";

@interface LumenPrefsController : PSListController
@end

@implementation LumenPrefsController

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *specs = [NSMutableArray array];
        [specs addObjectsFromArray:[self loadSpecifiersFromPlistName:@"LumenPrefsController" target:self]];
        PSSpecifier *paypal = [PSSpecifier preferenceSpecifierNamed:@"Donate with PayPal"
                                                               target:self
                                                                  set:nil
                                                                  get:nil
                                                               detail:nil
                                                                 cell:PSButtonCell
                                                                 edit:nil];
        paypal->action = @selector(openPayPal);
        [specs addObject:paypal];
        PSSpecifier *cashapp = [PSSpecifier preferenceSpecifierNamed:@"Donate with Cash App"
                                                               target:self
                                                                  set:nil
                                                                  get:nil
                                                               detail:nil
                                                                 cell:PSButtonCell
                                                                 edit:nil];
        cashapp->action = @selector(openCashApp);
        [specs addObject:cashapp];
        _specifiers = specs;
    }
    return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if ([key isEqualToString:@"countdownDateText"]) {
        NSDate *date = LumenCountdownDate();
        if (!date) return @"";
        static NSDateFormatter *formatter;
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            formatter = [NSDateFormatter new];
            formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
            formatter.dateFormat = @"yyyy-MM-dd";
        });
        return [formatter stringFromDate:date];
    }
    id value = [super readPreferenceValue:specifier];
    return value ?: [specifier propertyForKey:@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    [super setPreferenceValue:value specifier:specifier];
    NSString *key = [specifier propertyForKey:@"key"];
    if ([key isEqualToString:@"countdownDateText"]) {
        [self storeCountdownFromText:value];
    }
    LumenReloadPrefs();
}

- (void)storeCountdownFromText:(NSString *)text {
    static NSDateFormatter *parser;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        parser = [NSDateFormatter new];
        parser.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        parser.dateFormat = @"yyyy-MM-dd";
    });
    NSDate *date = [[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet] length]
        ? [parser dateFromString:text] : nil;
    LumenSetPref(@"countdownDate", date ? @([date timeIntervalSince1970]) : nil);
}

- (void)openPayPal { [self open:kLumenPayPalURL]; }
- (void)openCashApp { [self open:kLumenCashAppURL]; }
- (void)open:(NSString *)url {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url] options:@{} completionHandler:nil];
}

@end
