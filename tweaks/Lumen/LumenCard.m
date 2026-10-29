#import "LumenCard.h"
#import "LumenPrefs.h"
#import "LumenProviders.h"
#import <MessageUI/MessageUI.h>

static LumenCard *gLumenVisibleCard = nil;

@interface LumenCard () <MFMessageComposeViewControllerDelegate>
@property (nonatomic, strong) UIView *overlay;
@property (nonatomic, copy) NSString *pill;
@end

@implementation LumenCard

+ (void)presentForPill:(NSString *)pill inView:(UIView *)container {
    [gLumenVisibleCard dismissNow];
    LumenCard *card = [LumenCard new];
    card.pill = pill;
    gLumenVisibleCard = card;
    [card buildInView:container];
}

+ (void)dismissVisible {
    [gLumenVisibleCard dismissNow];
}

- (void)dealloc {
    if (gLumenVisibleCard == self) {
        gLumenVisibleCard = nil;
    }
}

- (void)buildInView:(UIView *)container {
    self.overlay = [[UIView alloc] initWithFrame:container.bounds];
    self.overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.overlay.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.24];
    [self.overlay addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismiss)]];

    UIView *panel = [UIView new];
    panel.backgroundColor = [UIColor.secondarySystemBackgroundColor colorWithAlphaComponent:0.98];
    panel.layer.cornerRadius = 20.0;
    panel.layer.cornerCurve = kCACornerCurveContinuous;
    panel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.overlay addSubview:panel];

    UILabel *title = [UILabel new];
    title.text = [self titleForPill];
    title.font = [UIFont systemFontOfSize:19.0 weight:UIFontWeightBold];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [panel addSubview:title];

    UILabel *body = [UILabel new];
    body.text = [self bodyForPill];
    body.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightRegular];
    body.textColor = UIColor.secondaryLabelColor;
    body.numberOfLines = 0;
    body.translatesAutoresizingMaskIntoConstraints = NO;
    [panel addSubview:body];

    UIStackView *actions = [UIStackView new];
    actions.axis = UILayoutConstraintAxisVertical;
    actions.spacing = 10.0;
    actions.translatesAutoresizingMaskIntoConstraints = NO;
    for (NSString *action in [self actionsForPill]) {
        [actions addArrangedSubview:[self buttonWithTitle:action]];
    }
    [panel addSubview:actions];

    // Overlay must be in the container hierarchy BEFORE constraints activate,
    // otherwise the layout engine has no common ancestor and throws an
    // exception that aborts SpringBoard (safe mode).
    [container addSubview:self.overlay];

    @try {
        [NSLayoutConstraint activateConstraints:@[
            [panel.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
            [panel.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
            [panel.widthAnchor constraintEqualToConstant:300.0],
            [panel.leadingAnchor constraintGreaterThanOrEqualToAnchor:container.leadingAnchor constant:16.0],
            [title.topAnchor constraintEqualToAnchor:panel.topAnchor constant:20.0],
            [title.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18.0],
            [title.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-18.0],
            [body.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:10.0],
            [body.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
            [body.trailingAnchor constraintEqualToAnchor:title.trailingAnchor],
            [actions.topAnchor constraintEqualToAnchor:body.bottomAnchor constant:18.0],
            [actions.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
            [actions.trailingAnchor constraintEqualToAnchor:title.trailingAnchor],
            [actions.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-20.0],
        ]];
    } @catch (NSException *e) {
        panel.frame = CGRectMake((container.bounds.size.width - 300.0) / 2.0,
                                 (container.bounds.size.height - 240.0) / 2.0, 300.0, 240.0);
    }

    self.overlay.alpha = 0.0;
    [UIView animateWithDuration:0.18 animations:^{
        self.overlay.alpha = 1.0;
    }];
}

- (NSString *)titleForPill {
    return @{
        @"time": @"Time",
        @"date": @"Date",
        @"battery": @"Battery",
        @"playing": @"Now playing",
        @"network": @"Network",
        @"storage": @"Storage",
        @"countdown": @"Countdown",
        @"message": @"Quick message",
        @"event": @"Next event",
        @"alarm": @"Alarm & timer",
        @"weather": @"Weather",
        @"unlocks": @"Unlocks",
    }[self.pill] ?: @"Lumen";
}

- (NSString *)bodyForPill {
    if ([self.pill isEqualToString:@"battery"]) {
        return [LumenBatteryDetails() componentsJoinedByString:@"\n"];
    }
    if ([self.pill isEqualToString:@"event"]) {
        return [LumenNextEventDetails() componentsJoinedByString:@"\n"];
    }
    if ([self.pill isEqualToString:@"alarm"]) {
        return [LumenAlarmDetails() componentsJoinedByString:@"\n"];
    }
    if ([self.pill isEqualToString:@"weather"]) {
        return [LumenWeatherDetails() componentsJoinedByString:@"\n"];
    }
    if ([self.pill isEqualToString:@"unlocks"]) {
        return LumenUnlocksSummary();
    }
    if ([self.pill isEqualToString:@"storage"]) {
        return [NSString stringWithFormat:@"%@ free\n%@ active memory", LumenStorageSummary(), LumenMemorySummary()];
    }
    if ([self.pill isEqualToString:@"countdown"]) {
        NSDate *target = LumenCountdownDate();
        if (!target) {
            return @"No countdown set. Choose a date in Settings.";
        }
        NSDateFormatter *formatter = [NSDateFormatter new];
        formatter.dateStyle = NSDateFormatterFullStyle;
        formatter.timeStyle = NSDateFormatterShortStyle;
        return [formatter stringFromDate:target];
    }
    if ([self.pill isEqualToString:@"playing"]) {
        NSString *now = LumenCachedNowPlaying();
        return now.length ? now : @"Nothing is playing right now.";
    }
    if ([self.pill isEqualToString:@"message"]) {
        return @"Write and send without leaving the app you are in.";
    }
    if ([self.pill isEqualToString:@"network"]) {
        return @"Read from system interface counters once per second.";
    }
    return @"Long press the pill to switch pills.";
}

- (NSArray<NSString *> *)actionsForPill {
    if ([self.pill isEqualToString:@"playing"]) {
        return @[ @"Play or pause", @"Next track", @"Previous track" ];
    }
    if ([self.pill isEqualToString:@"event"]) {
        return @[ @"Open Calendar", @"Close" ];
    }
    if ([self.pill isEqualToString:@"weather"]) {
        return @[ @"Refresh", @"Close" ];
    }
    if ([self.pill isEqualToString:@"event"]) {
        return @[ @"Open Calendar", @"Close" ];
    }
    if ([self.pill isEqualToString:@"weather"]) {
        return @[ @"Refresh", @"Close" ];
    }
    if ([self.pill isEqualToString:@"message"]) {
        return @[ @"New message" ];
    }
    return @[ @"Close" ];
}

- (UIButton *)buttonWithTitle:(NSString *)title {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.backgroundColor = [LumenAccentColor() colorWithAlphaComponent:0.14];
    button.layer.cornerRadius = 12.0;
    button.titleLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    [button setTitle:title forState:UIControlStateNormal];
    [button addTarget:self action:@selector(handleAction:) forControlEvents:UIControlEventTouchUpInside];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    return button;
}

- (void)handleAction:(UIButton *)sender {
    NSString *title = [sender titleForState:UIControlStateNormal];
    if ([title hasPrefix:@"Play"]) {
        LumenMediaPlayPause();
    } else if ([title hasPrefix:@"Next"]) {
        LumenMediaNext();
    } else if ([title hasPrefix:@"Previous"]) {
        LumenMediaPrevious();
    } else if ([title hasPrefix:@"Open Calendar"]) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"calshow://"] options:@{} completionHandler:nil];
    } else if ([title hasPrefix:@"Open Calendar"]) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"calshow://"] options:@{} completionHandler:nil];
    } else if ([title hasPrefix:@"New message"]) {
        [self composeMessage];
        return;
    }
    [self dismiss];
}

- (void)composeMessage {
    if (![MFMessageComposeViewController canSendText]) {
        [self dismiss];
        return;
    }
    MFMessageComposeViewController *controller = [MFMessageComposeViewController new];
    controller.messageComposeDelegate = self;
    UIViewController *presenter = [self topPresenter];
    [self dismiss];
    if (presenter) {
        [presenter presentViewController:controller animated:YES completion:nil];
    }
}

- (UIViewController *)topPresenter {
    UIWindow *key = nil;
    for (UIWindow *window in UIApplication.sharedApplication.windows) {
        if (window.isKeyWindow) {
            key = window;
            break;
        }
    }
    UIViewController *controller = key.rootViewController;
    while (controller.presentedViewController) {
        controller = controller.presentedViewController;
    }
    if ([controller isKindOfClass:UITabBarController.class]) {
        return ((UITabBarController *)controller).selectedViewController ?: controller;
    }
    if ([controller isKindOfClass:UINavigationController.class]) {
        return ((UINavigationController *)controller).topViewController ?: controller;
    }
    return controller;
}

- (void)messageComposeViewController:(MFMessageComposeViewController *)controller didFinishWithResult:(MessageComposeResult)result {
    [controller dismissViewControllerAnimated:YES completion:nil];
}

- (void)dismiss {
    [UIView animateWithDuration:0.15 animations:^{
        self.overlay.alpha = 0.0;
    } completion:^(BOOL finished) {
        [self.overlay removeFromSuperview];
        self.overlay = nil;
        if (gLumenVisibleCard == self) {
            gLumenVisibleCard = nil;
        }
    }];
}

- (void)dismissNow {
    [self.overlay removeFromSuperview];
    self.overlay = nil;
    if (gLumenVisibleCard == self) {
        gLumenVisibleCard = nil;
    }
}

@end
