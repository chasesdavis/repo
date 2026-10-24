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
static NSMutableArray<NSString *> *PinnedApps(void) {
    id stored = AXNReadPreference(@"PinnedApps", @[]);
    NSMutableArray *result = [NSMutableArray new];
    if ([stored isKindOfClass:NSArray.class]) for (id value in stored) {
        if ([value isKindOfClass:NSString.class] && [value length] && ![result containsObject:value]) [result addObject:value];
        if (result.count == 32) break;
    }
    return result;
}

@interface AXNCapsule : UIButton
@property(nonatomic, strong) UIVisualEffectView *material;
@property(nonatomic, strong) UIImageView *iconView;
@property(nonatomic, strong) UIImageView *pinView;
@property(nonatomic, strong) UILabel *nameLabel;
@property(nonatomic, strong) UILabel *badge;
@property(nonatomic) NSUInteger previousCount;
@property(nonatomic) BOOL configured;
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
    if (UIAccessibilityIsReduceMotionEnabled()) { self.transform = CGAffineTransformIdentity; return; }
    [UIView animateWithDuration:0.18 delay:0 usingSpringWithDamping:0.75 initialSpringVelocity:0
        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
        animations:^{ self.transform = target; } completion:nil];
}
- (void)configure:(AXNRailItem *)item total:(NSUInteger)total selected:(BOOL)selected pinned:(BOOL)pinned {
    UIColor *accent = Accent(); NSUInteger count = item ? item.count : total;
    BOOL reduceTransparency = UIAccessibilityIsReduceTransparencyEnabled();
    self.material.effect = reduceTransparency ? nil : [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
    self.material.backgroundColor = reduceTransparency ? [UIColor colorWithWhite:selected ? 0.25 : 0.12 alpha:1]
        : (selected ? [accent colorWithAlphaComponent:0.20] : [UIColor.whiteColor colorWithAlphaComponent:0.07]);
    self.layer.borderWidth = selected ? 1.5 : 0.75;
    self.layer.borderColor = (selected ? accent : [UIColor.whiteColor colorWithAlphaComponent:0.20]).CGColor;
    self.iconView.image = item ? (item.icon ?: [UIImage systemImageNamed:@"app.fill"]) : [UIImage systemImageNamed:@"square.grid.2x2.fill"];
    self.pinView.hidden = !pinned; self.pinView.tintColor = accent;
    self.nameLabel.text = item ? item.name : @"All";
    self.nameLabel.font = [UIFont preferredFontForTextStyle:selected ? UIFontTextStyleHeadline : UIFontTextStyleSubheadline];
    self.nameLabel.hidden = item && !selected && [AXNReadPreference(@"Compact", @NO) boolValue];
    self.badge.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightBold];
    self.badge.text = count > 999 ? @"999+" : [NSString stringWithFormat:@"%lu", (unsigned long)count];
    self.badge.textColor = selected ? UIColor.blackColor : UIColor.whiteColor;
    self.badge.backgroundColor = selected ? accent : [UIColor.whiteColor colorWithAlphaComponent:0.12];
    self.badge.hidden = ![AXNReadPreference(@"ShowCounts", @YES) boolValue];
    self.accessibilityLabel = item ? item.name : @"All";
    self.accessibilityValue = [NSString stringWithFormat:@"%lu notifications%@", (unsigned long)count, pinned ? @", pinned" : @""];
    self.accessibilityHint = item ? @"Filters to this app. Touch and hold for favorites and Show All." : @"Shows all notifications";
    self.accessibilityTraits = UIAccessibilityTraitButton | (selected ? UIAccessibilityTraitSelected : 0);
    if (self.configured && count > self.previousCount && self.window && !UIAccessibilityIsReduceMotionEnabled()) {
        CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
        pulse.fromValue = @1.18; pulse.toValue = @1; pulse.duration = 0.25;
        [self.badge.layer addAnimation:pulse forKey:@"arrival"];
    }
    self.previousCount = count; self.configured = YES;
}
@end

@interface AXNRailView ()
@property(nonatomic, strong) UILabel *heading;
@property(nonatomic, strong) UILabel *summary;
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
    _scroll = [UIScrollView new]; _scroll.showsHorizontalScrollIndicator = NO; _scroll.alwaysBounceHorizontal = YES;
    _stack = [UIStackView new]; _stack.axis = UILayoutConstraintAxisHorizontal; _stack.spacing = 10;
    _stack.alignment = UIStackViewAlignmentFill;
    for (UIView *v in @[_heading, _summary, _scroll, _stack]) v.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_heading]; [self addSubview:_summary]; [self addSubview:_scroll]; [_scroll addSubview:_stack];
    _railHeight = [self.heightAnchor constraintEqualToConstant:106]; _railHeight.priority = 999;
    [NSLayoutConstraint activateConstraints:@[_railHeight,
        [_heading.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16], [_heading.topAnchor constraintEqualToAnchor:self.topAnchor constant:8],
        [_summary.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16], [_summary.centerYAnchor constraintEqualToAnchor:_heading.centerYAnchor],
        [_heading.trailingAnchor constraintLessThanOrEqualToAnchor:_summary.leadingAnchor constant:-8],
        [_scroll.topAnchor constraintEqualToAnchor:_heading.bottomAnchor constant:10], [_scroll.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-10],
        [_scroll.leadingAnchor constraintEqualToAnchor:self.leadingAnchor], [_scroll.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_stack.leadingAnchor constraintEqualToAnchor:_scroll.contentLayoutGuide.leadingAnchor constant:12],
        [_stack.trailingAnchor constraintEqualToAnchor:_scroll.contentLayoutGuide.trailingAnchor constant:-12],
        [_stack.topAnchor constraintEqualToAnchor:_scroll.contentLayoutGuide.topAnchor], [_stack.bottomAnchor constraintEqualToAnchor:_scroll.contentLayoutGuide.bottomAnchor],
        [_stack.heightAnchor constraintEqualToAnchor:_scroll.frameLayoutGuide.heightAnchor]]];
    return self;
}
- (void)choose:(NSString *)bundle {
    if ([AXNReadPreference(@"Haptics", @YES) boolValue]) [[[UISelectionFeedbackGenerator alloc] init] selectionChanged];
    if (self.onSelect) self.onSelect(bundle);
}
- (void)togglePin:(NSString *)bundle {
    NSMutableArray *pins = PinnedApps();
    if ([pins containsObject:bundle]) [pins removeObject:bundle];
    else if (pins.count < 32) [pins addObject:bundle];
    AXNWritePreference(@"PinnedApps", pins);
    [self updateWithItems:self.items selected:self.selected];
}
- (AXNCapsule *)buttonForItem:(AXNRailItem *)item total:(NSUInteger)total pins:(NSArray *)pins {
    NSString *key = item.bundleID ?: @"";
    AXNCapsule *button = self.buttons[key];
    __weak typeof(self) weakSelf = self;
    if (!button) {
        button = [[AXNCapsule alloc] initWithFrame:CGRectZero]; self.buttons[key] = button;
        NSString *bundle = item.bundleID;
        [button addAction:[UIAction actionWithHandler:^(__kindof UIAction *action) { (void)action; [weakSelf choose:bundle]; }]
            forControlEvents:UIControlEventTouchUpInside];
    }
    BOOL pinned = [pins containsObject:key];
    [button configure:item total:total selected:(item ? [self.selected isEqualToString:key] : !self.selected) pinned:pinned];
    if (item) {
        UIAction *pin = [UIAction actionWithTitle:pinned ? @"Unpin favorite" : @"Pin favorite" image:[UIImage systemImageNamed:pinned ? @"pin.slash" : @"pin"]
            identifier:nil handler:^(__kindof UIAction *action) { (void)action; [weakSelf togglePin:key]; }];
        if (!pinned && pins.count >= 32) pin.attributes = UIMenuElementAttributesDisabled;
        UIAction *all = [UIAction actionWithTitle:@"Show all notifications" image:[UIImage systemImageNamed:@"square.grid.2x2"]
            identifier:nil handler:^(__kindof UIAction *action) { (void)action; [weakSelf choose:nil]; }];
        button.menu = [UIMenu menuWithTitle:item.name children:@[pin, all]];
        button.showsMenuAsPrimaryAction = NO;
    }
    return button;
}
- (void)updateWithItems:(NSArray<AXNRailItem *> *)items selected:(NSString *)selected {
    BOOL selectionChanged = !((self.selected == selected) || [self.selected isEqualToString:selected]);
    self.items = [items copy]; self.selected = [selected copy];
    NSArray *pins = PinnedApps(); NSMutableArray *ordered = [NSMutableArray new];
    for (NSString *pin in pins) for (AXNRailItem *item in items) if ([item.bundleID isEqualToString:pin]) [ordered addObject:item];
    for (AXNRailItem *item in items) if (![pins containsObject:item.bundleID]) [ordered addObject:item];
    NSUInteger total = 0; AXNRailItem *selection = nil;
    for (AXNRailItem *item in items) { total += item.count; if ([item.bundleID isEqualToString:selected]) selection = item; }
    self.heading.text = selection ? selection.name : @"All notifications";
    self.summary.text = selection ? [NSString stringWithFormat:@"%lu of %lu", (unsigned long)selection.count, (unsigned long)total]
        : [NSString stringWithFormat:@"%lu total", (unsigned long)total];
    self.summary.textColor = selection ? Accent() : [UIColor.whiteColor colorWithAlphaComponent:0.75];
    self.hidden = total == 0;
    self.railHeight.constant = MAX(106, [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline].pointSize * 2 + 68);
    CGPoint offset = self.scroll.contentOffset;
    NSMutableArray *desired = [NSMutableArray arrayWithObject:[self buttonForItem:nil total:total pins:pins]];
    NSMutableSet *keys = [NSMutableSet setWithObject:@""];
    for (AXNRailItem *item in ordered) { [desired addObject:[self buttonForItem:item total:total pins:pins]]; [keys addObject:item.bundleID]; }
    for (NSString *key in self.buttons.allKeys) if (![keys containsObject:key]) { [self.buttons[key] removeFromSuperview]; [self.buttons removeObjectForKey:key]; }
    // Keep controls alive across count updates so an in-flight touch/menu is not discarded.
    if (![self.stack.arrangedSubviews isEqualToArray:desired]) {
        for (UIView *v in self.stack.arrangedSubviews.copy) { [self.stack removeArrangedSubview:v]; [v removeFromSuperview]; }
        for (UIView *v in desired) [self.stack addArrangedSubview:v];
    }
    [self layoutIfNeeded];
    CGFloat maxX = MAX(0, self.scroll.contentSize.width - self.scroll.bounds.size.width);
    self.scroll.contentOffset = CGPointMake(MIN(MAX(0, offset.x), maxX), 0);
    if (selectionChanged && !self.scroll.tracking && !self.scroll.decelerating) {
        UIView *active = self.buttons[selected ?: @""];
        [self.scroll scrollRectToVisible:[active convertRect:active.bounds toView:self.scroll] animated:!UIAccessibilityIsReduceMotionEnabled()];
    }
}
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (self.items) [self updateWithItems:self.items selected:self.selected];
}
@end
