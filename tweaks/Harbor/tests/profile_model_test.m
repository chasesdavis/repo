#import <Foundation/Foundation.h>
#import "HBProfileModel.h"
#include <math.h>
static NSUInteger checks, failures;
static void Check(BOOL pass, NSString *name) { checks++; if (!pass) failures++; printf("%s: %s\n", pass ? "PASS" : "FAIL", name.UTF8String); }
int main(void) { @autoreleasepool {
    NSDictionary *base = HBDefaultLibrary(@"iris");
    Check([HBProfileWithID(base,@"default")[@"theme"][@"accent"] isEqual:@"#C2B8FF"], @"Existing Iris preference migrates into the default profile");
    Check([HBNormalizeLibrary(base) isEqual:base], @"Normalization preserves a valid library");
    Check(!HBFocusAccessEnabled(base), @"Automatic Focus access defaults off");
    for (id corrupt in @[NSNull.null, @42, @"oops", @[], @{@"schema":@99}, @{@"schema":@1,@"profiles":@[]}]) Check([HBNormalizeLibrary(corrupt)[@"profiles"] count] == 1, @"Corrupt or unsupported library has a recoverable default");
    NSDictionary *bad = HBNormalizeProfile(@{@"theme":@{@"accent":@"#ZZZZZZ", @"opacity":@(NAN), @"spacing":@999, @"radius":@(-20), @"material":@"unknown"}, @"layouts":@{@"compact":@{@"order":@[@"media", @"media", @"bad"], @"hidden":HBSectionKeys()}}});
    Check([bad[@"theme"][@"accent"] isEqual:@"#A3E8D6"] && [bad[@"theme"][@"opacity"] isEqual:@0.72], @"Invalid colors and nonfinite opacity recover safely");
    Check([bad[@"theme"][@"spacing"] isEqual:@18] && [bad[@"theme"][@"radius"] isEqual:@16], @"Geometry is bounded");
    Check([bad[@"layouts"][@"compact"][@"order"] count] == 5 && [bad[@"layouts"][@"compact"][@"order"][0] isEqual:@"media"], @"Duplicate and unknown sections cannot corrupt order");
    Check([bad[@"layouts"][@"compact"][@"hidden"] count] == 4, @"A layout cannot hide every section");
    Check([bad[@"layouts"][@"expanded"][@"hidden"] count] == 0, @"Compact changes do not leak into expanded layout");
    NSMutableDictionary *work = [HBProfileWithID(base,@"default") mutableCopy]; work[@"id"] = @"work"; work[@"name"] = @"Work";
    NSMutableDictionary *library = HBLibraryReplacingProfile(base,work).mutableCopy;
    library[@"automaticFocus"] = @YES; library[@"bindings"] = @{@"actual.exact.identifier":@"work", @"stale":@"missing"}; library[@"focusLabels"] = @{@"actual.exact.identifier":@"Work"};
    NSDictionary *legacy=HBNormalizeLibrary(library);
    Check(!HBFocusAccessEnabled(legacy) && [legacy[@"profiles"] count]==2 && [legacy[@"bindings"] count]==1, @"Legacy matching flags require fresh opt-in and preserve profiles and links");
    for (id invalid in @[@0,@2,@(-1),@(NAN),@"1",NSNull.null]) {
        library[@"focusOptInVersion"]=invalid;
        Check(!HBFocusAccessEnabled(HBNormalizeLibrary(library)), @"Missing, corrupt or unknown opt-in versions cannot enable reads");
    }
    library[@"focusOptInVersion"]=@1;
    Check(HBFocusAccessEnabled(HBNormalizeLibrary(library)), @"An explicit current opt-in enables matching");
    library = HBNormalizeLibrary(library).mutableCopy;
    Check([library[@"bindings"] count] == 1, @"Dangling Focus links are removed");
    Check([HBResolvedProfile(library,@{@"available":@YES,@"active":@YES,@"identifier":@"actual.exact.identifier"})[@"id"] isEqual:@"work"], @"An exact active Focus selects its linked profile");
    for (NSDictionary *focus in @[@{@"available":@NO,@"active":@YES,@"identifier":@"actual.exact.identifier"}, @{@"available":@YES,@"active":@NO}, @{@"available":@YES,@"active":@YES,@"identifier":@"actual.exact.identifier.extra"}]) Check([HBResolvedProfile(library,focus)[@"id"] isEqual:@"default"], @"Unknown, off, and unavailable Focus use the default");
    library[@"automaticFocus"] = @NO;
    Check([HBResolvedProfile(library,@{@"available":@YES,@"active":@YES,@"identifier":@"actual.exact.identifier"})[@"id"] isEqual:@"default"], @"Automatic Focus can be disabled without losing links");
    library[@"profiles"] = @[base[@"profiles"][0],base[@"profiles"][0],work];
    Check([HBNormalizeLibrary(library)[@"profiles"] count] == 2, @"Duplicate profile IDs are rejected");
    library[@"profiles"] = @[work]; library = HBNormalizeLibrary(library).mutableCopy;
    Check([library[@"activeID"] isEqual:@"work"], @"Deleting the default selects a surviving profile");
    NSMutableArray *many = [NSMutableArray array]; for (int i=0;i<100;i++) [many addObject:@{@"id":[NSString stringWithFormat:@"%d",i]}]; library[@"profiles"] = many;
    Check([HBNormalizeLibrary(library)[@"profiles"] count] == 12, @"Profile count is bounded");
    for (int i=0;i<100;i++) { NSDictionary *candidate = HBNormalizeLibrary(@{@"schema":@1,@"profiles":@[@{@"id":@"fuzz",@"theme":@{@"radius":@(i-50),@"spacing":@(i),@"opacity":@(i/10.0)}}]}); if (![candidate isEqual:HBNormalizeLibrary(candidate)]) failures++; }
    Check(failures == 0, @"Normalization stays idempotent across the numeric boundary matrix");
    printf("PROFILE_MODEL_TESTS: %lu checks, %lu failures\n", (unsigned long)checks, (unsigned long)failures); return failures ? 1 : 0;
} }
