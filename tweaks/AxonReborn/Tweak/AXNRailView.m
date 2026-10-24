// SPDX-License-Identifier: GPL-3.0-only
#import "AXNRailView.h"
#import "../Shared/AXNPreferences.h"
@implementation AXNRailItem
@end

@interface AXNRailView ()
@property(nonatomic, strong) UILabel *heading;
@property(nonatomic, strong) UILabel *summary;
@property(nonatomic, strong) UIScrollView *scroll;
@property(nonatomic, strong) UIStackView *stack;
@property(nonatomic, strong) NSArray<AXNRailItem *> *items;
@property(nonatomic, copy) NSString *selected;
@property(nonatomic, strong) NSLayoutConstraint *railHeight;
@end

@implementation AXNRailView
- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.accessibilityIdentifier = @"AxonReborn.Rail";
    _heading = [UILabel new];
    _heading.text = @"Notifications";
    _heading.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    _heading.adjustsFontForContentSizeCategory = YES;
    _heading.textColor = UIColor.whiteColor;
    _heading.accessibilityTraits = UIAccessibilityTraitHeader;
    _summary = [UILabel new];
    _summary.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    _summary.textColor = [UIColor.whiteColor colorWithAlphaComponent:0.75];
    _summary.adjustsFontForContentSizeCategory = YES;
    [_heading setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    _scroll = [UIScrollView new];
    _scroll.showsHorizontalScrollIndicator = NO;
    _scroll.alwaysBounceHorizontal = YES;
    _scroll.clipsToBounds = NO;
    _stack = [[UIStackView alloc] init];
    _stack.axis = UILayoutConstraintAxisHorizontal;
    _stack.spacing = 8;
    _stack.alignment = UIStackViewAlignmentFill;
    for (UIView *view in @[_heading, _summary, _scroll, _stack]) view.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_heading]; [self addSubview:_summary]; [self addSubview:_scroll];
    [_scroll addSubview:_stack];
    _railHeight = [self.heightAnchor constraintEqualToConstant:106];
    // A stack's UISV-hiding constraint must be able to collapse an empty rail.
    _railHeight.priority = 999;
    [NSLayoutConstraint activateConstraints:@[
        _railHeight,
        [_heading.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
        [_heading.topAnchor constraintEqualToAnchor:self.topAnchor constant:8],
        [_summary.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
        [_summary.centerYAnchor constraintEqualToAnchor:_heading.centerYAnchor],
        [_heading.trailingAnchor constraintLessThanOrEqualToAnchor:_summary.leadingAnchor constant:-8],
        [_scroll.topAnchor constraintEqualToAnchor:_heading.bottomAnchor constant:10],
        [_scroll.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [_scroll.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_scroll.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-10],
        [_stack.leadingAnchor constraintEqualToAnchor:_scroll.contentLayoutGuide.leadingAnchor constant:12],
        [_stack.trailingAnchor constraintEqualToAnchor:_scroll.contentLayoutGuide.trailingAnchor constant:-12],
        [_stack.topAnchor constraintEqualToAnchor:_scroll.contentLayoutGuide.topAnchor],
        [_stack.bottomAnchor constraintEqualToAnchor:_scroll.contentLayoutGuide.bottomAnchor],
        [_stack.heightAnchor constraintEqualToAnchor:_scroll.frameLayoutGuide.heightAnchor]
    ]];
    return self;
}

- (UIButton *)buttonForItem:(AXNRailItem *)item total:(NSUInteger)total {
    BOOL isAll = item == nil;
    BOOL selected = isAll ? self.selected == nil : [self.selected isEqualToString:item.bundleID];
    BOOL counts = [AXNReadPreference(@"ShowCounts", @YES) boolValue];
    BOOL compact = [AXNReadPreference(@"Compact", @NO) boolValue];
    NSString *name = isAll ? @"All" : item.name;
    NSUInteger count = isAll ? total : item.count;
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.layer.cornerRadius = 18;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    button.clipsToBounds = YES;
    button.layer.borderWidth = 0.75;
    button.layer.borderColor = [UIColor.whiteColor colorWithAlphaComponent:selected ? 0.65 : 0.16].CGColor;
    UIVisualEffectView *material = [[UIVisualEffectView alloc] initWithEffect:
        UIAccessibilityIsReduceTransparencyEnabled() ? nil :
        [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark]];
    material.userInteractionEnabled = NO;
    material.translatesAutoresizingMaskIntoConstraints = NO;
    material.backgroundColor = UIAccessibilityIsReduceTransparencyEnabled()
        ? [UIColor colorWithWhite:selected ? 0.30 : 0.13 alpha:1]
        : [UIColor.whiteColor colorWithAlphaComponent:selected ? 0.22 : 0.04];
    [button addSubview:material];
    [NSLayoutConstraint activateConstraints:@[
        [material.topAnchor constraintEqualToAnchor:button.topAnchor],
        [material.bottomAnchor constraintEqualToAnchor:button.bottomAnchor],
        [material.leadingAnchor constraintEqualToAnchor:button.leadingAnchor],
        [material.trailingAnchor constraintEqualToAnchor:button.trailingAnchor],
        [button.heightAnchor constraintGreaterThanOrEqualToConstant:48]
    ]];
    UIImageView *icon = [[UIImageView alloc] initWithImage:isAll ? [UIImage systemImageNamed:@"square.grid.2x2.fill"] : item.icon];
    if (!icon.image) icon.image = [UIImage systemImageNamed:@"app.fill"];
    icon.tintColor = UIColor.whiteColor;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.layer.cornerRadius = 8;
    icon.clipsToBounds = YES;
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[[icon.widthAnchor constraintEqualToConstant:30], [icon.heightAnchor constraintEqualToConstant:30]]];
    UILabel *label = [UILabel new];
    label.text = name;
    label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    label.adjustsFontForContentSizeCategory = YES;
    label.textColor = UIColor.whiteColor;
    UILabel *badge = [UILabel new];
    badge.text = count > 999 ? @"999+" : [NSString stringWithFormat:@"%lu", (unsigned long)count];
    badge.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightSemibold];
    badge.textColor = [UIColor.whiteColor colorWithAlphaComponent:0.8];
    UIStackView *content = [[UIStackView alloc] initWithArrangedSubviews:@[icon]];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    content.userInteractionEnabled = NO;
    content.axis = UILayoutConstraintAxisHorizontal;
    content.alignment = UIStackViewAlignmentCenter;
    content.spacing = 8;
    if (!compact || isAll) [content addArrangedSubview:label];
    if (counts) [content addArrangedSubview:badge];
    [button addSubview:content];
    [NSLayoutConstraint activateConstraints:@[
        [content.leadingAnchor constraintEqualToAnchor:button.leadingAnchor constant:12],
        [content.trailingAnchor constraintEqualToAnchor:button.trailingAnchor constant:-12],
        [content.centerYAnchor constraintEqualToAnchor:button.centerYAnchor]
    ]];
    button.accessibilityLabel = name;
    button.accessibilityValue = [NSString stringWithFormat:@"%lu notifications", (unsigned long)count];
    button.accessibilityHint = isAll ? @"Shows all notifications" : @"Filters notifications to this app";
    button.accessibilityTraits = UIAccessibilityTraitButton | (selected ? UIAccessibilityTraitSelected : 0);
    __weak typeof(self) weakSelf = self;
    NSString *bundle = item.bundleID;
    [button addAction:[UIAction actionWithHandler:^(__kindof UIAction *action) {
        (void)action;
        if ([AXNReadPreference(@"Haptics", @YES) boolValue]) {
            UISelectionFeedbackGenerator *feedback = [UISelectionFeedbackGenerator new];
            [feedback selectionChanged];
        }
        if (weakSelf.onSelect) weakSelf.onSelect(bundle);
    }] forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)updateWithItems:(NSArray<AXNRailItem *> *)items selected:(NSString *)selected {
    self.items = items; self.selected = selected;
    NSUInteger total = 0;
    for (AXNRailItem *item in items) total += item.count;
    self.summary.text = [NSString stringWithFormat:@"%lu total", (unsigned long)total];
    self.hidden = total == 0;
    CGFloat textSize = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline].pointSize;
    self.railHeight.constant = MAX(106, textSize * 2 + 68);
    CGPoint offset = self.scroll.contentOffset;
    for (UIView *view in self.stack.arrangedSubviews.copy) { [self.stack removeArrangedSubview:view]; [view removeFromSuperview]; }
    [self.stack addArrangedSubview:[self buttonForItem:nil total:total]];
    for (AXNRailItem *item in items) [self.stack addArrangedSubview:[self buttonForItem:item total:total]];
    [self layoutIfNeeded];
    CGFloat maxX = MAX(0, self.scroll.contentSize.width - self.scroll.bounds.size.width);
    self.scroll.contentOffset = CGPointMake(MIN(MAX(0, offset.x), maxX), 0);
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (self.items) [self updateWithItems:self.items selected:self.selected];
}
@end
