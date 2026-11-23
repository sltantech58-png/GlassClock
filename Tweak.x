// GlassClock - lock screen clock customizer for iOS 14-16
// NOTE: private class/ivar names can differ per iOS version. Verify with FLEX/Flexing on your device.
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSUserDefaults *D(void){ return NSUserDefaults.standardUserDefaults; }
static CGFloat GetF(NSString *k, CGFloat def){ id v=[D() objectForKey:[@"gc_" stringByAppendingString:k]]; return v?[v doubleValue]:def; }
static void SetF(NSString *k, CGFloat v){ [D() setDouble:v forKey:[@"gc_" stringByAppendingString:k]]; }

@interface SBFLockScreenDateView : UIView
- (void)gc_apply;
- (void)gc_longPress:(UILongPressGestureRecognizer *)g;
@end

static char kGlass, kMask, kPanel;

@interface GCPanel : UIView
@property (nonatomic, weak) UIView *target;
@end
@implementation GCPanel
- (instancetype)initWithFrame:(CGRect)f {
  if ((self=[super initWithFrame:f])) {
    UIVisualEffectView *bg=[[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterialDark]];
    bg.frame=self.bounds; bg.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    bg.layer.cornerRadius=22; bg.clipsToBounds=YES; [self addSubview:bg];
    NSArray *rows=@[@[@"size",@"Size",@0.5,@1.8,@1.0],@[@"hue",@"Color",@0,@1,@0.0],@[@"glass",@"Glass",@0,@1,@0.8],@[@"blur",@"Blur",@0,@1,@0.5]];
    CGFloat y=14;
    for (NSArray *r in rows) {
      UILabel *l=[[UILabel alloc] initWithFrame:CGRectMake(16,y,70,30)]; l.text=r[1]; l.textColor=UIColor.whiteColor; l.font=[UIFont systemFontOfSize:14]; [self addSubview:l];
      UISlider *s=[[UISlider alloc] initWithFrame:CGRectMake(90,y,f.size.width-106,30)];
      s.minimumValue=[r[2] floatValue]; s.maximumValue=[r[3] floatValue]; s.value=GetF(r[0],[r[4] doubleValue]);
      s.accessibilityIdentifier=r[0]; [s addTarget:self action:@selector(changed:) forControlEvents:UIControlEventValueChanged];
      [self addSubview:s]; y+=40;
    }
    UIButton *done=[UIButton buttonWithType:UIButtonTypeSystem]; done.frame=CGRectMake(f.size.width/2-40,y,80,30);
    [done setTitle:@"Done" forState:UIControlStateNormal]; [done addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside]; [self addSubview:done];
  } return self;
}
- (void)changed:(UISlider *)s { SetF(s.accessibilityIdentifier, s.value); [D() synchronize]; [(id)self.target gc_apply]; }
- (void)close { [UIView animateWithDuration:.2 animations:^{ self.alpha=0; } completion:^(BOOL f){ [self removeFromSuperview]; }]; }
@end

%hook SBFLockScreenDateView
- (void)didMoveToWindow {
  %orig;
  if (self.window && !objc_getAssociatedObject(self,&kGlass)) {
    UILongPressGestureRecognizer *lp=[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(gc_longPress:)];
    lp.minimumPressDuration=0.6; [self addGestureRecognizer:lp];
  }
}
- (void)layoutSubviews { %orig; [self gc_apply]; }

%new
- (void)gc_apply {
  UIView *time=nil; @try { time=[self valueForKey:@"_timeLabel"]; } @catch(...) {}
  if (!time) return;
  CGFloat size=GetF(@"size",1.0), hue=GetF(@"hue",0.0), glass=GetF(@"glass",0.8), blur=GetF(@"blur",0.5);
  time.transform=CGAffineTransformMakeScale(size,size);

  UIVisualEffectView *gv=objc_getAssociatedObject(self,&kGlass);
  UILabel *mask=objc_getAssociatedObject(self,&kMask);
  if (glass<=0.01) { gv.hidden=YES; time.alpha=1; return; }
  if (!gv) {
    gv=[[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialLight]];
    mask=[UILabel new]; mask.textAlignment=NSTextAlignmentCenter; mask.textColor=UIColor.whiteColor;
    gv.maskView=mask; gv.userInteractionEnabled=NO;
    objc_setAssociatedObject(self,&kGlass,gv,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self,&kMask,mask,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self addSubview:gv];
  }
  gv.hidden=NO;
  NSString *txt=nil; UIFont *font=nil;
  @try { txt=[(id)time valueForKey:@"string"]; font=[(id)time valueForKey:@"font"]; } @catch(...) {}
  if (!txt) return;
  gv.frame=time.frame; gv.transform=time.transform;
  mask.frame=gv.bounds; mask.text=txt; mask.font=font?:[UIFont systemFontOfSize:80 weight:UIFontWeightBold];
  gv.alpha=glass;
  gv.backgroundColor=[UIColor colorWithHue:hue saturation:(hue>0.01?0.6:0) brightness:1 alpha:0.35*blur+0.1];
  time.alpha=0.0; // hide original; glass copy replaces it
}

%new
- (void)gc_longPress:(UILongPressGestureRecognizer *)g {
  if (g.state!=UIGestureRecognizerStateBegan) return;
  GCPanel *old=objc_getAssociatedObject(self,&kPanel); if (old.superview) return;
  UIView *host=self.window; CGFloat w=MIN(host.bounds.size.width-40,340);
  GCPanel *p=[[GCPanel alloc] initWithFrame:CGRectMake((host.bounds.size.width-w)/2,host.bounds.size.height*0.5,w,225)];
  p.target=self; p.alpha=0; [host addSubview:p];
  objc_setAssociatedObject(self,&kPanel,p,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  [UIView animateWithDuration:.2 animations:^{ p.alpha=1; }];
}
%end
