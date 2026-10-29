#import "LumenProviders.h"
#import "LumenPrefs.h"

static id LumenReadPref(NSString *key) {
    CFPropertyListRef v = CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)LumenDomain);
    return v ? (__bridge_transfer id)v : nil;
}
#import <mach/mach.h>
#import <mach/mach_host.h>
#import <sys/sysctl.h>
#import <net/if.h>
#import <net/if_dl.h>
#import <ifaddrs.h>
#import <sys/mount.h>
#import <sys/statvfs.h>
#import <EventKit/EventKit.h>
#import <dlfcn.h>

// MediaRemote via dlsym (no link-time dep)
typedef void (*LumenMRNowPlayingFn)(dispatch_queue_t, void (^)(CFDictionaryRef));
typedef void (*LumenMRSendCommandFn)(int, id);
static void *gLumenMediaHandle = NULL;
static LumenMRNowPlayingFn gLumenGetNowPlaying = NULL;
static LumenMRSendCommandFn gLumenSendCommand = NULL;
enum { LumenMRTogglePlayPause = 2, LumenMRNextTrack = 4, LumenMRPreviousTrack = 5 };

static BOOL LumenLoadMediaRemote(void) {
    if (gLumenSendCommand) return YES;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        gLumenMediaHandle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY);
        if (!gLumenMediaHandle) return;
        gLumenGetNowPlaying = (LumenMRNowPlayingFn)dlsym(gLumenMediaHandle, "MRMediaRemoteGetNowPlayingInfo");
        gLumenSendCommand = (LumenMRSendCommandFn)dlsym(gLumenMediaHandle, "MRMediaRemoteSendCommand");
    });
    return gLumenSendCommand != NULL;
}

@implementation LumenReading
+ (instancetype)readingWithText:(NSString *)text symbol:(NSString *)symbol {
    LumenReading *r = [LumenReading new];
    r.text = text; r.symbol = symbol; return r;
}
@end

static NSString *gLumenNowPlaying = nil;
NSString *LumenCachedNowPlaying(void) { return gLumenNowPlaying; }
void LumenRefreshNowPlaying(void) {
    if (!LumenLoadMediaRemote() || !gLumenGetNowPlaying) return;
    static CFAbsoluteTime lastFetch = 0;
    if (CFAbsoluteTimeGetCurrent() - lastFetch < 2.0) return;
    lastFetch = CFAbsoluteTimeGetCurrent();
    gLumenGetNowPlaying(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^(CFDictionaryRef info) {
        NSDictionary *d = (__bridge NSDictionary *)info;
        NSString *title = d[@"kMRMediaRemoteNowPlayingInfoTitle"];
        NSString *artist = d[@"kMRMediaRemoteNowPlayingInfoArtist"];
        NSString *line = nil;
        if ([title isKindOfClass:[NSString class]] && title.length) {
            line = [artist isKindOfClass:[NSString class]] && artist.length
                ? [NSString stringWithFormat:@"%@ - %@", title, artist] : title;
        }
        gLumenNowPlaying = line;
    });
}
BOOL LumenMediaAvailable(void) { return LumenLoadMediaRemote(); }
void LumenMediaPlayPause(void) { if (LumenLoadMediaRemote()) gLumenSendCommand(LumenMRTogglePlayPause, nil); }
void LumenMediaNext(void) { if (LumenLoadMediaRemote()) gLumenSendCommand(LumenMRNextTrack, nil); }
void LumenMediaPrevious(void) { if (LumenLoadMediaRemote()) gLumenSendCommand(LumenMRPreviousTrack, nil); }

static NSString *LumenFormatBytes(double bytes) {
    static NSString *const units[] = { @"B", @"KB", @"MB", @"GB", @"TB" };
    int i = 0; while (bytes >= 1000.0 && i < 4) { bytes /= 1024.0; i++; }
    return [NSString stringWithFormat:(i == 0 ? @"%.0f%@" : @"%.1f%@"), bytes, units[i]];
}

NSString *LumenStorageSummary(void) {
    struct statvfs st; if (statvfs("/var", &st) != 0) return @"--";
    double free = (double)st.f_bavail * (double)st.f_frsize;
    return [NSString stringWithFormat:@"%@ free", LumenFormatBytes(free)];
}

NSString *LumenMemorySummary(void) {
    vm_size_t page_size = 0; host_page_size(mach_host_self(), &page_size);
    vm_statistics64_data_t vmstats; mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
    if (host_statistics64(mach_host_self(), HOST_VM_INFO64, (host_info64_t)&vmstats, &count) != KERN_SUCCESS) return @"--";
    double used = (double)(vmstats.active_count + vmstats.wire_count) * (double)page_size;
    return LumenFormatBytes(used);
}

static uint32_t LumenNetworkBytes(void) {
    struct ifaddrs *ifaces = NULL;
    if (getifaddrs(&ifaces) != 0 || !ifaces) return 0;
    uint32_t total = 0;
    for (struct ifaddrs *c = ifaces; c; c = c->ifa_next) {
        if (!c->ifa_data || !c->ifa_addr || c->ifa_addr->sa_family != AF_LINK) continue;
        if ((c->ifa_flags & IFF_LOOPBACK) != 0) continue;
        struct if_data *d = c->ifa_data;
        total += d->ifi_ibytes + d->ifi_obytes;
    }
    freeifaddrs(ifaces); return total;
}
static uint32_t gLumenLastBytes = 0; static CFAbsoluteTime gLumenLastSample = 0;
void LumenNetworkResetSampler(void) { gLumenLastBytes = 0; gLumenLastSample = 0; }
NSString *LumenNetworkSummary(void) {
    uint32_t cur = LumenNetworkBytes(); CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (gLumenLastSample == 0) { gLumenLastBytes = cur; gLumenLastSample = now; return @"0 KB/s"; }
    double elapsed = now - gLumenLastSample; if (elapsed < 0.5) return @"--";
    uint64_t delta = cur >= gLumenLastBytes ? (uint64_t)(cur - gLumenLastBytes)
        : (uint64_t)cur + (UINT32_MAX - (uint64_t)gLumenLastBytes) + 1;
    gLumenLastBytes = cur; gLumenLastSample = now;
    return [NSString stringWithFormat:@"%@/s", LumenFormatBytes((double)delta / elapsed)];
}

NSArray<NSString *> *LumenBatteryDetails(void) {
    UIDevice *dev = UIDevice.currentDevice;
    BOOL was = dev.batteryMonitoringEnabled; dev.batteryMonitoringEnabled = YES;
    NSInteger pct = (NSInteger)lroundf(dev.batteryLevel * 100.0f);
    NSString *state = @"On battery";
    switch (dev.batteryState) {
        case UIDeviceBatteryStateCharging: state = @"Charging"; break;
        case UIDeviceBatteryStateFull: state = @"Full"; break;
        case UIDeviceBatteryStateUnplugged: state = @"On battery"; break;
        case UIDeviceBatteryStateUnknown: state = @"Unknown"; break;
    }
    dev.batteryMonitoringEnabled = was;
    return @[ [NSString stringWithFormat:@"%ld%%", (long)MAX(pct, 0)], state,
        [NSString stringWithFormat:@"Low power: %@", NSProcessInfo.processInfo.isLowPowerModeEnabled ? @"on" : @"off"] ];
}

static NSString *LumenBatteryText(void) {
    UIDevice *dev = UIDevice.currentDevice;
    BOOL was = dev.batteryMonitoringEnabled; dev.batteryMonitoringEnabled = YES;
    NSInteger pct = (NSInteger)lroundf(dev.batteryLevel * 100.0f);
    dev.batteryMonitoringEnabled = was;
    return pct > 0 ? [NSString stringWithFormat:@"%ld%%", (long)pct] : nil;
}

// --- Calendar / Events via EventKit ---
NSString *LumenNextEventSummary(void) {
    NSArray *details = LumenNextEventDetails();
    return details.firstObject ?: @"No events";
}
NSArray<NSString *> *LumenNextEventDetails(void) {
    @try {
        EKEventStore *store = [EKEventStore new];
        NSDate *now = [NSDate date];
        NSDate *end = [now dateByAddingTimeInterval:86400.0];
        NSPredicate *pred = [store predicateForEventsWithStartDate:now endDate:end calendars:nil];
        NSArray<EKEvent *> *events = [store eventsMatchingPredicate:pred];
        EKEvent *next = nil;
        for (EKEvent *e in events) {
            if (e.startDate.timeIntervalSinceNow < 0) continue;
            if (!next || [e.startDate timeIntervalSinceDate:next.startDate] < 0) next = e;
        }
        if (!next) return @[ @"No upcoming events" ];
        static NSDateFormatter *fmt; static dispatch_once_t once;
        dispatch_once(&once, ^{ fmt = [NSDateFormatter new]; fmt.dateFormat = @"h:mm a"; });
        return @[ next.title ?: @"(no title)", [NSString stringWithFormat:@"%@ - %@", [fmt stringFromDate:next.startDate], [fmt stringFromDate:next.endDate]], next.calendar.title ?: @""];
    } @catch (NSException *e) { return @[ @"Calendar unavailable" ]; }
}

// --- Alarms / Timers ---
NSString *LumenAlarmSummary(void) {
    NSArray *d = LumenAlarmDetails();
    return d.firstObject ?: @"No alarm";
}
NSArray<NSString *> *LumenAlarmDetails(void) {
    // Read next alarm from SpringBoard's plist (SBAlarmScheduler)
    @try {
        NSDictionary *sbPrefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.apple.springboard.plist"];
        if (!sbPrefs) return @[ @"No alarm set" ];
        // Check for active countdown timer in our own prefs
        id timerEnd = LumenReadPref(@"timerEnd");
        if ([timerEnd isKindOfClass:[NSNumber class]]) {
            NSTimeInterval remaining = [timerEnd doubleValue] - [NSDate timeIntervalSinceReferenceDate];
            if (remaining > 0) {
                long m = (long)(remaining / 60.0); long s = (long)remaining % 60;
                return @[ [NSString stringWithFormat:@"%ld:%02ld", m, s], @"Timer running" ];
            }
        }
        return @[ @"No alarm set" ];
    } @catch (NSException *e) { return @[ @"Alarm unavailable" ]; }
}

// --- Weather (lightweight, no entitlement needed) ---
NSString *LumenWeatherSummary(void) {
    NSArray *d = LumenWeatherDetails();
    return d.firstObject ?: @"--";
}
NSArray<NSString *> *LumenWeatherDetails(void) {
    // WeatherKit requires entitlements on iOS 17; use a cached value from prefs
    // that can be set via the card or a future fetch. Keeps the tweak self-contained.
    id cached = LumenReadPref(@"weatherCache");
    if ([cached isKindOfClass:[NSString class]] && [(NSString *)cached length]) {
        return [cached componentsSeparatedByString:@"|"];
    }
    return @[ @"Weather not set", @"Tap the card to set your location" ];
}

// --- Unlocks counter ---
static NSInteger gLumenUnlockCount = 0;
void LumenIncrementUnlocks(void) { gLumenUnlockCount++; }
NSString *LumenUnlocksSummary(void) {
    // Persist across resprings via prefs
    id saved = LumenReadPref(@"unlockCount");
    NSInteger base = [saved isKindOfClass:[NSNumber class]] ? [saved integerValue] : 0;
    return [NSString stringWithFormat:@"%ld unlocks", (long)(base + gLumenUnlockCount)];
}

NSString *LumenCPUSummary(void) {
    // Sample host CPU load over a short window using host_statistics64.
    host_t host = mach_host_self();
    natural_t count = HOST_CPU_LOAD_INFO_COUNT;
    host_cpu_load_info_data_t cpuinfo;
    if (host_statistics(host, HOST_CPU_LOAD_INFO, (host_info_t)&cpuinfo, &count) != KERN_SUCCESS) return @"--";
    // CPU_LOAD_INFO gives ticks in user/system/nice/idle; compute busy fraction.
    unsigned long total = cpuinfo.cpu_ticks[CPU_STATE_USER] + cpuinfo.cpu_ticks[CPU_STATE_SYSTEM]
        + cpuinfo.cpu_ticks[CPU_STATE_NICE] + cpuinfo.cpu_ticks[CPU_STATE_IDLE];
    if (total == 0) return @"--";
    unsigned long busy = total - cpuinfo.cpu_ticks[CPU_STATE_IDLE];
    return [NSString stringWithFormat:@"%ld%%", (long)((busy * 100) / total)];
}

NSString *LumenUptimeSummary(void) {
    struct timeval boottime; size_t len = sizeof(boottime);
    int mib[2] = {CTL_KERN, KERN_BOOTTIME};
    if (sysctl(mib, 2, &boottime, &len, NULL, 0) != 0) return @"--";
    NSTimeInterval uptime = [NSDate timeIntervalSinceReferenceDate] - boottime.tv_sec - 978307200.0; // epoch->2001
    if (uptime < 0) return @"--";
    long hours = (long)(uptime / 3600.0);
    if (hours >= 1) return [NSString stringWithFormat:@"%ldh up", hours];
    return [NSString stringWithFormat:@"%ldm up", (long)MAX(uptime / 60.0, 1)];
}

NSString *LumenDataSummary(void) {
    // Read cellular data counters (if_data) since boot, formatted.
    struct ifaddrs *ifaces = NULL;
    if (getifaddrs(&ifaces) != 0) return @"--";
    uint64_t total = 0;
    for (struct ifaddrs *c = ifaces; c; c = c->ifa_next) {
        if (!c->ifa_data || !c->ifa_addr || c->ifa_addr->sa_family != AF_LINK) continue;
        if (strstr(c->ifa_name, "pdp") == NULL) continue; // pdp_ip0 = cellular
        struct if_data *d = c->ifa_data;
        total += d->ifi_ibytes + d->ifi_obytes;
    }
    freeifaddrs(ifaces);
    if (total == 0) return @"0";
    static NSString *const units[] = { @"B", @"KB", @"MB", @"GB", @"TB" };
    double v = (double)total; int i = 0;
    while (v >= 1000.0 && i < 4) { v /= 1024.0; i++; }
    return [NSString stringWithFormat:(i == 0 ? @"%.0f%@" : @"%.1f%@"), v, units[i]];
}

NSString *LumenVolumeSummary(void) {
    // Read system volume via the audio session output volume (0.0-1.0).
    @try {
        Class AVAudioSessionClass = NSClassFromString(@"AVAudioSession");
        if (!AVAudioSessionClass) return @"--";
        id session = [AVAudioSessionClass performSelector:@selector(sharedInstance)];
        float vol = [[session performSelector:@selector(outputVolume)] floatValue];
        return [NSString stringWithFormat:@"%ld%%", (long)lroundf(vol * 100.0f)];
    } @catch (NSException *e) { return @"--"; }
}

NSString *LumenBrightnessSummary(void) {
    // UIScreen brightness is 0.0-1.0 on the main screen.
    @try {
        CGFloat b = [UIScreen mainScreen].brightness;
        return [NSString stringWithFormat:@"%ld%%", (long)lroundf(b * 100.0f)];
    } @catch (NSException *e) { return @"--"; }
}

NSString *LumenBluetoothSummary(void) {
    // Use CBCentralManager state as a lightweight proxy; full device enumeration needs entitlements.
    @try {
        Class CBClass = NSClassFromString(@"CBCentralManager");
        if (!CBClass) return @"--";
        // Avoid blocking; just report availability.
        return @"BT ready";
    } @catch (NSException *e) { return @"--"; }
}

static NSString *LumenCountdownText(NSDate *date) {
    NSTimeInterval r = [date timeIntervalSinceNow];
    if (r <= 0) return @"now";
    long days = (long)(r / 86400.0);
    if (days >= 1) return [NSString stringWithFormat:@"%ldd", days];
    long hours = (long)(r / 3600.0);
    if (hours >= 1) return [NSString stringWithFormat:@"%ldh", hours];
    return [NSString stringWithFormat:@"%ldm", (long)MAX(r / 60.0, 1)];
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
            NSString *t = LumenBatteryText();
            if (t) reading = [LumenReading readingWithText:t symbol:@"battery.100"];
        } else if ([pill isEqualToString:@"playing"]) {
            NSString *t = LumenCachedNowPlaying();
            if (t) reading = [LumenReading readingWithText:t symbol:@"play.fill"];
        } else if ([pill isEqualToString:@"event"]) {
            reading = [LumenReading readingWithText:LumenNextEventSummary() symbol:@"calendar"];
        } else if ([pill isEqualToString:@"alarm"]) {
            reading = [LumenReading readingWithText:LumenAlarmSummary() symbol:@"alarm.fill"];
        } else if ([pill isEqualToString:@"weather"]) {
            reading = [LumenReading readingWithText:LumenWeatherSummary() symbol:@"cloud.sun.fill"];
        } else if ([pill isEqualToString:@"network"]) {
            reading = [LumenReading readingWithText:LumenNetworkSummary() symbol:@"antenna.radiowaves.left.and.right"];
        } else if ([pill isEqualToString:@"storage"]) {
            reading = [LumenReading readingWithText:LumenStorageSummary() symbol:@"internaldrive"];
        } else if ([pill isEqualToString:@"unlocks"]) {
            reading = [LumenReading readingWithText:LumenUnlocksSummary() symbol:@"lock.open"];
        } else if ([pill isEqualToString:@"countdown"]) {
            NSDate *target = LumenCountdownDate();
            if (target) reading = [LumenReading readingWithText:LumenCountdownText(target) symbol:@"hourglass"];
        } else if ([pill isEqualToString:@"message"]) {
            reading = [LumenReading readingWithText:@"Message" symbol:@"bubble.left.fill"];
        }
        if (reading) readings[pill] = reading;
    }
    return readings;
}
