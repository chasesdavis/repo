// SPDX-License-Identifier: GPL-3.0-only
#import "AXNRailView.h"
#import <QuartzCore/QuartzCore.h>
#import "../Shared/AXNPreferences.h"
@implementation AXNRailItem
@end

static UIColor *Accent(void) {
    NSArray *colors = @[[UIColor colorWithRed:0.38 green:0.94 blue:0.80 alpha:1],
        [UIColor colorWithRed:0.73 green:0.62 blue:1 alpha:1],
        [UIColor colorWithRed:0.38 green:0.76 blue:1 alpha:1],
        [UIColor colorWithRed:1 green:0.58 blue:0.72 alpha:1]];
    NSInteger choice = [AXNReadPreference(@"Accent", @0) integerValue];
    return colors[MAX(0, MIN(3, choice))];
}
static BOOL MotionEnabled(void) {
    return [AXNReadPreference(@"Motion", @YES) boolValue] &&
        !UIAccessibilityIsReduceMotionEnabled() && !NSProcessInfo.processInfo.lowPowerModeEnabled;
}
static UIFont *RailFont(UIFontTextStyle style, UITraitCollection *traits) {
    return [UIFont preferredFontForTextStyle:style compatibleWithTraitCollection:traits];
}
static NSMutableArray<NSString *> *PinnedApps(void) {
    return [AXNReadPreference(@"PinnedApps", @[]) mutableCopy];
}

@interface AXNCapsule : UIButton
@property(nonatomic, strong) UIVisualEffectView *material;
@property(nonatomic, strong) UIImageView *iconView;
@property(nonatomic, strong) UIImageView *pinView;
@property(nonatomic, strong) UILabel *nameLabel;
@property(nonatomic, strong) UILabel *badge;
@property(nonatomic) NSUInteger previousCount;
@property(nonatomic) BOOL configured;
@property(nonatomic, copy) void (^interactionEnded)(void);
@end
@implementation AXNCapsule
- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.layer.cornerRadius = 20; self.layer.cornerCurve = kCACornerCurveContinuous;
    self.clipsToBounds = YES;
    _material = [[UIVisualEffectView alloc] initWithEffect:nil];
    _material.userInteractionEnabled = NO; _material.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_material];
    _iconView = [UIImageView new]; _iconView.contentMode = UIViewContentModeScaleAspectFit;
    _iconView.layer.cornerRadius = 9; _iconView.clipsToBounds = YES; _iconView.tintColor = UIColor.whiteColor;
    _pinView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"pin.fill"]];
    _pinView.contentMode = UIViewContentModeScaleAspectFit;
    _nameLabel = [UILabel new]; _nameLabel.textColor = UIColor.whiteColor; _nameLabel.adjustsFontForContentSizeCategory = YES;
    _nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    _badge = [UILabel new]; _badge.textAlignment = NSTextAlignmentCenter;
    _badge.layer.cornerRadius = 10; _badge.clipsToBounds = YES;
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[_iconView, _pinView, _nameLabel, _badge]];
    row.axis = UILayoutConstraintAxisHorizontal; row.spacing = 8; row.alignment = UIStackViewAlignmentCenter;
    row.userInteractionEnabled = NO; row.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:row];
    for (UIView *view in @[_iconView, _pinView, _nameLabel, _badge]) view.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [_material.topAnchor constraintEqualToAnchor:self.topAnchor], [_material.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [_material.leadingAnchor constraintEqualToAnchor:self.leadingAnchor], [_material.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.heightAnchor constraintGreaterThanOrEqualToConstant:48],
        [_iconView.widthAnchor constraintEqualToConstant:32], [_iconView.heightAnchor constraintEqualToConstant:32],
        [_nameLabel.widthAnchor constraintLessThanOrEqualToConstant:150],
        [row.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
        [row.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12],
        [row.centerYAnchor constraintEqualToAnchor:self.centerYAnchor]]];
    // Hidden arranged views collapse without fighting required width constraints.
    for (NSLayoutConstraint *c in @[
        [_pinView.widthAnchor constraintEqualToConstant:11], [_pinView.heightAnchor constraintEqualToConstant:11],
        [_badge.widthAnchor constraintGreaterThanOrEqualToConstant:28], [_badge.heightAnchor constraintGreaterThanOrEqualToConstant:22]]) {
        c.priority = 999; c.active = YES;
    }
    return self;
}
- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    CGAffineTransform target = highlighted ? CGAffineTransformMakeScale(0.96, 0.96) : CGAffineTransformIdentity;
    if (!MotionEnabled()) { self.transform = CGAffineTransformIdentity; return; }
    [UIView animateWithDuration:0.18 delay:0 usingSpringWithDamping:0.75 initialSpringVelocity:0
        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
        animations:^{ self.transform = target; } completion:nil];
}
- (void)endTracking:(UITouch *)touch withEvent:(UIEvent *)event {
    [super endTracking:touch withEvent:event];
    if (self.interactionEnded) self.interactionEnded();
}
- (void)cancelTrackingWithEvent:(UIEvent *)event {
    [super cancelTrackingWithEvent:event];
    if (self.interactionEnded) self.interactionEnded();
}
- (void)configure:(AXNRailItem *)item total:(NSUInteger)total selected:(BOOL)selected pinned:(BOOL)pinned traits:(UITraitCollection *)traits {
    UIColor *accent = Accent(); NSUInteger count = item ? item.count : total;
    BOOL reduceTransparency = UIAccessibilityIsReduceTransparencyEnabled() || UIAccessibilityDarkerSystemColorsEnabled();
    if ((self.material.effect != nil) == reduceTransparency)
        self.material.effect = reduceTransparency ? nil : [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
    self.material.backgroundColor = reduceTransparency ? [UIColor colorWithWhite:selected ? 0.25 : 0.12 alpha:1]
        : (selected ? [accent colorWithAlphaComponent:0.20] : [UIColor.whiteColor colorWithAlphaComponent:0.07]);
    self.layer.borderWidth = selected ? 1.5 : 0.75;
    self.layer.borderColor = (selected ? accent : [UIColor.whiteColor colorWithAlphaComponent:0.20]).CGColor;
    self.iconView.image = item ? (item.icon ?: [UIImage systemImageNamed:@"app.fill"]) : [UIImage systemImageNamed:@"square.grid.2x2.fill"];
    self.pinView.hidden = !pinned; self.pinView.tintColor = accent;
    self.nameLabel.text = item ? item.name : @"All";
    self.nameLabel.font = RailFont(selected ? UIFontTextStyleHeadline : UIFontTextStyleSubheadline, traits);
    self.nameLabel.hidden = item && !selected && [AXNReadPreference(@"Compact", @NO) boolValue];
    self.badge.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCaption1]
        scaledFontForFont:[UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightBold] compatibleWithTraitCollection:traits];
    self.badge.text = count > 999 ? @"999+" : [NSString stringWithFormat:@"%lu", (unsigned long)count];
    self.badge.textColor = selected ? UIColor.blackColor : UIColor.whiteColor;
    self.badge.backgroundColor = selected ? accent : [UIColor.whiteColor colorWithAlphaComponent:0.12];
    self.badge.hidden = ![AXNReadPreference(@"ShowCounts", @YES) boolValue];
    self.accessibilityLabel = item ? item.name : @"All";
    self.accessibilityValue = [NSString stringWithFormat:@"%lu %@%@", (unsigned long)count, count == 1 ? @"notification" : @"notifications", pinned ? @", pinned" : @""];
    self.accessibilityHint = !item ? @"Shows all notifications" :
        (selected && [AXNReadPreference(@"TapSelectedToAll", @YES) boolValue]
            ? @"Activate again to show all notifications. Actions include favorites."
            : @"Filters to this app. Actions include favorites and Show All.");
    self.accessibilityTraits = UIAccessibilityTraitButton | (selected ? UIAccessibilityTraitSelected : 0);
    if (self.configured && count > self.previousCount && self.window && !self.badge.hidden && MotionEnabled()) {
        CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
        pulse.fromValue = @1.18; pulse.toValue = @1; pulse.duration = 0.25;
        [self.badge.layer addAnimation:pulse forKey:@"arrival"];
    }
    self.previousCount = count; self.configured = YES;
}
@end

@interface AXNRailView () <UIScrollViewDelegate>
@property(nonatomic, strong) UILabel *heading;
@property(nonatomic, strong) UILabel *summary;
@property(nonatomic, strong) UIStackView *header;
@property(nonatomic, strong) NSArray<AXNRailItem *> *pendingItems;
@property(nonatomic, copy) NSString *pendingSelection;
@property(nonatomic) BOOL hasPendingUpdate;
@property(nonatomic, strong) UIScrollView *scroll;
@property(nonatomic, strong) UIStackView *stack;
@property(nonatomic, strong) NSArray<AXNRailItem *> *items;
@property(nonatomic, copy) NSString *selected;
@property(nonatomic, strong) NSLayoutConstraint *railHeight;
@property(nonatomic, strong) NSMutableDictionary<NSString *, AXNCapsule *> *buttons;
@end
@implementation AXNRailView
- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.translatesAutoresizingMaskIntoConstraints = NO; self.accessibilityIdentifier = @"AxonReborn.Rail";
    _buttons = [NSMutableDictionary new];
    _heading = [UILabel new]; _heading.textColor = UIColor.whiteColor;
    _heading.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    _heading.adjustsFontForContentSizeCategory = YES; _heading.accessibilityTraits = UIAccessibilityTraitHeader;
    _summary = [UILabel new]; _summary.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    _summary.adjustsFontForContentSizeCategory = YES;
    [_heading setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    _header = [[UIStackView alloc] initWithArrangedSubviews:@[_heading, _summary]];
    _header.axis = UILayoutConstraintAxisHorizontal; _header.spacing = 8; _header.alignment = UIStackViewAlignmentCenter;
    _scroll = [UIScrollView new]; _scroll.delegate = self;
    _scroll.showsHorizontalScrollIndicator = NO; _scroll.alwaysBounceHorizontal = YES;
    _stack = [UIStackView new]; _stack.axis = UILayoutConstraintAxisHorizontal; _stack.spacing = 10;
    _stack.alignment = UIStackViewAlignmentFill;
    for (UIView *v in @[_header, _heading, _summary, _scroll, _stack]) v.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_header]; [self addSubview:_scroll]; [_scroll addSubview:_stack];
    _railHeight = [self.heightAnchor constraintEqualToConstant:106]; _railHeight.priority = 999;
    [NSLayoutConstraint activateConstraints:@[_railHeight,
        [_header.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
        [_header.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
        [_header.topAnchor constraintEqualToAnchor:self.topAnchor constant:8],
        [_scroll.topAnchor constraintEqualToAnchor:_header.bottomAnchor constant:10],
        [_scroll.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-10],
        [_scroll.leadingAnchor constraintEqualToAnchor:self.leadingAnchor], [_scroll.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_stack.leadingAnchor constraintEqualToAnchor:_scroll.contentLayoutGuide.leadingAnchor constant:12],
        [_stack.trailingAnchor constraintEqualToAnchor:_scroll.contentLayoutGuide.trailingAnchor constant:-12],
        [_stack.topAnchor constraintEqualToAnchor:_scroll.contentLayoutGuide.topAnchor], [_stack.bottomAnchor constraintEqualToAnchor:_scroll.contentLayoutGuide.bottomAnchor],
        [_stack.heightAnchor constraintEqualToAnchor:_scroll.frameLayoutGuide.heightAnchor]]];
    for (NSNotificationName name in @[UIAccessibilityReduceMotionStatusDidChangeNotification,
        UIAccessibilityReduceTransparencyStatusDidChangeNotification, UIAccessibilityDarkerSystemColorsStatusDidChangeNotification,
        NSProcessInfoPowerStateDidChangeNotification, UIContentSizeCategoryDidChangeNotification])
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(environmentChanged:) name:name object:nil];
    return self;
}
- (CGFloat)preferredRailHeight {
    UITraitCollection *traits = self.traitCollection;
    BOOL accessible = UIContentSizeCategoryIsAccessibilityCategory(traits.preferredContentSizeCategory);
    CGFloat heading = ceil(RailFont(UIFontTextStyleSubheadline, traits).lineHeight);
    CGFloat summary = ceil(RailFont(UIFontTextStyleCaption1, traits).lineHeight);
    CGFloat header = accessible ? heading + summary + 4 : MAX(heading, summary);
    CGFloat capsule = MAX(48, ceil(RailFont(UIFontTextStyleHeadline, traits).lineHeight) + 24);
    return 28 + header + capsule + 12 * [AXNReadPreference(@"Density", @1) integerValue];
}
- (BOOL)interactionActive {
    if (self.scroll.tracking || self.scroll.dragging || self.scroll.decelerating) return YES;
    for (AXNCapsule *button in self.buttons.allValues) if (button.tracking || button.highlighted) return YES;
    return NO;
}
- (void)flushPendingUpdate {
    if (!self.hasPendingUpdate || [self interactionActive]) return;
    NSArray *items = self.pendingItems; NSString *selection = self.pendingSelection;
    self.hasPendingUpdate = NO; self.pendingItems = nil; self.pendingSelection = nil;
    [self updateWithItems:items selected:selection];
}
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    (void)scrollView; if (!decelerate) [self flushPendingUpdate];
}
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    (void)scrollView; [self flushPendingUpdate];
}
- (void)didMoveToWindow {
    [super didMoveToWindow];
    // A detached rail cannot keep a pending snapshot alive indefinitely.
    if (!self.window) {
        self.hasPendingUpdate = NO; self.pendingItems = nil; self.pendingSelection = nil;
    }
}
- (void)environmentChanged:(NSNotification *)notification {
    (void)notification;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!MotionEnabled()) for (AXNCapsule *button in self.buttons.allValues) {
            [button.layer removeAllAnimations]; [button.badge.layer removeAllAnimations];
            button.transform = CGAffineTransformIdentity;
        }
        if (self.items) [self updateWithItems:self.hasPendingUpdate ? self.pendingItems : self.items
            selected:self.hasPendingUpdate ? self.pendingSelection : self.selected];
    });
}
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
- (void)choose:(NSString *)bundle {
    if ([AXNReadPreference(@"Haptics", @YES) boolValue]) [[[UISelectionFeedbackGenerator alloc] init] selectionChanged];
    if (self.onSelect) self.onSelect(bundle);
}
- (void)togglePin:(NSString *)bundle {
    if (!bundle.length) return;
    NSMutableArray *pins = PinnedApps();
    if ([pins containsObject:bundle]) [pins removeObject:bundle];
    else if (pins.count < 32) [pins addObject:bundle];
    AXNWritePreference(@"PinnedApps", pins);
    [self updateWithItems:self.hasPendingUpdate ? self.pendingItems : self.items selected:self.hasPendingUpdate ? self.pendingSelection : self.selected];
}
- (void)moveFavoriteFirst:(NSString *)bundle {
    NSMutableArray *pins = PinnedApps();
    if (![pins containsObject:bundle]) return;
    [pins removeObject:bundle]; [pins insertObject:bundle atIndex:0];
    AXNWritePreference(@"PinnedApps", pins);
    [self updateWithItems:self.hasPendingUpdate ? self.pendingItems : self.items selected:self.hasPendingUpdate ? self.pendingSelection : self.selected];
}
- (AXNCapsule *)buttonForItem:(AXNRailItem *)item total:(NSUInteger)total pins:(NSArray *)pins {
    NSString *key = item.bundleID ?: @"";
    AXNCapsule *button = self.buttons[key];
    __weak typeof(self) weakSelf = self;
    if (!button) {
        button = [[AXNCapsule alloc] initWithFrame:CGRectZero]; self.buttons[key] = button;
        NSString *bundle = item.bundleID;
        button.interactionEnded = ^{
            dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf flushPendingUpdate]; });
        };
        [button addAction:[UIAction actionWithHandler:^(__kindof UIAction *action) { (void)action; [weakSelf choose:bundle]; }]
            forControlEvents:UIControlEventTouchUpInside];
    }
    BOOL pinned = [pins containsObject:key];
    [button configure:item total:total selected:(item ? [self.selected isEqualToString:key] : !self.selected) pinned:pinned traits:self.traitCollection];
    if (item) {
        UIAction *pin = [UIAction actionWithTitle:pinned ? @"Unpin favorite" : @"Pin favorite" image:[UIImage systemImageNamed:pinned ? @"pin.slash" : @"pin"]
            identifier:nil handler:^(__kindof UIAction *action) { (void)action; [weakSelf togglePin:key]; }];
        if (!pinned && pins.count >= 32) pin.attributes = UIMenuElementAttributesDisabled;
        UIAction *all = [UIAction actionWithTitle:@"Show all notifications" image:[UIImage systemImageNamed:@"square.grid.2x2"]
            identifier:nil handler:^(__kindof UIAction *action) { (void)action; [weakSelf choose:nil]; }];
        NSMutableArray *menu = [NSMutableArray arrayWithObject:pin];
        NSMutableArray *accessibility = [NSMutableArray new];
        if (pinned || pins.count < 32) [accessibility addObject:[[UIAccessibilityCustomAction alloc]
            initWithName:pin.title actionHandler:^BOOL(UIAccessibilityCustomAction *action) {
                (void)action; [weakSelf togglePin:key]; return weakSelf != nil;
            }]];
        if (pinned && ![pins.firstObject isEqualToString:key]) {
            [menu addObject:[UIAction actionWithTitle:@"Move favorite first" image:[UIImage systemImageNamed:@"arrow.left.to.line"]
                identifier:nil handler:^(__kindof UIAction *action) { (void)action; [weakSelf moveFavoriteFirst:key]; }]];
            [accessibility addObject:[[UIAccessibilityCustomAction alloc] initWithName:@"Move favorite first"
                actionHandler:^BOOL(UIAccessibilityCustomAction *action) {
                    (void)action; [weakSelf moveFavoriteFirst:key]; return weakSelf != nil;
                }]];
        }
        [menu addObject:all];
        [accessibility addObject:[[UIAccessibilityCustomAction alloc] initWithName:@"Show all notifications"
            actionHandler:^BOOL(UIAccessibilityCustomAction *action) {
                (void)action; [weakSelf choose:nil]; return weakSelf != nil;
            }]];
        button.accessibilityCustomActions = accessibility;
        button.menu = [UIMenu menuWithTitle:item.name children:menu];
        button.showsMenuAsPrimaryAction = NO;
    }
    return button;
}
- (void)updateWithItems:(NSArray<AXNRailItem *> *)items selected:(NSString *)selected {
    if ([self interactionActive] && items.count) {
        self.pendingItems = [items copy]; self.pendingSelection = [selected copy]; self.hasPendingUpdate = YES;
        return;
    }
    self.hasPendingUpdate = NO; self.pendingItems = nil; self.pendingSelection = nil;
    BOOL selectionChanged = !((self.selected == selected) || [self.selected isEqualToString:selected]);
    self.items = [items copy]; self.selected = [selected copy];
    NSArray *pins = PinnedApps(); NSMutableArray *ordered = [NSMutableArray new];
    for (NSString *pin in pins) for (AXNRailItem *item in items) if ([item.bundleID isEqualToString:pin]) [ordered addObject:item];
    for (AXNRailItem *item in items) if (![pins containsObject:item.bundleID]) [ordered addObject:item];
    NSUInteger total = 0; AXNRailItem *selection = nil;
    for (AXNRailItem *item in items) { total += item.count; if ([item.bundleID isEqualToString:selected]) selection = item; }
    BOOL accessible = UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory);
    self.header.axis = accessible ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
    self.header.alignment = accessible ? UIStackViewAlignmentLeading : UIStackViewAlignmentCenter;
    self.header.spacing = accessible ? 4 : 8;
    self.heading.font = RailFont(UIFontTextStyleSubheadline, self.traitCollection);
    self.summary.font = RailFont(UIFontTextStyleCaption1, self.traitCollection);
    self.heading.text = selection ? selection.name : @"All notifications";
    self.summary.text = selection ? [NSString stringWithFormat:@"%lu of %lu", (unsigned long)selection.count, (unsigned long)total]
        : [NSString stringWithFormat:@"%lu total", (unsigned long)total];
    self.summary.textColor = selection ? Accent() : [UIColor.whiteColor colorWithAlphaComponent:0.75];
    self.hidden = total == 0;
    self.railHeight.constant = self.preferredRailHeight;
    CGPoint offset = self.scroll.contentOffset;
    NSMutableArray *desired = [NSMutableArray arrayWithObject:[self buttonForItem:nil total:total pins:pins]];
    NSMutableSet *keys = [NSMutableSet setWithObject:@""];
    for (AXNRailItem *item in ordered) { [desired addObject:[self buttonForItem:item total:total pins:pins]]; [keys addObject:item.bundleID]; }
    for (NSString *key in self.buttons.allKeys) if (![keys containsObject:key]) { [self.buttons[key] removeFromSuperview]; [self.buttons removeObjectForKey:key]; }
    // Move arranged entries in place. Never detach a surviving control.
    for (NSUInteger i = 0; i < desired.count; ++i)
        if (i >= self.stack.arrangedSubviews.count || self.stack.arrangedSubviews[i] != desired[i])
            [self.stack insertArrangedSubview:desired[i] atIndex:i];
    [self layoutIfNeeded];
    CGFloat maxX = MAX(0, self.scroll.contentSize.width - self.scroll.bounds.size.width);
    self.scroll.contentOffset = CGPointMake(MIN(MAX(0, offset.x), maxX), 0);
    if (selectionChanged && !self.scroll.tracking && !self.scroll.decelerating) {
        UIView *active = self.buttons[selected ?: @""];
        [self.scroll scrollRectToVisible:[active convertRect:active.bounds toView:self.scroll] animated:MotionEnabled()];
    }
}
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (self.items) [self updateWithItems:self.hasPendingUpdate ? self.pendingItems : self.items
        selected:self.hasPendingUpdate ? self.pendingSelection : self.selected];
}
@end
