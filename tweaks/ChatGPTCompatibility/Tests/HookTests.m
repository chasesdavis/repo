#import "../Tweak.m"
#import <objc/runtime.h>

static unsigned int checks;
#define CHECK(expression) do { checks++; if (!(expression)) { fprintf(stderr, "FAIL hook line %d: %s\n", __LINE__, #expression); exit(1); } } while (0)
static NSURL *fixtureURL;
static id capturedMinimum, capturedVersion;
static unsigned long long capturedRequired;
static NSError *__autoreleasing *capturedErrorPointer;
static NSUInteger installerCalls;
static id mockRequestProperties;
static NSString *capturedHeaderValue, *capturedHeaderField;

@interface CGCMockBuyParams : NSObject
@property(nonatomic) NSDictionary *dictionary;
@end
@implementation CGCMockBuyParams
@end
@interface CGCMockPurchaseInfo : NSObject
@property(nonatomic) CGCMockBuyParams *buyParams;
@end
@implementation CGCMockPurchaseInfo
@end
@interface CGCMockRequestProperties : NSObject
@property(nonatomic) CGCMockPurchaseInfo *purchaseInfo;
@end
@implementation CGCMockRequestProperties
@end
@interface NSMutableURLRequest (CGCTestProperties)
- (id)properties;
@end
@implementation NSMutableURLRequest (CGCTestProperties)
- (id)properties { return mockRequestProperties; }
@end

@interface CGCMockInstaller : NSObject
- (id)identifier;
- (id)bundleURL;
- (BOOL)_isMinimumOSVersion:(id)minimum applicableToOSVersion:(id)version requiredOS:(unsigned long long)required error:(NSError **)error;
@end
@implementation CGCMockInstaller
- (id)identifier { return CGCBundleIdentifier; }
- (id)bundleURL { return fixtureURL; }
- (BOOL)_isMinimumOSVersion:(id)minimum applicableToOSVersion:(id)version requiredOS:(unsigned long long)required error:(NSError **)error {
    installerCalls++;
    capturedMinimum = minimum; capturedVersion = version; capturedRequired = required; capturedErrorPointer = error;
    if (error) *error = [NSError errorWithDomain:@"FixtureOriginalDecision" code:7 userInfo:nil];
    return NO;
}
@end

void MSHookMessageEx(Class cls, SEL selector, IMP replacement, IMP *original) {
    CHECK(cls == CGCMockInstaller.class);
    *original = method_setImplementation(class_getInstanceMethod(cls, selector), replacement);
}

static NSURLRequest *capturedRequest;
static id capturedCompletion;
static unsigned long long capturedSignpost;
static id OriginalOne(id self, SEL selector, NSURLRequest *request) { capturedRequest = request; return @"original-task"; }
static id OriginalTwo(id self, SEL selector, NSURLRequest *request, id completion) { capturedCompletion = completion; return OriginalOne(self, selector, request); }
static id OriginalThree(id self, SEL selector, NSURLRequest *request, unsigned long long signpost, id completion) { capturedSignpost = signpost; return OriginalTwo(self, selector, request, completion); }
static void OriginalHeaderSetter(id self, SEL selector, NSString *value, NSString *field) { capturedHeaderValue = value; capturedHeaderField = field; }

int main(void) {
    @autoreleasepool {
        NSURL *root = [NSURL fileURLWithPath:[@".test-build" stringByAppendingPathComponent:NSUUID.UUID.UUIDString] isDirectory:YES];
        fixtureURL = [root URLByAppendingPathComponent:@"ChatGPT.app" isDirectory:YES];
        CHECK([NSFileManager.defaultManager createDirectoryAtURL:fixtureURL withIntermediateDirectories:YES attributes:nil error:NULL]);
        NSDictionary *info = @{@"CFBundleIdentifier":CGCBundleIdentifier, @"CFBundleShortVersionString":CGCTargetVersion};
        CHECK([info writeToURL:[fixtureURL URLByAppendingPathComponent:@"Info.plist"] atomically:YES]);
        SEL installerSelector = @selector(_isMinimumOSVersion:applicableToOSVersion:requiredOS:error:);
        CGCInstallerHooked = CGCInstallHook(CGCMockInstaller.class, installerSelector, @encode(BOOL), @[@"@", @":", @"@", @"@", @"Q", @"^@"], (IMP)CGCMinimumOS, (IMP *)&CGCOriginalMinimumOS);
        CHECK(CGCInstallerHooked);
        CGCMockInstaller *bundle = [CGCMockInstaller new];
        NSError *__autoreleasing error = nil;
        atomic_store(&CGCEnabled, true);
        CHECK(![bundle _isMinimumOSVersion:@"18.0" applicableToOSVersion:@"17.0" requiredOS:42 error:&error]);
        CHECK(installerCalls == 1); CHECK([capturedMinimum isEqual:@"18.0"]); CHECK([capturedVersion isEqual:@"18.0"]);
        CHECK(capturedRequired == 42); CHECK(capturedErrorPointer == &error); CHECK(error.code == 7);
        atomic_store(&CGCEnabled, false);
        CHECK(![bundle _isMinimumOSVersion:@"18.0" applicableToOSVersion:@"17.0" requiredOS:99 error:NULL]);
        CHECK([capturedVersion isEqual:@"17.0"]); CHECK(capturedRequired == 99); CHECK(capturedErrorPointer == NULL);
        atomic_store(&CGCEnabled, true);
        CHECK(![bundle _isMinimumOSVersion:@"19.0" applicableToOSVersion:@"17.0" requiredOS:1 error:NULL]);
        CHECK([capturedVersion isEqual:@"17.0"]); CHECK(installerCalls == 3);
        CHECK(CGCInstallerHooked);
        CHECK([NSFileManager.defaultManager removeItemAtURL:root error:NULL]);

        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://buy.itunes.apple.com/WebObjects/MZBuy.woa/wa/buyProduct"]];
        request.HTTPMethod = @"POST";
        request.HTTPBody = [@"salableAdamId=6448311069&productType=C" dataUsingEncoding:NSUTF8StringEncoding];
        [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
        [request setValue:@"AppStore/3.0 iOS/17.0 model/iPhone16,2" forHTTPHeaderField:@"User-Agent"];
        CGCOriginalNSOne = OriginalOne; CGCOriginalAMSOne = OriginalOne;
        CGCOriginalNSTwo = OriginalTwo; CGCOriginalAMSTwo = OriginalTwo; CGCOriginalAMSThree = OriginalThree;
        id completion = [NSObject new]; SEL command = @selector(description);
        CHECK([CGCNSOne(nil, command, request) isEqual:@"original-task"]);
        CHECK([[capturedRequest valueForHTTPHeaderField:@"User-Agent"] containsString:@"iOS/18.0"]);
        CHECK([capturedRequest.HTTPBody isEqual:request.HTTPBody]);
        CHECK([CGCNSTwo(nil, command, request, completion) isEqual:@"original-task"]); CHECK(capturedCompletion == completion);
        CHECK([CGCAMSOne(nil, command, request) isEqual:@"original-task"]);
        CHECK([CGCAMSTwo(nil, command, request, completion) isEqual:@"original-task"]); CHECK(capturedCompletion == completion);
        CHECK([CGCAMSThree(nil, command, request, 72, completion) isEqual:@"original-task"]);
        CHECK(capturedSignpost == 72); CHECK(capturedCompletion == completion);
        atomic_store(&CGCEnabled, false); CGCNSOne(nil, command, request); CHECK(capturedRequest == request);
        atomic_store(&CGCEnabled, true); request.HTTPBody = [@"salableAdamId=1&productType=C" dataUsingEncoding:NSUTF8StringEncoding];
        CGCNSTwo(nil, command, request, completion); CHECK(capturedRequest == request);
        CGCMockBuyParams *params = [CGCMockBuyParams new];
        params.dictionary = @{@"salableAdamId":@6448311069LL, @"productType":@"C"};
        CGCMockPurchaseInfo *purchase = [CGCMockPurchaseInfo new]; purchase.buyParams = params;
        CGCMockRequestProperties *properties = [CGCMockRequestProperties new]; properties.purchaseInfo = purchase;
        mockRequestProperties = properties;
        request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://buy.itunes.apple.com/WebObjects/MZBuy.woa/wa/buyProduct"]];
        request.HTTPMethod = @"POST";
        CGCOriginalHeaderSetter = OriginalHeaderSetter;
        atomic_store(&CGCEnabled, true);
        CGCSetHeaderValue(request, @selector(setValue:forHTTPHeaderField:), @"AppStore/3.0 iOS/17.0 model/iPhone16,2", @"User-Agent");
        CHECK([capturedHeaderValue isEqualToString:@"AppStore/3.0 iOS/18.0 model/iPhone16,2"]);
        CHECK([capturedHeaderField isEqualToString:@"User-Agent"]);
        params.dictionary = @{@"salableAdamId":@1, @"productType":@"C"};
        CGCSetHeaderValue(request, @selector(setValue:forHTTPHeaderField:), @"AppStore/3.0 iOS/17.0", @"User-Agent");
        CHECK([capturedHeaderValue isEqualToString:@"AppStore/3.0 iOS/17.0"]);
        printf("PASS: %u hook integration assertions (mock installer/provider; no device or network access)\n", checks);
    }
    return 0;
}
