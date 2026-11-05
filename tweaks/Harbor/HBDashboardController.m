#import "HBDashboardController.h"
#import "HBPreferences.h"
#import "HBPolicy.h"
#import "HBProfileStore.h"
#import "HBProfileEditorController.h"
#import "HBFocusMonitor.h"
#import "HBTheme.h"
#import <MediaPlayer/MediaPlayer.h>
#import <AVKit/AVKit.h>

static UIColor *HBInk(void) { return [UIColor colorWithWhite:0.97 alpha:1]; }
static UIColor *HBMuted(void) { return [UIColor colorWithWhite:0.72 alpha:1]; }
static UIImage *HBSymbol(NSString *name, CGFloat size) {
    if ([name isEqual:@"harbor.bluetooth"]) {
        UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(20, 24)];
        return [[r imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
            UIBezierPath *p = [UIBezierPath bezierPath]; [p moveToPoint:CGPointMake(6, 7)]; [p addLineToPoint:CGPointMake(15, 17)];
            [p addLineToPoint:CGPointMake(10, 22)]; [p addLineToPoint:CGPointMake(10, 2)]; [p addLineToPoint:CGPointMake(15, 7)]; [p addLineToPoint:CGPointMake(6, 17)];
            p.lineWidth = 1.8; p.lineCapStyle = kCGLineCapRound; p.lineJoinStyle = kCGLineJoinRound; [UIColor.whiteColor setStroke]; [p stroke];
        }] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    return [UIImage systemImageNamed:name withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:size weight:UIImageSymbolWeightMedium]];
}
static UILabel *HBLabel(NSString *text, CGFloat size, UIFontWeight weight) {
    UILabel *label = [UILabel new]; label.text = text; label.textColor = HBInk();
    label.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:[UIFont systemFontOfSize:size weight:weight] maximumPointSize:size * 1.5];
    label.adjustsFontForContentSizeCategory = YES; label.numberOfLines = 1;
    return label;
}
static UIStackView *HBStack(NSArray *views, UILayoutConstraintAxis axis, CGFloat gap) {
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:views]; stack.axis = axis; stack.spacing = gap; return stack;
}
static void HBPin(UIView *child, UIView *parent, UIEdgeInsets inset) {
    child.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[[child.leadingAnchor constraintEqualToAnchor:parent.leadingAnchor constant:inset.left],
        [child.trailingAnchor constraintEqualToAnchor:parent.trailingAnchor constant:-inset.right],
        [child.topAnchor constraintEqualToAnchor:parent.topAnchor constant:inset.top],
        [child.bottomAnchor constraintEqualToAnchor:parent.bottomAnchor constant:-inset.bottom]]];
}
@interface HBPressButton : UIButton
@end
@implementation HBPressButton
- (void)setHighlighted:(BOOL)value {
    [super setHighlighted:value];
    [UIView animateWithDuration:UIAccessibilityIsReduceMotionEnabled() ? 0 : 0.12 delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction animations:^{ self.alpha = value ? 0.6 : (self.enabled ? 1 : 0.35); } completion:nil];
}
- (void)setEnabled:(BOOL)value { [super setEnabled:value]; self.alpha = value ? 1 : 0.35; }
@end
@interface HBPassthroughView : UIView
@end
@implementation HBPassthroughView
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event { UIView *hit = [super hitTest:point withEvent:event]; return hit == self ? nil : hit; }
@end

// The standard UISlider remains the accessible/tracking control. Only its track
// rendering changes; there is no custom touch-to-volume implementation.
@interface HBPillSlider : UISlider
@end
@implementation HBPillSlider
- (CGRect)trackRectForBounds:(CGRect)bounds { return CGRectInset(bounds, 0, 4); }
- (void)updateFromTouch:(UITouch *)touch {
    // A pill has no protruding thumb: touching anywhere starts native slider tracking.
    CGFloat fraction = MAX(0, MIN(1, [touch locationInView:self].x / MAX(1, self.bounds.size.width)));
    if (self.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft) fraction = 1 - fraction;
    self.value = self.minimumValue + fraction * (self.maximumValue - self.minimumValue);
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}
- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event { [self updateFromTouch:touch]; return YES; }
- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event { [self updateFromTouch:touch]; return YES; }
- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event { if (touch) [self updateFromTouch:touch]; }
@end
static UIImage *HBTrackImage(UIColor *color) {
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(52, 52)];
    UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) { [color setFill]; [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, 52, 52) cornerRadius:26] fill]; }];
    return [image resizableImageWithCapInsets:UIEdgeInsetsMake(25, 25, 25, 25) resizingMode:UIImageResizingModeStretch];
}

@interface HBDashboardController ()
@property (nonatomic, strong) UIView *backdrop;
@property (nonatomic, strong) UIView *sheet;
@property (nonatomic, strong) UIVisualEffectView *blur;
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UIStackView *stack;
@property (nonatomic, strong) UIStackView *levels;
@property (nonatomic, strong) UIStackView *shortcuts;
@property (nonatomic, strong) UIStackView *moreRows;
@property (nonatomic, strong) UIView *header;
@property (nonatomic, strong) UIView *footer;
@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, strong) UILabel *batteryLabel;
@property (nonatomic, strong) UILabel *mediaTitle;
@property (nonatomic, strong) UILabel *mediaArtist;
@property (nonatomic, strong) UIImageView *artwork;
@property (nonatomic, strong) UIButton *play;
@property (nonatomic, strong) UIButton *previous;
@property (nonatomic, strong) UIButton *next;
@property (nonatomic, strong) UIButton *appearance;
@property (nonatomic, strong) UIButton *allControlsButton;
@property (nonatomic, strong) UIButton *expandButton;
@property (nonatomic, strong) AVRoutePickerView *routes;
@property (nonatomic, strong) UISlider *brightness;
@property (nonatomic, strong) MPVolumeView *volume;
@property (nonatomic, strong) UIButton *volumeFallback;
@property (nonatomic, strong) HBMediaProvider *media;
@property (nonatomic, strong) NSTimer *clock;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic, strong) NSMutableDictionary<NSString *, UIButton *> *nativeButtons;
@property (nonatomic, strong) UIView *radioRow;
@property (nonatomic, strong) UIButton *connectionsFallback;
@property (nonatomic) BOOL active;
@property (nonatomic) BOOL expanded;
@property (nonatomic) CGFloat layoutWidth;
@property (nonatomic, strong) NSLayoutConstraint *stackWidth;
@property (nonatomic, copy, readwrite) NSDictionary *profile;
@property (nonatomic, copy, readwrite) NSDictionary *focusSnapshot;
@property (nonatomic, strong) NSDictionary<NSString *, UIView *> *sections;
@property (nonatomic, strong) NSMutableArray<UIButton *> *allButtons;
@property (nonatomic, strong) NSMutableArray<UIView *> *fillViews;
@property (nonatomic, strong) NSMutableArray<UIButton *> *roundButtons;
@property (nonatomic, strong) UIImageView *sun;
@property (nonatomic, strong) HBFocusMonitor *focusMonitor;
@property (nonatomic) BOOL focusPausedForEditor;
@property (nonatomic, strong) HBProfileEditorController *editor;
@property (nonatomic) BOOL pendingProfile;
@property (nonatomic, strong) UIColor *accent;
@property (nonatomic, strong) UIColor *ink;
@property (nonatomic, strong) UIColor *muted;
@property (nonatomic, strong) UIColor *controlFill;
@property (nonatomic, copy) NSDictionary *renderedTheme;
@end

@implementation HBDashboardController
- (UIButton *)button:(NSString *)name symbol:(NSString *)symbol identifier:(NSString *)identifier action:(SEL)action {
    UIButton *button = [HBPressButton buttonWithType:UIButtonTypeCustom]; [self.allButtons addObject:button];
    [button setImage:HBSymbol(symbol, 20) forState:UIControlStateNormal]; button.tintColor = HBInk();
    button.accessibilityLabel = name; button.accessibilityIdentifier = [@"harbor." stringByAppendingString:identifier];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [button.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
    return button;
}
- (UIView *)pill:(UIView *)content {
    UIView *view = [UIView new]; [self.fillViews addObject:view]; view.layer.cornerRadius = 28; view.layer.cornerCurve = kCACornerCurveContinuous;
    view.backgroundColor = [UIColor colorWithWhite:1 alpha:0.075]; [view addSubview:content]; HBPin(content, view, UIEdgeInsetsMake(8, 10, 8, 10)); return view;
}
- (void)loadView {
    self.view = [HBPassthroughView new]; self.view.backgroundColor = UIColor.clearColor; self.view.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.nativeButtons = [NSMutableDictionary dictionary]; self.allButtons = [NSMutableArray array]; self.roundButtons = [NSMutableArray array]; self.fillViews = [NSMutableArray array];
    if (!self.profile) self.profile = HBResolvedProfile(HBLoadProfileLibrary(), self.focusSnapshot);
    self.accent = HBColorFromHex(self.profile[@"theme"][@"accent"]);
    self.backdrop = [UIView new]; self.backdrop.userInteractionEnabled = NO; self.backdrop.accessibilityIdentifier = @"harbor.backdrop";
    self.backdrop.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; [self.view addSubview:self.backdrop];
    self.sheet = [UIView new]; self.sheet.layer.cornerRadius = 36; self.sheet.layer.cornerCurve = kCACornerCurveContinuous;
    self.sheet.clipsToBounds = YES; self.sheet.accessibilityIdentifier = @"harbor.sheet"; [self.view addSubview:self.sheet];
    self.blur = [[UIVisualEffectView alloc] initWithEffect:nil]; self.blur.userInteractionEnabled = NO; [self.sheet addSubview:self.blur]; HBPin(self.blur, self.sheet, UIEdgeInsetsZero);
    self.header = [UIView new]; [self.sheet addSubview:self.header];
    self.expandButton = [self button:@"More controls" symbol:@"chevron.compact.up" identifier:@"expand" action:@selector(toggleExpanded)];
    [self.header addSubview:self.expandButton];
    UIPanGestureRecognizer *grabber = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(grabberPanned:)];
    [self.expandButton addGestureRecognizer:grabber];
    self.dateLabel = HBLabel(@"Harbor", 15, UIFontWeightSemibold); [self.header addSubview:self.dateLabel];
    self.batteryLabel = HBLabel(@"", 12, UIFontWeightMedium); self.batteryLabel.textAlignment = NSTextAlignmentRight; self.batteryLabel.textColor = HBMuted(); [self.header addSubview:self.batteryLabel];
    self.appearance = [self button:@"Profiles and appearance" symbol:@"ellipsis" identifier:@"appearance" action:@selector(noAction)]; self.appearance.showsMenuAsPrimaryAction = YES; [self.header addSubview:self.appearance];
    self.scroll = [UIScrollView new]; self.scroll.accessibilityIdentifier = @"harbor.scroll"; self.scroll.alwaysBounceVertical = NO;
    self.scroll.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever; self.scroll.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    self.scroll.delaysContentTouches = NO; self.scroll.directionalLockEnabled = YES; [self.sheet addSubview:self.scroll];
    self.sections = @{@"connectivity":[self buildConnectivity], @"levels":[self buildLevels], @"shortcuts":[self buildShortcuts], @"media":[self buildMedia], @"extras":[self buildMore]};
    NSMutableArray *sections = [NSMutableArray array]; for (NSString *key in HBSectionKeys()) [sections addObject:self.sections[key]];
    self.stack = HBStack(sections, UILayoutConstraintAxisVertical, 10);
    [self.scroll addSubview:self.stack]; self.stack.translatesAutoresizingMaskIntoConstraints = NO;
    self.stackWidth = [self.stack.widthAnchor constraintEqualToConstant:300];
    [NSLayoutConstraint activateConstraints:@[self.stackWidth,
        [self.stack.leadingAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.leadingAnchor],
        [self.stack.trailingAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.trailingAnchor],
        [self.stack.topAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.topAnchor constant:2],
        [self.stack.bottomAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.bottomAnchor constant:-12]]];
    self.footer = [UIView new]; [self.sheet addSubview:self.footer];
    self.allControlsButton = [self button:@"All controls" symbol:@"square.grid.2x2" identifier:@"allControls" action:@selector(allControls)];
    UIButtonConfiguration *configuration = [UIButtonConfiguration plainButtonConfiguration]; configuration.title = @"All controls";
    configuration.image = HBSymbol(@"square.grid.2x2", 14); configuration.imagePadding = 8; configuration.baseForegroundColor = HBMuted();
    configuration.titleTextAttributesTransformer = ^NSDictionary *(NSDictionary *attributes) { NSMutableDictionary *a = attributes.mutableCopy; a[NSFontAttributeName] = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium]; return a; };
    self.allControlsButton.configuration = configuration; self.allControlsButton.accessibilityHint = @"Shows Apple's controls for this visit. Reopen Control Center to return to Harbor.";
    [self.footer addSubview:self.allControlsButton]; [self.footer addSubview:self.routes];
    self.media = self.previewMode ? nil : [HBMediaProvider new]; __weak typeof(self) weakSelf = self; self.media.onUpdate = ^(HBMediaSnapshot *snapshot) { [weakSelf displayMedia:snapshot]; };
    self.dateFormatter = [NSDateFormatter new]; [self.dateFormatter setLocalizedDateFormatFromTemplate:@"jm"];
    NSNotificationCenter *nc = NSNotificationCenter.defaultCenter;
    [nc addObserver:self selector:@selector(refreshStatus) name:UIScreenBrightnessDidChangeNotification object:nil];
    [nc addObserver:self selector:@selector(applyAppearance) name:UIAccessibilityReduceTransparencyStatusDidChangeNotification object:nil];
    [nc addObserver:self selector:@selector(contentSizeChanged) name:UIContentSizeCategoryDidChangeNotification object:nil];
    [nc addObserver:self selector:@selector(localeChanged) name:NSCurrentLocaleDidChangeNotification object:nil];
    [self applyAppearance];
}
- (UIButton *)nativeButton:(NSString *)key name:(NSString *)name symbol:(NSString *)symbol {
    UIButton *button = [self button:name symbol:symbol identifier:key action:@selector(nativePressed:)];
    [self.roundButtons addObject:button]; button.layer.cornerRadius = 25; button.layer.cornerCurve = kCACornerCurveContinuous;
    [button.heightAnchor constraintEqualToConstant:50].active = YES; [button.widthAnchor constraintEqualToConstant:50].active = YES; self.nativeButtons[key] = button; return button;
}
- (UIView *)buildConnectivity {
    UIStackView *row = HBStack(@[[self nativeButton:@"wifi" name:@"Wi-Fi" symbol:@"wifi"],
        [self nativeButton:@"bluetooth" name:@"Bluetooth" symbol:@"harbor.bluetooth"],
        [self nativeButton:@"airplane" name:@"Airplane Mode" symbol:@"airplane"],
        [self nativeButton:@"cellular" name:@"Cellular Data" symbol:@"antenna.radiowaves.left.and.right"]], UILayoutConstraintAxisHorizontal, 9);
    row.distribution = UIStackViewDistributionEqualSpacing;
    self.radioRow = [self pill:row];
    self.connectionsFallback = [self button:@"Connections" symbol:@"wifi" identifier:@"connections" action:@selector(connections)];
    UIButtonConfiguration *c = [UIButtonConfiguration plainButtonConfiguration]; c.title = @"Connections"; c.subtitle = @"Wi-Fi, Bluetooth and cellular";
    c.image = HBSymbol(@"wifi", 22); c.imagePadding = 14; c.baseForegroundColor = HBInk(); self.connectionsFallback.configuration = c;
    UIView *host = [UIView new]; [host.heightAnchor constraintEqualToConstant:66].active = YES;
    [host addSubview:self.radioRow]; HBPin(self.radioRow, host, UIEdgeInsetsZero);
    [host addSubview:self.connectionsFallback]; HBPin(self.connectionsFallback, host, UIEdgeInsetsZero); return host;
}
- (UIView *)buildLevels {
    self.brightness = [HBPillSlider new]; self.brightness.minimumValue = 0.02; self.brightness.maximumValue = 1;
    self.brightness.value = HBUnitValue(UIScreen.mainScreen.brightness, 0.5); self.brightness.accessibilityLabel = @"Brightness"; self.brightness.accessibilityIdentifier = @"harbor.brightness"; self.brightness.isAccessibilityElement = YES;
    [self.brightness addTarget:self action:@selector(brightnessChanged) forControlEvents:UIControlEventValueChanged];
    [self.brightness addTarget:self action:@selector(feedback) forControlEvents:UIControlEventTouchDown];
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(1, 1)];
    [self.brightness setThumbImage:[renderer imageWithActions:^(__unused UIGraphicsImageRendererContext *ctx) {}] forState:UIControlStateNormal];
    UIView *bright = [UIView new]; bright.layer.cornerRadius = 26; bright.clipsToBounds = YES; [bright addSubview:self.brightness]; HBPin(self.brightness, bright, UIEdgeInsetsZero);
    UIImageView *sun = [[UIImageView alloc] initWithImage:HBSymbol(@"sun.max.fill", 20)]; self.sun = sun; sun.userInteractionEnabled = NO; sun.tintColor = HBInk(); sun.contentMode = UIViewContentModeCenter; [bright addSubview:sun];
    sun.translatesAutoresizingMaskIntoConstraints = NO; [NSLayoutConstraint activateConstraints:@[[sun.leadingAnchor constraintEqualToAnchor:bright.leadingAnchor constant:16], [sun.centerYAnchor constraintEqualToAnchor:bright.centerYAnchor], [sun.widthAnchor constraintEqualToConstant:24]]];
    self.volume = [MPVolumeView new];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    self.volume.showsRouteButton = NO;
#pragma clang diagnostic pop
    self.volume.showsVolumeSlider = YES; self.volume.accessibilityIdentifier = @"harbor.volume";
    UIView *volumeHost = [UIView new]; [self.fillViews addObject:volumeHost]; volumeHost.layer.cornerRadius = 26; volumeHost.backgroundColor = [UIColor colorWithWhite:1 alpha:0.10];
    [volumeHost addSubview:self.volume]; HBPin(self.volume, volumeHost, UIEdgeInsetsZero); volumeHost.clipsToBounds = YES;
    self.volumeFallback = [self button:@"Open system volume controls" symbol:@"speaker.wave.2.fill" identifier:@"volumeFallback" action:@selector(systemVolume)];
    [volumeHost addSubview:self.volumeFallback]; HBPin(self.volumeFallback, volumeHost, UIEdgeInsetsZero);
    [bright.heightAnchor constraintEqualToConstant:56].active = YES; [volumeHost.heightAnchor constraintEqualToConstant:56].active = YES;
    self.levels = HBStack(@[bright, volumeHost], UILayoutConstraintAxisHorizontal, 10); self.levels.distribution = UIStackViewDistributionFillEqually; return self.levels;
}
- (UIButton *)panelButton:(NSString *)name symbol:(NSString *)symbol key:(NSString *)key destination:(HBSystemDestination)destination {
    UIButton *button = [self button:name symbol:symbol identifier:key action:@selector(panelPressed:)]; button.tag = destination;
    [self.roundButtons addObject:button]; button.backgroundColor = [UIColor colorWithWhite:1 alpha:0.09]; button.layer.cornerRadius = 25;
    [button.heightAnchor constraintEqualToConstant:50].active = YES; [button.widthAnchor constraintEqualToConstant:50].active = YES;
    button.accessibilityHint = destination == HBSystemDestinationFocus ? @"Opens Apple's Focus controls. Choosing a mode there can change Focus." : @"Opens the system control."; return button;
}
- (UIView *)buildShortcuts {
    self.shortcuts = HBStack(@[[self nativeButton:@"rotation" name:@"Rotation Lock" symbol:@"lock.rotation"],
        [self panelButton:@"Focus controls" symbol:@"moon.fill" key:@"focus" destination:HBSystemDestinationFocus],
        [self nativeButton:@"power" name:@"Low Power Mode" symbol:@"battery.25percent"],
        [self panelButton:@"Connections" symbol:@"antenna.radiowaves.left.and.right" key:@"connections" destination:HBSystemDestinationConnections]], UILayoutConstraintAxisHorizontal, 14);
    self.shortcuts.distribution = UIStackViewDistributionEqualSpacing; return self.shortcuts;
}
- (UIView *)buildMore {
    NSArray *names = @[@"Flashlight", @"Timer", @"Calculator", @"Camera", @"Screen Recording", @"Remote", @"Hearing", @"Display"];
    NSArray *symbols = @[@"flashlight.on.fill", @"timer", @"plus.forwardslash.minus", @"camera.fill", @"record.circle", @"appletvremote.gen4.fill", @"ear", @"sun.max.fill"];
    NSArray *keys = @[@"flashlight", @"timer", @"calculator", @"camera", @"recording", @"remote", @"hearing", @"display"];
    NSMutableArray *rows = [NSMutableArray array];
    for (NSUInteger row = 0; row < 2; row++) {
        NSMutableArray *buttons = [NSMutableArray array];
        for (NSUInteger col = 0; col < 4; col++) { NSUInteger i = row * 4 + col; [buttons addObject:[self panelButton:names[i] symbol:symbols[i] key:keys[i] destination:HBSystemDestinationFlashlight + i]]; }
        UIStackView *stack = HBStack(buttons, UILayoutConstraintAxisHorizontal, 14); stack.distribution = UIStackViewDistributionEqualSpacing; [rows addObject:stack];
    }
    self.moreRows = HBStack(rows, UILayoutConstraintAxisVertical, 12); self.moreRows.hidden = YES; return self.moreRows;
}
- (UIView *)buildMedia {
    self.artwork = [UIImageView new]; self.artwork.layer.cornerRadius = 17; self.artwork.clipsToBounds = YES; self.artwork.contentMode = UIViewContentModeScaleAspectFill;
    [self.artwork.widthAnchor constraintEqualToConstant:44].active = YES; [self.artwork.heightAnchor constraintEqualToConstant:44].active = YES;
    self.mediaTitle = HBLabel(@"Not Playing", 14, UIFontWeightSemibold); self.mediaArtist = HBLabel(@"Music", 11, UIFontWeightRegular); self.mediaArtist.textColor = HBMuted();
    UIStackView *words = HBStack(@[self.mediaTitle, self.mediaArtist], UILayoutConstraintAxisVertical, 3);
    [words setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    self.previous = [self button:@"Previous track" symbol:@"backward.end.fill" identifier:@"previous" action:@selector(previousTrack)];
    self.play = [self button:@"Play" symbol:@"play.fill" identifier:@"play" action:@selector(playPause)];
    self.next = [self button:@"Next track" symbol:@"forward.end.fill" identifier:@"next" action:@selector(nextTrack)];
    for (UIButton *button in @[self.previous, self.play, self.next]) { NSLayoutConstraint *w = [button.widthAnchor constraintEqualToConstant:44]; w.priority = 999; w.active = YES; button.enabled = NO; }
    // Previous/next are in the media accessibility menu on narrow widths; play stays one tap.
    UIStackView *row = HBStack(@[self.artwork, words, self.previous, self.play, self.next], UILayoutConstraintAxisHorizontal, 4); row.alignment = UIStackViewAlignmentCenter;
    UIView *pill = [self pill:row]; [pill.heightAnchor constraintGreaterThanOrEqualToConstant:68].active = YES;
    AVRoutePickerView *routes = [AVRoutePickerView new]; self.routes = routes; routes.tintColor = HBMuted(); routes.activeTintColor = self.accent; routes.prioritizesVideoDevices = NO;
    // Audio routing belongs in the expanded section, keeping the resting strip compact.
    routes.accessibilityLabel = @"Audio output";
    self.mediaTitle.accessibilityCustomActions = @[[[UIAccessibilityCustomAction alloc] initWithName:@"Previous track" target:self selector:@selector(accessiblePrevious)], [[UIAccessibilityCustomAction alloc] initWithName:@"Next track" target:self selector:@selector(accessibleNext)]];

    return pill;
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    UIEdgeInsets safe = self.view.safeAreaInsets; CGFloat width = MIN(420, self.view.bounds.size.width - safe.left - safe.right - 20);
    self.stackWidth.constant = MAX(240, width - 28);
    BOOL narrow = width < 320;
    self.previous.hidden = self.next.hidden = narrow;
    CGFloat contentHeight = [self.stack systemLayoutSizeFittingSize:CGSizeMake(self.stackWidth.constant, UILayoutFittingCompressedSize.height) withHorizontalFittingPriority:UILayoutPriorityRequired verticalFittingPriority:UILayoutPriorityFittingSizeLevel].height + 14;
    CGFloat available = MAX(180, self.view.bounds.size.height - safe.top - safe.bottom - 16);
    CGFloat height = MIN(available, contentHeight + 94);
    CGRect frame = CGRectMake((self.view.bounds.size.width - width) * 0.5, self.view.bounds.size.height - safe.bottom - height - 8, width, height);
    if (!CGRectEqualToRect(self.sheet.frame, frame)) self.sheet.frame = frame;
    self.header.frame = CGRectMake(0, 0, width, 50);
    self.dateLabel.frame = CGRectMake(20, 8, 90, 36); self.batteryLabel.frame = CGRectMake(width - 108, 8, 48, 36);
    self.appearance.frame = CGRectMake(width - 54, 3, 44, 44); self.expandButton.frame = CGRectMake((width - 56) * 0.5, 0, 56, 46);
    self.scroll.frame = CGRectMake(14, 50, width - 28, MAX(1, height - 94));
    self.footer.frame = CGRectMake(14, height - 44, width - 28, 44); self.allControlsButton.frame = CGRectInset(self.footer.bounds, 44, 0); self.routes.frame = CGRectMake(0, 0, 44, 44);
    self.scroll.contentInset = UIEdgeInsetsZero; self.scroll.scrollIndicatorInsets = UIEdgeInsetsZero;
    // No per-frame offset pinning. UIKit owns dragging and deceleration.
    [self.scroll layoutIfNeeded];
    [self updateVolumeAvailability];
}
- (CGRect)previewSheetFrame { return self.sheet.frame; }
- (BOOL)containsInteractionPoint:(CGPoint)point { return !self.sheet.hidden && CGRectContainsPoint(self.sheet.frame, point); }
- (void)useBackdropHost:(UIView *)host {
    [self loadViewIfNeeded]; UIView *destination = host ?: self.view;
    if (self.backdrop.superview != destination) { [self.backdrop removeFromSuperview]; [destination insertSubview:self.backdrop atIndex:0]; }
    if (!CGRectEqualToRect(self.backdrop.frame, destination.bounds)) self.backdrop.frame = destination.bounds;
}
- (void)contentSizeChanged {
    self.levels.axis = UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory) ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
    [self.view setNeedsLayout];
}
- (void)updateVolumeAvailability {
    BOOL available = NO;
    for (UIView *child in self.volume.subviews) if ([child isKindOfClass:UISlider.class] && !child.hidden && child.alpha > 0.01 && [(UISlider *)child isEnabled] && child.bounds.size.width > 0) { available = YES; break; }
    self.volumeFallback.hidden = available; self.volume.accessibilityElementsHidden = !available;
}
- (void)refreshNativeControls {
    BOOL radiosAvailable = YES;
    for (NSString *key in self.nativeButtons) {
        UIButton *display = self.nativeButtons[key]; UIControl *native = [self.nativeControls buttonForKey:key];
        BOOL exists = native && native.enabled && native.userInteractionEnabled;
        if ([@[@"wifi", @"bluetooth", @"airplane", @"cellular"] containsObject:key] && !exists) radiosAvailable = NO;
        // Unavailable shortcut is an explicit native handoff, never a pretend toggle.
        display.accessibilityHint = exists ? @"Uses the system control." : @"Opens all system controls.";
        display.accessibilityValue = exists ? (native.accessibilityValue ?: (native.selected ? @"On" : @"Off")) : @"Open system controls";
        display.backgroundColor = exists && native.selected ? self.accent : self.controlFill;
        display.tintColor = exists && native.selected ? HBContrastingInk(self.accent) : self.ink;
        display.accessibilityTraits = UIAccessibilityTraitButton | ((exists && native.selected) ? UIAccessibilityTraitSelected : 0);
    }
    self.radioRow.hidden = !radiosAvailable; self.connectionsFallback.hidden = radiosAvailable;
}
- (void)applySectionLayout {
    NSDictionary *layout = self.profile[@"layouts"][self.expanded ? @"expanded" : @"compact"];
    // Remove hidden sections from the arrangement rather than imposing a zero
    // height on containers whose controls have required minimum touch sizes.
    for (UIView *view in self.stack.arrangedSubviews.copy) { [self.stack removeArrangedSubview:view]; [view removeFromSuperview]; }
    for (NSString *key in layout[@"order"]) {
        UIView *view = self.sections[key]; view.hidden = [layout[@"hidden"] containsObject:key];
        if (!view.hidden) [self.stack addArrangedSubview:view];
    }
    self.expandButton.accessibilityLabel = self.expanded ? @"Fewer controls" : @"More controls";
    [self.expandButton setImage:HBSymbol(self.expanded ? @"chevron.compact.down" : @"chevron.compact.up", 20) forState:UIControlStateNormal];
    [self.view setNeedsLayout];
}
- (void)applyProfile:(NSDictionary *)profile expanded:(BOOL)expanded {
    NSDictionary *next = HBNormalizeProfile(profile);
    BOOL layoutChanged = !self.isViewLoaded || _expanded != expanded || ![self.profile[@"layouts"] isEqual:next[@"layouts"]];
    self.profile = next; _expanded = expanded; [self loadViewIfNeeded];
    if (layoutChanged) [self applySectionLayout]; [self renderTheme];
    if (layoutChanged && !self.scroll.dragging && !self.scroll.decelerating) self.scroll.contentOffset = CGPointZero;
}
- (BOOL)isInteracting {
    if (self.editor || self.presentedViewController || self.scroll.dragging || self.scroll.decelerating || self.brightness.tracking) return YES;
    for (UIButton *button in self.allButtons) if (button.tracking || button.highlighted) return YES;
    for (UIView *view in self.volume.subviews) if ([view isKindOfClass:UIControl.class] && [(UIControl *)view isTracking]) return YES;
    return NO;
}
- (void)reloadSelectedProfile:(BOOL)opening {
    if (self.previewMode) return;
    NSDictionary *library = HBLoadProfileLibrary(); [self synchronizeFocusAccess:library];
    if ([self isInteracting]) { self.pendingProfile = YES; return; }
    self.pendingProfile = NO; NSDictionary *next = HBResolvedProfile(library, self.focusSnapshot);
    BOOL changed = ![next isEqual:self.profile];
    if (changed || opening) [self applyProfile:next expanded:(opening || ![next[@"id"] isEqual:self.profile[@"id"]]) ? [next[@"startExpanded"] boolValue] : self.expanded];
    [self rebuildProfileMenu:library];
}
- (void)acceptFocusSnapshot:(NSDictionary *)snapshot {
    if (![self allowsFocusAccess:HBLoadProfileLibrary()]) snapshot = [self disabledFocusSnapshot];
    self.focusSnapshot = snapshot; [self.editor updateFocusSnapshot:snapshot];
    if (self.active) [self reloadSelectedProfile:NO];
}
- (BOOL)allowsFocusAccess:(NSDictionary *)library {
    return self.active && !self.previewMode && HBEnabled() && !self.focusPausedForEditor && HBFocusAccessEnabled(library);
}
- (NSDictionary *)disabledFocusSnapshot {
    if (!self.focusPausedForEditor) return HBFocusDisabledSnapshot();
    NSMutableDictionary *snapshot = HBFocusDisabledSnapshot().mutableCopy;
    snapshot[@"paused"] = @YES;
    snapshot[@"status"] = @"Focus reading is paused. Save keeps it off; Cancel restores your saved choice.";
    return snapshot;
}
- (HBFocusMonitor *)createFocusMonitor { return [HBFocusMonitor new]; }
- (void)synchronizeFocusAccess:(NSDictionary *)library {
    if (![self allowsFocusAccess:library]) {
        [self.focusMonitor stop];
        NSDictionary *disabled = [self disabledFocusSnapshot];
        if (![self.focusSnapshot isEqual:disabled]) { self.focusSnapshot = disabled; [self.editor updateFocusSnapshot:disabled]; }
        return;
    }
    if (!self.focusMonitor) {
        self.focusMonitor = [self createFocusMonitor]; __weak typeof(self) weakSelf = self;
        self.focusMonitor.onChange = ^(NSDictionary *snapshot) { [weakSelf acceptFocusSnapshot:snapshot]; };
    }
    [self.focusMonitor start];
}
- (void)refreshFocus {
    NSDictionary *library = HBLoadProfileLibrary();
    [self synchronizeFocusAccess:library];
    if ([self allowsFocusAccess:library]) [self.focusMonitor refresh];
}
- (void)applyAppearance {
    if (!self.isViewLoaded) return;
    if (!self.previewMode) [self reloadSelectedProfile:NO];
    [self renderTheme]; [self contentSizeChanged];
}
- (void)renderTheme {
    NSDictionary *theme = self.profile[@"theme"]; if (!theme) return;
    BOOL opaque = UIAccessibilityIsReduceTransparencyEnabled() || [theme[@"material"] isEqual:@"solid"];
    UIColor *surface = HBColorFromHex(theme[@"surface"]); self.accent = HBColorFromHex(theme[@"accent"]); self.ink = HBContrastingInk(surface);
    // Light custom surfaces are opaque so text contrast cannot depend on wallpaper.
    BOOL light = [self.ink isEqual:UIColor.blackColor]; opaque |= light;
    self.muted = [self.ink colorWithAlphaComponent:0.72]; self.controlFill = [self.ink colorWithAlphaComponent:0.09];
    self.backdrop.backgroundColor = [UIColor colorWithWhite:0 alpha:opaque ? 0.30 : 0.10];
    self.sheet.backgroundColor = [surface colorWithAlphaComponent:opaque ? 1 : [theme[@"opacity"] doubleValue]];
    self.sheet.layer.cornerRadius = [theme[@"radius"] doubleValue]; self.stack.spacing = [theme[@"spacing"] doubleValue];
    NSString *effectKey = [NSString stringWithFormat:@"%@-%d", theme[@"material"], opaque];
    if (![self.blur.accessibilityIdentifier isEqual:effectKey]) { self.blur.effect = opaque ? nil : [UIBlurEffect effectWithStyle:[theme[@"material"] isEqual:@"soft"] ? UIBlurEffectStyleSystemMaterialDark : UIBlurEffectStyleSystemChromeMaterialDark]; self.blur.accessibilityIdentifier = effectKey; }
    for (UIButton *button in self.allButtons) button.tintColor = self.ink;
    for (UIButton *button in self.roundButtons) { button.backgroundColor = self.controlFill; button.layer.cornerRadius = [theme[@"shape"] isEqual:@"rounded"] ? 16 : 25; }
    for (UIView *view in self.fillViews) view.backgroundColor = self.controlFill;
    self.dateLabel.textColor = self.mediaTitle.textColor = self.ink; self.batteryLabel.textColor = self.mediaArtist.textColor = self.muted;
    UIButtonConfiguration *configuration = self.allControlsButton.configuration; configuration.baseForegroundColor = self.muted; self.allControlsButton.configuration = configuration;
    self.sun.tintColor = self.brightness.value > 0.25 ? HBContrastingInk(self.accent) : self.ink; self.routes.tintColor = self.muted; self.routes.activeTintColor = self.accent;
    if (![self.renderedTheme[@"accent"] isEqual:theme[@"accent"]] || ![self.renderedTheme[@"surface"] isEqual:theme[@"surface"]]) {
        UIImage *minimum = HBTrackImage(self.accent), *maximum = HBTrackImage([self.ink colorWithAlphaComponent:0.12]);
        [self.brightness setMinimumTrackImage:minimum forState:UIControlStateNormal]; [self.brightness setMaximumTrackImage:maximum forState:UIControlStateNormal];
        [self.volume setMinimumVolumeSliderImage:minimum forState:UIControlStateNormal]; [self.volume setMaximumVolumeSliderImage:maximum forState:UIControlStateNormal];
    }
    self.volume.tintColor = self.accent; self.artwork.tintColor = self.accent; self.renderedTheme = theme;
    [self refreshNativeControls]; [self.view setNeedsLayout];
}
- (void)showProfileError:(NSError *)error {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Harbor" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]]; [self presentViewController:alert animated:YES completion:nil];
}
- (void)editProfile:(NSString *)identifier {
    if (self.presentedViewController || self.previewMode) return;
    self.editor = [[HBProfileEditorController alloc] initWithLibrary:HBLoadProfileLibrary() profileID:identifier focus:self.focusSnapshot]; self.editor.nativeControls = self.nativeControls;
    __weak typeof(self) weakSelf = self;
    self.editor.onFinish = ^(BOOL saved) { weakSelf.editor = nil; weakSelf.focusPausedForEditor = NO; [weakSelf reloadSelectedProfile:saved]; };
    self.editor.onRefreshFocus = ^{ [weakSelf refreshFocus]; };
    self.editor.onPauseFocus = ^{ weakSelf.focusPausedForEditor = YES; [weakSelf synchronizeFocusAccess:HBLoadProfileLibrary()]; };
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:self.editor];
    navigation.modalPresentationStyle = UIModalPresentationOverFullScreen; navigation.modalInPresentation = YES; navigation.view.accessibilityViewIsModal = YES;
    [self presentViewController:navigation animated:YES completion:nil];
}
- (void)deleteProfile:(NSString *)identifier {
    NSDictionary *library = HBLoadProfileLibrary(); if ([library[@"profiles"] count] <= 1) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Delete profile?" message:@"Its Focus links will also be removed. Other profiles stay saved." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        NSMutableDictionary *next = library.mutableCopy; NSMutableArray *profiles = [NSMutableArray array];
        for (NSDictionary *p in library[@"profiles"]) if (![p[@"id"] isEqual:identifier]) [profiles addObject:p]; next[@"profiles"] = profiles;
        NSError *error = nil; if (!HBSaveProfileLibrary(next, library[@"revision"], &error)) [weakSelf showProfileError:error]; else [weakSelf reloadSelectedProfile:YES];
    }]]; [self presentViewController:alert animated:YES completion:nil];
}
- (void)rebuildProfileMenu:(NSDictionary *)library {
    __weak typeof(self) weakSelf = self;
    UIAction *edit = [UIAction actionWithTitle:@"Edit layout & theme…" image:HBSymbol(@"slider.horizontal.3", 18) identifier:nil handler:^(__unused UIAction *action) { [weakSelf editProfile:weakSelf.profile[@"id"]]; }];
    NSMutableArray *profiles = [NSMutableArray array];
    for (NSDictionary *p in library[@"profiles"]) {
        NSString *identifier = p[@"id"];
        UIAction *use = [UIAction actionWithTitle:@"Use as default" image:nil identifier:nil handler:^(__unused UIAction *action) {
            NSDictionary *current = HBLoadProfileLibrary(); NSMutableDictionary *next = current.mutableCopy; next[@"activeID"] = identifier;
            NSError *error = nil; if (!HBSaveProfileLibrary(next, current[@"revision"], &error)) [weakSelf showProfileError:error]; else [weakSelf reloadSelectedProfile:YES];
        }]; use.state = [library[@"activeID"] isEqual:identifier] ? UIMenuElementStateOn : UIMenuElementStateOff;
        UIAction *editOther = [UIAction actionWithTitle:@"Edit…" image:nil identifier:nil handler:^(__unused UIAction *action) { [weakSelf editProfile:identifier]; }];
        NSMutableArray *items = [NSMutableArray arrayWithArray:@[use, editOther]];
        if ([library[@"profiles"] count] > 1) { UIAction *remove = [UIAction actionWithTitle:@"Delete…" image:nil identifier:nil handler:^(__unused UIAction *action) { [weakSelf deleteProfile:identifier]; }]; remove.attributes = UIMenuElementAttributesDestructive; [items addObject:remove]; }
        [profiles addObject:[UIMenu menuWithTitle:p[@"name"] children:items]];
    }
    self.appearance.menu = [UIMenu menuWithTitle:[NSString stringWithFormat:@"Harbor · %@", self.profile[@"name"]] children:@[edit, [UIMenu menuWithTitle:@"Saved profiles" children:profiles]]];
    self.appearance.accessibilityValue = self.profile[@"name"];
}
- (void)setDashboardActive:(BOOL)active {
    if (self.previewMode || self.active == active) return; self.active = active;
    if (active) {
        [self loadViewIfNeeded]; [self reloadSelectedProfile:YES]; [self applyAppearance]; [self refreshStatus]; [self.media start];
        __weak typeof(self) weakSelf = self;
        self.clock = [NSTimer timerWithTimeInterval:1 repeats:YES block:^(__unused NSTimer *timer) { [weakSelf refreshStatus]; }]; self.clock.tolerance = 0.2;
        // Default mode deliberately avoids state/label polling while the user drags.
        [[NSRunLoop mainRunLoop] addTimer:self.clock forMode:NSDefaultRunLoopMode];
    } else { [self.clock invalidate]; self.clock = nil; [self.media stop]; [self.focusMonitor stop];
        if (self.presentedViewController) [self dismissViewControllerAnimated:NO completion:nil]; self.editor = nil; self.focusPausedForEditor = NO;
    }
}
- (void)refreshStatus {
    if (!self.active) return;
    if (self.pendingProfile && ![self isInteracting]) [self reloadSelectedProfile:NO];
    NSString *time = [self.dateFormatter stringFromDate:NSDate.date]; if (![self.dateLabel.text isEqual:time]) self.dateLabel.text = time;
    float level = UIDevice.currentDevice.batteryLevel; self.batteryLabel.text = level >= 0 ? [NSString stringWithFormat:@"%d%%", (int)lroundf(level * 100)] : @"";
    if (!self.brightness.tracking) self.brightness.value = HBUnitValue(UIScreen.mainScreen.brightness, 0.5);
    [self refreshNativeControls]; [self updateVolumeAvailability];
}
- (void)localeChanged { [self.dateFormatter setLocalizedDateFormatFromTemplate:@"jm"]; [self refreshStatus]; }
- (void)brightnessChanged { if (self.previewMode) return; self.sun.tintColor = self.brightness.value > 0.25 ? HBContrastingInk(self.accent) : self.ink; UIScreen.mainScreen.brightness = MAX(0.02, HBUnitValue(self.brightness.value, 0.5)); }
- (void)displayMedia:(HBMediaSnapshot *)snapshot {
    self.mediaTitle.text = snapshot.hasSession ? snapshot.title : @"Not Playing"; self.mediaArtist.text = snapshot.hasSession ? snapshot.artist : @"Music";
    self.artwork.contentMode = snapshot.artwork ? UIViewContentModeScaleAspectFill : UIViewContentModeCenter; self.artwork.image = snapshot.artwork ?: HBSymbol(@"music.note", 22);
    [self.play setImage:HBSymbol(snapshot.playing ? @"pause.fill" : @"play.fill", 20) forState:UIControlStateNormal]; self.play.accessibilityLabel = snapshot.playing ? @"Pause" : @"Play";
    self.play.enabled = snapshot.available && snapshot.hasSession; self.previous.enabled = self.next.enabled = snapshot.available && snapshot.canSkip;
}
- (void)setExpanded:(BOOL)expanded {
    if (_expanded == expanded) return; _expanded = expanded;
    // Layout changes once per action; the native host owns the opening/dismiss animation.
    [self applySectionLayout]; self.expandButton.accessibilityLabel = expanded ? @"Fewer controls" : @"More controls";
    [self.expandButton setImage:HBSymbol(expanded ? @"chevron.compact.down" : @"chevron.compact.up", 20) forState:UIControlStateNormal];
    [self.view setNeedsLayout];
    [UIView animateWithDuration:UIAccessibilityIsReduceMotionEnabled() ? 0 : 0.20 delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction animations:^{ [self.view layoutIfNeeded]; } completion:nil];
    CGFloat maximum = MAX(0, self.scroll.contentSize.height - self.scroll.bounds.size.height);
    if (self.scroll.contentOffset.y > maximum) self.scroll.contentOffset = CGPointMake(0, maximum);
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, self.expandButton);
}
- (void)toggleExpanded { self.expanded = !self.expanded; [self feedback]; }
- (void)grabberPanned:(UIPanGestureRecognizer *)pan {
    if (pan.state == UIGestureRecognizerStateEnded) { CGFloat distance = [pan translationInView:self.view].y; if (fabs(distance) > 18) { self.expanded = distance < 0; [self feedback]; } }
}
- (void)nativePressed:(UIButton *)button {
    if (self.previewMode) return;
    NSString *key = [button.accessibilityIdentifier substringFromIndex:@"harbor.".length];
    if ([self.nativeControls activateKey:key]) { [self feedback]; [self refreshNativeControls]; }
    else if ([@[@"wifi", @"bluetooth", @"cellular", @"airplane"] containsObject:key]) [self connections]; else [self allControls];
}
- (void)panelPressed:(UIButton *)button { if (self.previewMode) return; [self feedback]; if (self.openSystemControls) self.openSystemControls(button.tag); }
- (void)feedback { if (HBHapticsEnabled()) [[[UISelectionFeedbackGenerator alloc] init] selectionChanged]; }
- (void)sendCommand:(int)command { if ([self.media sendCommand:command]) [self feedback]; else UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, @"Media action unavailable. Try All controls."); }
- (void)playPause { [self sendCommand:2]; }
- (void)previousTrack { [self sendCommand:5]; }
- (void)nextTrack { [self sendCommand:4]; }
- (BOOL)accessiblePrevious { [self previousTrack]; return YES; }
- (BOOL)accessibleNext { [self nextTrack]; return YES; }
- (void)connections { [self feedback]; if (self.openSystemControls) self.openSystemControls(HBSystemDestinationConnections); }
- (void)allControls { [self feedback]; if (self.openSystemControls) self.openSystemControls(HBSystemDestinationAll); }
- (void)systemVolume { [self feedback]; if (self.openSystemControls) self.openSystemControls(HBSystemDestinationVolume); }
- (void)noAction {}
- (void)dealloc { [_focusMonitor stop]; [_clock invalidate]; [_media stop]; [NSNotificationCenter.defaultCenter removeObserver:self]; }
@end
