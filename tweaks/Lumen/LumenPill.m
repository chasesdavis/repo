#import "LumenPill.h"
#import "LumenCard.h"
#import "LumenPrefs.h"
#import "LumenProviders.h"

static const CGFloat kLumenPillHeight = 26.0;
static const CGFloat kLumenPillInset = 18.0;
static const CGFloat kLumenFontSize = 13.0;
static const NSTimeInterval kLumenFastTick = 1.0;
static const NSTimeInterval kLumenSlowTick = 10.0;

@interface LumenPill ()
/// Status bar window from SpringBoard. It persists above foreground apps, so
/// the pill stays visible without owning a second window.
@property (nonatomic, weak) UIView *host;
@property (nonatomic, strong) UIView *pill;
@property (nonatomic, strong) UIVisualEffectView *blur;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *label;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, copy) NSString *activePill;
@property (nonatomic, assign) NSInteger attachAttempts;
@property (nonatomic, strong) NSDateFormatter *timeFormatter;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@end

@implementation LumenPill

+ (instancetype)shared {
    static LumenPill *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [LumenPill new]; });
    return shared;
}

- (instancetype)init {
    if ((self = [super init])) {
        _timeFormatter = [NSDateFormatter new];
        _timeFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        _timeFormatter.dateFormat = @"h:mm a";
        _dateFormatter = [NSDateFormatter new];
        _dateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        _dateFormatter.dateFormat = @"EEE d";
    }
    return self;
}

#pragma mark - Host

- (NSArray<UIWindow *> *)allWindows {
    NSMutableArray<UIWindow *> *windows = [NSMutableArray arrayWithArray:UIApplication.sharedApplication.windows];
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:UIWindowScene.class]) {
            [windows addObjectsFromArray:((UIWindowScene *)scene).windows];
        }
    }
    return windows;
}

- (UIView *)statusBarWindow {
    for (UIWindow *window in [self allWindows]) {
        if ([NSStringFromClass(window.class) containsString:@"StatusBar"] && !window.hidden) {
            return window;
        }
    }
    return nil;
}

- (CGFloat)statusBarHeight {
    UIView *host = self.host;
    UIWindow *window = host.window ?: (UIWindow *)host;
    CGFloat height = window.windowScene.statusBarManager.statusBarFrame.size.height;
    return height > 0 ? height : 54.0;
}

#pragma mark - Lifecycle

- (void)attach {
    if (!LumenEnabled()) {
        [self teardown];
        return;
    }
    UIView *host = [self statusBarWindow];
    if (!host) {
        // SpringBoard can still be bringing up the status bar window.
        if (self.attachAttempts < 40) {
            self.attachAttempts++;
            [self performSelector:@selector(attach) withObject:nil afterDelay:0.25];
        }
        return;
    }
    self.attachAttempts = 0;

    if (self.pill && self.host != host) {
        [self.pill removeFromSuperview];
        self.pill = nil;
    }
    self.host = host;

    NSArray<NSString *> *pills = LumenEnabledPills();
    if (!self.activePill || ![pills containsObject:self.activePill]) {
        NSString *preferred = LumenDefaultPill();
        self.activePill = [pills containsObject:preferred] ? preferred : pills.firstObject;
    }

    host.userInteractionEnabled = YES;
    if (!self.pill) {
        [self buildPill];
    }
    [host bringSubviewToFront:self.pill];
    [self suppressFocusIndicatorIn:host];
    [self layoutPill];
    if ([self.activePill isEqualToString:@"playing"]) {
        LumenRefreshNowPlaying();
    }
    [self refresh];
    [self startTimer];
}

- (void)teardown {
    [self.timer invalidate];
    self.timer = nil;
    [LumenCard dismissVisible];
    [self restoreFocusIndicator];
    [self.pill removeFromSuperview];
    self.pill = nil;
    self.host = nil;
}

/// Stops rendering without clearing prefs state; used when SpringBoard hides
/// the status bar window entirely.
/// Cards belong on the app's window, not the short status bar strip.
- (UIView *)cardContainer {
    for (UIWindow *window in [self allWindows]) {
        if (window.isKeyWindow && ![NSStringFromClass(window.class) containsString:@"StatusBar"]) {
            return window;
        }
    }
    return self.host;
}

/// Hide the Focus/DND moon icon that peeks out beside the pill. The icon
/// lives in the status bar window as a sibling of the time item. We walk
/// the host subviews and hide any whose class name references focus, quiet
/// mode, or DND. A tag marks hidden views so teardown can restore them.
static const NSInteger kLumenFocusHideTag = 91743;

- (void)suppressFocusIndicatorIn:(UIView *)host {
    if (!LumenEnabled() || !LumenHideClock()) {
        return;
    }
    for (UIView *view in host.subviews) {
        NSString *cls = NSStringFromClass(view.class);
        if ([cls containsString:@"Focus"] || [cls containsString:@"Quiet"] || [cls containsString:@"DND"] || [cls containsString:@"DoNotDisturb"]) {
            if (view.tag != kLumenFocusHideTag && view.alpha > 0.01) {
                view.tag = kLumenFocusHideTag;
                view.alpha = 0.0;
            }
        }
    }
}

- (void)restoreFocusIndicator {
    for (UIWindow *window in [self allWindows]) {
        if (![NSStringFromClass(window.class) containsString:@"StatusBar"]) continue;
        for (UIView *view in window.subviews) {
            if (view.tag == kLumenFocusHideTag) {
                view.tag = 0;
                view.alpha = 1.0;
            }
        }
    }
}

#pragma mark - Pill

- (void)buildPill {
    self.pill = [UIView new];
    self.pill.clipsToBounds = NO;

    self.blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark]];
    self.blur.layer.cornerRadius = kLumenPillHeight / 2.0;
    self.blur.layer.cornerCurve = kCACornerCurveContinuous;
    self.blur.clipsToBounds = YES;
    self.blur.userInteractionEnabled = NO;
    [self.pill addSubview:self.blur];

    self.iconView = [UIImageView new];
    self.iconView.contentMode = UIViewContentModeScaleAspectFit;
    [self.pill addSubview:self.iconView];

    self.label = [UILabel new];
    self.label.textAlignment = NSTextAlignmentCenter;
    self.label.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.pill addSubview:self.label];

    [self.pill addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openCard)]];
    UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    press.minimumPressDuration = 0.4;
    [self.pill addGestureRecognizer:press];

    [self.host addSubview:self.pill];
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        [self cyclePill];
    }
}

- (void)cyclePill {
    NSArray<NSString *> *pills = LumenEnabledPills();
    if (pills.count < 2) {
        [self refresh];
        return;
    }
    NSUInteger index = [pills indexOfObject:self.activePill ?: @""];
    self.activePill = pills[(index + 1) % pills.count];
    [self refresh];
}

- (void)openCard {
    if (!self.pill || !self.host) {
        return;
    }
    [LumenCard presentForPill:self.activePill ?: @"time" inView:[self cardContainer]];
}

- (void)layoutPill {
    if (!self.pill) {
        return;
    }
    CGFloat scale = LumenFontScale();
    self.label.font = [UIFont monospacedDigitSystemFontOfSize:kLumenFontSize * scale weight:UIFontWeightSemibold];
    self.blur.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:LumenPillOpacity()];
    self.blur.layer.borderWidth = 0.5;
    self.blur.layer.borderColor = [LumenAccentColor() colorWithAlphaComponent:0.3].CGColor;
}

#pragma mark - Render

- (void)refresh {
    if (!self.pill || !self.host) {
        return;
    }
    if (!LumenEnabled()) {
        [self teardown];
        return;
    }
    NSArray<NSString *> *pills = LumenEnabledPills();
    if (![pills containsObject:self.activePill]) {
        self.activePill = pills.firstObject;
    }
    [self layoutPill];

    NSString *pill = self.activePill ?: @"time";
    LumenReading *reading = LumenReadingsForPills(@[ pill ], self.timeFormatter, self.dateFormatter)[pill];
    if (!reading) {
        reading = [LumenReading readingWithText:@"--" symbol:nil];
    }

    self.label.text = reading.text;
    self.label.textColor = [UIColor colorWithWhite:1.0 alpha:0.96];
    [self.label sizeToFit];

    UIImage *symbol = reading.symbol.length ? [UIImage systemImageNamed:reading.symbol] : nil;
    self.iconView.image = symbol;
    self.iconView.tintColor = LumenAccentColor();
    self.iconView.hidden = (symbol == nil);

    CGFloat iconWidth = symbol ? 13.0 : 0.0;
    CGFloat gap = symbol ? 4.0 : 0.0;
    CGFloat padding = 10.0;
    CGFloat contentWidth = self.label.bounds.size.width + iconWidth + gap + padding * 2.0;
    CGFloat maxWidth = self.host.bounds.size.width - kLumenPillInset * 2.0;
    CGFloat width = MIN(MAX(contentWidth, kLumenPillHeight + 8.0), maxWidth);

    CGFloat height = kLumenPillHeight;
    CGFloat y = MAX(([self statusBarHeight] - height) / 2.0, 2.0);
    self.pill.frame = CGRectMake(kLumenPillInset, y, width, height);
    self.blur.frame = self.pill.bounds;

    CGFloat textX = padding + iconWidth + gap;
    self.iconView.frame = CGRectMake(padding, (height - 13.0) / 2.0, iconWidth, 13.0);
    self.label.frame = CGRectMake(textX, 0, MAX(width - textX - padding, 0), height);
}

- (void)startTimer {
    [self.timer invalidate];
    BOOL fast = [self.activePill isEqualToString:@"time"] ||
                [self.activePill isEqualToString:@"countdown"] ||
                [self.activePill isEqualToString:@"network"];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:(fast ? kLumenFastTick : kLumenSlowTick)
                                                  target:self
                                                selector:@selector(tick)
                                                userInfo:nil
                                                 repeats:YES];
    self.timer.tolerance = 0.2;
}

- (void)tick {
    // The status bar window is recreated across app switches and resprings;
    // re-attach instead of staying detached once the weak host clears.
    if (!self.host || self.pill.superview != self.host) {
        [self attach];
        return;
    }
    if ([self.activePill isEqualToString:@"playing"]) {
        LumenRefreshNowPlaying();
    }
    [self refresh];
    BOOL fast = [self.activePill isEqualToString:@"time"] ||
                [self.activePill isEqualToString:@"countdown"] ||
                [self.activePill isEqualToString:@"network"];
    if ((self.timer.timeInterval == kLumenFastTick) != fast) {
        [self startTimer];
    }
}

@end
