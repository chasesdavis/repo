#import "CompatPolicy.h"
#import <CoreFoundation/CoreFoundation.h>

NSString *const CGCBundleIdentifier = @"com.openai.chat";
NSString *const CGCTargetVersion = @"1.2026.272";
static NSString *const CGCStoreIdentifier = @"6448311069";

BOOL CGCPreferencesEnabled(id preferences) {
    if (![preferences isKindOfClass:NSDictionary.class]) return NO;
    id value = preferences[@"Enabled"];
    return [value isKindOfClass:NSNumber.class] && CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID() && [value boolValue];
}

BOOL CGCRuntimeAllowed(NSString *process, NSString *machine, NSOperatingSystemVersion version) {
    return ([process isEqualToString:@"appstored"] || [process isEqualToString:@"installd"])
        && [machine isEqualToString:@"iPhone16,2"]
        && version.majorVersion == 17 && version.minorVersion == 0 && version.patchVersion == 0;
}

// Accept only flat XML plists and reject duplicate keys before Foundation parses them.
// A general plist parser alone may silently collapse duplicate product identifiers.
@interface CGCFlatPlistValidator : NSObject <NSXMLParserDelegate>
@property(nonatomic) NSUInteger depth;
@property(nonatomic) BOOL expectsKey;
@property(nonatomic) BOOL valid;
@property(nonatomic) BOOL readingKey;
@property(nonatomic) NSMutableSet<NSString *> *keys;
@property(nonatomic) NSMutableString *keyText;
@end

@implementation CGCFlatPlistValidator
- (instancetype)init {
    if ((self = [super init])) {
        _valid = YES;
        _expectsKey = YES;
        _keys = [NSMutableSet set];
    }
    return self;
}
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)element namespaceURI:(NSString *)uri qualifiedName:(NSString *)qualified attributes:(NSDictionary *)attributes {
    self.depth++;
    BOOL allowed = self.depth == 1 ? [element isEqualToString:@"plist"] :
        self.depth == 2 ? [element isEqualToString:@"dict"] :
        self.depth == 3 ? (self.expectsKey ? [element isEqualToString:@"key"] :
            [@[@"string", @"integer", @"real", @"data", @"date", @"true", @"false"] containsObject:element]) : NO;
    if (!allowed) { self.valid = NO; [parser abortParsing]; return; }
    if (self.depth == 3 && self.expectsKey) {
        self.readingKey = YES;
        self.keyText = [NSMutableString string];
    }
}
- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    if (self.readingKey) [self.keyText appendString:string];
}
- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)element namespaceURI:(NSString *)uri qualifiedName:(NSString *)qualified {
    if (self.depth == 3) {
        if (self.readingKey) {
            if (!self.keyText.length || [self.keys containsObject:self.keyText]) {
                self.valid = NO;
                [parser abortParsing];
                return;
            }
            [self.keys addObject:[self.keyText copy]];
            self.readingKey = NO;
        }
        self.expectsKey = !self.expectsKey;
    }
    self.depth--;
}
@end

static NSDictionary *CGCRequestParameters(NSURLRequest *request) {
    NSData *body = request.HTTPBody;
    if (!body.length || body.length > 65536 || request.HTTPBodyStream) return nil;
    NSString *encoding = [request valueForHTTPHeaderField:@"Content-Encoding"];
    if (encoding.length && ![encoding.lowercaseString isEqualToString:@"identity"]) return nil;
    NSString *type = [[[[request valueForHTTPHeaderField:@"Content-Type"] componentsSeparatedByString:@";"] firstObject] lowercaseString];
    type = [type stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    if ([type isEqualToString:@"application/x-www-form-urlencoded"]) {
        NSString *text = [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding];
        if (!text.length) return nil;
        NSMutableDictionary *values = [NSMutableDictionary dictionary];
        for (NSString *pair in [text componentsSeparatedByString:@"&"]) {
            NSRange separator = [pair rangeOfString:@"="];
            if (separator.location == NSNotFound) return nil;
            NSString *key = [[[pair substringToIndex:separator.location] stringByReplacingOccurrencesOfString:@"+" withString:@" "] stringByRemovingPercentEncoding];
            NSString *value = [[[pair substringFromIndex:separator.location + 1] stringByReplacingOccurrencesOfString:@"+" withString:@" "] stringByRemovingPercentEncoding];
            if (!key.length || !value || values[key] || [key rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"[]"]].location != NSNotFound) return nil;
            values[key] = value;
        }
        return values;
    }
    if (![@[@"application/x-apple-plist", @"application/x-plist", @"application/xml", @"text/xml"] containsObject:type ?: @""]) return nil;
    NSString *xml = [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding];
    if (!xml || [xml rangeOfString:@"<!ENTITY" options:NSCaseInsensitiveSearch].location != NSNotFound || [xml rangeOfString:@"<![CDATA["].location != NSNotFound) return nil;
    CGCFlatPlistValidator *validator = [CGCFlatPlistValidator new];
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:body];
    parser.shouldResolveExternalEntities = NO;
    parser.delegate = validator;
    if (![parser parse] || !validator.valid || validator.depth != 0 || !validator.expectsKey) return nil;
    id value = [NSPropertyListSerialization propertyListWithData:body options:NSPropertyListImmutable format:NULL error:NULL];
    return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

static BOOL CGCStoreIDMatches(id value) {
    if ([value isKindOfClass:NSString.class]) return [value isEqualToString:CGCStoreIdentifier];
    if (![value isKindOfClass:NSNumber.class] || CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID() || CFNumberIsFloatType((__bridge CFNumberRef)value)) return NO;
    return [value isEqualToNumber:@6448311069LL];
}

BOOL CGCRequestTargetsChatGPT(NSURLRequest *request) {
    if (![request isKindOfClass:NSURLRequest.class]) return NO;
    NSURL *url = request.URL;
    NSString *host = url.host.lowercaseString;
    if (![url.scheme.lowercaseString isEqualToString:@"https"] || url.user || url.password || url.fragment || url.query.length || (url.port && url.port.integerValue != 443)) return NO;
    if (![host isEqualToString:@"itunes.apple.com"] && ![host hasSuffix:@".itunes.apple.com"]) return NO;
    if (![url.path isEqualToString:@"/WebObjects/MZBuy.woa/wa/buyProduct"] || ![request.HTTPMethod isEqualToString:@"POST"]) return NO;
    NSDictionary *values = CGCRequestParameters(request);
    if (!CGCStoreIDMatches(values[@"salableAdamId"]) || ![values[@"productType"] isEqual:@"C"]) return NO;
    for (NSString *key in @[@"adamId", @"appAdamId", @"itemId", @"itemID", @"trackId"]) {
        if (values[key] && !CGCStoreIDMatches(values[key])) return NO;
    }
    for (NSString *key in @[@"bundleId", @"bundleID", @"bundleIdentifier", @"bid"]) {
        if (values[key] && ![values[key] isEqual:CGCBundleIdentifier]) return NO;
    }
    for (NSString *key in @[@"items", @"purchases", @"buyParams", @"buyParameters", @"salableAdamIds", @"adamIds"]) {
        if (values[key]) return NO;
    }
    return YES;
}

NSURLRequest *CGCPreparedRequest(NSURLRequest *request, BOOL enabled) {
    if (!enabled || !CGCRequestTargetsChatGPT(request)) return request;
    NSString *agent = [request valueForHTTPHeaderField:@"User-Agent"];
    if (!agent.length || agent.length > 4096) return request;
    NSRegularExpression *tokens = [NSRegularExpression regularExpressionWithPattern:@"(?:^| )iOS/[^ ]+" options:0 error:NULL];
    NSRange all = NSMakeRange(0, agent.length);
    NSArray<NSTextCheckingResult *> *matches = [tokens matchesInString:agent options:0 range:all];
    if (matches.count != 1) return request;
    NSRange range = matches.firstObject.range;
    NSString *token = [[agent substringWithRange:range] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    if (![@[@"iOS/17.0", @"iOS/17.0.0"] containsObject:token]) return request;
    NSString *replacement = [agent stringByReplacingCharactersInRange:range withString:[agent characterAtIndex:range.location] == ' ' ? @" iOS/18.0" : @"iOS/18.0"];
    NSMutableURLRequest *copy = [request mutableCopy];
    [copy setValue:replacement forHTTPHeaderField:@"User-Agent"];
    return copy;
}

BOOL CGCBundleMatchesTarget(NSString *identifier, NSURL *bundleURL) {
    if (![identifier isKindOfClass:NSString.class] || ![bundleURL isKindOfClass:NSURL.class] || !bundleURL.isFileURL) return NO;
    NSURL *canonical = bundleURL.URLByResolvingSymlinksInPath.URLByStandardizingPath;
    BOOL mainBundle = [canonical.pathExtension isEqualToString:@"app"];
    if (mainBundle ? ![identifier isEqualToString:CGCBundleIdentifier] :
        !([canonical.pathExtension isEqualToString:@"appex"] && [identifier hasPrefix:[CGCBundleIdentifier stringByAppendingString:@"."]])) return NO;
    NSURL *parent = canonical;
    for (NSUInteger depth = 0; depth < 8 && parent.path.length > 1; depth++) {
        if ([parent.pathExtension isEqualToString:@"app"]) {
            NSDictionary *main = [NSDictionary dictionaryWithContentsOfURL:[parent URLByAppendingPathComponent:@"Info.plist"]];
            if (![main[@"CFBundleIdentifier"] isEqual:CGCBundleIdentifier] || ![main[@"CFBundleShortVersionString"] isEqual:CGCTargetVersion]) return NO;
            NSDictionary *own = [NSDictionary dictionaryWithContentsOfURL:[canonical URLByAppendingPathComponent:@"Info.plist"]];
            return [own[@"CFBundleIdentifier"] isEqual:identifier];
        }
        parent = parent.URLByDeletingLastPathComponent;
    }
    return NO;
}

id CGCInstallerVersion(id minimumVersion, id originalVersion, NSString *identifier, NSURL *bundleURL, BOOL enabled) {
    if (!enabled || ![minimumVersion isKindOfClass:NSString.class] || ![originalVersion isKindOfClass:NSString.class]) return originalVersion;
    if (![@[@"18.0", @"18.0.0"] containsObject:minimumVersion] || ![@[@"17.0", @"17.0.0"] containsObject:originalVersion]) return originalVersion;
    return CGCBundleMatchesTarget(identifier, bundleURL) ? @"18.0" : originalVersion;
}
