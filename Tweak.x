#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@interface SBFLockScreenDateView : UIView
@end

static CGFloat clockScale = 1.0;
static CGFloat glassOpacity = 0.8;
static UIColor *glassColor = nil; 

static void *kPanel = &kPanel;
static void *kGlass = &kGlass;
static void *kMask = &kMask;

%ctor {
    glassColor = [UIColor colorWithWhite:1.0 alpha:0.2];
}

// --- 1. لوحة التحكم ---
@interface GCConfigPanel : UIView
@end

@implementation GCConfigPanel
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.85];
        self.layer.cornerRadius = 20;
        self.layer.masksToBounds = YES;
        
        UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(0, 15, frame.size.width, 30)];
        title.text = @"GlassClock Control";
        title.textColor = [UIColor whiteColor];
        title.textAlignment = NSTextAlignmentCenter;
        title.font = [UIFont boldSystemFontOfSize:16];
        [self addSubview:title];
        
        UISlider *sizeSlider = [[UISlider alloc] initWithFrame:CGRectMake(20, 60, frame.size.width - 40, 30)];
        sizeSlider.minimumValue = 0.8; sizeSlider.maximumValue = 1.5; sizeSlider.value = clockScale;
        [sizeSlider addTarget:self action:@selector(sizeChanged:) forControlEvents:UIControlEventValueChanged];
        [self addSubview:sizeSlider];
        
        UISlider *opacitySlider = [[UISlider alloc] initWithFrame:CGRectMake(20, 120, frame.size.width - 40, 30)];
        opacitySlider.minimumValue = 0.1; opacitySlider.maximumValue = 1.0; opacitySlider.value = glassOpacity;
        [opacitySlider addTarget:self action:@selector(opacityChanged:) forControlEvents:UIControlEventValueChanged];
        [self addSubview:opacitySlider];
        
        NSArray *colors = @[[UIColor whiteColor], [UIColor cyanColor], [UIColor systemPinkColor], [UIColor systemYellowColor]];
        for (int i = 0; i < colors.count; i++) {
            UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
            btn.frame = CGRectMake(20 + (i * 45), 180, 35, 35);
            btn.backgroundColor = colors[i];
            btn.layer.cornerRadius = 17.5;
            btn.tag = i;
            [btn addTarget:self action:@selector(colorChanged:) forControlEvents:UIControlEventTouchUpInside];
            [self addSubview:btn];
        }
        
        UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        closeBtn.frame = CGRectMake(20, 240, frame.size.width - 40, 40);
        [closeBtn setTitle:@"إغلاق" forState:UIControlStateNormal];
        [closeBtn setTitleColor:[UIColor systemRedColor] forState:UIControlStateNormal];
        [closeBtn addTarget:self action:@selector(closePanel) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:closeBtn];
    }
    return self;
}
- (void)sizeChanged:(UISlider *)s { clockScale = s.value; [[NSNotificationCenter defaultCenter] postNotificationName:@"GCUpdateClock" object:nil]; }
- (void)opacityChanged:(UISlider *)s { glassOpacity = s.value; [[NSNotificationCenter defaultCenter] postNotificationName:@"GCUpdateClock" object:nil]; }
- (void)colorChanged:(UIButton *)b {
    if(b.tag==0) glassColor=[UIColor colorWithWhite:1.0 alpha:0.5];
    if(b.tag==1) glassColor=[UIColor colorWithRed:0 green:1 blue:1 alpha:0.5];
    if(b.tag==2) glassColor=[UIColor colorWithRed:1 green:0.4 blue:0.6 alpha:0.5];
    if(b.tag==3) glassColor=[UIColor colorWithRed:1 green:1 blue:0 alpha:0.5];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"GCUpdateClock" object:nil];
}
- (void)closePanel { [UIView animateWithDuration:0.2 animations:^{ self.alpha = 0; } completion:^(BOOL finished) { [self removeFromSuperview]; }]; }
@end

// --- 2. الهوك الأساسي للساعة ---
%hook SBFLockScreenDateView
- (void)layoutSubviews {
    %orig; 
    
    UILabel *timeLabel = nil;
    @try {
        timeLabel = [self valueForKey:@"_timeLabel"];
    } @catch (NSException *exception) {
        return; // لو مفيش ليبل، اخرج بأمان
    }
    if (!timeLabel) return;

    // إخفاء الساعة الأصلية (بدون تغيير حجم الكلاس الأساسي عشان ميهنجش)
    timeLabel.alpha = 0.0; 

    UIVisualEffectView *glassView = objc_getAssociatedObject(self, &kGlass);
    if (!glassView) {
        glassView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial]];
        glassView.userInteractionEnabled = NO;
        
        UILabel *maskLabel = [[UILabel alloc] initWithFrame:timeLabel.bounds];
        maskLabel.textAlignment = NSTextAlignmentCenter;
        maskLabel.textColor = [UIColor whiteColor];
        glassView.maskView = maskLabel;
        
        objc_setAssociatedObject(self, &kGlass, glassView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, &kMask, maskLabel, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self addSubview:glassView];
    }
    
    // تطبيق التكبير على الزجاج نفسه فقط لتجنب الهنج
    glassView.transform = CGAffineTransformMakeScale(clockScale, clockScale);
    glassView.frame = timeLabel.frame;
    
    UILabel *mask = (UILabel *)objc_getAssociatedObject(self, &kMask);
    mask.text = timeLabel.text;
    mask.font = timeLabel.font;
    mask.frame = glassView.bounds;
    
    glassView.alpha = glassOpacity;
    glassView.contentView.backgroundColor = glassColor;

    // إضافة مستشعر الضغط المطول
    if (![self.gestureRecognizers count]) {
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
        [self addGestureRecognizer:longPress];
    }
}

%new
- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        UIView *window = self.window;
        if (!window) return;
        
        if (!objc_getAssociatedObject(self, &kPanel)) {
            GCConfigPanel *panel = [[GCConfigPanel alloc] initWithFrame:CGRectMake(30, window.bounds.size.height / 2 - 150, window.bounds.size.width - 60, 310)];
            [window addSubview:panel];
            objc_setAssociatedObject(self, &kPanel, panel, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
}
%end

// --- 3. الاستجابة للتحديثات (بدون كراش) ---
%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshClock) name:@"GCUpdateClock" object:nil];
}
%new
- (void)refreshClock {
    // إخفاء تحذير آبل عشان الكومبيلر ميزعلش
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
    
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        for (UIView *view in window.subviews) {
            if ([view isKindOfClass:NSClassFromString(@"SBFLockScreenDateView")]) {
                [view setNeedsLayout];
            }
        }
    }
    
    #pragma clang diagnostic pop
}
%end
