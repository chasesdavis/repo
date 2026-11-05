#import "HBProfileEditorController.h"
#import "HBProfileStore.h"
#import "HBDashboardController.h"
#import "HBTheme.h"
#import "HBFocusMonitor.h"

@interface HBFocusDiagnosticsController : UIViewController
@property (nonatomic, copy) NSString *report;
@end
@implementation HBFocusDiagnosticsController
- (void)viewDidLoad {
    [super viewDidLoad]; self.title = @"Focus diagnostics"; self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Copy" style:UIBarButtonItemStylePlain target:self action:@selector(copyReport)];
    UIScrollView *scroll = [UIScrollView new]; scroll.alwaysBounceVertical = YES; scroll.accessibilityIdentifier = @"harbor.focus.diagnostics";
    scroll.translatesAutoresizingMaskIntoConstraints = NO; [self.view addSubview:scroll];
    UILabel *text = [UILabel new]; text.numberOfLines = 0; text.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    text.adjustsFontForContentSizeCategory = YES; text.text = self.report; text.translatesAutoresizingMaskIntoConstraints = NO; [scroll addSubview:text];
    [NSLayoutConstraint activateConstraints:@[[scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor], [scroll.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor], [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor], [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [text.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:16], [text.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-24], [text.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:16], [text.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-16], [text.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-32]]];
}
- (void)copyReport { UIPasteboard.generalPasteboard.string = self.report; self.navigationItem.rightBarButtonItem.title = @"Copied"; }
@end

// Preserve the final finger position even when a very fast drag is coalesced
// into a release. UISlider still owns hit testing, accessibility and tracking.
@interface HBEditorSlider : UISlider @end
@implementation HBEditorSlider
- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    [super endTrackingWithTouch:touch withEvent:event];
    if (!touch) return;
    CGRect track = [self trackRectForBounds:self.bounds];
    CGFloat start = CGRectGetMidX([self thumbRectForBounds:self.bounds trackRect:track value:self.minimumValue]);
    CGFloat end = CGRectGetMidX([self thumbRectForBounds:self.bounds trackRect:track value:self.maximumValue]);
    if (fabs(end - start) < 1) return;
    CGFloat fraction = MAX(0, MIN(1, ([touch locationInView:self].x - start) / (end - start)));
    if (end > start && self.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft) fraction = 1 - fraction;
    self.value = self.minimumValue + (self.maximumValue - self.minimumValue) * fraction;
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}
@end

@interface HBProfileEditorController () <UIColorPickerViewControllerDelegate, UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *previewHeader;
@property (nonatomic, copy) NSDictionary *library;
@property (nonatomic, copy) NSDictionary *profile;
@property (nonatomic, copy) NSDictionary *originalLibrary;
@property (nonatomic, copy) NSDictionary *focus;
@property (nonatomic, strong) HBDashboardController *preview;
@property (nonatomic, strong) UIView *previewHost;
@property (nonatomic, strong) UISegmentedControl *page;
@property (nonatomic, strong) UISegmentedControl *layout;
@property (nonatomic, copy) NSString *colorKey;
@property (nonatomic) BOOL previewQueued;
@property (nonatomic, copy) NSDictionary *pendingFocus;
@property (nonatomic) BOOL focusRefreshQueued;
@end

@implementation HBProfileEditorController
- (instancetype)initWithLibrary:(NSDictionary *)library profileID:(NSString *)identifier focus:(NSDictionary *)focus {
    if ((self = [super init])) {
        _library = library; _originalLibrary = library; _profile = HBProfileWithID(library, identifier); _focus = focus ?: @{};
    } return self;
}
- (void)viewDidLoad {
    [super viewDidLoad]; self.title = self.profile[@"name"]; self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark; self.navigationController.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(save)];
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped]; self.tableView.delegate = self; self.tableView.dataSource = self; [self.view addSubview:self.tableView];
    self.tableView.accessibilityIdentifier = @"harbor.editor.table"; self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.tableView.allowsSelectionDuringEditing = YES;
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 272)];
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(20, 4, header.bounds.size.width - 40, 24)]; label.text = @"LIVE PREVIEW · controls disabled"; label.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold]; label.textColor = UIColor.secondaryLabelColor; label.textAlignment = NSTextAlignmentCenter; label.autoresizingMask = UIViewAutoresizingFlexibleWidth; [header addSubview:label];
    self.previewHost = [[UIView alloc] initWithFrame:CGRectMake(20, 28, header.bounds.size.width - 40, 156)]; self.previewHost.autoresizingMask = UIViewAutoresizingFlexibleWidth; self.previewHost.clipsToBounds = YES; self.previewHost.accessibilityElementsHidden = YES; self.previewHost.userInteractionEnabled = NO; [header addSubview:self.previewHost];
    self.preview = [HBDashboardController new]; self.preview.previewMode = YES; self.preview.nativeControls = self.nativeControls;
    [self addChildViewController:self.preview]; [self.previewHost addSubview:self.preview.view]; [self.preview didMoveToParentViewController:self];
    self.layout = [[UISegmentedControl alloc] initWithItems:@[@"Compact", @"Expanded"]]; self.layout.selectedSegmentIndex = 0; self.layout.accessibilityIdentifier = @"harbor.editor.layout";
    self.layout.frame = CGRectMake(20, 190, header.bounds.size.width - 40, 32); self.layout.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.layout addTarget:self action:@selector(layoutChanged) forControlEvents:UIControlEventValueChanged]; [header addSubview:self.layout];
    self.page = [[UISegmentedControl alloc] initWithItems:@[@"Layout", @"Theme", @"Focus"]]; self.page.selectedSegmentIndex = 0; self.page.accessibilityIdentifier = @"harbor.editor.page";
    self.page.frame = CGRectMake(20, 232, header.bounds.size.width - 40, 32); self.page.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.page addTarget:self action:@selector(pageChanged) forControlEvents:UIControlEventValueChanged]; [header addSubview:self.page]; self.previewHeader = header; [self.view addSubview:header];
    [self pageChanged]; [self updatePreview];
}
- (NSString *)layoutKey { return self.layout.selectedSegmentIndex == 1 ? @"expanded" : @"compact"; }
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews]; UIEdgeInsets safe = self.view.safeAreaInsets;
    CGFloat top = safe.top, width = self.view.bounds.size.width, available = self.view.bounds.size.height - top - safe.bottom;
    CGFloat previewHeight = MIN(208, MAX(100, available * 0.29)), height = previewHeight + 116;
    self.previewHeader.frame = CGRectMake(0, top, width, height);
    self.previewHost.frame = CGRectMake(20, 28, width - 40, previewHeight);
    self.layout.frame = CGRectMake(20, previewHeight + 36, width - 40, 32); self.page.frame = CGRectMake(20, previewHeight + 78, width - 40, 32);
    self.tableView.frame = CGRectMake(0, top + height, width, MAX(100, available - height + safe.bottom));
    [self layoutPreview];
}
- (void)layoutPreview {
    // Render the same controller at phone width, then scale the whole canvas. It
    // never becomes a second active controller and cannot change device state.
    CGFloat width = MAX(300, MIN(420, self.view.bounds.size.width));
    self.preview.view.transform = CGAffineTransformIdentity; self.preview.view.bounds = CGRectMake(0, 0, width, 720);
    [self.preview.view setNeedsLayout]; [self.preview.view layoutIfNeeded];
    CGRect sheet = [self.preview previewSheetFrame];
    CGFloat scale = MIN(self.previewHost.bounds.size.width / width, self.previewHost.bounds.size.height / MAX(1, sheet.size.height));
    self.preview.view.transform = CGAffineTransformMakeScale(scale, scale);
    self.preview.view.center = CGPointMake(self.previewHost.bounds.size.width / 2, self.previewHost.bounds.size.height / 2 + (360 - CGRectGetMidY(sheet)) * scale);
}
- (void)updatePreview { [self.preview applyProfile:self.profile expanded:self.layout.selectedSegmentIndex == 1]; [self layoutPreview]; }
- (void)queuePreview {
    if (self.previewQueued) return; self.previewQueued = YES;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 30), dispatch_get_main_queue(), ^{ weakSelf.previewQueued = NO; [weakSelf updatePreview]; });
}
- (void)replaceProfile:(NSDictionary *)profile { self.profile = HBNormalizeProfile(profile); self.library = HBLibraryReplacingProfile(self.library, self.profile); [self queuePreview]; }
- (void)layoutChanged { [self.tableView reloadData]; [self updatePreview]; }
- (void)pageChanged { [self.tableView setEditing:self.page.selectedSegmentIndex == 0 animated:NO]; [self.tableView reloadData]; self.tableView.contentOffset = CGPointMake(0, -self.tableView.adjustedContentInset.top); }
- (void)updateFocusSnapshot:(NSDictionary *)snapshot {
    if ([snapshot[@"disabled"] boolValue]) self.pendingFocus = nil;
    if (![snapshot[@"disabled"] boolValue] && (self.tableView.tracking || self.tableView.dragging || self.tableView.decelerating)) {
        self.pendingFocus = snapshot;
        if (!self.focusRefreshQueued) {
            self.focusRefreshQueued = YES; __weak typeof(self) weakSelf = self;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 4), dispatch_get_main_queue(), ^{
                weakSelf.focusRefreshQueued = NO; NSDictionary *pending = weakSelf.pendingFocus; weakSelf.pendingFocus = nil;
                if (pending) [weakSelf updateFocusSnapshot:pending];
            });
        } return;
    }
    self.focus = snapshot; if (self.isViewLoaded && self.page.selectedSegmentIndex == 2) [self.tableView reloadData];
}
- (BOOL)canRefreshFocus {
    return HBFocusAccessEnabled(self.library) && HBFocusAccessEnabled(self.originalLibrary) && ![self.focus[@"disabled"] boolValue];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return self.page.selectedSegmentIndex == 0 ? 3 : (self.page.selectedSegmentIndex == 1 ? 2 : 3); }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.page.selectedSegmentIndex == 0) return section == 0 ? 3 : (section == 1 ? 5 : 1);
    if (self.page.selectedSegmentIndex == 1) return section == 0 ? 4 : 7;
    return section == 0 ? 3 : (section == 1 ? ([self canRefreshFocus] ? [self.focus[@"modes"] count] : 0) : [self.library[@"bindings"] count]);
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (self.page.selectedSegmentIndex == 0) return @[@"Profile", [self.layoutKey isEqual:@"compact"] ? @"Compact arrangement" : @"Expanded arrangement", @"Recovery"][section];
    if (self.page.selectedSegmentIndex == 1) return section == 0 ? @"Presets" : @"Make it yours";
    return @[@"Automatic layouts", @"Focus modes from iOS", @"Saved links"][section];
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (self.page.selectedSegmentIndex == 0 && section == 1) return @"Drag a handle to reorder. Tap a row to show or hide it. Compact and expanded arrangements are saved separately. At least one section stays visible.";
    if (self.page.selectedSegmentIndex == 0 && section == 2) return @"All controls and the editor always remain available. Reset only changes this draft. Save applies your changes and makes this your default profile.";
    if (self.page.selectedSegmentIndex == 1 && section == 1) return @"Tap Material or Control shape to cycle. Light colors, Solid, and Reduce Transparency use an opaque surface. Changes stay in the preview until you save.";
    if (self.page.selectedSegmentIndex == 2 && section == 0) {
        if (!HBFocusAccessEnabled(self.library)) return @"Off by default. Turning this on and saving permits Harbor to read Focus and observe changes to choose its own layout. Turning it off pauses reading immediately; Save keeps it off and Cancel restores your saved choice. Native Focus controls are separate.";
        if (!HBFocusAccessEnabled(self.originalLibrary)) return @"Save to enable Focus reads. No reading starts from this draft. Reopen this page after saving to link modes returned by iOS. Harbor changes its own layout, not your Focus settings.";
        if ([self.focus[@"paused"] boolValue]) return @"Reading stays paused while this draft is open. Save or Cancel restores the choice you keep.";
        return self.focus[@"status"] ?: @"Focus unavailable. Your default profile stays selected.";
    }
    if (self.page.selectedSegmentIndex == 2 && section == 1) return [self.focus[@"modes"] count] ? @"Tap a mode to link it to this profile. Harbor reads Focus; it never turns Focus on or off. Layout changes wait until your interaction ends." : @"No modes are available to link. Saved links stay intact. When iOS permits reading the current mode, it appears here even if the full mode list is unavailable.";
    if (self.page.selectedSegmentIndex == 2 && section == 2) return @"Tap a saved link to remove it. Focus off, an unlinked Focus, or an unavailable service uses your default profile.";
    return nil;
}
- (UITableViewCell *)cell:(NSString *)title detail:(NSString *)detail {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil]; cell.textLabel.text = title; cell.detailTextLabel.text = detail;
    cell.textLabel.numberOfLines = 0; cell.detailTextLabel.numberOfLines = 0; cell.textLabel.adjustsFontForContentSizeCategory = YES; cell.detailTextLabel.adjustsFontForContentSizeCategory = YES; cell.isAccessibilityElement = YES; cell.accessibilityLabel = title; cell.accessibilityValue = detail; cell.accessibilityTraits = UIAccessibilityTraitButton; return cell;
}
- (NSArray *)bindingKeys { return [self.library[@"bindings"] allKeys] ? [[self.library[@"bindings"] allKeys] sortedArrayUsingSelector:@selector(compare:)] : @[]; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    NSInteger section = path.section, row = path.row;
    if (self.page.selectedSegmentIndex == 0) {
        if (section == 0) {
            if (row == 0) { UITableViewCell *c = [self cell:@"Name" detail:self.profile[@"name"]]; c.accessoryType = UITableViewCellAccessoryDisclosureIndicator; return c; }
            if (row == 1) return [self cell:@"Save as new profile…" detail:@"Keep the original and edit a separate copy."];
            UITableViewCell *c = [self cell:@"Open expanded" detail:nil]; UISwitch *s = [UISwitch new]; s.on = [self.profile[@"startExpanded"] boolValue]; [s addTarget:self action:@selector(startExpandedChanged:) forControlEvents:UIControlEventValueChanged]; s.accessibilityLabel = @"Open expanded"; c.accessoryView = s; c.editingAccessoryView = s; c.isAccessibilityElement = NO; c.accessibilityElements = @[s]; return c;
        }
        if (section == 2) return [self cell:@"Reset this profile" detail:@"Restore the original layout and Sea Glass theme."];
        NSString *key = self.profile[@"layouts"][self.layoutKey][@"order"][row]; BOOL hidden = [self.profile[@"layouts"][self.layoutKey][@"hidden"] containsObject:key];
        UITableViewCell *c = [self cell:HBSectionName(key) detail:hidden ? @"Hidden · tap to show" : @"Visible · tap to hide"]; c.showsReorderControl = YES; c.accessibilityIdentifier = [@"harbor.editor.section." stringByAppendingString:key];
        __weak typeof(self) weakSelf = self;
        c.accessibilityCustomActions = @[[[UIAccessibilityCustomAction alloc] initWithName:@"Move up" actionHandler:^BOOL(UIAccessibilityCustomAction *a) { return [weakSelf moveSection:key offset:-1]; }], [[UIAccessibilityCustomAction alloc] initWithName:@"Move down" actionHandler:^BOOL(UIAccessibilityCustomAction *a) { return [weakSelf moveSection:key offset:1]; }]];
        return c;
    }
    if (self.page.selectedSegmentIndex == 1) {
        if (section == 0) { NSString *key = @[@"sea", @"graphite", @"iris", @"ember"][row]; NSDictionary *preset = HBThemePresets()[key]; UITableViewCell *c = [self cell:preset[@"name"] detail:nil];
            if ([self.profile[@"theme"] isEqual:HBNormalizeProfile(@{@"theme":preset})[@"theme"]]) c.accessoryType = UITableViewCellAccessoryCheckmark;
            c.imageView.image = [UIImage systemImageNamed:@"circle.fill"]; c.imageView.tintColor = HBColorFromHex(preset[@"accent"]); return c; }
        NSDictionary *theme = self.profile[@"theme"];
        if (row < 2) { NSString *key = row == 0 ? @"accent" : @"surface"; UITableViewCell *c = [self cell:row == 0 ? @"Accent color" : @"Surface color" detail:theme[key]]; c.imageView.image = [UIImage systemImageNamed:@"circle.fill"]; c.imageView.tintColor = HBColorFromHex(theme[key]); c.accessoryType = UITableViewCellAccessoryDisclosureIndicator; return c; }
        if (row < 4) return [self cell:row == 2 ? @"Material" : @"Control shape" detail:row == 2 ? [theme[@"material"] capitalizedString] : ([theme[@"shape"] isEqual:@"rounded"] ? @"Soft squares" : @"Circles")];
        NSString *key = @[@"opacity", @"radius", @"spacing"][row - 4]; NSString *name = @[@"Surface opacity", @"Corner radius", @"Section spacing"][row - 4];
        UITableViewCell *c = [self cell:name detail:[NSString stringWithFormat:row == 4 ? @"%.0f%%" : @"%.0f pt", [theme[key] doubleValue] * (row == 4 ? 100 : 1)]];
        UISlider *s = [[HBEditorSlider alloc] initWithFrame:CGRectMake(0, 0, 132, 44)]; s.minimumValue = row == 4 ? 0.55 : (row == 5 ? 16 : 6); s.maximumValue = row == 4 ? 1 : (row == 5 ? 42 : 18); s.value = [theme[key] floatValue];
        if (row == 4 && (UIAccessibilityIsReduceTransparencyEnabled() || [theme[@"material"] isEqual:@"solid"] || [HBContrastingInk(HBColorFromHex(theme[@"surface"])) isEqual:UIColor.blackColor])) { s.enabled = NO; c.detailTextLabel.text = @"Opaque surface"; }
        s.accessibilityLabel = name; s.accessibilityIdentifier = key;
        [s addTarget:self action:@selector(themeSlider:) forControlEvents:UIControlEventValueChanged]; [s addTarget:self action:@selector(sliderEnded:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel]; c.accessoryView = s; c.isAccessibilityElement = NO; c.accessibilityElements = @[s]; return c;
    }
    if (section == 0) {
        if (row == 1) { UITableViewCell *c = [self cell:@"Focus diagnostics" detail:@"Read status, live updates and mode discovery"]; c.accessoryType = UITableViewCellAccessoryDisclosureIndicator; return c; }
        if (row == 2) {
            BOOL enabled = [self canRefreshFocus]; UITableViewCell *c = [self cell:@"Refresh Focus" detail:enabled ? @"Check again without changing your saved profiles." : @"Reading is off. Enable matching and save to allow it."];
            c.userInteractionEnabled = enabled; if (!enabled) { c.textLabel.textColor = UIColor.secondaryLabelColor; c.accessibilityTraits |= UIAccessibilityTraitNotEnabled; } return c;
        }
        UITableViewCell *c = [self cell:@"Match Focus automatically" detail:nil]; UISwitch *s = [UISwitch new]; s.on = HBFocusAccessEnabled(self.library); s.accessibilityLabel = @"Match Focus automatically"; s.accessibilityHint = @"Off by default. Save to allow read-only Focus matching. Turning off pauses reading immediately."; [s addTarget:self action:@selector(automaticChanged:) forControlEvents:UIControlEventValueChanged]; c.accessoryView = s; c.isAccessibilityElement = NO; c.accessibilityElements = @[s]; return c;
    }
    if (section == 1) { NSDictionary *mode = self.focus[@"modes"][row]; NSString *linked = self.library[@"bindings"][mode[@"id"]]; UITableViewCell *c = [self cell:mode[@"name"] detail:linked ? [NSString stringWithFormat:@"Linked to %@", HBProfileWithID(self.library, linked)[@"name"]] : @"Use this profile"]; if ([linked isEqual:self.profile[@"id"]]) c.accessoryType = UITableViewCellAccessoryCheckmark; return c; }
    NSString *key = self.bindingKeys[row]; return [self cell:self.library[@"focusLabels"][key] detail:[NSString stringWithFormat:@"%@ · tap to unlink", HBProfileWithID(self.library, self.library[@"bindings"][key])[@"name"]]];
}
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath { return self.page.selectedSegmentIndex == 0 && indexPath.section == 1; }
- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)path { return UITableViewCellEditingStyleNone; }
- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)path { return NO; }
- (NSIndexPath *)tableView:(UITableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)source toProposedIndexPath:(NSIndexPath *)destination { return [NSIndexPath indexPathForRow:destination.section < 1 ? 0 : (destination.section > 1 ? 4 : destination.row) inSection:1]; }
- (void)changeLayout:(NSDictionary *)layout {
    NSMutableDictionary *p = self.profile.mutableCopy, *layouts = [p[@"layouts"] mutableCopy]; layouts[self.layoutKey] = layout; p[@"layouts"] = layouts; [self replaceProfile:p];
}
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)source toIndexPath:(NSIndexPath *)destination {
    NSMutableDictionary *layout = [self.profile[@"layouts"][self.layoutKey] mutableCopy]; NSMutableArray *order = [layout[@"order"] mutableCopy]; id key = order[source.row]; [order removeObjectAtIndex:source.row]; [order insertObject:key atIndex:destination.row]; layout[@"order"] = order; [self changeLayout:layout];
}
- (BOOL)moveSection:(NSString *)key offset:(NSInteger)offset {
    NSArray *order = self.profile[@"layouts"][self.layoutKey][@"order"]; NSInteger from = [order indexOfObject:key], to = from + offset; if (to < 0 || to >= (NSInteger)order.count) return NO;
    [self tableView:self.tableView moveRowAtIndexPath:[NSIndexPath indexPathForRow:from inSection:1] toIndexPath:[NSIndexPath indexPathForRow:to inSection:1]]; [self.tableView reloadData]; return YES;
}
- (void)startExpandedChanged:(UISwitch *)sender { NSMutableDictionary *p = self.profile.mutableCopy; p[@"startExpanded"] = @(sender.on); [self replaceProfile:p]; }
- (void)automaticChanged:(UISwitch *)sender {
    NSMutableDictionary *l = self.library.mutableCopy; l[@"automaticFocus"] = @(sender.on); l[@"focusOptInVersion"] = sender.on ? @1 : @0; self.library = l;
    if (!sender.on && self.onPauseFocus) self.onPauseFocus(); [self.tableView reloadData];
}
- (void)setThemeValue:(id)value key:(NSString *)key { NSMutableDictionary *p = self.profile.mutableCopy, *theme = [p[@"theme"] mutableCopy]; theme[key] = value; p[@"theme"] = theme; [self replaceProfile:p]; }
- (void)themeSlider:(UISlider *)sender { [self setThemeValue:@(sender.value) key:sender.accessibilityIdentifier]; UITableViewCell *cell = (id)sender.superview; while (cell && ![cell isKindOfClass:UITableViewCell.class]) cell = (id)cell.superview; cell.accessibilityValue = cell.detailTextLabel.text = [NSString stringWithFormat:[sender.accessibilityIdentifier isEqual:@"opacity"] ? @"%.0f%%" : @"%.0f pt", sender.value * ([sender.accessibilityIdentifier isEqual:@"opacity"] ? 100 : 1)]; }
- (void)sliderEnded:(UISlider *)sender { [self updatePreview]; }
- (void)renameAsCopy:(BOOL)copy {
    if (copy && [self.library[@"profiles"] count] >= 12) { [self showError:@"You can save up to 12 profiles. Remove a profile from the Harbor menu first."]; return; }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:copy ? @"New profile" : @"Profile name" message:@"Use up to 32 characters." preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.text = copy ? @"New profile" : self.profile[@"name"]; field.accessibilityLabel = @"Profile name"; field.clearButtonMode = UITextFieldViewModeWhileEditing; }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:copy ? @"Create" : @"Rename" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) {
        NSString *name = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (!name.length || name.length > 32) { [self showError:@"Please use a name between 1 and 32 characters."]; return; }
        for (NSDictionary *existing in self.library[@"profiles"]) {
            if ((copy || ![existing[@"id"] isEqual:self.profile[@"id"]]) && [existing[@"name"] caseInsensitiveCompare:name] == NSOrderedSame) { [self showError:@"A profile already uses that name. Choose a different name."]; return; }
        }
        NSMutableDictionary *p = self.profile.mutableCopy; p[@"name"] = name; if (copy) {
            for (NSDictionary *original in self.originalLibrary[@"profiles"]) if ([original[@"id"] isEqual:p[@"id"]]) { self.library = HBLibraryReplacingProfile(self.library, original); break; }
            p[@"id"] = NSUUID.UUID.UUIDString;
        }
        [self replaceProfile:p]; self.title = name; [self.tableView reloadData];
    }]]; [self presentViewController:alert animated:YES completion:nil];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES]; NSInteger row = path.row, section = path.section;
    if (self.page.selectedSegmentIndex == 0) {
        if (section == 0) { if (row < 2) [self renameAsCopy:row == 1]; return; }
        if (section == 2) { UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Reset this draft?" message:@"Other profiles and Focus links stay saved." preferredStyle:UIAlertControllerStyleAlert]; [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]]; [a addAction:[UIAlertAction actionWithTitle:@"Reset" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) { [self replaceProfile:@{@"id":self.profile[@"id"], @"name":self.profile[@"name"]}]; [self.tableView reloadData]; }]]; [self presentViewController:a animated:YES completion:nil]; return; }
        NSMutableDictionary *layout = [self.profile[@"layouts"][self.layoutKey] mutableCopy]; NSString *key = layout[@"order"][row]; NSMutableArray *hidden = [layout[@"hidden"] mutableCopy];
        if ([hidden containsObject:key]) [hidden removeObject:key]; else if (hidden.count < 4) [hidden addObject:key]; else { [self showError:@"Keep at least one section visible in this layout."]; return; }
        layout[@"hidden"] = hidden; [self changeLayout:layout]; [tableView reloadRowsAtIndexPaths:@[path] withRowAnimation:UITableViewRowAnimationNone]; return;
    }
    if (self.page.selectedSegmentIndex == 1) {
        if (section == 0) { NSMutableDictionary *p = self.profile.mutableCopy; p[@"theme"] = HBThemePresets()[@[@"sea", @"graphite", @"iris", @"ember"][row]]; [self replaceProfile:p]; [tableView reloadData]; return; }
        if (row < 2) { self.colorKey = row == 0 ? @"accent" : @"surface"; UIColorPickerViewController *picker = [UIColorPickerViewController new]; picker.supportsAlpha = NO; picker.selectedColor = HBColorFromHex(self.profile[@"theme"][self.colorKey]); picker.delegate = self; [self presentViewController:picker animated:YES completion:nil]; }
        else if (row < 4) { NSString *key = row == 2 ? @"material" : @"shape"; NSArray *choices = row == 2 ? @[@"glass", @"soft", @"solid"] : @[@"circle", @"rounded"]; NSUInteger next = ([choices indexOfObject:self.profile[@"theme"][key]] + 1) % choices.count; [self setThemeValue:choices[next] key:key]; [tableView reloadData]; } return;
    }
    if (section == 0) {
        if (row == 1) [self showFocusDiagnostics];
        if (row == 2 && [self canRefreshFocus] && self.onRefreshFocus) self.onRefreshFocus();
        return;
    }
    NSMutableDictionary *l = self.library.mutableCopy, *bindings = [l[@"bindings"] mutableCopy], *labels = [l[@"focusLabels"] mutableCopy];
    if (section == 1) { NSDictionary *mode = self.focus[@"modes"][row]; bindings[mode[@"id"]] = self.profile[@"id"]; labels[mode[@"id"]] = mode[@"name"]; }
    if (section == 2) { NSString *key = self.bindingKeys[row]; [bindings removeObjectForKey:key]; [labels removeObjectForKey:key]; }
    l[@"bindings"] = bindings; l[@"focusLabels"] = labels; self.library = l; [tableView reloadData];
}
- (void)colorPickerViewControllerDidSelectColor:(UIColorPickerViewController *)picker { [self setThemeValue:HBHexFromColor(picker.selectedColor) key:self.colorKey]; [self.tableView reloadData]; }
- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)picker { [self.tableView reloadData]; [self updatePreview]; }
- (void)showError:(NSString *)message { UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Harbor" message:message preferredStyle:UIAlertControllerStyleAlert]; [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]]; [self presentViewController:alert animated:YES completion:nil]; }
- (void)showFocusDiagnostics {
    HBFocusDiagnosticsController *page = [HBFocusDiagnosticsController new]; page.report = HBFocusDiagnosticSummary(self.focus);
    [self.navigationController pushViewController:page animated:YES];
}
- (void)save {
    NSMutableDictionary *library = HBLibraryReplacingProfile(self.library, self.profile).mutableCopy;
    // Saving a profile makes it the deliberate fallback for off/unmatched Focus.
    library[@"activeID"] = self.profile[@"id"]; NSError *error = nil;
    if (!HBSaveProfileLibrary(library, self.originalLibrary[@"revision"], &error)) { [self showError:error.localizedDescription]; return; }
    [self dismissViewControllerAnimated:YES completion:^{ if (self.onFinish) self.onFinish(YES); }];
}
- (void)cancel { [self dismissViewControllerAnimated:YES completion:^{ if (self.onFinish) self.onFinish(NO); }]; }
@end
