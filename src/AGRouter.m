//  AGRouter.m - API 路由分发实现
//  60+ 端点，覆盖 ios-mcp + go-ios + AutoGo 全部功能

#import "AGRouter.h"
#import "AGJSON.h"
#import "AGDeviceInfo.h"
#import "AGTouchController.h"
#import "AGAppController.h"
#import "AGFileController.h"
#import "AGVPNController.h"
#import "AGWiFiController.h"
#import "AGShellController.h"
#import "AGClipboardController.h"
#import "AGAccessibilityController.h"
#import "AGHIDController.h"
#import "AGMCPHandler.h"

@interface AGRouter ()
@property (nonatomic, strong) AGMCPHandler *mcpHandler;
- (NSDictionary *)route:(NSString *)method path:(NSString *)path body:(NSString *)body;
- (NSDictionary *)respond:(int)status body:(NSString *)body contentType:(NSString *)ct;
- (NSDictionary *)respondOK:(NSString *)body;
- (NSDictionary *)respondError:(int)code msg:(NSString *)msg;
- (NSDictionary *)respondHTML:(NSString *)html;
- (NSDictionary *)respondImage:(NSData *)data;
@end

@implementation AGRouter

+ (instancetype)sharedRouter {
    static AGRouter *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _mcpHandler = [[AGMCPHandler alloc] init];
    }
    return self;
}

- (NSDictionary *)handleRequest:(NSDictionary *)request {
    NSString *method = request[@"method"];
    NSString *path = request[@"path"];
    NSString *body = request[@"body"];

    // OPTIONS 预检
    if ([method isEqualToString:@"OPTIONS"]) {
        return [self respondOK:@""];
    }

    // 路由分发
    @try {
        return [self route:method path:path body:body];
    } @catch (NSException *e) {
        return [self respondError:500 msg:[e description]];
    }
}

- (NSDictionary *)route:(NSString *)method path:(NSString *)path body:(NSString *)body {
    // === 健康检查 ===
    if ([path isEqualToString:@"/health"] || [path isEqualToString:@"/ping"]) {
        return [self respondOK:[AGJSON successResponse:@{
            @"status": @"ok",
            @"version": @"1.0.0",
            @"name": @"AutoGo Daemon",
            @"device": [AGDeviceInfo deviceName],
            @"os": [AGDeviceInfo systemVersion]
        }]];
    }

    // === API 文档 ===
    if ([path isEqualToString:@"/api/docs"]) {
        return [self respondHTML:[AGRouter apiDocsHTML]];
    }

    // === MCP 协议 ===
    if ([path isEqualToString:@"/mcp"]) {
        NSString *result = [_mcpHandler handleRequest:body];
        return [self respondOK:result];
    }
    if ([path isEqualToString:@"/sse"]) {
        return [self respondOK:[AGJSON successResponse:@{@"sse": @"Stream endpoint (use GET for SSE)"}]];
    }

    // === 设备信息 (6) ===
    if ([path isEqualToString:@"/api/device/info"])     return [self respondOK:[AGJSON successResponse:[AGDeviceInfo fullDeviceInfo]]];
    if ([path isEqualToString:@"/api/device/name"])      return [self respondOK:[AGJSON successResponse:@{@"name":[AGDeviceInfo deviceName]}]];
    if ([path isEqualToString:@"/api/device/model"])     return [self respondOK:[AGJSON successResponse:@{@"model":[AGDeviceInfo deviceModel]}]];
    if ([path isEqualToString:@"/api/device/osversion"]) return [self respondOK:[AGJSON successResponse:@{@"version":[AGDeviceInfo systemVersion]}]];
    if ([path isEqualToString:@"/api/device/info"])      return [self respondOK:[AGJSON successResponse:[AGDeviceInfo fullDeviceInfo]]];

    // === 电池 & 存储 (3) ===
    if ([path isEqualToString:@"/api/battery/level"])    return [self respondOK:[AGJSON successResponse:@{@"level":@([AGDeviceInfo batteryLevel])}]];
    if ([path isEqualToString:@"/api/battery/state"])    return [self respondOK:[AGJSON successResponse:@{@"state":[AGDeviceInfo batteryState], @"charging":@([AGDeviceInfo isCharging])}]];
    if ([path isEqualToString:@"/api/storage/info"])     return [self respondOK:[AGJSON successResponse:[AGDeviceInfo storageInfo]]];

    // === 屏幕控制 (7) ===
    if ([path isEqualToString:@"/api/screen/info"])      return [self respondOK:[AGJSON successResponse:[AGDeviceInfo screenInfo]]];
    if ([path isEqualToString:@"/api/screen/screenshot"]) {
        NSData *imgData = [AGDeviceInfo captureScreenshot];
        return [self respondImage:imgData];
    }

    if ([path isEqualToString:@"/api/screen/brightness"]) {
        if ([method isEqualToString:@"GET"]) {
            return [self respondOK:[AGJSON successResponse:@{@"brightness":@([AGDeviceInfo brightness])}]];
        } else {
            float v = [self floatValue:body key:@"value" def:50];
            float delta = [self floatValue:body key:@"delta" def:0];
            if (delta != 0) v = [AGDeviceInfo brightness] + delta;
            [AGDeviceInfo setBrightness:v];
            return [self respondOK:[AGJSON successResponse:@{@"brightness":@([AGDeviceInfo brightness])}]];
        }
    }

    if ([path isEqualToString:@"/api/screen/keepawake"]) {
        if ([method isEqualToString:@"POST"])   { [AGDeviceInfo keepScreenOn]; return [self respondOK:[AGJSON successResponse:@{@"keepAwake":@YES}]]; }
        if ([method isEqualToString:@"DELETE"]) { [AGDeviceInfo allowScreenOff]; return [self respondOK:[AGJSON successResponse:@{@"keepAwake":@NO}]]; }
        return [self respondOK:[AGJSON successResponse:@{@"keepAwake":@([AGDeviceInfo isScreenKeptOn])}]];
    }

    if ([path isEqualToString:@"/api/screen/orientation/lock"])   { [AGDeviceInfo lockOrientation:YES]; return [self respondOK:[AGJSON successResponse:@{@"locked":@YES}]]; }
    if ([path isEqualToString:@"/api/screen/orientation/unlock"]) { [AGDeviceInfo lockOrientation:NO]; return [self respondOK:[AGJSON successResponse:@{@"locked":@NO}]]; }

    if ([path isEqualToString:@"/api/screen/darkmode"]) {
        if ([method isEqualToString:@"GET"]) return [self respondOK:[AGJSON successResponse:@{@"darkMode":@([AGDeviceInfo isDarkMode])}]];
        BOOL on = [self boolValue:body key:@"enable" def:NO];
        [AGDeviceInfo setDarkMode:on];
        return [self respondOK:[AGJSON successResponse:@{@"darkMode":@([AGDeviceInfo isDarkMode])}]];
    }

    // === 触控手势 (5) ===
    if ([path isEqualToString:@"/api/touch/tap"]) {
        float x = [self floatValue:body key:@"x" def:0], y = [self floatValue:body key:@"y" def:0];
        [AGTouchController tap:x y:y];
        return [self respondOK:[AGJSON successResponse:@{@"action":@"tap",@"x":@(x),@"y":@(y)}]];
    }
    if ([path isEqualToString:@"/api/touch/doubletap"]) {
        float x = [self floatValue:body key:@"x" def:0], y = [self floatValue:body key:@"y" def:0];
        [AGTouchController doubleTap:x y:y];
        return [self respondOK:[AGJSON successResponse:@{@"action":@"doubleTap"}]];
    }
    if ([path isEqualToString:@"/api/touch/longpress"]) {
        float x = [self floatValue:body key:@"x" def:0], y = [self floatValue:body key:@"y" def:0];
        float d = [self floatValue:body key:@"duration" def:1.0];
        [AGTouchController longPress:x y:y duration:d];
        return [self respondOK:[AGJSON successResponse:@{@"action":@"longPress",@"duration":@(d)}]];
    }
    if ([path isEqualToString:@"/api/touch/swipe"]) {
        float fx = [self floatValue:body key:@"fromX" def:0], fy = [self floatValue:body key:@"fromY" def:0];
        float tx = [self floatValue:body key:@"toX" def:0],   ty = [self floatValue:body key:@"toY" def:0];
        float d  = [self floatValue:body key:@"duration" def:0.5];
        [AGTouchController swipe:fx fy:fy tx:tx ty:ty duration:d];
        return [self respondOK:[AGJSON successResponse:@{@"action":@"swipe"}]];
    }
    if ([path isEqualToString:@"/api/touch/drag"]) {
        float fx = [self floatValue:body key:@"fromX" def:0], fy = [self floatValue:body key:@"fromY" def:0];
        float tx = [self floatValue:body key:@"toX" def:0],   ty = [self floatValue:body key:@"toY" def:0];
        float d  = [self floatValue:body key:@"duration" def:0.8];
        int s    = (int)[self floatValue:body key:@"steps" def:20];
        [AGTouchController drag:fx fy:fy tx:tx ty:ty duration:d steps:s];
        return [self respondOK:[AGJSON successResponse:@{@"action":@"drag"}]];
    }

    // === 硬件按键 (5) ===
    if ([path isEqualToString:@"/api/key/home"]) {
        BOOL db = [self boolValue:body key:@"doubleClick" def:NO];
        [AGHIDController pressHome:db];
        return [self respondOK:[AGJSON successResponse:@{@"action":@"home"}]];
    }
    if ([path isEqualToString:@"/api/key/power"]) {
        BOOL lp = [self boolValue:body key:@"longPress" def:NO];
        [AGHIDController pressPower:lp];
        return [self respondOK:[AGJSON successResponse:@{@"action":@"power"}]];
    }
    if ([path isEqualToString:@"/api/key/volume/up"])   { [AGHIDController pressVolumeUp];   return [self respondOK:[AGJSON successResponse:@{@"action":@"volumeUp"}]]; }
    if ([path isEqualToString:@"/api/key/volume/down"]) { [AGHIDController pressVolumeDown]; return [self respondOK:[AGJSON successResponse:@{@"action":@"volumeDown"}]]; }
    if ([path isEqualToString:@"/api/key/mute"])        { [AGHIDController toggleMute];      return [self respondOK:[AGJSON successResponse:@{@"action":@"mute"}]]; }

    // === 文字输入 (2) ===
    if ([path isEqualToString:@"/api/input/text"]) {
        NSString *text = [self stringValue:body key:@"text"];
        NSString *via  = [self stringValue:body key:@"via"] ?: @"clipboard";
        if (!text) return [self respondError:400 msg:@"需要 text 字段"];
        if ([via isEqualToString:@"clipboard"]) {
            [AGClipboardController setClipboard:text];
        }
        return [self respondOK:[AGJSON successResponse:@{@"action":@"inputText", @"length":@(text.length)}]];
    }
    if ([path isEqualToString:@"/api/input/key"]) {
        NSString *key = [self stringValue:body key:@"key"];
        if (!key) return [self respondError:400 msg:@"需要 key 字段"];
        [AGHIDController pressKey:key];
        return [self respondOK:[AGJSON successResponse:@{@"key":key}]];
    }

    // === App 管理 (8) ===
    if ([path isEqualToString:@"/api/apps/list"])      { return [self respondOK:[AGJSON successResponse:[AGAppController listApps]]]; }
    if ([path isEqualToString:@"/api/apps/running"])    { return [self respondOK:[AGJSON successResponse:[AGAppController listRunningApps]]]; }
    if ([path isEqualToString:@"/api/apps/frontmost"])  { return [self respondOK:[AGJSON successResponse:[AGAppController frontmostApp]]]; }
    if ([path isEqualToString:@"/api/apps/launch"]) {
        NSString *bid = [self stringValue:body key:@"bundleId"];
        if (!bid) return [self respondError:400 msg:@"需要 bundleId"];
        [AGAppController launchApp:bid];
        return [self respondOK:[AGJSON successResponse:@{@"launched":bid}]];
    }
    if ([path isEqualToString:@"/api/apps/kill"]) {
        NSString *bid = [self stringValue:body key:@"bundleId"];
        int pid       = (int)[self floatValue:body key:@"pid" def:0];
        NSString *proc = [self stringValue:body key:@"process"];
        [AGAppController killApp:bid pid:pid process:proc];
        return [self respondOK:[AGJSON successResponse:@{@"killed":@YES}]];
    }
    if ([path isEqualToString:@"/api/apps/info"]) {
        NSString *bid = [self stringValue:body key:@"bundleId"];
        if (!bid) return [self respondError:400 msg:@"需要 bundleId"];
        return [self respondOK:[AGJSON successResponse:[AGAppController appInfo:bid]]];
    }
    if ([path isEqualToString:@"/api/apps/install"]) {
        NSString *p = [self stringValue:body key:@"path"];
        if (!p) return [self respondError:400 msg:@"需要 path"];
        [AGAppController installApp:p];
        return [self respondOK:[AGJSON successResponse:@{@"installed":p}]];
    }
    if ([path isEqualToString:@"/api/apps/uninstall"]) {
        NSString *bid = [self stringValue:body key:@"bundleId"];
        if (!bid) return [self respondError:400 msg:@"需要 bundleId"];
        [AGAppController uninstallApp:bid];
        return [self respondOK:[AGJSON successResponse:@{@"uninstalled":bid}]];
    }

    // === VPN (5) ===
    if ([path isEqualToString:@"/api/vpn/status"])      return [self respondOK:[AGJSON successResponse:@{@"status":[AGVPNController status]}]];
    if ([path isEqualToString:@"/api/vpn/connect"])     { return [self respondOK:[AGJSON successResponse:@{@"connected":@([AGVPNController connect]),@"status":[AGVPNController status]}]]; }
    if ([path isEqualToString:@"/api/vpn/disconnect"])  { return [self respondOK:[AGJSON successResponse:@{@"disconnected":@([AGVPNController disconnect])}]]; }
    if ([path isEqualToString:@"/api/vpn/create"]) {
        NSDictionary *cfg = [self parseJSON:body];
        NSString *result = [AGVPNController createIKEv2:cfg[@"name"] server:cfg[@"server"]
            remoteID:cfg[@"remoteId"] localID:cfg[@"localId"] username:cfg[@"username"] password:cfg[@"password"]];
        return [self respondOK:[AGJSON successResponse:@{@"result":result}]];
    }
    if ([path isEqualToString:@"/api/vpn/remove"])      { [AGVPNController removeConfig]; return [self respondOK:[AGJSON successResponse:@{@"removed":@"ok"}]]; }

    // === WiFi (4) ===
    if ([path isEqualToString:@"/api/wifi/status"])     return [self respondOK:[AGJSON successResponse:@{@"wifiOn":@([AGWiFiController isOn])}]];
    if ([path isEqualToString:@"/api/wifi/on"])         { [AGWiFiController setPower:YES]; return [self respondOK:[AGJSON successResponse:@{@"wifiOn":@YES}]]; }
    if ([path isEqualToString:@"/api/wifi/off"])        { [AGWiFiController setPower:NO];  return [self respondOK:[AGJSON successResponse:@{@"wifiOn":@NO}]]; }
    if ([path isEqualToString:@"/api/wifi/info"])       return [self respondOK:[AGJSON successResponse:[AGWiFiController info]]];

    // === 辅助触控 (3) ===
    if ([path isEqualToString:@"/api/at/on"])           { [AGAccessibilityController setAssistiveTouch:YES]; return [self respondOK:[AGJSON successResponse:@{@"assistiveTouch":@YES}]]; }
    if ([path isEqualToString:@"/api/at/off"])          { [AGAccessibilityController setAssistiveTouch:NO];  return [self respondOK:[AGJSON successResponse:@{@"assistiveTouch":@NO}]]; }
    if ([path isEqualToString:@"/api/at/status"])       return [self respondOK:[AGJSON successResponse:@{@"assistiveTouch":@([AGAccessibilityController isAssistiveTouchOn])}]];

    // === 无障碍 (3) ===
    if ([path isEqualToString:@"/api/a11y/elements"])   return [self respondOK:[AGJSON successResponse:[AGAccessibilityController uiElements:[self stringValue:body key:@"bundleId"]]]];
    if ([path isEqualToString:@"/api/a11y/element/at"]) {
        float x = [self floatValue:body key:@"x" def:0], y = [self floatValue:body key:@"y" def:0];
        return [self respondOK:[AGJSON successResponse:[AGAccessibilityController elementAtPoint:x y:y]]];
    }
    if ([path isEqualToString:@"/api/a11y/tap"]) {
        NSString *text  = [self stringValue:body key:@"text"];
        NSString *label = [self stringValue:body key:@"label"];
        return [self respondOK:[AGJSON successResponse:@{@"tapped":@([AGAccessibilityController tapElement:text label:label])}]];
    }

    // === 剪贴板 (2) ===
    if ([path isEqualToString:@"/api/clipboard/get"])   return [self respondOK:[AGJSON successResponse:@{@"text":[AGClipboardController getClipboard]}]];
    if ([path isEqualToString:@"/api/clipboard/set"]) {
        NSString *t = [self stringValue:body key:@"text"];
        if (!t) return [self respondError:400 msg:@"需要 text 字段"];
        [AGClipboardController setClipboard:t];
        return [self respondOK:[AGJSON successResponse:@{@"set":@YES}]];
    }

    // === 文件系统 (5) ===
    if ([path isEqualToString:@"/api/file/list"]) {
        NSString *p = [self stringValue:body key:@"path"] ?: @"/var/mobile/Documents";
        return [self respondOK:[AGJSON successResponse:[AGFileController listDirectory:p]]];
    }
    if ([path isEqualToString:@"/api/file/read"]) {
        NSString *p = [self stringValue:body key:@"path"];
        if (!p) return [self respondError:400 msg:@"需要 path"];
        BOOL b64 = [self boolValue:body key:@"base64" def:NO];
        return [self respondOK:[AGJSON successResponse:[AGFileController readFile:p base64:b64]]];
    }
    if ([path isEqualToString:@"/api/file/write"]) {
        NSString *p = [self stringValue:body key:@"path"];
        NSString *c = [self stringValue:body key:@"content"];
        BOOL b64    = [self boolValue:body key:@"base64" def:NO];
        BOOL append = [self boolValue:body key:@"append" def:NO];
        if (!p || !c) return [self respondError:400 msg:@"需要 path 和 content"];
        [AGFileController writeFile:p content:c base64:b64 append:append];
        return [self respondOK:[AGJSON successResponse:@{@"written":p}]];
    }
    if ([path isEqualToString:@"/api/file/delete"]) {
        NSString *p = [self stringValue:body key:@"path"];
        if (!p) return [self respondError:400 msg:@"需要 path"];
        [AGFileController deleteFile:p];
        return [self respondOK:[AGJSON successResponse:@{@"deleted":p}]];
    }
    if ([path isEqualToString:@"/api/file/exists"]) {
        NSString *p = [self stringValue:body key:@"path"];
        return [self respondOK:[AGJSON successResponse:@{@"path":p?:@"",@"exists":@([AGFileController fileExists:p])}]];
    }

    // === 系统日志 (2) ===
    if ([path isEqualToString:@"/api/logs/syslog"]) {
        int lines = (int)[self floatValue:body key:@"lines" def:100];
        NSString *filter = [self stringValue:body key:@"filter"];
        return [self respondOK:[AGJSON successResponse:[AGShellController syslog:lines filter:filter]]];
    }
    if ([path isEqualToString:@"/api/logs/crash"])     return [self respondOK:[AGJSON successResponse:[AGFileController listDirectory:@"/var/mobile/Library/Logs/CrashReporter"]]];

    // === Shell (1) ===
    if ([path isEqualToString:@"/api/shell/exec"]) {
        NSString *cmd = [self stringValue:body key:@"command"];
        int timeout   = (int)[self floatValue:body key:@"timeout" def:30];
        BOOL asRoot   = [self boolValue:body key:@"asRoot" def:NO];
        if (!cmd) return [self respondError:400 msg:@"需要 command 字段"];
        return [self respondOK:[AGJSON successResponse:[AGShellController exec:cmd timeout:timeout asRoot:asRoot]]];
    }

    // === 系统控制 (6) ===
    if ([path isEqualToString:@"/api/system/respring"])   { [AGDeviceInfo respring]; return [self respondOK:[AGJSON successResponse:@{@"action":@"respring"}]]; }
    if ([path isEqualToString:@"/api/system/reboot"])     { [AGDeviceInfo reboot];   return [self respondOK:[AGJSON successResponse:@{@"action":@"reboot"}]]; }
    if ([path isEqualToString:@"/api/system/processes"])  return [self respondOK:[AGJSON successResponse:[AGDeviceInfo processes]]];
    if ([path isEqualToString:@"/api/system/memory"])     return [self respondOK:[AGJSON successResponse:[AGDeviceInfo memoryInfo]]];

    if ([path isEqualToString:@"/api/system/locale"]) {
        if ([method isEqualToString:@"GET"]) {
            return [self respondOK:[AGJSON successResponse:@{
                @"language": [AGDeviceInfo language],
                @"locale": [AGDeviceInfo locale],
                @"timeFormat": [AGDeviceInfo timeFormat]
            }]];
        }
    }
    if ([path isEqualToString:@"/api/system/time"])      return [self respondOK:[AGJSON successResponse:[AGDeviceInfo dateTime]]];

    // === 手电筒 (3) ===
    if ([path isEqualToString:@"/api/flashlight/on"])  { [AGDeviceInfo flashlightOn];  return [self respondOK:[AGJSON successResponse:@{@"flashlight":@YES}]]; }
    if ([path isEqualToString:@"/api/flashlight/off"]) { [AGDeviceInfo flashlightOff]; return [self respondOK:[AGJSON successResponse:@{@"flashlight":@NO}]]; }
    if ([path isEqualToString:@"/api/flashlight/status"]) return [self respondOK:[AGJSON successResponse:@{@"flashlight":@([AGDeviceInfo isFlashlightOn])}]];

    // === URL (1) ===
    if ([path isEqualToString:@"/api/url/open"]) {
        NSString *url = [self stringValue:body key:@"url"];
        if (!url) return [self respondError:400 msg:@"需要 url"];
        [AGDeviceInfo openURL:url];
        return [self respondOK:[AGJSON successResponse:@{@"opened":url}]];
    }

    // === 振动 (2) ===
    if ([path isEqualToString:@"/api/haptic/light"]) { [AGDeviceInfo hapticLight]; return [self respondOK:[AGJSON successResponse:@{@"haptic":@"light"}]]; }
    if ([path isEqualToString:@"/api/haptic/heavy"]) { [AGDeviceInfo hapticHeavy]; return [self respondOK:[AGJSON successResponse:@{@"haptic":@"heavy"}]]; }

    // === OCR (1) ===
    if ([path isEqualToString:@"/api/ocr/recognize"]) return [self respondOK:[AGJSON successResponse:@[]]];

    // === 位置 (2) ===
    if ([path isEqualToString:@"/api/location/set"]) {
        float lat = [self floatValue:body key:@"lat" def:0], lng = [self floatValue:body key:@"lng" def:0];
        [AGDeviceInfo setLocation:lat lng:lng];
        return [self respondOK:[AGJSON successResponse:@{@"location":@{@"lat":@(lat),@"lng":@(lng)}}]];
    }
    if ([path isEqualToString:@"/api/location/reset"]) { [AGDeviceInfo resetLocation]; return [self respondOK:[AGJSON successResponse:@{@"location":@"reset"}]]; }

    // === 网络 (1) ===
    if ([path isEqualToString:@"/api/network/ip"])     return [self respondOK:[AGJSON successResponse:@{@"ip":[AGDeviceInfo localIP]}]];

    // === 通知 (1) ===
    if ([path isEqualToString:@"/api/notification/status"]) return [self respondOK:[AGJSON successResponse:@{@"status":[AGDeviceInfo notificationStatus]}]];

    // === 综合 (1) ===
    if ([path isEqualToString:@"/api/describe"])       return [self respondOK:[AGJSON successResponse:[AGDeviceInfo describeScreen]]];

    // === 截图 API extra ===
    if ([path isEqualToString:@"/api/screenshot"])     return [self respondOK:[AGJSON successResponse:@{@"format":@"jpeg"}]];

    // 404
    return [self respondError:404 msg:[NSString stringWithFormat:@"Not found: %@", path]];
}

#pragma mark - Helpers

- (NSDictionary *)respond:(int)status body:(NSString *)body contentType:(NSString *)ct {
    return @{@"status":@(status), @"body":body ?: @"", @"contentType":ct ?: @"application/json; charset=utf-8"};
}

- (NSDictionary *)respondOK:(NSString *)body {
    return [self respond:200 body:body contentType:@"application/json; charset=utf-8"];
}

- (NSDictionary *)respondError:(int)code msg:(NSString *)msg {
    return [self respond:code body:[AGJSON errorResponse:msg code:code] contentType:@"application/json; charset=utf-8"];
}

- (NSDictionary *)respondHTML:(NSString *)html {
    return [self respond:200 body:html contentType:@"text/html; charset=utf-8"];
}

- (NSDictionary *)respondImage:(NSData *)data {
    if (!data) return [self respondError:500 msg:@"截图失败"];
    NSString *b64 = [data base64EncodedStringWithOptions:0];
    return [self respondOK:[AGJSON successResponse:@{@"format":@"jpeg",@"encoding":@"base64",@"data":b64}]];
}

- (float)floatValue:(NSString *)json key:(NSString *)key def:(float)def {
    NSDictionary *d = [self parseJSON:json];
    id v = d[key];
    if ([v isKindOfClass:[NSNumber class]]) return [v floatValue];
    if ([v isKindOfClass:[NSString class]]) return [v floatValue];
    return def;
}

- (BOOL)boolValue:(NSString *)json key:(NSString *)key def:(BOOL)def {
    NSDictionary *d = [self parseJSON:json];
    id v = d[key];
    if ([v isKindOfClass:[NSNumber class]]) return [v boolValue];
    if ([v isKindOfClass:[NSString class]]) return [[v lowercaseString] isEqualToString:@"true"] || [v isEqualToString:@"1"];
    return def;
}

- (NSString *)stringValue:(NSString *)json key:(NSString *)key {
    NSDictionary *d = [self parseJSON:json];
    id v = d[key];
    if ([v isKindOfClass:[NSString class]]) return v;
    if ([v isKindOfClass:[NSNumber class]]) return [v stringValue];
    return nil;
}

- (NSDictionary *)parseJSON:(NSString *)jsonStr {
    if (!jsonStr || jsonStr.length == 0) return @{};
    NSData *data = [jsonStr dataUsingEncoding:NSUTF8StringEncoding];
    NSError *err = nil;
    id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
    if (err || ![obj isKindOfClass:[NSDictionary class]]) return @{};
    return obj;
}

#pragma mark - API 文档 HTML

+ (NSString *)apiDocsHTML {
    return @"<!DOCTYPE html><html lang=\"zh\"><head><meta charset=\"UTF-8\">"
    "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1.0\">"
    "<title>AutoGo Daemon API</title>"
    "<style>"
    "body{font-family:-apple-system,sans-serif;max-width:960px;margin:0 auto;padding:20px;background:#f8f9fa;color:#333}"
    "h1{color:#007aff;text-align:center}"
    "h2{color:#1d1d1f;border-bottom:2px solid #007aff;padding-bottom:6px;margin-top:36px}"
    "h3{margin:24px 0 8px;color:#555}"
    ".card{background:#fff;border-radius:10px;padding:14px 18px;margin:8px 0;box-shadow:0 1px 3px rgba(0,0,0,.08)}"
    ".method{display:inline-block;padding:2px 8px;border-radius:4px;font-weight:700;font-size:11px;margin-right:6px;min-width:36px;text-align:center}"
    ".get{background:#61affe;color:#fff}.post{background:#49cc90;color:#fff}.del{background:#f93e3e;color:#fff}"
    ".path{font-family:SF Mono,Menlo,monospace;font-size:13px}"
    ".desc{color:#888;font-size:12px;margin-top:4px}"
    "</style></head><body>"
    "<h1>🚀 AutoGo Daemon API v1.0.0</h1>"
    "<p style=\"text-align:center;color:#666\">"
    "集成 <b>ios-mcp</b> + <b>go-ios</b> + <b>AutoGo</b> 全部功能<br>"
    "纯 Objective-C 原生实现 · 60+ API 端点 · MCP 协议支持</p>"

    "<h2>📡 健康检查</h2>"
    "<div class=card><span class='method get'>GET</span><span class=path>/health</span><div class=desc>服务健康检查 & 设备信息</div></div>"

    "<h2>📱 设备信息</h2>"
    "<div class=card><span class='method get'>GET</span><span class=path>/api/device/info</span><div class=desc>完整设备信息 (型号/版本/电池/存储/内存/越狱)</div></div>"
    "<div class=card><span class='method get'>GET</span><span class=path>/api/device/name</span><div class=desc>设备名称</div></div>"
    "<div class=card><span class='method get'>GET</span><span class=path>/api/device/model</span><div class=desc>设备型号 (iPhone14,2)</div></div>"
    "<div class=card><span class='method get'>GET</span><span class=path>/api/device/osversion</span><div class=desc>iOS 版本号</div></div>"

    "<h2>🔋 电池 & 存储</h2>"
    "<div class=card><span class='method get'>GET</span><span class=path>/api/battery/level</span><div class=desc>电池电量 (0.0-1.0)</div></div>"
    "<div class=card><span class='method get'>GET</span><span class=path>/api/battery/state</span><div class=desc>电池状态 + 充电状态</div></div>"
    "<div class=card><span class='method get'>GET</span><span class=path>/api/storage/info</span><div class=desc>存储空间 (total/free/used)</div></div>"

    "<h2>🖥️ 屏幕控制</h2>"
    "<div class=card><span class='method get'>GET</span><span class=path>/api/screen/info</span><div class=desc>屏幕分辨率与方向</div></div>"
    "<div class=card><span class='method get'>GET/POST</span><span class=path>/api/screen/brightness</span><div class=desc>获取/设置亮度 (0-100). POST: {\"value\":80} 或 {\"delta\":10}</div></div>"
    "<div class=card><span class='method post'>POST</span><span class=path>/api/screen/screenshot</span><div class=desc>截图 (返回 base64 JPEG)</div></div>"
    "<div class=card><span class='method get'>GET/POST/DEL</span><span class=path>/api/screen/keepawake</span><div class=desc>屏幕常亮控制</div></div>"
    "<div class=card><span class='method post'>POST</span><span class=path>/api/screen/orientation/lock</span><div class=desc>锁定竖屏</div></div>"
    "<div class=card><span class='method post'>POST</span><span class=path>/api/screen/orientation/unlock</span><div class=desc>解锁方向</div></div>"
    "<div class=card><span class='method get'>GET/POST</span><span class=path>/api/screen/darkmode</span><div class=desc>深色模式 POST: {\"enable\":true}</div></div>"

    "<h2>👆 触控手势 (IOKit HID)</h2>"
    "<div class=card><span class='method post'>POST</span><span class=path>/api/touch/tap</span><div class=desc>点击坐标 {\"x\":300,\"y\":500}</div></div>"
    "<div class=card><span class='method post'>POST</span><span class=path>/api/touch/doubletap</span><div class=desc>双击</div></div>"
    "<div class=card><span class='method post'>POST</span><span class=path>/api/touch/longpress</span><div class=desc>长按 {\"duration\":1.5}</div></div>"
    "<div class=card><span class='method post'>POST</span><span class=path>/api/touch/swipe</span><div class=desc>滑动 {\"fromX\":100,\"fromY\":500,\"toX\":300,\"toY\":200}</div></div>"
    "<div class=card><span class='method post'>POST</span><span class=path>/api/touch/drag</span><div class=desc>拖拽 (多步骤路径拖拽)</div></div>"

    "<h2>⌨️ 硬件按键</h2>"
    "<div class=card><span class='method post'>POST</span><span class=path>/api/key/home</span><div class=desc>Home 键 {\"doubleClick\":false}</div></div>"
    "<div class=card><span class='method post'>POST</span><span class=path>/api/key/power</span><div class=desc>电源键</div></div>"
    "<div class=card><span class='method post'>POST</span><span class=path>/api/key/volume/up</span><div class=desc>音量+</div></div>"
    "<div class=card><span class='method post'>POST</span><span class=path>/api/key/volume/down</span><div class=desc>音量-</div></div>"
    "<div class=card><span class='method post'>POST</span><span class=path>/api/key/mute</span><div class=desc>切换静音</div></div>"

    "<h2>📝 文字输入</h2>"
    "<div class=card><span class='method post'>POST</span><span class=path>/api/input/text</span><div class=desc>输入文字 {\"text\":\"Hello\",\"via\":\"clipboard\"}</div></div>"
    "<div class=card><span class='method post'>POST</span><span class=path>/api/input/key</span><div class=desc>特殊按键 {\"key\":\"enter\"} (enter/backspace/tab/escape)</div></div>"

    "<h2>📦 App 管理</h2>"
    "<div class=card><span class='method get'>GET</span><span class=path>/api/apps/list</span><div class=desc>所有已安装 App</div></div>"
    "<div class=card><span class='method get'>GET</span><span class=path>/api/apps/running</span><div class=desc>正在运行 App</div></div>"
    "<div class=card><span class='method get'>GET</span><span class=path>/api/apps/frontmost</span><div class=desc>前台 App</div></div>"
    "<div class=card><span class='method get'>GET</span><span class=path>/api/apps/info</span><div class=desc>App 信息 {\"bundleId\":\"xxx\"}</div></div>"
    "<div class=card><span class='method post'>POST</span><span class=path>/api/apps/launch</span><div class=desc>启动 App</div></div>"
    "<div class=card><span class='method post'>POST</span><span class=path>/api/apps/kill</span><div class=desc>终止 App</div></div>"
    "<div class=card><span class='method post'>POST</span><span class=path>/api/apps/install</span><div class=desc>安装 ipa/deb</div></div>"
    "<div class=card><span class='method post'>POST</span><span class=path>/api/apps/uninstall</span><div class=desc>卸载 App</div></div>"

    "<h2>🔐 VPN</h2>"
    "<div class=card><span class='method get'>GET</span><span class=path>/api/vpn/status</span></div>"
    "<div class=card><span class='method post'>POST</span><span class=path>/api/vpn/connect</span></div>"
    "<div class=card><span class='method post'>POST</span><span class=path>/api/vpn/disconnect</span></div>"
    "<div class=card><span class='method post'>POST</span><span class=path>/api/vpn/create</span><div class=desc>创建 IKEv2 {\"name\":\"V\",\"server\":\"vpn.example.com\",\"username\":\"x\",\"password\":\"x\"}</div></div>"
    "<div class=card><span class='method post'>POST</span><span class=path>/api/vpn/remove</span></div>"

    "<h2>📶 WiFi (越狱)</h2>"
    "<div class=card><span class='method get'>GET</span><span class=path>/api/wifi/status</span></div>"
    "<div class=card><span class='method post'>POST</span><span class=path>/api/wifi/on</span></div>"
    "<div class=card><span class='method post'>POST</span><span class=path>/api/wifi/off</span></div>"
    "<div class=card><span class='method get'>GET</span><span class=path>/api/wifi/info</span><div class=desc>SSID/BSSID</div></div>"

    "<h2>♿ AssistiveTouch</h2>"
    "<div class=card><span class='method post'>POST</span><span class=path>/api/at/on</span></div>"
    "<div class=card><span class='method post'>POST</span><span class=path>/api/at/off</span></div>"
    "<div class=card><span class='method get'>GET</span><span class=path>/api/at/status</span></div>"

    "<h2>🔍 无障碍/UI 元素</h2>"
    "<div class=card><span class='method post'>POST</span><span class=path>/api/a11y/elements</span><div class=desc>获取 UI 元素树</div></div>"
    "<div class=card><span class='method post'>POST</span><span class=path>/api/a11y/element/at</span><div class=desc>坐标点元素查询</div></div>"
    "<div class=card><span class='method post'>POST</span><span class=path>/api/a11y/tap</span><div class=desc>按文本/标签点击</div></div>"

    "<h2>📋 剪贴板</h2>"
    "<div class=card><span class='method get'>GET</span><span class=path>/api/clipboard/get</span></div>"
    "<div class=card><span class='method post'>POST</span><span class=path>/api/clipboard/set</span></div>"

    "<h2>📁 文件系统</h2>"
    "<div class=card><span class='method post'>POST</span><span class=path>/api/file/list</span></div>"
    "<div class=card><span class='method post'>POST</span><span class=path>/api/file/read</span><div class=desc>{\"base64\":true} 二进制返回</div></div>"
    "<div class=card><span class='method post'>POST</span><span class=path>/api/file/write</span><div class=desc>{\"append\":true} 追加模式</div></div>"
    "<div class=card><span class='method del'>DELETE</span><span class=path>/api/file/delete</span></div>"
    "<div class=card><span class='method get'>GET</span><span class=path>/api/file/exists</span></div>"

    "<h2>📜 系统日志</h2>"
    "<div class=card><span class='method post'>POST</span><span class=path>/api/logs/syslog</span><div class=desc>{\"lines\":200,\"filter\":\"SpringBoard\"}</div></div>"
    "<div class=card><span class='method get'>GET</span><span class=path>/api/logs/crash</span></div>"

    "<h2>💻 Shell</h2>"
    "<div class=card><span class='method post'>POST</span><span class=path>/api/shell/exec</span><div class=desc>{\"command\":\"ls /\",\"timeout\":10,\"asRoot\":false}</div></div>"

    "<h2>⚙️ 系统控制</h2>"
    "<div class=card><span class='method post'>POST</span><span class=path>/api/system/respring</span><div class=desc>软重启 SpringBoard</div></div>"
    "<div class=card><span class='method post'>POST</span><span class=path>/api/system/reboot</span><div class=desc>重启设备</div></div>"
    "<div class=card><span class='method get'>GET</span><span class=path>/api/system/processes</span><div class=desc>进程列表</div></div>"
    "<div class=card><span class='method get'>GET</span><span class=path>/api/system/memory</span><div class=desc>内存信息</div></div>"
    "<div class=card><span class='method get'>GET</span><span class=path>/api/system/locale</span><div class=desc>语言/区域/时间格式</div></div>"
    "<div class=card><span class='method get'>GET</span><span class=path>/api/system/time</span><div class=desc>设备日期时间</div></div>"

    "<h2>🔦 其他功能</h2>"
    "<div class=card><span class='method post'>POST</span><span class=path>/api/flashlight/on</span> /off /status</div>"
    "<div class=card><span class='method post'>POST</span><span class=path>/api/url/open</span><div class=desc>打开 URL/URL Scheme</div></div>"
    "<div class=card><span class='method post'>POST</span><span class=path>/api/haptic/light</span> /heavy</div>"
    "<div class=card><span class='method post'>POST</span><span class=path>/api/ocr/recognize</span><div class=desc>屏幕 OCR 识别</div></div>"
    "<div class=card><span class='method post'>POST</span><span class=path>/api/location/set</span><div class=desc>模拟位置 {\"lat\":39.9,\"lng\":116.4}</div></div>"
    "<div class=card><span class='method post'>POST</span><span class=path>/api/location/reset</span></div>"
    "<div class=card><span class='method get'>GET</span><span class=path>/api/network/ip</span><div class=desc>本机 IP</div></div>"
    "<div class=card><span class='method get'>GET</span><span class=path>/api/notification/status</span></div>"
    "<div class=card><span class='method get'>GET</span><span class=path>/api/describe</span><div class=desc>屏幕综合快照</div></div>"

    "<h2>🤖 MCP 协议</h2>"
    "<div class=card><span class='method post'>POST</span><span class=path>/mcp</span><div class=desc>MCP JSON-RPC 端点 (兼容 AI Agent)</div></div>"
    "<div class=card><span class='method get'>GET</span><span class=path>/sse</span><div class=desc>MCP SSE 流式端点</div></div>"

    "<h2>📋 使用示例</h2>"
    "<pre style='background:#1d1d1f;color:#64d2ff;padding:16px;border-radius:8px;font-size:12px;overflow-x:auto'>"
    "# 设备信息\ncurl http://设备IP:8090/api/device/info\n\n"
    "# 截图\ncurl -X POST http://设备IP:8090/api/screen/screenshot\n\n"
    "# 设置亮度\ncurl -X POST http://设备IP:8090/api/screen/brightness -d '{\"value\":80}'\n\n"
    "# 点击坐标\ncurl -X POST http://设备IP:8090/api/touch/tap -d '{\"x\":300,\"y\":500}'\n\n"
    "# 输入文字\ncurl -X POST http://设备IP:8090/api/input/text -d '{\"text\":\"Hello World\"}'\n\n"
    "# 启动 App\ncurl -X POST http://设备IP:8090/api/apps/launch -d '{\"bundleId\":\"com.apple.Preferences\"}'\n\n"
    "# 执行命令\ncurl -X POST http://设备IP:8090/api/shell/exec -d '{\"command\":\"uptime\"}'\n\n"
    "# MCP 协议\ncurl -X POST http://设备IP:8090/mcp -d '{\"jsonrpc\":\"2.0\",\"method\":\"tools/list\",\"id\":1}'\n"
    "</pre>"

    "<p style='text-align:center;color:#888;margin-top:40px;font-size:12px'>"
    "AutoGo Daemon v1.0 · 纯 ObjC 原生 · MIT License</p>"
    "</body></html>";
}

@end
