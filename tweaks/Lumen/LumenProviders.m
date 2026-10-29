#import "LumenProviders.h"
#import "LumenPrefs.h"
#import <dlfcn.h>
#import <net/if.h>
#import <net/if_var.h>
#import <ifaddrs.h>
#import <sys/mount.h>
#import <sys/statvfs.h>

// MediaRemote is private and header-less. It is resolved with dlsym so the
// tweak has no link-time dependency on the framework or its path.
typedef void (*LumenMRNowPlayingFn)(dispatch_queue_t, void (^)(CFDictionaryRef));
typedef void (*LumenMRSendCommandFn)(int, id);

static void *gLumenMediaHandle = NULL;
static LumenMRNowPlayingFn gLumenGetNowPlaying = NULL;
static LumenMRSendCommandFn gLumenSendCommand = NULL;

static BOOL LumenLoadMediaRemote(void) {
    if (gLumenSendCommand) {
        return YES;
    }
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        gLumenMediaHandle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY);
        if (!gLumenMediaHandle) {
            return;
        }
        gLumenGetNowPlaying = (LumenMRNowPlayingFn)dlsym(gLumenMediaHandle, "MRMediaRemoteGetNowPlayingInfo");
        gLumenSendCommand = (LumenMRSendCommandFn)dlsym(gLumenMediaHandle, "MRMediaRemoteSendCommand");
    });
    return gLumenSendCommand != NULL;
}

enum {
    LumenMRTogglePlayPause = 2,
    LumenMRNextTrack = 4,
    LumenMRPreviousTrack = 5,
};

@implementation LumenReading
+ (instancetype)readingWithText:(NSString *)text symbol:(NSString *)symbol {
    LumenReading *reading = [LumenReading new];
    reading.text = text;
    reading.symbol = symbol;
    return reading;
}
@end

static NSString *gLumenNowPlaying = nil;

NSString *LumenCachedNowPlaying(void) {
    return gLumenNowPlaying;
}

void LumenRefreshNowPlaying(void) {
    if (!LumenLoadMediaRemote() || !gLumenGetNowPlaying) {
        return;
    }
    static CFAbsoluteTime lastFetch = 0;
    if (CFAbsoluteTimeGetCurrent() - lastFetch < 2.0) {
        return;
    }
    lastFetch = CFAbsoluteTimeGetCurrent();
    gLumenGetNowPlaying(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^(CFDictionaryRef info) {
        NSDictionary *dictionary = (__bridge NSDictionary *)info;
        NSString *title = dictionary[@"kMRMediaRemoteNowPlayingInfoTitle"];
        NSString *artist = dictionary[@"kMRMediaRemoteNowPlayingInfoArtist"];
        NSString *line = nil;
        if ([title isKindOfClass:[NSString class]] && title.length) {
            line = [artist isKindOfClass:[NSString class]] && artist.length
                ? [NSString stringWithFormat:@"%@ - %@", title, artist]
                : title;
        }
        gLumenNowPlaying = line;
    });
}

BOOL LumenMediaAvailable(void) {
    return LumenLoadMediaRemote();
}

void LumenMediaPlayPause(void) {
    if (LumenLoadMediaRemote()) {
        gLumenSendCommand(LumenMRTogglePlayPause, nil);
    }
}

void LumenMediaNext(void) {
    if (LumenLoadMediaRemote()) {
        gLumenSendCommand(LumenMRNextTrack, nil);
    }
}

void LumenMediaPrevious(void) {
    if (LumenLoadMediaRemote()) {
        gLumenSendCommand(LumenMRPreviousTrack, nil);
    }
}

static NSString *LumenFormatBytes(double bytes) {
    static NSString *const units[] = { @"B", @"KB", @"MB", @"GB", @"TB" };
    int index = 0;
    while (bytes >= 1000.0 && index < 4) {
        bytes /= 1024.0;
        index++;
    }
    return [NSString stringWithFormat:(index == 0 ? @"%.0f%@" : @"%.1f%@"), bytes, units[index]];
}

NSString *LumenStorageSummary(void) {
    struct statvfs stats;
    if (statvfs("/var", &stats) != 0) {
        return @"--";
    }
    double free = (double)stats.f_bavail * (double)stats.f_frsize;
    double total = (double)stats.f_blocks * (double)stats.f_frsize;
    if (total <= 0) {
        return @"--";
    }
    return [NSString stringWithFormat:@"%@ free", LumenFormatBytes(free)];
}

// if_data counters are 32-bit and wrap; at a one second cadence fewer than 4 GB
// can accumulate between samples, so a wrap is detected instead of misread.
static uint32_t LumenNetworkBytes(void) {
    struct ifaddrs *interfaces = NULL;
    if (getifaddrs(&interfaces) != 0 || !interfaces) {
        return 0;
    }
    uint32_t total = 0;
    for (struct ifaddrs *cursor = interfaces; cursor; cursor = cursor->ifa_next) {
        if (!cursor->ifa_data || !cursor->ifa_addr || cursor->ifa_addr->sa_family != AF_LINK) {
            continue;
        }
        if ((cursor->ifa_flags & IFF_LOOPBACK) != 0) {
            continue;
        }
        struct if_data *data = cursor->ifa_data;
        total += data->ifi_ibytes + data->ifi_obytes;
    }
    freeifaddrs(interfaces);
    return total;
}

static uint32_t gLumenLastBytes = 0;
static CFAbsoluteTime gLumenLastSample = 0;

void LumenNetworkResetSampler(void) {
    gLumenLastBytes = 0;
    gLumenLastSample = 0;
}

NSString *LumenNetworkSummary(void) {
    uint32_t current = LumenNetworkBytes();
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (gLumenLastSample == 0) {
        gLumenLastBytes = current;
        gLumenLastSample = now;
        return @"0 KB/s";
    }
    double elapsed = now - gLumenLastSample;
    if (elapsed < 0.5) {
        return @"--";
    }
    uint64_t delta = current >= gLumenLastBytes ? (uint64_t)(current - gLumenLastBytes)
                                                : (uint64_t)current + (UINT32_MAX - (uint64_t)gLumenLastBytes) + 1;
    gLumenLastBytes = current;
    gLumenLastSample = now;
    return [NSString stringWithFormat:@"%@/s", LumenFormatBytes((double)delta / elapsed)];
}

NSArray<NSString *> *LumenBatteryDetails(void) {
    UIDevice *device = UIDevice.currentDevice;
    BOOL wasEnabled = device.batteryMonitoringEnabled;
    device.batteryMonitoringEnabled = YES;
    NSInteger percent = (NSInteger)lroundf(device.batteryLevel * 100.0f);
    NSString *state = @"On battery";
    switch (device.batteryState) {
        case UIDeviceBatteryStateCharging: state = @"Charging"; break;
        case UIDeviceBatteryStateFull: state = @"Full"; break;
        case UIDeviceBatteryStateUnplugged: state = @"On battery"; break;
        case UIDeviceBatteryStateUnknown: state = @"Unknown"; break;
    }
    device.batteryMonitoringEnabled = wasEnabled;
    return @[
        [NSString stringWithFormat:@"%ld%%", (long)MAX(percent, 0)],
        state,
        [NSString stringWithFormat:@"Low power mode: %@", NSProcessInfo.processInfo.isLowPowerModeEnabled ? @"on" : @"off"],
    ];
}

static NSString *LumenBatteryText(void) {
    UIDevice *device = UIDevice.currentDevice;
    BOOL wasEnabled = device.batteryMonitoringEnabled;
    device.batteryMonitoringEnabled = YES;
    NSInteger percent = (NSInteger)lroundf(device.batteryLevel * 100.0f);
    device.batteryMonitoringEnabled = wasEnabled;
    if (percent <= 0) {
        return nil;
    }
    return [NSString stringWithFormat:@"%ld%%", (long)percent];
}

static NSString *LumenCountdownText(NSDate *date) {
    NSTimeInterval remaining = [date timeIntervalSinceNow];
    if (remaining <= 0) {
        return @"now";
    }
    long days = (long)(remaining / 86400.0);
    if (days >= 1) {
        return [NSString stringWithFormat:@"%ldd", days];
    }
    long hours = (long)(remaining / 3600.0);
    if (hours >= 1) {
        return [NSString stringWithFormat:@"%ldh", hours];
    }
    return [NSString stringWithFormat:@"%ldm", (long)MAX(remaining / 60.0, 1)];
}

NSDictionary<NSString *, LumenReading *> *LumenReadingsForPills(NSArray<NSString *> *pills,
                                                                NSDateFormatter *timeFormatter,
                                                                NSDateFormatter *dateFormatter) {
    NSMutableDictionary *readings = [NSMutableDictionary dictionary];
    NSDate *now = [NSDate date];

    for (NSString *pill in pills) {
        LumenReading *reading = nil;
        if ([pill isEqualToString:@"time"]) {
            reading = [LumenReading readingWithText:[timeFormatter stringFromDate:now] symbol:nil];
        } else if ([pill isEqualToString:@"date"]) {
            reading = [LumenReading readingWithText:[dateFormatter stringFromDate:now] symbol:nil];
        } else if ([pill isEqualToString:@"battery"]) {
            NSString *text = LumenBatteryText();
            if (text) {
                reading = [LumenReading readingWithText:text symbol:nil];
            }
        } else if ([pill isEqualToString:@"playing"]) {
            NSString *text = LumenCachedNowPlaying();
            if (text) {
                reading = [LumenReading readingWithText:text symbol:@"play.fill"];
            }
        } else if ([pill isEqualToString:@"network"]) {
            reading = [LumenReading readingWithText:LumenNetworkSummary() symbol:@"antenna.radiowaves.left.and.right"];
        } else if ([pill isEqualToString:@"storage"]) {
            reading = [LumenReading readingWithText:LumenStorageSummary() symbol:@"internaldrive"];
        } else if ([pill isEqualToString:@"countdown"]) {
            NSDate *target = LumenCountdownDate();
            if (target) {
                reading = [LumenReading readingWithText:LumenCountdownText(target) symbol:@"hourglass"];
            }
        } else if ([pill isEqualToString:@"message"]) {
            reading = [LumenReading readingWithText:@"Message" symbol:@"bubble.left.fill"];
        }
        if (reading) {
            readings[pill] = reading;
        }
    }
    return readings;
}
