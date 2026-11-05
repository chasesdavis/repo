#import "HBMediaProvider.h"
#import "HBPolicy.h"
#import <ImageIO/ImageIO.h>
#import <dlfcn.h>

typedef void (*HBGetInfo)(dispatch_queue_t, void (^)(CFDictionaryRef));
typedef Boolean (*HBSendCommand)(int, NSDictionary *);

@implementation HBMediaSnapshot
@end

@interface HBMediaProvider ()
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic) BOOL active;
@property (nonatomic) BOOL inFlight;
@property (nonatomic) NSUInteger generation;
@property (nonatomic, strong) HBMediaSnapshot *snapshot;
@end

@implementation HBMediaProvider {
    void *_handle;
    HBGetInfo _getInfo;
    HBSendCommand _send;
    dispatch_queue_t _queue;
    NSDictionary<NSString *, NSString *> *_keys;
    NSData *_previousArtwork;
    UIImage *_thumbnail;
}
- (instancetype)init {
    if ((self = [super init])) {
        _queue = dispatch_queue_create("com.chasedavis.harbor.media", DISPATCH_QUEUE_SERIAL);
        _handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY | RTLD_LOCAL);
        if (_handle) {
            _getInfo = (HBGetInfo)dlsym(_handle, "MRMediaRemoteGetNowPlayingInfo");
            _send = (HBSendCommand)dlsym(_handle, "MRMediaRemoteSendCommand");
            NSMutableDictionary *keys = [NSMutableDictionary dictionary];
            for (NSString *suffix in @[@"Title", @"Artist", @"ArtworkData", @"PlaybackRate", @"ProhibitsSkip"]) {
                NSString *name = [@"kMRMediaRemoteNowPlayingInfo" stringByAppendingString:suffix];
                CFStringRef *symbol = (CFStringRef *)dlsym(_handle, name.UTF8String);
                if (symbol && *symbol) keys[suffix] = (__bridge NSString *)*symbol;
            }
            _keys = [keys copy];
        }
    }
    return self;
}
- (void)start {
    if (self.active) return;
    self.active = YES;
    __weak typeof(self) weakSelf = self;
    self.timer = [NSTimer timerWithTimeInterval:2 repeats:YES block:^(NSTimer *timer) { [weakSelf refresh]; }];
    self.timer.tolerance = 0.3;
    [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSDefaultRunLoopMode];
    [self refresh];
}
- (void)stop {
    self.active = NO;
    self.generation++;
    self.inFlight = NO;
    [self.timer invalidate];
    self.timer = nil;
}
- (void)refresh {
    NSAssert(NSThread.isMainThread, @"Harbor media lifecycle must run on main");
    if (!self.active || self.inFlight) return;
    HBMediaSnapshot *empty = [HBMediaSnapshot new];
    empty.title = @"Nothing playing";
    empty.artist = @"Your next moment of calm.";
    empty.available = _getInfo && _send && _keys[@"Title"];
    if (!empty.available) {
        empty.title = @"Media unavailable";
        empty.artist = @"Use All controls for system media.";
        self.snapshot = empty;
        if (self.onUpdate) self.onUpdate(empty);
        return;
    }
    self.inFlight = YES;
    NSUInteger generation = ++self.generation;
    __weak typeof(self) weakSelf = self;
    // A missing private callback must not leave stale, actionable media forever.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 4 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        HBMediaProvider *self = weakSelf;
        if (!self.active || self.generation != generation || !self.inFlight) return;
        self.generation++;
        self.inFlight = NO;
        self.snapshot = empty;
        if (self.onUpdate) self.onUpdate(empty);
    });
    _getInfo(_queue, ^(CFDictionaryRef info) {
        HBMediaProvider *self = weakSelf;
        if (!self) return;
        NSDictionary *data = (__bridge NSDictionary *)info;
        if (![data isKindOfClass:NSDictionary.class]) data = @{};
        id (^value)(NSString *) = ^id(NSString *key) { NSString *resolved = self->_keys[key]; return resolved ? data[resolved] : nil; };
        id title = value(@"Title"), artist = value(@"Artist"), art = value(@"ArtworkData");
        id rate = value(@"PlaybackRate"), prohibitsSkip = value(@"ProhibitsSkip");
        HBMediaSnapshot *snapshot = [HBMediaSnapshot new];
        snapshot.available = YES;
        snapshot.hasSession = [title isKindOfClass:NSString.class] && [title length] > 0;
        snapshot.title = snapshot.hasSession ? title : empty.title;
        snapshot.artist = snapshot.hasSession && [artist isKindOfClass:NSString.class] && [artist length] ? artist : empty.artist;
        snapshot.playing = [rate isKindOfClass:NSNumber.class] && [rate doubleValue] > 0;
        snapshot.canSkip = snapshot.hasSession && !([prohibitsSkip isKindOfClass:NSNumber.class] && [prohibitsSkip boolValue]);
        NSData *artwork = [art isKindOfClass:NSData.class] && [art length] <= 8 * 1024 * 1024 ? art : nil;
        if (![artwork isEqual:self->_previousArtwork]) {
            self->_previousArtwork = artwork;
            self->_thumbnail = nil;
            if (artwork.length) {
                CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)artwork, NULL);
                if (source) {
                    NSDictionary *options = @{(__bridge NSString *)kCGImageSourceCreateThumbnailFromImageAlways: @YES,
                        (__bridge NSString *)kCGImageSourceThumbnailMaxPixelSize: @320,
                        (__bridge NSString *)kCGImageSourceCreateThumbnailWithTransform: @YES};
                    CGImageRef image = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)options);
                    if (image) { self->_thumbnail = [UIImage imageWithCGImage:image]; CGImageRelease(image); }
                    CFRelease(source);
                }
            }
        }
        snapshot.artwork = snapshot.hasSession ? self->_thumbnail : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            HBMediaProvider *self = weakSelf;
            if (!self.active || self.generation != generation) return;
            self.inFlight = NO;
            self.snapshot = snapshot;
            if (self.onUpdate) self.onUpdate(snapshot);
        });
    });
}
- (BOOL)sendCommand:(int)command {
    if (!self.active || !_send || !HBValidMediaCommand(command) || !self.snapshot.hasSession) return NO;
    if (command != 2 && !self.snapshot.canSkip) return NO;
    BOOL sent = _send(command, nil);
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 4), dispatch_get_main_queue(), ^{ [weakSelf refresh]; });
    return sent;
}
- (void)dealloc {
    [_timer invalidate];
    // Keep MediaRemote loaded: callbacks may still be in flight during teardown.
}
@end
