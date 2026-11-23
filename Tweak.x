#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// تعريف الكلاس عشان الكومبيلر ميزعلش
@interface SBFLockScreenDateView : UIView
@end

static CGFloat clockScale = 1.0;
static CGFloat glassOpacity = 0.8;
static UIColor *glassColor = [UIColor colorWithWhite:1.0 alpha:0.2]; 
static BOOL isOnlineUpdateLoaded = NO;

static void *kPanel = &kPanel;
static void *kGlass = &kGlass;

// --- دالة التطور الذاتي ---
void FetchRemoteConfig() {
    if (isOnlineUpdateLoaded) return; 
    NSURL *url = [NSURL URLWithString:@"https://raw.githubusercontent.com/slanttech58-png/GlassClock/main/config.json"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData]; 
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (data && !error) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (json) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (json[@"scale"]) clockScale = [json[@"scale"] floatValue];
                    if (json[@"opacity"]) glassOpacity = [json[@"opacity"] floatValue];
                    if (json[@"color"]) {
                        NSArray *rgba = json[@"color"];
                        if (rgba.count == 4) {
                            glassColor = [UIColor colorWithRed:[rgba[0] floatValue] green:[rgba[1] floatValue] blue:[rgba[2] floatValue] alpha:[rgba[3] floatValue]];
                        }
                    }
                    isOnlineUpdateLoaded = YES;
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"GCUpdateClock" object:nil];
                });
            }
        }
    }];
    [task resume];
}

// --- لوحة التحكم (كاملة) ---
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
        
        // Size Slider
        UISlider *sizeSlider = [[UISlider alloc] initWithFrame:CGRectMake(20, 60, frame.size.width - 40, 30)];
        sizeSlider.minimumValue = 0.8; sizeSlider.maximumValue = 1.5; sizeSlider.value = clockScale;
        [sizeSlider addTarget:self action:@selector(sizeChanged:) forControlEvents:UIControlEventValueChanged];
        [self addSubview:sizeSlider];
        
        // Opacity Slider
        UISlider *opacitySlider = [[UISlider alloc] initWithFrame:CGRectMake(20, 120, frame.size.width - 40, 30)];
        opacitySlider.minimumValue = 0.1; opacitySlider.maximumValue = 1.0; opacitySlider.value = glassOpacity;
        [opacitySlider addTarget:self action:@selector(opacityChanged:) forControlEvents:UIControlEventValueChanged];
        [self addSubview:opacitySlider];
        
        // Colors
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

// --- الهوك الأساسي ---
%hook SBFLockScreenDateView

- (void)layoutSubviews {
    %orig; 
    UILabel *timeLabel = [self valueForKey:@"_timeLabel"];
    if (!timeLabel) return;

    timeLabel.alpha = 0.0; // إخفاء ساعة النظام
    self.transform = CGAffineTransformMakeScale(clockScale, clockScale);

    UIVisualEffectView *glassView = objc_getAssociatedObject(self, &kGlass);
    if (!glassView) {
        glassView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial]];
        glassView.userInteractionEnabled = NO;
        
        UILabel *maskLabel = [[UILabel alloc] initWithFrame:timeLabel.bounds];
        maskLabel.textAlignment = NSTextAlignmentCenter;
        maskLabel.textColor = [UIColor whiteColor];
        glassView.maskView = maskLabel;
        
        objc_setAssociatedObject(self, &kGlass, glassView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self addSubview:glassView];
    }
    
    glassView.frame = timeLabel.frame;
    UILabel *mask = (UILabel *)glassView.maskView;
    mask.text = timeLabel.text;
    mask.font = timeLabel.font;
    mask.frame = glassView.bounds;
    glassView.alpha = glassOpacity;
    glassView.contentView.backgroundColor = glassColor;

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
            GCConfigPanel *panel = [[GCConfigPanel alloc] initWithFrame:CGRectMake(30, window.bounds.size.height / 2 - 150, window.bounds.size.width - 60, 310)];
            [window addSubview:panel];
            objc_setAssociatedObject(self, &kPanel, panel, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
}
%end

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshClock) name:@"GCUpdateClock" object:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ FetchRemoteConfig(); });
}
%new
- (void)refreshClock {
    Class dateViewClass = objc_getClass("SBFLockScreenDateView");
    if (dateViewClass) { [[dateViewClass new] setNeedsLayout]; }
}
%end
