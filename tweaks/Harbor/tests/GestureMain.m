// Touch-event regression fixture. This models documented CCUIScrollView delegate
// arbitration, not Apple's private implementation. No real radios or device actions.
#import <UIKit/UIKit.h>
#import "HBSession.h"
#import "HBDashboardController.h"
#import "HBPreferences.h"
#import <objc/message.h>

static UIView *Find(UIView *v, NSString *name) { if ([v.accessibilityIdentifier isEqual:name]) return v; for (UIView *c in v.subviews) { UIView *r=Find(c,name); if(r)return r; } return nil; }
static BOOL Owns(HBSession *s, UIGestureRecognizer *g, UIView *v) {
    SEL sel=NSSelectorFromString(v ? @"ownsTouchView:recognizer:" : @"ownsGestureStart:");
    if (![s respondsToSelector:sel]) return NO;
    return v ? ((BOOL(*)(id,SEL,id,id))objc_msgSend)(s,sel,v,g) : ((BOOL(*)(id,SEL,id))objc_msgSend)(s,sel,g);
}
@interface HBFixtureToggle : UIViewController
@property(nonatomic,strong) UIButton *buttonView;
@property(nonatomic) NSUInteger actions;
@end
@implementation HBFixtureToggle
- (void)loadView { self.buttonView=[UIButton buttonWithType:UIButtonTypeSystem]; self.view=self.buttonView; [self.buttonView setTitle:@"Fixture" forState:UIControlStateNormal]; [self.buttonView addTarget:self action:@selector(toggle) forControlEvents:UIControlEventTouchUpInside]; }
- (void)toggle { self.actions++; self.buttonView.selected=!self.buttonView.selected; }
@end
@interface HBFixtureWiFi : HBFixtureToggle @end
@implementation HBFixtureWiFi @end
@interface HBFixtureBluetooth : HBFixtureToggle @end
@implementation HBFixtureBluetooth @end
@interface HBFixtureAirplane : HBFixtureToggle @end
@implementation HBFixtureAirplane @end
@interface HBFixtureCellular : HBFixtureToggle @end
@implementation HBFixtureCellular @end
@interface HBFixtureModule : UIViewController
@property(nonatomic,copy) NSString *moduleIdentifier;
@property(nonatomic,strong) UIViewController *contentViewController;
@end
@implementation HBFixtureModule @end
@interface HBFixtureCollection : UIViewController
@property(nonatomic) NSUInteger expandedModuleCount;
@property(nonatomic,copy) NSString *lastExpanded;
@end
@implementation HBFixtureCollection
- (void)expandModuleWithIdentifier:(NSString *)identifier { self.lastExpanded=identifier; }
@end
@interface HBFixtureOuterScroll : UIScrollView
@property(nonatomic,weak) HBSession *session;
@end
@implementation HBFixtureOuterScroll
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)g { return !Owns(self.session,g,nil) && [super gestureRecognizerShouldBegin:g]; }
@end
@interface HBFixtureHost : UIViewController <UIGestureRecognizerDelegate, UIScrollViewDelegate>
@property(nonatomic,strong) HBFixtureCollection *moduleCollectionViewController;
@property(nonatomic,strong) UIView *overlayContainerView;
@property(nonatomic,strong) HBFixtureOuterScroll *overlayScrollView;
@property(nonatomic,strong) UIView *overlayBackgroundView;
@property(nonatomic,strong) UILabel *overlayHeaderView;
@property(nonatomic,strong) HBSession *session;
@property(nonatomic,strong) HBDashboardController *dashboard;
@property(nonatomic,strong) NSMutableArray *events;
@property(nonatomic) NSUInteger nativeStarts;
@property(nonatomic) NSUInteger harborStarts;
@property(nonatomic) double maxOffset;
@property(nonatomic,strong) NSTimer *metrics;
@property(nonatomic,strong) CADisplayLink *displayLink;
@property(nonatomic) CFTimeInterval previousFrame;
@property(nonatomic) double maxFrameGap;
@property(nonatomic) NSUInteger frames;
@end
@implementation HBFixtureHost
- (UIStatusBarStyle)preferredStatusBarStyle { return UIStatusBarStyleLightContent; }
- (void)viewDidLoad {
    [super viewDidLoad]; self.events=[NSMutableArray array];
    self.view.backgroundColor=[UIColor colorWithRed:0.18 green:0.28 blue:0.32 alpha:1];
    self.overlayBackgroundView=[[UIView alloc] initWithFrame:self.view.bounds]; self.overlayBackgroundView.userInteractionEnabled=NO; [self.view addSubview:self.overlayBackgroundView];
    self.overlayScrollView=[[HBFixtureOuterScroll alloc] initWithFrame:self.view.bounds]; self.overlayScrollView.contentInsetAdjustmentBehavior=UIScrollViewContentInsetAdjustmentNever;
    self.overlayScrollView.contentSize=CGSizeMake(self.view.bounds.size.width,self.view.bounds.size.height+160); self.overlayScrollView.alwaysBounceVertical=YES; self.overlayScrollView.delegate=self; [self.view addSubview:self.overlayScrollView];
    self.overlayContainerView=[[UIView alloc] initWithFrame:CGRectMake(0,142,self.view.bounds.size.width,self.view.bounds.size.height-284)]; self.overlayContainerView.clipsToBounds=YES; [self.overlayScrollView addSubview:self.overlayContainerView];
    self.moduleCollectionViewController=[HBFixtureCollection new]; [self addChildViewController:self.moduleCollectionViewController]; self.moduleCollectionViewController.view.frame=self.overlayContainerView.bounds; [self.overlayContainerView addSubview:self.moduleCollectionViewController.view]; [self.moduleCollectionViewController didMoveToParentViewController:self];
    NSArray *ids=@[@"com.apple.control-center.ConnectivityModule",@"com.apple.control-center.OrientationLockModule",@"com.apple.control-center.LowPowerModule",@"com.apple.FocusUIModule",@"com.apple.control-center.FlashlightModule",@"com.apple.control-center.TimerModule",@"com.apple.control-center.CalculatorModule",@"com.apple.control-center.CameraModule",@"com.apple.control-center.ScreenRecordingModule",@"com.apple.control-center.RemoteModule",@"com.apple.control-center.HearingModule",@"com.apple.control-center.DisplayModule"];
    for(NSUInteger i=0;i<ids.count;i++) { HBFixtureModule *m=[HBFixtureModule new]; m.moduleIdentifier=ids[i]; [self.moduleCollectionViewController addChildViewController:m]; [self.moduleCollectionViewController.view addSubview:m.view]; [m didMoveToParentViewController:self.moduleCollectionViewController];
        NSArray *classes=i==0?@[HBFixtureWiFi.class,HBFixtureBluetooth.class,HBFixtureAirplane.class,HBFixtureCellular.class]:@[HBFixtureToggle.class];
        for(Class c in classes) { HBFixtureToggle *t=[c new]; [m addChildViewController:t]; t.view.frame=CGRectMake(0,0,50,50); [m.view addSubview:t.view]; [t didMoveToParentViewController:m]; if(i>0)m.contentViewController=t; }
    }
    self.overlayHeaderView=[[UILabel alloc] initWithFrame:CGRectMake(20,75,self.view.bounds.size.width-40,36)]; self.overlayHeaderView.text=@"Native status · gesture fixture"; self.overlayHeaderView.textColor=UIColor.whiteColor; self.overlayHeaderView.textAlignment=NSTextAlignmentCenter; [self.view addSubview:self.overlayHeaderView];
    UIPanGestureRecognizer *native=[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(nativePan:)]; native.delegate=self; [self.view addGestureRecognizer:native];
    [self.overlayScrollView.panGestureRecognizer addTarget:self action:@selector(nativePan:)];
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated]; HBSetPreference(@"enabled",@YES); HBSetPreference(@"haptics",@NO); HBSetPreference(@"palette",@"sea");
    self.session=[HBSession sessionForHost:self create:YES]; self.overlayScrollView.session=self.session; [self.session begin];
    for(UIViewController *c in self.childViewControllers)if([c isKindOfClass:HBDashboardController.class])self.dashboard=(id)c;
    if([NSProcessInfo.processInfo.arguments containsObject:@"--large"]) { self.dashboard.traitOverrides.preferredContentSizeCategory=UIContentSizeCategoryAccessibilityExtraExtraExtraLarge; [self.dashboard applyAppearance]; }
    if([NSProcessInfo.processInfo.arguments containsObject:@"--expanded"] && [self.dashboard respondsToSelector:NSSelectorFromString(@"setExpanded:")]) [self.dashboard setValue:@YES forKey:@"expanded"];
    [self.view layoutIfNeeded]; [self.dashboard.view layoutIfNeeded];
    UIScrollView *cards=(id)Find(self.dashboard.view,@"harbor.scroll");
    // Native CC establishes its own failure relationships. Give the outer pan
    // priority here so an ungated nested scroll reliably reproduces starvation.
    [cards.panGestureRecognizer requireGestureRecognizerToFail:self.overlayScrollView.panGestureRecognizer];
    for(UIGestureRecognizer *g in self.view.gestureRecognizers) [cards.panGestureRecognizer requireGestureRecognizerToFail:g];
    [cards.panGestureRecognizer addTarget:self action:@selector(harborPan:)];
    __weak typeof(self) weakSelf=self; self.metrics=[NSTimer scheduledTimerWithTimeInterval:0.25 repeats:YES block:^(__unused NSTimer *timer){ [weakSelf saveMetrics]; }];
    self.displayLink=[CADisplayLink displayLinkWithTarget:self selector:@selector(frame:)]; [self.displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes]; [self saveMetrics];
}
- (void)frame:(CADisplayLink *)link { UIScrollView *cards=(id)Find(self.dashboard.view,@"harbor.scroll"); if(cards.dragging||cards.decelerating) { self.frames++; if(self.previousFrame>0)self.maxFrameGap=MAX(self.maxFrameGap,link.timestamp-self.previousFrame); self.previousFrame=link.timestamp; } else self.previousFrame=0; }
- (void)nativePan:(UIPanGestureRecognizer *)pan { if(pan.state==UIGestureRecognizerStateBegan){self.nativeStarts++; [self.events addObject:@"native pan began"];} }
- (void)harborPan:(UIPanGestureRecognizer *)pan { if(pan.state==UIGestureRecognizerStateBegan){self.harborStarts++;[self.events addObject:@"Harbor pan began"];} }
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)g shouldReceiveTouch:(UITouch *)touch { return !Owns(self.session,g,touch.view); }
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)g { return !Owns(self.session,g,nil); }
- (void)scrollViewDidScroll:(UIScrollView *)scrollView { if([self.session respondsToSelector:NSSelectorFromString(@"scrollPositionChanged")]) ((void(*)(id,SEL))objc_msgSend)(self.session,NSSelectorFromString(@"scrollPositionChanged")); else [self.session layout]; }
- (void)saveMetrics {
    UIScrollView *cards=(id)Find(self.dashboard.view,@"harbor.scroll"); self.maxOffset=MAX(self.maxOffset,cards.contentOffset.y);
    NSMutableDictionary *actions=[NSMutableDictionary dictionary];
    for(HBFixtureModule *m in self.moduleCollectionViewController.childViewControllers)for(HBFixtureToggle *t in m.childViewControllers)actions[[NSString stringWithFormat:@"%@/%@",m.moduleIdentifier,NSStringFromClass(t.class)]]=@(t.actions);
    UIView *last=Find(self.dashboard.view,@"harbor.display")?:Find(self.dashboard.view,@"harbor.focus"); CGRect lastRect=[last convertRect:last.bounds toView:cards];
    NSDictionary *report=@{@"scope":@"Synthetic CC gesture-priority fixture driven by HID touches, not SpringBoard",@"nativeStarts":@(self.nativeStarts),@"harborStarts":@(self.harborStarts),@"offset":@(cards.contentOffset.y),@"maxOffset":@(self.maxOffset),@"contentHeight":@(cards.contentSize.height),@"viewportHeight":@(cards.bounds.size.height),@"lastControlVisible":@(last&&CGRectContainsRect(cards.bounds,lastRect)),@"frameSamples":@(self.frames),@"largestFrameGapMs":@(self.maxFrameGap*1000),@"events":self.events,@"actions":actions,@"nativeRequested":@(self.dashboard.parentViewController==nil),@"lastExpanded":self.moduleCollectionViewController.lastExpanded?:@"",@"brightness":@(UIScreen.mainScreen.brightness)};
    NSString *path=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"gesture-results.json"];
    [[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:nil] writeToFile:path atomically:YES];
}
@end
@interface HBFixtureApp : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation HBFixtureApp
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options { CGRect frame=UIScreen.mainScreen.bounds; if([NSProcessInfo.processInfo.arguments containsObject:@"--short"])frame.size.height=568; self.window=[[UIWindow alloc] initWithFrame:frame]; self.window.rootViewController=[HBFixtureHost new]; [self.window makeKeyAndVisible]; return YES; }
@end
int main(int argc,char *argv[]){@autoreleasepool{return UIApplicationMain(argc,argv,nil,NSStringFromClass(HBFixtureApp.class));}}
