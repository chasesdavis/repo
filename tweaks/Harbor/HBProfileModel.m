#import "HBProfileModel.h"
#include <math.h>

NSArray *HBSectionKeys(void) { return @[@"connectivity", @"levels", @"shortcuts", @"media", @"extras"]; }
NSString *HBSectionName(NSString *key) { return @{@"connectivity":@"Connections", @"levels":@"Brightness & volume", @"shortcuts":@"Essentials", @"media":@"Now Playing", @"extras":@"More shortcuts"}[key] ?: key; }
static NSString *Text(id value, NSString *fallback, NSUInteger limit) {
    if (![value isKindOfClass:NSString.class]) return fallback;
    NSString *s = [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return s.length && s.length <= limit ? s : fallback;
}
static NSDictionary *Dict(id value) { return [value isKindOfClass:NSDictionary.class] ? value : @{}; }
static NSArray *Array(id value) { return [value isKindOfClass:NSArray.class] ? value : @[]; }
static NSNumber *Number(id value, double fallback, double minimum, double maximum) {
    double n = [value isKindOfClass:NSNumber.class] ? [value doubleValue] : fallback;
    return @(isfinite(n) ? fmax(minimum, fmin(maximum, n)) : fallback);
}
static NSString *Hex(id value, NSString *fallback) {
    NSString *s = Text(value, fallback, 7).uppercaseString;
    NSCharacterSet *invalid = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEF"] invertedSet];
    return s.length == 7 && [s hasPrefix:@"#"] && [[s substringFromIndex:1] rangeOfCharacterFromSet:invalid].location == NSNotFound ? s : fallback;
}
NSDictionary *HBThemePresets(void) {
    return @{
        @"sea":@{@"name":@"Sea Glass", @"accent":@"#A3E8D6", @"surface":@"#0E1618", @"opacity":@0.72, @"radius":@36, @"spacing":@10, @"material":@"glass", @"shape":@"circle"},
        @"graphite":@{@"name":@"Graphite", @"accent":@"#E8E8ED", @"surface":@"#17171C", @"opacity":@0.92, @"radius":@28, @"spacing":@10, @"material":@"soft", @"shape":@"rounded"},
        @"iris":@{@"name":@"Iris", @"accent":@"#C2B8FF", @"surface":@"#1F1932", @"opacity":@0.78, @"radius":@36, @"spacing":@12, @"material":@"glass", @"shape":@"circle"},
        @"ember":@{@"name":@"Ember", @"accent":@"#FFBA75", @"surface":@"#291B17", @"opacity":@0.86, @"radius":@32, @"spacing":@10, @"material":@"soft", @"shape":@"rounded"}
    };
}
static NSDictionary *Theme(id input) {
    NSDictionary *v = Dict(input), *base = HBThemePresets()[@"sea"];
    return @{@"accent":Hex(v[@"accent"], base[@"accent"]), @"surface":Hex(v[@"surface"], base[@"surface"]),
        @"opacity":Number(v[@"opacity"], 0.72, 0.55, 1), @"radius":Number(v[@"radius"], 36, 16, 42),
        @"spacing":Number(v[@"spacing"], 10, 6, 18),
        @"material":[@[@"glass", @"soft", @"solid"] containsObject:v[@"material"] ?: @""] ? v[@"material"] : @"glass",
        @"shape":[v[@"shape"] isEqual:@"rounded"] ? @"rounded" : @"circle"};
}
static NSDictionary *Layout(id input, BOOL expanded) {
    NSDictionary *v = Dict(input); NSMutableArray *order = [NSMutableArray array], *hidden = [NSMutableArray array];
    for (id key in Array(v[@"order"])) if ([HBSectionKeys() containsObject:key] && ![order containsObject:key]) [order addObject:key];
    for (NSString *key in HBSectionKeys()) if (![order containsObject:key]) [order addObject:key];
    NSArray *requested = v[@"hidden"] ? Array(v[@"hidden"]) : (expanded ? @[] : @[@"extras"]);
    for (id key in requested) if ([order containsObject:key] && ![hidden containsObject:key] && hidden.count < order.count - 1) [hidden addObject:key];
    return @{@"order":order.copy, @"hidden":hidden.copy};
}
NSDictionary *HBNormalizeProfile(id input) {
    NSDictionary *v = Dict(input), *layouts = Dict(v[@"layouts"]);
    return @{@"id":Text(v[@"id"], @"default", 80), @"name":Text(v[@"name"], @"Everyday", 32),
        @"layouts":@{@"compact":Layout(layouts[@"compact"], NO), @"expanded":Layout(layouts[@"expanded"], YES)},
        @"theme":Theme(v[@"theme"]), @"startExpanded":@([Number(v[@"startExpanded"], 0, 0, 1) boolValue])};
}
NSDictionary *HBDefaultLibrary(NSString *legacyPalette) {
    NSDictionary *theme = HBThemePresets()[legacyPalette ?: @"sea"] ?: HBThemePresets()[@"sea"];
    return @{@"schema":@1, @"revision":@0, @"activeID":@"default", @"automaticFocus":@NO, @"focusOptInVersion":@0,
        @"profiles":@[HBNormalizeProfile(@{@"id":@"default", @"name":@"Everyday", @"theme":theme})], @"bindings":@{}, @"focusLabels":@{}};
}
BOOL HBFocusAccessEnabled(NSDictionary *library) {
    return [library[@"automaticFocus"] isEqual:@YES] && [library[@"focusOptInVersion"] isEqual:@1];
}
NSDictionary *HBNormalizeLibrary(id input) {
    NSDictionary *v = Dict(input);
    if (![v[@"schema"] isEqual:@1]) return HBDefaultLibrary(@"sea");
    NSMutableArray *profiles = [NSMutableArray array]; NSMutableSet *ids = [NSMutableSet set];
    for (id p in Array(v[@"profiles"])) {
        if (![p isKindOfClass:NSDictionary.class] || !Text(p[@"id"], nil, 80)) continue;
        NSDictionary *profile = HBNormalizeProfile(p); NSString *key = profile[@"id"];
        if ([ids containsObject:key]) continue; [ids addObject:key]; [profiles addObject:profile]; if (profiles.count == 12) break;
    }
    if (!profiles.count) return HBDefaultLibrary(@"sea");
    NSString *active = Text(v[@"activeID"], @"", 80); if (![ids containsObject:active]) active = profiles[0][@"id"];
    NSMutableDictionary *bindings = [NSMutableDictionary dictionary], *labels = [NSMutableDictionary dictionary];
    NSDictionary *givenLabels = Dict(v[@"focusLabels"]), *givenBindings = Dict(v[@"bindings"]);
    for (id key in givenBindings) if (Text(key, nil, 200) && [ids containsObject:givenBindings[key]]) {
        bindings[key] = givenBindings[key]; labels[key] = Text(givenLabels[key], @"Linked Focus", 80); if (bindings.count == 32) break;
    }
    return @{@"schema":@1, @"revision":Number(v[@"revision"], 0, 0, 1000000000), @"activeID":active,
        @"automaticFocus":@(HBFocusAccessEnabled(v)), @"focusOptInVersion":HBFocusAccessEnabled(v) ? @1 : @0,
        @"profiles":profiles.copy, @"bindings":bindings.copy, @"focusLabels":labels.copy};
}
NSDictionary *HBProfileWithID(NSDictionary *library, NSString *identifier) {
    for (NSDictionary *profile in library[@"profiles"]) if ([profile[@"id"] isEqual:identifier]) return profile;
    return [library[@"profiles"] firstObject];
}
NSDictionary *HBResolvedProfile(NSDictionary *library, NSDictionary *focus) {
    NSString *identifier = library[@"activeID"];
    if (HBFocusAccessEnabled(library) && [focus[@"available"] boolValue] && [focus[@"active"] boolValue])
        identifier = library[@"bindings"][focus[@"identifier"] ?: @""] ?: identifier;
    return HBProfileWithID(library, identifier);
}
NSDictionary *HBLibraryReplacingProfile(NSDictionary *library, NSDictionary *profile) {
    NSMutableDictionary *next = library.mutableCopy; NSMutableArray *profiles = [NSMutableArray array]; BOOL found = NO;
    for (NSDictionary *p in library[@"profiles"]) { BOOL match = [p[@"id"] isEqual:profile[@"id"]]; [profiles addObject:match ? profile : p]; found |= match; }
    if (!found && profiles.count < 12) [profiles addObject:profile]; next[@"profiles"] = profiles;
    return HBNormalizeLibrary(next);
}
