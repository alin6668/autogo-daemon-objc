//  AGAppDelegate.m - AutoGo Dashboard App
//  显示守护进程服务状态、设备信息，可打开 Web 控制台

#import "AGAppDelegate.h"

#define DAEMON_PORT 8888

@interface AGAppDelegate ()
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIView *statusDot;
@property (nonatomic, strong) UILabel *detailLabel;
@property (nonatomic, strong) UILabel *deviceLabel;
@property (nonatomic, strong) UILabel *ipLabel;
@property (nonatomic, strong) UILabel *portLabel;
@property (nonatomic, strong) UILabel *versionLabel;
@property (nonatomic, strong) UIButton *openButton;
@property (nonatomic, strong) UIButton *refreshButton;
@property (nonatomic, strong) UIButton *apiDocsButton;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) NSTimer *autoRefreshTimer;
@end

@implementation AGAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.08 alpha:1.0];

    UIViewController *vc = [[UIViewController alloc] init];
    [self setupUI:vc.view];
    self.window.rootViewController = vc;
    [self.window makeKeyAndVisible];

    [self checkServiceStatus];

    // 每 10 秒自动刷新状态
    self.autoRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:10.0
                                                             target:self
                                                           selector:@selector(checkServiceStatus)
                                                           userInfo:nil
                                                            repeats:YES];

    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    [self.autoRefreshTimer invalidate];
    self.autoRefreshTimer = nil;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    [self checkServiceStatus];
    self.autoRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:10.0
                                                             target:self
                                                           selector:@selector(checkServiceStatus)
                                                           userInfo:nil
                                                            repeats:YES];
}

#pragma mark - UI Setup

- (void)setupUI:(UIView *)rootView {
    // 计算 safe area 偏移 (状态栏)
    CGFloat topOffset = 44;
    if (@available(iOS 11.0, *)) {
        topOffset = [UIApplication sharedApplication].keyWindow.safeAreaInsets.top;
        if (topOffset < 44) topOffset = 44;
    }

    CGFloat w = rootView.bounds.size.width;
    CGFloat pad = 16;
    CGFloat y = topOffset + 20;

    // 标题
    UILabel *titleLabel = [self label:CGRectMake(pad, y, w - 2*pad, 36)
                                text:@"AutoGo 控制模块"
                                font:[UIFont boldSystemFontOfSize:26]
                               color:[UIColor whiteColor]];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [rootView addSubview:titleLabel];
    y += 48;

    // 副标题
    UILabel *subtitle = [self label:CGRectMake(pad, y, w - 2*pad, 20)
                               text:@"iOS 设备远程控制守护进程"
                               font:[UIFont systemFontOfSize:13]
                              color:[UIColor colorWithWhite:0.5 alpha:1.0]];
    subtitle.textAlignment = NSTextAlignmentCenter;
    [rootView addSubview:subtitle];
    y += 30;

    // === 服务状态卡片 ===
    UIView *statusCard = [self card:CGRectMake(pad, y, w - 2*pad, 0)];
    CGFloat cy = 16;

    // 状态标题行
    UILabel *cardTitle = [self label:CGRectMake(16, cy, 80, 20)
                                text:@"服务状态"
                                font:[UIFont boldSystemFontOfSize:15]
                               color:[UIColor colorWithWhite:0.6 alpha:1.0]];
    [statusCard addSubview:cardTitle];

    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    _spinner.color = [UIColor colorWithWhite:0.4 alpha:1.0];
    _spinner.frame = CGRectMake(statusCard.bounds.size.width - 44, cy - 2, 24, 24);
    [statusCard addSubview:_spinner];
    cy += 30;

    // 状态圆点 + 文本
    _statusDot = [[UIView alloc] initWithFrame:CGRectMake(16, cy + 4, 14, 14)];
    _statusDot.backgroundColor = [UIColor grayColor];
    _statusDot.layer.cornerRadius = 7;
    [statusCard addSubview:_statusDot];

    _statusLabel = [self label:CGRectMake(38, cy, 200, 22)
                          text:@"检测中..."
                          font:[UIFont boldSystemFontOfSize:17]
                         color:[UIColor whiteColor]];
    [statusCard addSubview:_statusLabel];

    // 刷新按钮
    _refreshButton = [self button:CGRectMake(statusCard.bounds.size.width - 80, cy - 4, 64, 30)
                            title:@"刷新"
                             font:[UIFont systemFontOfSize:13]
                       titleColor:[UIColor colorWithRed:0.3 green:0.55 blue:0.9 alpha:1.0]
                           action:@selector(checkServiceStatus)];
    _refreshButton.layer.borderWidth = 1;
    _refreshButton.layer.borderColor = [UIColor colorWithRed:0.3 green:0.55 blue:0.9 alpha:0.5].CGColor;
    _refreshButton.layer.cornerRadius = 6;
    [statusCard addSubview:_refreshButton];
    cy += 36;

    // 详细信息
    _detailLabel = [self label:CGRectMake(16, cy, statusCard.bounds.size.width - 32, 0)
                           text:@""
                           font:[UIFont systemFontOfSize:12]
                          color:[UIColor colorWithWhite:0.45 alpha:1.0]];
    _detailLabel.numberOfLines = 0;
    [statusCard addSubview:_detailLabel];
    cy += 0; // 动态高度

    statusCard.frame = CGRectMake(pad, y, w - 2*pad, cy + 12);
    [rootView addSubview:statusCard];
    y += statusCard.bounds.size.height + 12;

    // === 设备信息卡片 ===
    UIView *infoCard = [self card:CGRectMake(pad, y, w - 2*pad, 0)];
    CGFloat iy = 12;

    UILabel *infoTitle = [self label:CGRectMake(16, iy, 120, 20)
                                text:@"设备信息"
                                font:[UIFont boldSystemFontOfSize:15]
                               color:[UIColor colorWithWhite:0.6 alpha:1.0]];
    [infoCard addSubview:infoTitle];
    iy += 30;

    NSArray *infoItems = @[
        @[@"版本", @"获取中..."],
        @[@"设备", @"获取中..."],
        @[@"IP 地址", @"获取中..."],
        @[@"服务端口", @"8888"],
        @[@"Web 控制台", @"http://127.0.0.1:8888"],
    ];

    for (NSArray *item in infoItems) {
        UILabel *keyLbl = [self label:CGRectMake(16, iy, 80, 18)
                                 text:item[0]
                                 font:[UIFont systemFontOfSize:13]
                                color:[UIColor colorWithWhite:0.45 alpha:1.0]];
        [infoCard addSubview:keyLbl];

        UILabel *valLbl = [self label:CGRectMake(100, iy, infoCard.bounds.size.width - 120, 18)
                                 text:item[1]
                                 font:[UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular]
                                color:[UIColor colorWithWhite:0.75 alpha:1.0]];
        valLbl.tag = 100 + [infoItems indexOfObject:item];

        if ([[item[0] stringValue] isEqualToString:@"Web 控制台"]) {
            valLbl.textColor = [UIColor colorWithRed:0.3 green:0.55 blue:0.9 alpha:1.0];
        }
        [infoCard addSubview:valLbl];
        iy += 22;
    }

    infoCard.frame = CGRectMake(pad, y, w - 2*pad, iy + 12);
    [rootView addSubview:infoCard];
    y += infoCard.bounds.size.height + 16;

    // === 操作按钮 ===
    CGFloat btnW = w - 2*pad;
    CGFloat btnH = 48;

    _openButton = [self button:CGRectMake(pad, y, btnW, btnH)
                         title:@"打开 Web 控制台"
                          font:[UIFont boldSystemFontOfSize:16]
                    titleColor:[UIColor whiteColor]
                        action:@selector(openDashboard)];
    _openButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.45 blue:0.85 alpha:1.0];
    _openButton.layer.cornerRadius = 12;
    [rootView addSubview:_openButton];
    y += btnH + 10;

    _apiDocsButton = [self button:CGRectMake(pad, y, btnW, btnH)
                            title:@"API 接口文档"
                             font:[UIFont systemFontOfSize:15]
                       titleColor:[UIColor colorWithRed:0.3 green:0.55 blue:0.9 alpha:1.0]
                           action:@selector(openAPIDocs)];
    _apiDocsButton.layer.borderWidth = 1;
    _apiDocsButton.layer.borderColor = [UIColor colorWithRed:0.3 green:0.55 blue:0.9 alpha:0.4].CGColor;
    _apiDocsButton.layer.cornerRadius = 12;
    [rootView addSubview:_apiDocsButton];
    y += btnH + 24;

    // 底部信息
    UILabel *footer = [self label:CGRectMake(pad, y, w - 2*pad, 28)
                             text:@"AutoGo Daemon v1.0.0 · Rootless"
                             font:[UIFont systemFontOfSize:11]
                            color:[UIColor colorWithWhite:0.25 alpha:1.0]];
    footer.textAlignment = NSTextAlignmentCenter;
    [rootView addSubview:footer];
}

- (void)checkServiceStatus {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->_spinner startAnimating];
        self->_statusDot.backgroundColor = [UIColor colorWithWhite:0.35 alpha:1.0];
        self->_statusLabel.text = @"检测中...";
        self->_statusLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
    });

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *healthURL = [NSString stringWithFormat:@"http://127.0.0.1:%d/health", DAEMON_PORT];
        NSString *infoURL  = [NSString stringWithFormat:@"http://127.0.0.1:%d/api/device/info", DAEMON_PORT];
        NSString *memoryURL = [NSString stringWithFormat:@"http://127.0.0.1:%d/api/system/memory", DAEMON_PORT];
        NSString *batteryURL = [NSString stringWithFormat:@"http://127.0.0.1:%d/api/battery/level", DAEMON_PORT];
        NSString *ipURL = [NSString stringWithFormat:@"http://127.0.0.1:%d/api/network/ip", DAEMON_PORT];

        NSDictionary *health = [self fetchJSON:healthURL];
        NSDictionary *info   = [self fetchJSON:infoURL];
        NSDictionary *memory = [self fetchJSON:memoryURL];
        NSDictionary *battery = [self fetchJSON:batteryURL];
        NSDictionary *network = [self fetchJSON:ipURL];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_spinner stopAnimating];

            BOOL active = (health != nil);
            self->_statusDot.backgroundColor = active
                ? [UIColor colorWithRed:0.2 green:0.78 blue:0.35 alpha:1.0]
                : [UIColor colorWithRed:0.95 green:0.3 blue:0.25 alpha:1.0];
            self->_statusLabel.text = active ? @"服务已激活" : @"服务未激活";
            self->_statusLabel.textColor = active
                ? [UIColor colorWithRed:0.2 green:0.78 blue:0.35 alpha:1.0]
                : [UIColor colorWithRed:0.95 green:0.3 blue:0.25 alpha:1.0];

            // 详细信息
            NSMutableString *detail = [NSMutableString string];
            if (active) {
                [detail appendFormat:@"响应时间: %.0fms\n", [self lastResponseTime]];
                [detail appendFormat:@"协议: HTTP/1.1 · REST + MCP\n"];
                [detail appendString:@"60+ API 端点 · 50+ MCP 工具"];

                // 更新设备信息标签
                UIView *root = self.window.rootViewController.view;
                NSDictionary *apiData = [self extractData:info];
                NSDictionary *memData = [self extractData:memory];
                NSDictionary *batData = [self extractData:battery];
                NSDictionary *netData = [self extractData:network];

                for (UIView *sv in root.subviews) {
                    if (sv.tag >= 100 && sv.tag < 200) {
                        UILabel *lbl = (UILabel *)sv;
                        switch (sv.tag) {
                            case 100: // 版本
                                lbl.text = [NSString stringWithFormat:@"v1.0.0 (iOS %@)", apiData[@"osVersion"] ?: @"--"];
                                break;
                            case 101: // 设备
                                lbl.text = [NSString stringWithFormat:@"%@ (%@)", apiData[@"name"] ?: @"--", apiData[@"model"] ?: @"--"];
                                break;
                            case 102: // IP
                                lbl.text = netData[@"ip"] ?: @"127.0.0.1";
                                break;
                            case 103: // 端口
                                lbl.text = @"8888";
                                break;
                            case 104: // Web 控制台
                                lbl.text = @"http://127.0.0.1:8888";
                                break;
                        }
                    }
                }
            } else {
                [detail appendString:@"守护进程未运行或无响应\n"];
                [detail appendString:@"请检查 Dobby 越狱状态\n"];
                [detail appendFormat:@"确认端口 %d 是否被占用", DAEMON_PORT];
            }
            self->_detailLabel.text = detail;
            [self->_detailLabel sizeToFit];

            // 调整卡片
            [self relayoutCards];
        });
    });
}

#pragma mark - Actions

- (void)openDashboard {
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%d", DAEMON_PORT]];
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

- (void)openAPIDocs {
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%d/api/docs", DAEMON_PORT]];
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

- (void)relayoutCards {
    CGFloat w = self.window.bounds.size.width;
    CGFloat pad = 16;
    CGFloat y = 44 + 20 + 48 + 30;
    CGFloat statusCardHeight = 16 + 30 + 36 + _detailLabel.bounds.size.height + 12;

    // Status card
    UIView *statusCard = nil;
    UIView *infoCard = nil;
    for (UIView *sv in self.window.rootViewController.view.subviews) {
        if (sv.tag == 0 && sv.backgroundColor && sv.layer.cornerRadius > 0) {
            if (!statusCard) {
                statusCard = sv;
            } else if (!infoCard) {
                infoCard = sv;
            }
        }
    }
    if (statusCard) {
        statusCard.frame = CGRectMake(pad, y, w - 2*pad, statusCardHeight);
        y += statusCardHeight + 12;
    }
    if (infoCard) {
        infoCard.frame = CGRectMake(pad, y, w - 2*pad, infoCard.bounds.size.height);
        y += infoCard.bounds.size.height + 16;
    }
    if (_openButton) {
        _openButton.frame = CGRectMake(pad, y, w - 2*pad, 48);
        y += 58;
    }
    if (_apiDocsButton) {
        _apiDocsButton.frame = CGRectMake(pad, y, w - 2*pad, 48);
    }
}

#pragma mark - Helpers

- (NSDictionary *)fetchJSON:(NSString *)urlString {
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) return nil;

    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __block NSDictionary *result = nil;
    __block CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url
                                                       cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                   timeoutInterval:3.0];
    [req setHTTPMethod:@"GET"];
    [req setValue:@"AutoGo-Dashboard/1.0" forHTTPHeaderField:@"User-Agent"];

    NSURLSession *session = [NSURLSession sharedSession];
    [[session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        if (data && !err) {
            NSError *jsonErr = nil;
            id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
            if ([obj isKindOfClass:[NSDictionary class]]) {
                result = obj;
            }
        }
        _lastResponseTime = (CFAbsoluteTimeGetCurrent() - start) * 1000.0;
        dispatch_semaphore_signal(sem);
    }] resume];

    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
    return result;
}

static CGFloat _lastResponseTime = 0;

- (CGFloat)lastResponseTime {
    return _lastResponseTime;
}

/// 从 { success: true, data: {...} } 响应中提取 data
- (NSDictionary *)extractData:(NSDictionary *)response {
    if (!response) return @{};
    id data = response[@"data"];
    if ([data isKindOfClass:[NSDictionary class]]) return data;
    // 可能是直接返回的 data (如 health)
    if (response[@"status"]) return response;
    return response;
}

#pragma mark - View Builders

- (UIView *)card:(CGRect)frame {
    UIView *v = [[UIView alloc] initWithFrame:frame];
    v.backgroundColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.12 alpha:1.0];
    v.layer.cornerRadius = 14;
    v.layer.borderWidth = 1;
    v.layer.borderColor = [UIColor colorWithWhite:0.18 alpha:1.0].CGColor;
    return v;
}

- (UILabel *)label:(CGRect)frame text:(NSString *)text font:(UIFont *)font color:(UIColor *)color {
    UILabel *l = [[UILabel alloc] initWithFrame:frame];
    l.text = text;
    l.font = font;
    l.textColor = color;
    return l;
}

- (UIButton *)button:(CGRect)frame title:(NSString *)title font:(UIFont *)font titleColor:(UIColor *)color action:(SEL)action {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = frame;
    [b setTitle:title forState:UIControlStateNormal];
    b.titleLabel.font = font;
    [b setTitleColor:color forState:UIControlStateNormal];
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return b;
}

@end
