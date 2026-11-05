#import "../SpoofyPolicy.h"
#include <assert.h>
int main(void) { @autoreleasepool {
    NSOperatingSystemVersion real = {17,0,0};
    NSDictionary *on = @{@"Enabled":@YES, @"ReportedVersion":@"18.0"};
    assert([SpoofyReplacement(on,@"com.apple.AppStore",real) isEqual:@"18.0"]);
    assert(!SpoofyReplacement(nil,@"com.apple.AppStore",real));
    assert(!SpoofyReplacement(@[],@"com.apple.AppStore",real));
    assert(!SpoofyReplacement(on,@"com.apple.appstored",real));
    assert(!SpoofyReplacement(on,@"com.example.app",real));
    assert(!SpoofyReplacement(on,@"com.apple.AppStore",(NSOperatingSystemVersion){17,0,1}));
    assert(!SpoofyReplacement(on,@"com.apple.AppStore",(NSOperatingSystemVersion){18,0,0}));
    for (id value in @[@NO, @"YES", @1, NSNull.null]) {
        assert(!SpoofyReplacement(@{@"Enabled":value,@"ReportedVersion":@"18.0"},@"com.apple.AppStore",real));
    }
    for (id value in @[@"",@"17.0",@"17.0.0",@"16.6",@"18",@"18.0\n",@"18.00",@"18.0.1.2",@"999.0",@"18.0evil",@18,NSNull.null]) {
        assert(!SpoofyReplacement(@{@"Enabled":@YES,@"ReportedVersion":value},@"com.apple.AppStore",real));
    }
    for (NSString *value in @[@"17.1",@"17.0.1",@"18.0.1",@"26.0"]) {
        assert([SpoofyReplacement(@{@"Enabled":@YES,@"ReportedVersion":value},@"com.apple.AppStore",real) isEqual:value]);
    }
    puts("27 policy cases passed");
} return 0; }
