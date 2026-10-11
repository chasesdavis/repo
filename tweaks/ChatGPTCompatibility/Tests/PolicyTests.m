#import "CompatPolicy.h"
#import "MethodTypes.h"

static unsigned int checks;
#define CHECK(expression) do { checks++; if (!(expression)) { fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #expression); exit(1); } } while (0)

@interface CGCSignatureFixture : NSObject
- (BOOL)check:(id)minimum os:(id)os required:(unsigned long long)required error:(NSError **)error;
- (id)identifier;
- (NSInteger)badIdentifier;
- (id)task:(id)request completion:(void (^)(void))completion;
@end
@implementation CGCSignatureFixture
- (BOOL)check:(id)minimum os:(id)os required:(unsigned long long)required error:(NSError **)error { return NO; }
- (id)identifier { return @"com.openai.chat"; }
- (NSInteger)badIdentifier { return 1; }
- (id)task:(id)request completion:(void (^)(void))completion { return request; }
@end

static NSMutableURLRequest *Request(NSString *body) {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://p71-buy.itunes.apple.com/WebObjects/MZBuy.woa/wa/buyProduct"]];
    request.HTTPMethod = @"POST";
    request.HTTPBody = [body dataUsingEncoding:NSUTF8StringEncoding];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"AppStore/3.0 iOS/17.0 model/iPhone16,2 build/21A329" forHTTPHeaderField:@"User-Agent"];
    [request setValue:@"unchanged-fixture-value" forHTTPHeaderField:@"X-Fixture"];
    return request;
}

static NSMutableURLRequest *XMLRequest(NSDictionary *parameters) {
    NSMutableURLRequest *request = Request(@"");
    request.HTTPBody = [NSPropertyListSerialization dataWithPropertyList:parameters format:NSPropertyListXMLFormat_v1_0 options:0 error:NULL];
    [request setValue:@"application/x-apple-plist" forHTTPHeaderField:@"Content-Type"];
    return request;
}

static void TestRequests(void) {
    NSString *valid = @"salableAdamId=6448311069&productType=C&appExtVrsId=123456";
    NSMutableURLRequest *request = Request(valid);
    CHECK(CGCRequestTargetsChatGPT(request));
    CHECK(CGCPreparedRequest(request, NO) == request);
    NSURLRequest *prepared = CGCPreparedRequest(request, YES);
    CHECK(prepared != request);
    CHECK([[prepared valueForHTTPHeaderField:@"User-Agent"] isEqualToString:@"AppStore/3.0 iOS/18.0 model/iPhone16,2 build/21A329"]);
    CHECK([[request valueForHTTPHeaderField:@"User-Agent"] containsString:@"iOS/17.0"]);
    CHECK([prepared.HTTPBody isEqual:request.HTTPBody]);
    CHECK([prepared.URL isEqual:request.URL]);
    CHECK([prepared.HTTPMethod isEqual:request.HTTPMethod]);
    CHECK([[prepared valueForHTTPHeaderField:@"X-Fixture"] isEqual:[request valueForHTTPHeaderField:@"X-Fixture"]]);
    CHECK(CGCPreparedRequest(prepared, YES) == prepared);
    CHECK(CGCPreparedRequest(nil, YES) == nil);
    NSMutableURLRequest *lateHeader = Request(valid);
    [lateHeader setValue:nil forHTTPHeaderField:@"User-Agent"];
    NSURLRequest *earlyResult = CGCPreparedRequest(lateHeader, YES);
    CHECK(earlyResult == lateHeader);
    NSString *lateValue = CGCPreparedHeaderValue(lateHeader, @{@"salableAdamId":@6448311069LL, @"productType":@"C"}, @"User-Agent", @"AppStore/3.0 iOS/17.0 model/iPhone16,2", YES);
    CHECK([lateValue isEqualToString:@"AppStore/3.0 iOS/18.0 model/iPhone16,2"]);
    CHECK([CGCPreparedHeaderValue(lateHeader, @{@"salableAdamId":@1, @"productType":@"C"}, @"User-Agent", @"AppStore/3.0 iOS/17.0", YES) isEqualToString:@"AppStore/3.0 iOS/17.0"]);
    CHECK([CGCPreparedHeaderValue(lateHeader, @{@"salableAdamId":@6448311069LL, @"productType":@"C"}, @"X-Fixture", @"iOS/17.0", YES) isEqualToString:@"iOS/17.0"]);
    CHECK([CGCPreparedHeaderValue(lateHeader, @{@"salableAdamId":@6448311069LL, @"productType":@"C"}, @"User-Agent", @"AppStore/3.0 iOS/17.0", NO) isEqualToString:@"AppStore/3.0 iOS/17.0"]);
    for (NSString *body in @[@"", @"salableAdamId=1&productType=C", @"productType=C", @"salableAdamId=6448311069&productType=A", @"salableAdamId=64483110690&productType=C", @"salableAdamId=6448311069x&productType=C", @"salableAdamId=6448311069&productType=C&salableAdamId=1", @"salableAdamId=6448311069&productType=C&salable%41damId=1", @"salableAdamId=6448311069&productType=C&appAdamId=1", @"salableAdamId=6448311069&productType=C&bid=com.other.app", @"salableAdamId=6448311069&productType=C&items=x", @"salableAdamId=6448311069&productType=C&items[]=x", @"salableAdamId=6448311069&productType=C&x=%ZZ", @"salableAdamId=6448311069&productType=C&broken"]) {
        NSMutableURLRequest *other = Request(body);
        CHECK(!CGCRequestTargetsChatGPT(other));
        CHECK(CGCPreparedRequest(other, YES) == other);
    }
    for (NSString *url in @[@"http://p71-buy.itunes.apple.com/WebObjects/MZBuy.woa/wa/buyProduct", @"https://itunes.apple.com.example.org/WebObjects/MZBuy.woa/wa/buyProduct", @"https://notitunes.apple.com/WebObjects/MZBuy.woa/wa/buyProduct", @"https://user@itunes.apple.com/WebObjects/MZBuy.woa/wa/buyProduct", @"https://itunes.apple.com:8443/WebObjects/MZBuy.woa/wa/buyProduct", @"https://itunes.apple.com/WebObjects/MZBuy.woa/wa/buyProduct?salableAdamId=1", @"https://itunes.apple.com/WebObjects/MZBuy.woa/wa/buyProduct#x", @"https://itunes.apple.com/updates"]) {
        NSMutableURLRequest *other = Request(valid); other.URL = [NSURL URLWithString:url];
        CHECK(CGCPreparedRequest(other, YES) == other);
    }
    request.HTTPMethod = @"GET"; CHECK(CGCPreparedRequest(request, YES) == request);
    request = Request(valid); [request setValue:@"gzip" forHTTPHeaderField:@"Content-Encoding"]; CHECK(CGCPreparedRequest(request, YES) == request);
    request = Request(valid); [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"]; CHECK(CGCPreparedRequest(request, YES) == request);
    request = Request(valid); request.HTTPBody = [NSMutableData dataWithLength:65537]; CHECK(CGCPreparedRequest(request, YES) == request);
    request = Request(valid); request.HTTPBodyStream = [NSInputStream inputStreamWithData:request.HTTPBody]; CHECK(CGCPreparedRequest(request, YES) == request);
    for (NSString *agent in @[@"", @"iOS/18.0", @"iOS/17.0.1", @"iOS/17.0 iOS/17.0", @"fakeiOS/17.0 iOS/18.0", @"iOS/17.00", @"iOS/17.0extra"]) {
        request = Request(valid); [request setValue:agent forHTTPHeaderField:@"User-Agent"];
        CHECK(CGCPreparedRequest(request, YES) == request);
    }
    request = Request(valid); [request setValue:@"iOS/17.0.0" forHTTPHeaderField:@"User-Agent"];
    CHECK([[CGCPreparedRequest(request, YES) valueForHTTPHeaderField:@"User-Agent"] isEqualToString:@"iOS/18.0"]);
    request = XMLRequest(@{@"salableAdamId":@6448311069LL, @"productType":@"C"});
    CHECK(CGCRequestTargetsChatGPT(request)); CHECK(CGCPreparedRequest(request, YES) != request);
    for (NSDictionary *parameters in @[@{@"salableAdamId":@YES, @"productType":@"C"}, @{@"salableAdamId":@6448311069.0, @"productType":@"C"}, @{@"salableAdamId":@"6448311069", @"productType":@"C", @"items":@[]}, @{@"salableAdamId":@"6448311069", @"productType":@"C", @"context":@{}}]) {
        request = XMLRequest(parameters); CHECK(CGCPreparedRequest(request, YES) == request);
    }
    request = XMLRequest(@{});
    request.HTTPBody = [@"<plist><dict><key>salableAdamId</key><string>6448311069</string><key>productType</key><string>C</string><key>salableAdamId</key><string>1</string></dict></plist>" dataUsingEncoding:NSUTF8StringEncoding];
    CHECK(CGCPreparedRequest(request, YES) == request);
    request.HTTPBody = [@"<!DOCTYPE plist [<!ENTITY item '6448311069'>]><plist><dict><key>salableAdamId</key><string>&item;</string><key>productType</key><string>C</string></dict></plist>" dataUsingEncoding:NSUTF8StringEncoding];
    CHECK(CGCPreparedRequest(request, YES) == request);
    request.HTTPBody = [@"<plist><dict><key>salableAdamId</key>" dataUsingEncoding:NSUTF8StringEncoding];
    CHECK(CGCPreparedRequest(request, YES) == request);
}

static void WriteInfo(NSURL *url, NSString *identity, NSString *version) {
    CHECK([NSFileManager.defaultManager createDirectoryAtURL:url withIntermediateDirectories:YES attributes:nil error:NULL]);
    CHECK(([@{@"CFBundleIdentifier":identity, @"CFBundleShortVersionString":version} writeToURL:[url URLByAppendingPathComponent:@"Info.plist"] atomically:YES]));
}

static void TestBundles(void) {
    NSURL *root = [NSURL fileURLWithPath:[@".test-build" stringByAppendingPathComponent:NSUUID.UUID.UUIDString] isDirectory:YES];
    NSURL *app = [root URLByAppendingPathComponent:@"ChatGPT.app" isDirectory:YES];
    WriteInfo(app, CGCBundleIdentifier, CGCTargetVersion);
    CHECK(CGCBundleMatchesTarget(CGCBundleIdentifier, app));
    CHECK([CGCInstallerVersion(@"18.0", @"17.0", CGCBundleIdentifier, app, YES) isEqual:@"18.0"]);
    CHECK([CGCInstallerVersion(@"18.0.0", @"17.0.0", CGCBundleIdentifier, app, YES) isEqual:@"18.0"]);
    CHECK([CGCInstallerVersion(@"18.0", @"17.0", CGCBundleIdentifier, app, NO) isEqual:@"17.0"]);
    CHECK([CGCInstallerVersion(@"18.1", @"17.0", CGCBundleIdentifier, app, YES) isEqual:@"17.0"]);
    CHECK([CGCInstallerVersion(@"18.0", @"17.0.1", CGCBundleIdentifier, app, YES) isEqual:@"17.0.1"]);
    NSNumber *original = @17;
    CHECK(CGCInstallerVersion(@18, original, CGCBundleIdentifier, app, YES) == original);
    CHECK(!CGCBundleMatchesTarget(@"com.other.app", app));
    CHECK(!CGCBundleMatchesTarget(CGCBundleIdentifier, nil));
    CHECK(!CGCBundleMatchesTarget(CGCBundleIdentifier, [NSURL URLWithString:@"https://example.org/ChatGPT.app"]));
    NSURL *plugin = [app URLByAppendingPathComponent:@"PlugIns/Example.appex" isDirectory:YES];
    WriteInfo(plugin, @"com.openai.chat.example", @"1.0");
    CHECK(CGCBundleMatchesTarget(@"com.openai.chat.example", plugin));
    CHECK(!CGCBundleMatchesTarget(@"com.openai.chat.mismatch", plugin));
    NSURL *framework = [app URLByAppendingPathComponent:@"Frameworks/Example.framework" isDirectory:YES];
    WriteInfo(framework, @"com.openai.chat.example", @"1.0");
    CHECK(!CGCBundleMatchesTarget(@"com.openai.chat.example", framework));
    WriteInfo(app, CGCBundleIdentifier, @"1.2026.237");
    CHECK(!CGCBundleMatchesTarget(CGCBundleIdentifier, app));
    CHECK(!CGCBundleMatchesTarget(@"com.openai.chat.example", plugin));
    CHECK([CGCInstallerVersion(@"18.0", @"17.0", CGCBundleIdentifier, app, YES) isEqual:@"17.0"]);
    WriteInfo(app, @"com.other.app", CGCTargetVersion);
    CHECK(!CGCBundleMatchesTarget(CGCBundleIdentifier, app));
    CHECK([NSFileManager.defaultManager removeItemAtURL:root error:NULL]);
}

int main(void) {
    @autoreleasepool {
        CHECK(!CGCPreferencesEnabled(nil)); CHECK(!CGCPreferencesEnabled(@{}));
        CHECK(!CGCPreferencesEnabled(@{@"Enabled":@NO})); CHECK(!CGCPreferencesEnabled(@{@"Enabled":@"YES"}));
        CHECK(!CGCPreferencesEnabled(@{@"Enabled":@1})); CHECK(CGCPreferencesEnabled(@{@"Enabled":@YES}));
        NSOperatingSystemVersion os = {17,0,0};
        CHECK(CGCRuntimeAllowed(@"appstored", @"iPhone16,2", os)); CHECK(CGCRuntimeAllowed(@"installd", @"iPhone16,2", os));
        CHECK(CGCRuntimeAllowed(@"itunesstored", @"iPhone16,2", os)); CHECK(CGCRuntimeAllowed(@"AppStore", @"iPhone16,2", os));
        CHECK(CGCRuntimeAllowed(@"StoreKitUIService", @"iPhone16,2", os));
        CHECK(!CGCRuntimeAllowed(@"ChatGPT", @"iPhone16,2", os)); CHECK(!CGCRuntimeAllowed(@"SpringBoard", @"iPhone16,2", os));
        CHECK(!CGCRuntimeAllowed(@"appstored", @"iPhone16,1", os));
        os.patchVersion = 1; CHECK(CGCRuntimeAllowed(@"appstored", @"iPhone16,2", os));
        os.patchVersion = 3; CHECK(CGCRuntimeAllowed(@"installd", @"iPhone16,2", os));
        os.minorVersion = 1; CHECK(!CGCRuntimeAllowed(@"appstored", @"iPhone16,2", os));
        Method method = class_getInstanceMethod(CGCSignatureFixture.class, @selector(check:os:required:error:));
        CHECK(CGCMethodMatches(method, @encode(BOOL), @[@"@", @":", @"@", @"@", @"Q", @"^@"]));
        CHECK(!CGCMethodMatches(method, "@", @[@"@", @":", @"@", @"@", @"Q", @"^@"]));
        CHECK(!CGCMethodMatches(method, @encode(BOOL), @[@"@", @":", @"@", @"@", @"I", @"^@"]));
        CHECK(!CGCMethodMatches(NULL, "@", @[]));
        CHECK(CGCMethodMatches(class_getInstanceMethod(CGCSignatureFixture.class, @selector(identifier)), "@", @[@"@", @":"]));
        CHECK(!CGCMethodMatches(class_getInstanceMethod(CGCSignatureFixture.class, @selector(badIdentifier)), "@", @[@"@", @":"]));
        CHECK(CGCMethodMatches(class_getInstanceMethod(CGCSignatureFixture.class, @selector(task:completion:)), "@", @[@"@", @":", @"@", @"@?"]));
        TestRequests(); TestBundles();
        printf("PASS: %u policy and ABI assertions (host tests, not device validation)\n", checks);
    }
    return 0;
}
