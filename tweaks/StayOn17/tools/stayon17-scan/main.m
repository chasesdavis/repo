#import <Foundation/Foundation.h>
#import <stdio.h>
#import <string.h>
#import "../../SO17Prefs.h"

static NSString *RunShell(NSString *cmd) {
    FILE *fp = popen(cmd.UTF8String, "r");
    if (!fp) return @"";
    NSMutableData *data = [NSMutableData data];
    char buf[4096];
    size_t n;
    while ((n = fread(buf, 1, sizeof(buf), fp)) > 0) [data appendBytes:buf length:n];
    pclose(fp);
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
}

static NSString *CatalogPath(void) {
    for (NSString *p in @[@"/Library/ApplicationSupport/StayOn17/ios18_frameworks.json",
                          @"/var/jb/Library/ApplicationSupport/StayOn17/ios18_frameworks.json"]) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:p]) return p;
    }
    return @"/Library/ApplicationSupport/StayOn17/ios18_frameworks.json";
}

static NSDictionary *LoadCatalog(void) {
    NSData *d = [NSData dataWithContentsOfFile:CatalogPath()];
    if (!d) return @{};
    id j = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
    return [j isKindOfClass:[NSDictionary class]] ? j : @{};
}

static NSString *VerdictString(SO17ScanVerdict v) {
    if (v == SO17ScanVerdictLikelyOK) return @"likely_ok";
    if (v == SO17ScanVerdictNotFeasible) return @"not_feasible";
    return @"spoof_only";
}

static NSString *AppPathForBundleID(NSString *bundleID) {
    Class LS = NSClassFromString(@"LSApplicationWorkspace");
    if (!LS) return nil;
    id workspace = [LS performSelector:@selector(defaultWorkspace)];
    if (!workspace) return nil;
    id app = [workspace performSelector:@selector(applicationForBundleIdentifier:) withObject:bundleID];
    if (!app || ![app respondsToSelector:@selector(bundleURL)]) return nil;
    return [[app performSelector:@selector(bundleURL)] path];
}

static void CollectMachOBinaries(NSString *root, NSMutableArray *out, NSMutableSet *seen) {
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = NO;
    if (![fm fileExistsAtPath:root isDirectory:&isDir]) return;
    if (!isDir) {
        if ([seen containsObject:root]) return;
        NSString *head = RunShell([NSString stringWithFormat:@"/usr/bin/otool -h %@ 2>/dev/null", root]);
        if ([head containsString:@"Mach-O"]) { [out addObject:root]; [seen addObject:root]; }
        return;
    }
    for (NSString *name in [fm contentsOfDirectoryAtPath:root error:nil]) {
        NSString *full = [root stringByAppendingPathComponent:name];
        BOOL d = NO;
        [fm fileExistsAtPath:full isDirectory:&d];
        if (d) CollectMachOBinaries(full, out, seen);
        else if (![seen containsObject:full]) {
            NSString *head = RunShell([NSString stringWithFormat:@"/usr/bin/otool -h %@ 2>/dev/null", full]);
            if ([head containsString:@"Mach-O"]) { [out addObject:full]; [seen addObject:full]; }
        }
    }
}

static NSDictionary *ScanAppAtPath(NSString *appPath, NSDictionary *catalog) {
    NSMutableArray *binaries = [NSMutableArray array];
    CollectMachOBinaries(appPath, binaries, [NSMutableSet set]);
    NSString *info = [appPath stringByAppendingPathComponent:@"Info.plist"];
    NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:info] ?: @{};
    NSString *minOS = plist[@"MinimumOSVersion"] ?: @"0";
    BOOL min18 = [minOS compare:@"18.0" options:NSNumericSearch] != NSOrderedAscending;
    NSArray *frameworks = catalog[@"frameworks"] ?: @[];
    NSArray *risky = catalog[@"risky_dylibs"] ?: @[];
    NSMutableSet *linkedRisky = [NSMutableSet set];
    double maxMinOS = 0;
    for (NSString *bin in binaries) {
        NSString *lv = RunShell([NSString stringWithFormat:@"/usr/bin/otool -l %@ 2>/dev/null", bin]);
        for (NSString *r in risky) if ([lv containsString:r]) [linkedRisky addObject:r];
        for (NSString *fw in frameworks) if ([lv containsString:fw]) [linkedRisky addObject:fw];
        NSString *bv = RunShell([NSString stringWithFormat:@"/usr/bin/otool -l -build_version %@ 2>/dev/null", bin]);
        NSScanner *sc = [NSScanner scannerWithString:bv];
        double ver = 0;
        while ([sc scanDouble:&ver]) if (ver > maxMinOS && ver < 30) maxMinOS = ver;
    }
    SO17ScanVerdict verdict = SO17ScanVerdictSpoofOnly;
    if (linkedRisky.count > 0) verdict = SO17ScanVerdictNotFeasible;
    else if (!min18 && maxMinOS < 18.0) verdict = SO17ScanVerdictLikelyOK;
    return @{
        @"path": appPath ?: @"",
        @"minimumOSVersion": minOS,
        @"machOMaxMinOS": @(maxMinOS),
        @"riskyLinks": linkedRisky.allObjects,
        @"verdict": VerdictString(verdict),
        @"scannedAt": [NSDate date].description
    };
}

static void PrintUsage(void) {
    fputs("stayon17-scan scan --bundle-id <id> [--json]\n", stderr);
    fputs("stayon17-scan enable <id> [--spoof 18.0]\n", stderr);
    fputs("stayon17-scan disable <id>\n", stderr);
    fputs("stayon17-scan list\n", stderr);
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        if (argc < 2) { PrintUsage(); return 1; }
        NSString *cmd = [NSString stringWithUTF8String:argv[1]];
        SO17Prefs *prefs = [SO17Prefs shared];
        if ([cmd isEqualToString:@"list"]) {
            for (NSString *bid in [prefs enabledBundleIDs]) printf("%s\n", bid.UTF8String);
            return 0;
        }
        if ([cmd isEqualToString:@"enable"] && argc >= 3) {
            NSString *bid = [NSString stringWithUTF8String:argv[2]];
            NSString *spoof = [prefs defaultSpoofVersion];
            for (int i = 3; i + 1 < argc; i++) if (!strcmp(argv[i], "--spoof")) spoof = [NSString stringWithUTF8String:argv[i + 1]];
            [prefs setEnabled:YES forBundle:bid spoofVersion:spoof];
            printf("enabled %s\n", bid.UTF8String);
            return 0;
        }
        if ([cmd isEqualToString:@"disable"] && argc >= 3) {
            NSString *bid = [NSString stringWithUTF8String:argv[2]];
            [prefs setEnabled:NO forBundle:bid spoofVersion:nil];
            return 0;
        }
        if ([cmd isEqualToString:@"scan"]) {
            BOOL json = NO;
            NSString *bundleID = nil;
            NSString *ipa = nil;
            for (int i = 2; i < argc; i++) {
                if (!strcmp(argv[i], "--json")) json = YES;
                else if (!strcmp(argv[i], "--bundle-id") && i + 1 < argc) bundleID = [NSString stringWithUTF8String:argv[++i]];
                else if (!strcmp(argv[i], "--ipa") && i + 1 < argc) ipa = [NSString stringWithUTF8String:argv[++i]];
            }
            NSString *appPath = nil;
            if (bundleID.length) appPath = AppPathForBundleID(bundleID);
            else if (ipa.length) {
                NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
                [[NSFileManager defaultManager] createDirectoryAtPath:tmp withIntermediateDirectories:YES attributes:nil error:nil];
                RunShell([NSString stringWithFormat:@"/usr/bin/unzip -q %@ -d %@ 2>/dev/null", ipa, tmp]);
                for (NSString *rel in [[NSFileManager defaultManager] enumeratorAtPath:tmp]) {
                    if ([rel hasSuffix:@".app"] && [rel hasPrefix:@"Payload/"]) {
                        appPath = [tmp stringByAppendingPathComponent:rel];
                        break;
                    }
                }
            }
            if (!appPath.length) return 1;
            NSDictionary *result = ScanAppAtPath(appPath, LoadCatalog());
            if (bundleID.length) [prefs setScanCache:result forBundle:bundleID];
            if (json) {
                NSData *d = [NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:nil];
                NSString *s = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
                printf("%s\n", s.UTF8String);
            } else {
                printf("verdict=%s minOS=%s\n", [result[@"verdict"] UTF8String], [result[@"minimumOSVersion"] UTF8String]);
            }
            return 0;
        }
        PrintUsage();
        return 1;
    }
}
