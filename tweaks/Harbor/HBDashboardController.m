#import "HBDashboardController.h"
#import "HBPreferences.h"
#import "HBPolicy.h"
#import <MediaPlayer/MediaPlayer.h>
#import <AVKit/AVKit.h>

static UIColor *HBInk(void) { return [UIColor colorWithWhite:0.96 alpha:1]; }
static UIColor *HBMuted(void) { return [UIColor colorWithWhite:0.73 alpha:1]; }
static UIFont *HBFont(CGFloat size, UIFontWeight weight, UIFontTextStyle style) {
    return [[UIFontMetrics metricsForTextStyle:style] scaledFontForFont:[UIFont systemFontOfSize:size weight:weight] maximumPointSize:size * 1.5];
}
static UILabel *HBLabel(NSString *text, CGFloat size, UIFontWeight weight, UIColor *color) {
    UILabel *label = [UILabel new];
    label.text = text;
    label.font = HBFont(size, weight, size >= 26 ? UIFontTextStyleTitle1 : UIFontTextStyleBody);
    label.textColor = color;
    label.adjustsFontForContentSizeCategory = YES;
    label.numberOfLines = 0;
    return label;
}
static UIImage *HBSymbol(NSString *name, CGFloat size) {
    return [UIImage systemImageNamed:name withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:size weight:UIImageSymbolWeightMedium]];
}
static UIStackView *HBStack(NSArray<UIView *> *views, UILayoutConstraintAxis axis, CGFloat spacing) {
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:views];
    stack.axis = axis;
    stack.spacing = spacing;
    return stack;
}
static void HBPin(UIView *child, UIView *parent, UIEdgeInsets insets) {
    child.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [child.leadingAnchor constraintEqualToAnchor:parent.leadingAnchor constant:insets.left],
        [child.trailingAnchor constraintEqualToAnchor:parent.trailingAnchor constant:-insets.right],
        [child.topAnchor constraintEqualToAnchor:parent.topAnchor constant:insets.top],
        [child.bottomAnchor constraintEqualToAnchor:parent.bottomAnchor constant:-insets.bottom]]];
}

@interface HBCard : UIView
@end
@implementation HBCard
- (instancetype)init {
    if ((self = [super init])) {
        self.layer.cornerRadius = 26;
        self.layer.cornerCurve = kCACornerCurveContinuous;
        self.backgroundColor = [UIColor colorWithWhite:1 alpha:0.065];
        self.layer.borderWidth = 0.5;
        self.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.10].CGColor;
    }
    return self;
}
@end

// Small, interruptible opacity feedback. No scale bounce or delayed tap handling.
@interface HBPressButton : UIButton
@end
@implementation HBPressButton
- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    [UIView animateWithDuration:UIAccessibilityIsReduceMotionEnabled() ? 0 : 0.12 delay:0
        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
        animations:^{ self.alpha = highlighted ? 0.58 : (self.enabled ? 1 : 0.35); } completion:nil];
}
- (void)setEnabled:(BOOL)enabled { [super setEnabled:enabled]; self.alpha = enabled ? 1 : 0.35; }
@end

@interface HBDashboardController ()
@property (nonatomic, strong) UIVisualEffectView *blur;
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UIStackView *stack;
@property (nonatomic, strong) UIStackView *levels;
@property (nonatomic, strong) UIStackView *shortcuts;
@property (nonatomic, strong) UILabel *greeting;
@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, strong) UILabel *batteryLabel;
@property (nonatomic, strong) UILabel *mediaTitle;
@property (nonatomic, strong) UILabel *mediaArtist;
@property (nonatomic, strong) UILabel *mediaEyebrow;
@property (nonatomic, strong) UILabel *brightnessValue;
@property (nonatomic, strong) UIImageView *artwork;
@property (nonatomic, strong) UIButton *play;
@property (nonatomic, strong) UIButton *previous;
@property (nonatomic, strong) UIButton *next;
@property (nonatomic, strong) UIButton *appearance;
@property (nonatomic, strong) UISlider *brightness;
@property (nonatomic, strong) MPVolumeView *volume;
@property (nonatomic, strong) UIButton *volumeFallback;
@property (nonatomic, strong) HBMediaProvider *media;
@property (nonatomic, strong) NSTimer *clock;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic, strong) NSMutableArray<UIView *> *accentViews;
@property (nonatomic) BOOL active;
@end

@implementation HBDashboardController
- (void)loadView {
    self.view = [UIView new];
    self.view.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.accentViews = [NSMutableArray array];
    self.blur = [[UIVisualEffectView alloc] initWithEffect:nil];
    self.blur.userInteractionEnabled = NO;
    [self.view addSubview:self.blur];
    HBPin(self.blur, self.view, UIEdgeInsetsZero);

    self.scroll = [UIScrollView new];
    self.scroll.alwaysBounceVertical = NO;
    self.scroll.showsVerticalScrollIndicator = NO;
    self.scroll.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    [self.view addSubview:self.scroll];
    self.scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [self.scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
        [self.scroll.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-8],
        [self.scroll.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.scroll.widthAnchor constraintLessThanOrEqualToConstant:440],
        [self.scroll.widthAnchor constraintLessThanOrEqualToAnchor:self.view.widthAnchor]]];
    NSLayoutConstraint *width = [self.scroll.widthAnchor constraintEqualToAnchor:self.view.widthAnchor];
    width.priority = UILayoutPriorityDefaultHigh;
    width.active = YES;

    self.stack = HBStack(@[[self buildHeader], [self buildMedia], [self buildLevels], [self buildShortcuts], [self buildAllControls]], UILayoutConstraintAxisVertical, 12);
    [self.scroll addSubview:self.stack];
    self.stack.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [self.stack.topAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.topAnchor constant:12],
        [self.stack.bottomAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.bottomAnchor constant:-12],
        [self.stack.leadingAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.leadingAnchor constant:20],
        [self.stack.trailingAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.trailingAnchor constant:-20],
        [self.stack.widthAnchor constraintEqualToAnchor:self.scroll.frameLayoutGuide.widthAnchor constant:-40]]];
    self.media = [HBMediaProvider new];
    __weak typeof(self) weakSelf = self;
    self.media.onUpdate = ^(HBMediaSnapshot *snapshot) { [weakSelf displayMedia:snapshot]; };
    self.dateFormatter = [NSDateFormatter new];
    [self.dateFormatter setLocalizedDateFormatFromTemplate:@"EEE MMM d"];
    NSNotificationCenter *nc = NSNotificationCenter.defaultCenter;
    [nc addObserver:self selector:@selector(refreshStatus) name:UIScreenBrightnessDidChangeNotification object:nil];
    [nc addObserver:self selector:@selector(refreshStatus) name:NSProcessInfoPowerStateDidChangeNotification object:nil];
    [nc addObserver:self selector:@selector(applyAppearance) name:UIAccessibilityReduceTransparencyStatusDidChangeNotification object:nil];
    [nc addObserver:self selector:@selector(contentSizeChanged) name:UIContentSizeCategoryDidChangeNotification object:nil];
    [nc addObserver:self selector:@selector(localeChanged) name:NSCurrentLocaleDidChangeNotification object:nil];
    [self applyAppearance];
}
- (UIView *)buildHeader {
    UILabel *brand = HBLabel(@"H A R B O R", 11, UIFontWeightBold, HBMuted());
    self.batteryLabel = HBLabel(@"", 12, UIFontWeightMedium, HBMuted());
    self.batteryLabel.textAlignment = NSTextAlignmentRight;
    self.appearance = [HBPressButton buttonWithType:UIButtonTypeCustom];
    [self.appearance setImage:HBSymbol(@"slider.horizontal.3", 17) forState:UIControlStateNormal];
    self.appearance.accessibilityLabel = @"Harbor appearance";
    self.appearance.accessibilityIdentifier = @"harbor.appearance";
    self.appearance.showsMenuAsPrimaryAction = YES;
    [self.appearance.widthAnchor constraintEqualToConstant:44].active = YES;
    [self.appearance.heightAnchor constraintEqualToConstant:44].active = YES;
    UIStackView *top = HBStack(@[brand, self.batteryLabel, self.appearance], UILayoutConstraintAxisHorizontal, 10);
    top.alignment = UIStackViewAlignmentCenter;
    [brand setContentHuggingPriority:UILayoutPriorityDefaultLow - 1 forAxis:UILayoutConstraintAxisHorizontal];
    self.greeting = HBLabel(@"Good evening.", 31, UIFontWeightSemibold, HBInk());
    self.greeting.accessibilityTraits = UIAccessibilityTraitHeader;
    self.dateLabel = HBLabel(@"", 13, UIFontWeightMedium, HBMuted());
    UIStackView *header = HBStack(@[top, self.greeting, self.dateLabel], UILayoutConstraintAxisVertical, 5);
    [header setCustomSpacing:2 afterView:top];
    return header;
}
- (UIButton *)transport:(NSString *)symbol label:(NSString *)label action:(SEL)action {
    UIButton *button = [HBPressButton buttonWithType:UIButtonTypeCustom];
    [button setImage:HBSymbol(symbol, 20) forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    button.accessibilityLabel = label;
    button.accessibilityIdentifier = [@"harbor." stringByAppendingString:label.lowercaseString];
    [button.heightAnchor constraintEqualToConstant:54].active = YES;
    [button.widthAnchor constraintEqualToConstant:64].active = YES;
    return button;
}
- (UIView *)buildMedia {
    HBCard *card = [HBCard new];
    self.mediaEyebrow = HBLabel(@"NOW PLAYING", 10, UIFontWeightBold, HBMuted());
    AVRoutePickerView *routes = [AVRoutePickerView new];
    routes.tintColor = HBMuted();
    routes.activeTintColor = HBAccentColor();
    routes.prioritizesVideoDevices = NO;
    routes.accessibilityLabel = @"Audio output";
    [routes.widthAnchor constraintEqualToConstant:44].active = YES;
    [routes.heightAnchor constraintEqualToConstant:44].active = YES;
    UIStackView *heading = HBStack(@[self.mediaEyebrow, routes], UILayoutConstraintAxisHorizontal, 8);
    heading.alignment = UIStackViewAlignmentCenter;
    self.artwork = [UIImageView new];
    self.artwork.contentMode = UIViewContentModeScaleAspectFill;
    self.artwork.clipsToBounds = YES;
    self.artwork.layer.cornerRadius = 16;
    self.artwork.layer.cornerCurve = kCACornerCurveContinuous;
    self.artwork.backgroundColor = [UIColor colorWithWhite:1 alpha:0.06];
    [self.artwork.widthAnchor constraintEqualToConstant:62].active = YES;
    [self.artwork.heightAnchor constraintEqualToConstant:62].active = YES;
    self.artwork.isAccessibilityElement = NO;
    self.mediaTitle = HBLabel(@"Nothing playing", 20, UIFontWeightSemibold, HBInk());
    self.mediaTitle.numberOfLines = 2;
    self.mediaArtist = HBLabel(@"Your next moment of calm.", 13, UIFontWeightRegular, HBMuted());
    self.mediaArtist.numberOfLines = 2;
    UIStackView *words = HBStack(@[self.mediaTitle, self.mediaArtist], UILayoutConstraintAxisVertical, 4);
    UIStackView *track = HBStack(@[self.artwork, words], UILayoutConstraintAxisHorizontal, 14);
    track.alignment = UIStackViewAlignmentCenter;
    self.previous = [self transport:@"backward.end.fill" label:@"Previous track" action:@selector(previousTrack)];
    self.play = [self transport:@"play.fill" label:@"Play" action:@selector(playPause)];
    self.next = [self transport:@"forward.end.fill" label:@"Next track" action:@selector(nextTrack)];
    self.play.layer.cornerRadius = 27;
    self.play.accessibilityIdentifier = @"harbor.play";
    self.previous.enabled = self.play.enabled = self.next.enabled = NO;
    UIStackView *buttons = HBStack(@[self.previous, self.play, self.next], UILayoutConstraintAxisHorizontal, 14);
    buttons.alignment = UIStackViewAlignmentCenter;
    UIView *transport = [UIView new];
    [transport addSubview:buttons];
    buttons.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [buttons.centerXAnchor constraintEqualToAnchor:transport.centerXAnchor],
        [buttons.topAnchor constraintEqualToAnchor:transport.topAnchor],
        [buttons.bottomAnchor constraintEqualToAnchor:transport.bottomAnchor],
        [buttons.leadingAnchor constraintGreaterThanOrEqualToAnchor:transport.leadingAnchor]]];
    UIStackView *content = HBStack(@[heading, track, transport], UILayoutConstraintAxisVertical, 12);
    [content setCustomSpacing:6 afterView:heading];
    [card addSubview:content];
    HBPin(content, card, UIEdgeInsetsMake(7, 18, 18, 18));
    return card;
}
- (UIView *)levelCard:(NSString *)title symbol:(NSString *)symbol slider:(UIView *)slider value:(UILabel *)value {
    HBCard *card = [HBCard new];
    UIImageView *icon = [[UIImageView alloc] initWithImage:HBSymbol(symbol, 20)];
    icon.contentMode = UIViewContentModeLeft;
    [icon.widthAnchor constraintEqualToConstant:26].active = YES;
    [icon.heightAnchor constraintEqualToConstant:28].active = YES;
    [self.accentViews addObject:icon];
    UIStackView *top = HBStack(value ? @[icon, value] : @[icon, [UIView new]], UILayoutConstraintAxisHorizontal, 6);
    top.alignment = UIStackViewAlignmentCenter;
    UILabel *label = HBLabel(title, 13, UIFontWeightMedium, HBInk());
    [slider.heightAnchor constraintEqualToConstant:44].active = YES;
    UIStackView *content = HBStack(@[top, label, slider], UILayoutConstraintAxisVertical, 2);
    [card addSubview:content];
    HBPin(content, card, UIEdgeInsetsMake(16, 16, 8, 16));
    return card;
}
- (UIView *)buildLevels {
    self.brightness = [UISlider new];
    self.brightness.minimumValue = 0.02; // Keep the screen recoverably visible.
    self.brightness.maximumValue = 1;
    self.brightness.accessibilityLabel = @"Brightness";
    self.brightness.accessibilityIdentifier = @"harbor.brightness";
    [self.brightness addTarget:self action:@selector(brightnessChanged) forControlEvents:UIControlEventValueChanged];
    [self.brightness addTarget:self action:@selector(feedback) forControlEvents:UIControlEventTouchDown];
    self.brightnessValue = HBLabel(@"", 12, UIFontWeightMedium, HBMuted());
    self.brightnessValue.textAlignment = NSTextAlignmentRight;
    self.volume = [MPVolumeView new];
    // This deprecated flag is still the only public way to hide MPVolumeView's
    // legacy route button; the separate AVRoutePickerView handles routing.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    self.volume.showsRouteButton = NO;
#pragma clang diagnostic pop
    self.volume.showsVolumeSlider = YES;
    self.volume.accessibilityIdentifier = @"harbor.volume";
    UIView *volumeHost = [UIView new];
    [volumeHost addSubview:self.volume];
    HBPin(self.volume, volumeHost, UIEdgeInsetsZero);
    self.volumeFallback = [HBPressButton buttonWithType:UIButtonTypeCustom];
    [self.volumeFallback setTitle:@"Open controls ↗" forState:UIControlStateNormal];
    self.volumeFallback.titleLabel.font = HBFont(11, UIFontWeightMedium, UIFontTextStyleCaption1);
    self.volumeFallback.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
    self.volumeFallback.accessibilityLabel = @"Open system volume controls";
    self.volumeFallback.accessibilityIdentifier = @"harbor.volumeFallback";
    [self.volumeFallback addTarget:self action:@selector(systemVolume) forControlEvents:UIControlEventTouchUpInside];
    self.volumeFallback.hidden = YES;
    [volumeHost addSubview:self.volumeFallback];
    HBPin(self.volumeFallback, volumeHost, UIEdgeInsetsZero);
    self.levels = HBStack(@[
        [self levelCard:@"Brightness" symbol:@"sun.max.fill" slider:self.brightness value:self.brightnessValue],
        [self levelCard:@"Volume" symbol:@"speaker.wave.2.fill" slider:volumeHost value:nil]], UILayoutConstraintAxisHorizontal, 12);
    self.levels.distribution = UIStackViewDistributionFillEqually;
    return self.levels;
}
- (UIButton *)shortcut:(NSString *)title subtitle:(NSString *)subtitle symbol:(NSString *)symbol action:(SEL)action {
    UIButton *button = [HBPressButton buttonWithType:UIButtonTypeCustom];
    button.backgroundColor = [UIColor colorWithWhite:1 alpha:0.065];
    button.layer.cornerRadius = 24;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    button.layer.borderWidth = 0.5;
    button.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.1].CGColor;
    UIImageView *icon = [[UIImageView alloc] initWithImage:HBSymbol(symbol, 20)];
    [self.accentViews addObject:icon];
    [icon.widthAnchor constraintEqualToConstant:25].active = YES;
    [icon.heightAnchor constraintEqualToConstant:26].active = YES;
    UIImageView *arrow = [[UIImageView alloc] initWithImage:HBSymbol(@"arrow.up.right", 12)];
    arrow.tintColor = HBMuted();
    arrow.contentMode = UIViewContentModeRight;
    UIStackView *top = HBStack(@[icon, arrow], UILayoutConstraintAxisHorizontal, 8);
    UIStackView *content = HBStack(@[top, HBLabel(title, 14, UIFontWeightSemibold, HBInk()), HBLabel(subtitle, 11, UIFontWeightRegular, HBMuted())], UILayoutConstraintAxisVertical, 6);
    content.userInteractionEnabled = NO;
    [button addSubview:content];
    HBPin(content, button, UIEdgeInsetsMake(16, 16, 16, 16));
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    button.accessibilityLabel = title;
    button.accessibilityHint = [@"Opens system controls. " stringByAppendingString:subtitle];
    button.accessibilityIdentifier = [@"harbor." stringByAppendingString:title.lowercaseString];
    button.isAccessibilityElement = YES;
    return button;
}
- (UIView *)buildShortcuts {
    self.shortcuts = HBStack(@[
        [self shortcut:@"Connections" subtitle:@"Wi-Fi · Bluetooth" symbol:@"antenna.radiowaves.left.and.right" action:@selector(connections)],
        [self shortcut:@"Focus" subtitle:@"Choose a mode" symbol:@"moon.fill" action:@selector(focus)]], UILayoutConstraintAxisHorizontal, 12);
    self.shortcuts.distribution = UIStackViewDistributionFillEqually;
    return self.shortcuts;
}
- (UIView *)buildAllControls {
    UIButton *button = [HBPressButton buttonWithType:UIButtonTypeCustom];
    UIButtonConfiguration *configuration = [UIButtonConfiguration plainButtonConfiguration];
    configuration.title = @"All controls";
    configuration.image = HBSymbol(@"square.grid.2x2", 16);
    configuration.imagePadding = 10;
    configuration.baseForegroundColor = HBInk();
    configuration.contentInsets = NSDirectionalEdgeInsetsMake(16, 18, 16, 18);
    button.configuration = configuration;
    button.accessibilityIdentifier = @"harbor.allControls";
    button.accessibilityHint = @"Shows Apple's Control Center for this visit. Reopen Control Center to return to Harbor.";
    [button.heightAnchor constraintGreaterThanOrEqualToConstant:52].active = YES;
    [button addTarget:self action:@selector(allControls) forControlEvents:UIControlEventTouchUpInside];
    return button;
}
- (void)contentSizeChanged {
    BOOL large = UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory);
    self.levels.axis = self.shortcuts.axis = large ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
    [self.view setNeedsLayout];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    // Bottom weight without scaling text or controls; small displays simply scroll.
    CGFloat inset = MAX(0, self.scroll.bounds.size.height - self.stack.bounds.size.height - 24);
    if (fabs(self.scroll.contentInset.top - inset) > 0.5) {
        self.scroll.contentInset = UIEdgeInsetsMake(inset, 0, 0, 0);
        if (!self.scroll.dragging && !self.scroll.decelerating) self.scroll.contentOffset = CGPointMake(0, -inset);
    }
    [self updateVolumeAvailability];
}
- (void)updateVolumeAvailability {
    // MPVolumeView deliberately has no usable slider on some routes and in Simulator.
    // Inspect only public UIView/UISlider properties; don't use a private volume setter.
    BOOL available = NO;
    for (UIView *child in self.volume.subviews) {
        if ([child isKindOfClass:UISlider.class] && !child.hidden && child.alpha > 0.01 &&
            ((UISlider *)child).enabled && child.bounds.size.width > 0) { available = YES; break; }
    }
    self.volumeFallback.hidden = available;
    self.volume.accessibilityElementsHidden = !available;
}
- (void)applyAppearance {
    if (!self.isViewLoaded) return;
    UIColor *accent = HBAccentColor();
    self.view.backgroundColor = [UIColor colorWithRed:0.035 green:0.07 blue:0.09 alpha:UIAccessibilityIsReduceTransparencyEnabled() ? 1 : 0.94];
    self.blur.effect = UIAccessibilityIsReduceTransparencyEnabled() ? nil : [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
    self.blur.contentView.backgroundColor = [UIColor colorWithRed:0.035 green:0.07 blue:0.09 alpha:UIAccessibilityIsReduceTransparencyEnabled() ? 1 : 0.45];
    self.play.backgroundColor = accent;
    self.play.tintColor = [UIColor colorWithRed:0.06 green:0.13 blue:0.14 alpha:1];
    self.previous.tintColor = self.next.tintColor = HBInk();
    self.appearance.tintColor = HBMuted();
    self.brightness.minimumTrackTintColor = accent;
    self.brightness.maximumTrackTintColor = [UIColor colorWithWhite:1 alpha:0.14];
    self.volume.tintColor = accent;
    [self.volumeFallback setTitleColor:accent forState:UIControlStateNormal];
    self.artwork.tintColor = accent;
    for (UIView *view in self.accentViews) view.tintColor = accent;
    NSMutableArray *palettes = [NSMutableArray array];
    NSArray *keys = @[@"sea", @"ember", @"iris"];
    NSArray *names = @[@"Sea Glass", @"Ember", @"Iris"];
    __weak typeof(self) weakSelf = self;
    for (NSUInteger i = 0; i < keys.count; i++) {
        NSString *key = keys[i];
        UIAction *action = [UIAction actionWithTitle:names[i] image:nil identifier:nil handler:^(UIAction *a) {
            HBSetPreference(@"palette", key); [weakSelf applyAppearance]; [weakSelf feedback];
        }];
        action.state = [HBPalette() isEqual:key] ? UIMenuElementStateOn : UIMenuElementStateOff;
        [palettes addObject:action];
    }
    UIAction *haptics = [UIAction actionWithTitle:@"Gentle haptics" image:HBSymbol(@"waveform", 16) identifier:nil handler:^(UIAction *a) {
        HBSetPreference(@"haptics", @(!HBHapticsEnabled())); [weakSelf applyAppearance]; [weakSelf feedback];
    }];
    haptics.state = HBHapticsEnabled() ? UIMenuElementStateOn : UIMenuElementStateOff;
    UIAction *system = [UIAction actionWithTitle:@"Use system controls" image:HBSymbol(@"square.grid.2x2", 16) identifier:nil handler:^(UIAction *a) { [weakSelf allControls]; }];
    self.appearance.menu = [UIMenu menuWithTitle:@"Make it yours" children:@[[UIMenu menuWithTitle:@"Palette" children:palettes], haptics, system]];
    [self contentSizeChanged];
}
- (void)setDashboardActive:(BOOL)active {
    if (self.active == active) return;
    self.active = active;
    if (active) {
        [self loadViewIfNeeded];
        [self applyAppearance];
        [self refreshStatus];
        [self.media start];
        __weak typeof(self) weakSelf = self;
        self.clock = [NSTimer timerWithTimeInterval:15 repeats:YES block:^(NSTimer *timer) { [weakSelf refreshStatus]; }];
        self.clock.tolerance = 2;
        [[NSRunLoop mainRunLoop] addTimer:self.clock forMode:NSRunLoopCommonModes];
    } else {
        [self.clock invalidate]; self.clock = nil;
        [self.media stop];
    }
}
- (void)refreshStatus {
    if (!self.active) return;
    NSInteger hour = [NSCalendar.currentCalendar component:NSCalendarUnitHour fromDate:NSDate.date];
    self.greeting.text = hour < 12 ? @"Good morning." : hour < 18 ? @"Good afternoon." : @"Good evening.";
    self.dateLabel.text = [self.dateFormatter stringFromDate:NSDate.date];
    // Do not change the host process's batteryMonitoringEnabled setting.
    float level = UIDevice.currentDevice.batteryLevel;
    self.batteryLabel.text = level >= 0 ? [NSString stringWithFormat:@"%d%%%@", (int)lroundf(level * 100), NSProcessInfo.processInfo.lowPowerModeEnabled ? @" · Low power" : @""] : @"";
    if (!self.brightness.tracking) self.brightness.value = HBUnitValue(UIScreen.mainScreen.brightness, 0.5);
    self.brightnessValue.text = [NSString stringWithFormat:@"%.0f%%", UIScreen.mainScreen.brightness * 100];
    [self updateVolumeAvailability];
}
- (void)localeChanged { [self.dateFormatter setLocalizedDateFormatFromTemplate:@"EEE MMM d"]; [self refreshStatus]; }
- (void)brightnessChanged {
    CGFloat value = MAX(0.02, HBUnitValue(self.brightness.value, 0.5));
    UIScreen.mainScreen.brightness = value;
    self.brightnessValue.text = [NSString stringWithFormat:@"%.0f%%", value * 100];
}
- (void)displayMedia:(HBMediaSnapshot *)snapshot {
    self.mediaTitle.text = snapshot.title;
    self.mediaArtist.text = snapshot.artist;
    self.mediaEyebrow.text = snapshot.hasSession ? (snapshot.playing ? @"NOW PLAYING" : @"PAUSED") : @"A LITTLE QUIET";
    self.artwork.contentMode = snapshot.artwork ? UIViewContentModeScaleAspectFill : UIViewContentModeCenter;
    self.artwork.image = snapshot.artwork ?: HBSymbol(@"waveform", 27);
    [self.play setImage:HBSymbol(snapshot.playing ? @"pause.fill" : @"play.fill", 20) forState:UIControlStateNormal];
    self.play.accessibilityLabel = snapshot.playing ? @"Pause" : @"Play";
    self.play.enabled = snapshot.available && snapshot.hasSession;
    self.previous.enabled = self.next.enabled = snapshot.available && snapshot.canSkip;
}
- (void)feedback {
    if (HBHapticsEnabled()) [[[UISelectionFeedbackGenerator alloc] init] selectionChanged];
}
- (void)sendCommand:(int)command {
    if ([self.media sendCommand:command]) [self feedback];
    else UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, @"This media action is unavailable. Try All controls.");
}
- (void)playPause { [self sendCommand:2]; }
- (void)previousTrack { [self sendCommand:5]; }
- (void)nextTrack { [self sendCommand:4]; }
- (void)connections { [self feedback]; if (self.openSystemControls) self.openSystemControls(HBSystemDestinationConnections); }
- (void)focus { [self feedback]; if (self.openSystemControls) self.openSystemControls(HBSystemDestinationFocus); }
- (void)allControls { [self feedback]; if (self.openSystemControls) self.openSystemControls(HBSystemDestinationAll); }
- (void)systemVolume { [self feedback]; if (self.openSystemControls) self.openSystemControls(HBSystemDestinationVolume); }
- (void)dealloc { [_clock invalidate]; [_media stop]; [NSNotificationCenter.defaultCenter removeObserver:self]; }
@end
