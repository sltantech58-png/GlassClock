#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static CGFloat clockScale = 1.0;
static void *kPanel = &kPanel;
static void *kGlass = &kGlass;

// ---------------------------------------------------------
// 1. لوحة التخصيص اللي هتظهر لما تدوس مطول على الساعة
// ---------------------------------------------------------
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
        title.text = @"GlassClock Settings (iOS 15)";
        title.textColor = [UIColor whiteColor];
        title.textAlignment = NSTextAlignmentCenter;
        title.font = [UIFont boldSystemFontOfSize:16];
        [self addSubview:title];
        
        // زر التكبير
        UIButton *sizeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        sizeBtn.frame = CGRectMake(20, 60, frame.size.width - 40, 40);
        [sizeBtn setTitle:@"تكبير / تصغير الساعة" forState:UIControlStateNormal];
        [sizeBtn addTarget:self action:@selector(toggleSize) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:sizeBtn];
        
        // زر إغلاق
        UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        closeBtn.frame = CGRectMake(20, 150, frame.size.width - 40, 40);
        [closeBtn setTitle:@"إغلاق وحفظ" forState:UIControlStateNormal];
        [closeBtn setTitleColor:[UIColor systemRedColor] forState:UIControlStateNormal];
        [closeBtn addTarget:self action:@selector(closePanel) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:closeBtn];
    }
    return self;
}
- (void)toggleSize {
    clockScale = (clockScale > 1.0) ? 1.0 : 1.4;
    // إرسال إشعار للساعة عشان تتحدث فوراً
    [[NSNotificationCenter defaultCenter] postNotificationName:@"GCUpdateClock" object:nil];
}
- (void)closePanel {
    [UIView animateWithDuration:0.2 animations:^{ self.alpha = 0; } completion:^(BOOL finished) { [self removeFromSuperview]; }];
}
@end

// ---------------------------------------------------------
// 2. الهوك الأساسي على شاشة القفل (iOS 15)
// ---------------------------------------------------------
%hook SBFLockScreenDateView

- (void)layoutSubviews {
    %orig; // تنفيذ كود آبل الأساسي
    
    // إيجاد الليبل بتاع الوقت
    UILabel *timeLabel = [self valueForKey:@"_timeLabel"];
    if (!timeLabel) return;

    // تطبيق التكبير
    self.transform = CGAffineTransformMakeScale(clockScale, clockScale);

    // بناء تأثير الزجاج
    UIVisualEffectView *glassView = objc_getAssociatedObject(self, &kGlass);
    if (!glassView) {
        glassView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialLight]];
        glassView.userInteractionEnabled = NO;
        
        // عمل قناع (Mask) بشكل النص
        UILabel *maskLabel = [[UILabel alloc] initWithFrame:timeLabel.bounds];
        maskLabel.textAlignment = NSTextAlignmentCenter;
        maskLabel.textColor = [UIColor whiteColor];
        glassView.maskView = maskLabel;
        
        objc_setAssociatedObject(self, &kGlass, glassView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self addSubview:glassView];
        [self bringSubviewToFront:glassView];
    }
    
    // تحديث إعدادات الزجاج
    glassView.frame = timeLabel.frame;
    UILabel *mask = (UILabel *)glassView.maskView;
    mask.text = timeLabel.text;
    mask.font = timeLabel.font;
    mask.frame = glassView.bounds;
    
    // إخفاء الساعة الأصلية عشان الزجاج يبان
    timeLabel.alpha = 0.2; 

    // إضافة خاصية الضغط المطول (لو مش مضافة)
    if (![self.gestureRecognizers count]) {
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
        [self addGestureRecognizer:longPress];
    }
}

%new
- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        UIView *window = self.window;
        if (!objc_getAssociatedObject(self, &kPanel)) {
            GCConfigPanel *panel = [[GCConfigPanel alloc] initWithFrame:CGRectMake(40, window.bounds.size.height / 2 - 100, window.bounds.size.width - 80, 210)];
            [window addSubview:panel];
            objc_setAssociatedObject(self, &kPanel, panel, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
}
%end

// ---------------------------------------------------------
// 3. التحديث الفوري عند التغيير
// ---------------------------------------------------------
%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshClock) name:@"GCUpdateClock" object:nil];
}
%new
- (void)refreshClock {
    // إجبار شاشة القفل على إعادة التخطيط
    [[objc_getClass("SBFLockScreenDateView") new] setNeedsLayout];
}
%end
