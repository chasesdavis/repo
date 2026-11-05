#import "SpoofyConfig.h"

NSDictionary *SpoofyReadConfig(NSString *path) {
    return [NSDictionary dictionaryWithContentsOfFile:path];
}

BOOL SpoofySaveEnabled(NSString *path, BOOL enabled) {
    if (!path.length) return NO;
    NSString *directory = [path stringByDeletingLastPathComponent];
    if (![[NSFileManager defaultManager] createDirectoryAtPath:directory
        withIntermediateDirectories:YES attributes:nil error:NULL]) return NO;
    NSDictionary *config = @{@"Enabled": @(enabled), @"ReportedVersion": @"18.0"};
    return [config writeToFile:path atomically:YES];
}
