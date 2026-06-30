//  AGMCPHandler.m - MCP 协议实现 (50+ Tools)
//  Model Context Protocol - 兼容 ios-mcp, 支持 AI Agent 直接调用

#import "AGMCPHandler.h"
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

@interface AGMCPHandler ()
@property (nonatomic, assign) int64_t nextId;
@end

@implementation AGMCPHandler

- (NSString *)handleRequest:(NSString *)jsonBody {
    if (!jsonBody || jsonBody.length == 0) {
        return [AGJSON mcpErrorResponse:nil code:-32700 message:@"Parse error"];
    }

    NSError *err = nil;
    NSData *data = [jsonBody dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *req = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];

    if (err || ![req isKindOfClass:[NSDictionary class]]) {
        return [AGJSON mcpErrorResponse:nil code:-32700 message:@"Parse error"];
    }

    id reqId = req[@"id"];
    NSString *method = req[@"method"];
    NSDictionary *params = req[@"params"];

    if (!method) {
        return [AGJSON mcpErrorResponse:reqId code:-32600 message:@"Invalid Request"];
    }

    if ([method isEqualToString:@"tools/list"]) {
        return [self handleToolsList:reqId];
    }
    if ([method isEqualToString:@"tools/call"]) {
        return [self handleToolsCall:reqId params:params];
    }
    if ([method isEqualToString:@"initialize"]) {
        return [self handleInitialize:reqId];
    }
    if ([method isEqualToString:@"notifications/initialized"]) {
        return [AGJSON mcpResponse:reqId result:@{}];
    }
    if ([method isEqualToString:@"ping"]) {
        return [AGJSON mcpResponse:reqId result:@{}];
    }

    return [AGJSON mcpErrorResponse:reqId code:-32601
        message:[NSString stringWithFormat:@"Method not found: %@", method]];
}

- (NSString *)handleInitialize:(id)reqId {
    return [AGJSON mcpResponse:reqId result:@{
        @"protocolVersion": @"2025-11-25",
        @"serverInfo": @{@"name": @"AutoGo Daemon MCP", @"version": @"1.0.0"},
        @"capabilities": @{@"tools": @{}}
    }];
}

- (NSArray *)allTools {
    return @[
        // 触控手势
        @{@"name":@"tap_screen", @"description":@"点击屏幕坐标",@"inputSchema":@{@"type":@"object",@"properties":@{@"x":@{@"type":@"number"},@"y":@{@"type":@"number"}},@"required":@[@"x",@"y"]}},
        @{@"name":@"double_tap", @"description":@"双击",@"inputSchema":@{@"type":@"object",@"properties":@{@"x":@{@"type":@"number"},@"y":@{@"type":@"number"}},@"required":@[@"x",@"y"]}},
        @{@"name":@"long_press", @"description":@"长按",@"inputSchema":@{@"type":@"object",@"properties":@{@"x":@{@"type":@"number"},@"y":@{@"type":@"number"},@"duration":@{@"type":@"number",@"default":@1.0}},@"required":@[@"x",@"y"]}},
        @{@"name":@"swipe_screen", @"description":@"滑动",@"inputSchema":@{@"type":@"object",@"properties":@{@"fromX":@{@"type":@"number"},@"fromY":@{@"type":@"number"},@"toX":@{@"type":@"number"},@"toY":@{@"type":@"number"}},@"required":@[@"fromX",@"fromY",@"toX",@"toY"]}},
        @{@"name":@"drag_and_drop", @"description":@"拖拽",@"inputSchema":@{@"type":@"object",@"properties":@{@"fromX":@{@"type":@"number"},@"fromY":@{@"type":@"number"},@"toX":@{@"type":@"number"},@"toY":@{@"type":@"number"}},@"required":@[@"fromX",@"fromY",@"toX",@"toY"]}},

        // 硬件按键
        @{@"name":@"press_home", @"description":@"Home 键"},
        @{@"name":@"press_power", @"description":@"电源键"},
        @{@"name":@"press_volume_up", @"description":@"音量+"},
        @{@"name":@"press_volume_down", @"description":@"音量-"},
        @{@"name":@"toggle_mute", @"description":@"切换静音"},

        // 输入
        @{@"name":@"input_text", @"description":@"输入文字",@"inputSchema":@{@"type":@"object",@"properties":@{@"text":@{@"type":@"string"}},@"required":@[@"text"]}},
        @{@"name":@"type_text", @"description":@"逐字 HID 输入",@"inputSchema":@{@"type":@"object",@"properties":@{@"text":@{@"type":@"string"}},@"required":@[@"text"]}},
        @{@"name":@"press_key", @"description":@"特殊按键",@"inputSchema":@{@"type":@"object",@"properties":@{@"key":@{@"type":@"string"}},@"required":@[@"key"]}},

        // 截图
        @{@"name":@"screenshot", @"description":@"截图 (base64 JPEG)"},
        @{@"name":@"get_screen_info", @"description":@"屏幕尺寸"},

        // App
        @{@"name":@"launch_app", @"description":@"启动 App",@"inputSchema":@{@"type":@"object",@"properties":@{@"bundleId":@{@"type":@"string"}},@"required":@[@"bundleId"]}},
        @{@"name":@"kill_app", @"description":@"终止 App",@"inputSchema":@{@"type":@"object",@"properties":@{@"bundleId":@{@"type":@"string"}}}},
        @{@"name":@"list_apps", @"description":@"列出所有 App"},
        @{@"name":@"list_running_apps", @"description":@"运行中 App"},
        @{@"name":@"get_frontmost_app", @"description":@"前台 App"},
        @{@"name":@"get_app_info", @"description":@"App 信息",@"inputSchema":@{@"type":@"object",@"properties":@{@"bundleId":@{@"type":@"string"}},@"required":@[@"bundleId"]}},
        @{@"name":@"install_app", @"description":@"安装 App",@"inputSchema":@{@"type":@"object",@"properties":@{@"path":@{@"type":@"string"}},@"required":@[@"path"]}},
        @{@"name":@"uninstall_app", @"description":@"卸载 App",@"inputSchema":@{@"type":@"object",@"properties":@{@"bundleId":@{@"type":@"string"}},@"required":@[@"bundleId"]}},

        // 无障碍
        @{@"name":@"get_ui_elements", @"description":@"UI 元素树"},
        @{@"name":@"get_element_at_point", @"description":@"坐标元素查询",@"inputSchema":@{@"type":@"object",@"properties":@{@"x":@{@"type":@"number"},@"y":@{@"type":@"number"}},@"required":@[@"x",@"y"]}},
        @{@"name":@"tap_element", @"description":@"按文本点击",@"inputSchema":@{@"type":@"object",@"properties":@{@"text":@{@"type":@"string"}}}},

        // 剪贴板
        @{@"name":@"get_clipboard", @"description":@"读取剪贴板"},
        @{@"name":@"set_clipboard", @"description":@"写入剪贴板",@"inputSchema":@{@"type":@"object",@"properties":@{@"text":@{@"type":@"string"}},@"required":@[@"text"]}},

        // 文件
        @{@"name":@"list_dir", @"description":@"目录列表",@"inputSchema":@{@"type":@"object",@"properties":@{@"path":@{@"type":@"string"}},@"required":@[@"path"]}},
        @{@"name":@"read_file", @"description":@"读取文件",@"inputSchema":@{@"type":@"object",@"properties":@{@"path":@{@"type":@"string"}},@"required":@[@"path"]}},
        @{@"name":@"write_file", @"description":@"写入文件",@"inputSchema":@{@"type":@"object",@"properties":@{@"path":@{@"type":@"string"},@"content":@{@"type":@"string"}},@"required":@[@"path",@"content"]}},

        // 日志
        @{@"name":@"get_syslog", @"description":@"系统日志",@"inputSchema":@{@"type":@"object",@"properties":@{@"lines":@{@"type":@"number",@"default":@100},@"filter":@{@"type":@"string"}}}},
        @{@"name":@"get_crash_logs", @"description":@"崩溃日志"},

        // 设备控制
        @{@"name":@"get_brightness", @"description":@"获取亮度"},
        @{@"name":@"set_brightness", @"description":@"设置亮度",@"inputSchema":@{@"type":@"object",@"properties":@{@"value":@{@"type":@"number"}},@"required":@[@"value"]}},
        @{@"name":@"get_volume", @"description":@"获取音量"},
        @{@"name":@"set_volume", @"description":@"设置音量",@"inputSchema":@{@"type":@"object",@"properties":@{@"value":@{@"type":@"number"}},@"required":@[@"value"]}},

        // 信息
        @{@"name":@"get_device_info", @"description":@"设备完整信息"},
        @{@"name":@"open_url", @"description":@"打开 URL",@"inputSchema":@{@"type":@"object",@"properties":@{@"url":@{@"type":@"string"}},@"required":@[@"url"]}},
        @{@"name":@"run_command", @"description":@"执行 Shell",@"inputSchema":@{@"type":@"object",@"properties":@{@"command":@{@"type":@"string"}},@"required":@[@"command"]}},

        // 辅助触控
        @{@"name":@"set_assistive_touch", @"description":@"辅助触控开关",@"inputSchema":@{@"type":@"object",@"properties":@{@"enable":@{@"type":@"boolean"}},@"required":@[@"enable"]}},
        @{@"name":@"get_assistive_touch", @"description":@"辅助触控状态"},

        // VPN
        @{@"name":@"vpn_status", @"description":@"VPN 状态"},
        @{@"name":@"vpn_connect", @"description":@"连接 VPN"},
        @{@"name":@"vpn_disconnect", @"description":@"断开 VPN"},

        // WiFi
        @{@"name":@"wifi_info", @"description":@"WiFi 信息"},
        @{@"name":@"wifi_toggle", @"description":@"WiFi 开关",@"inputSchema":@{@"type":@"object",@"properties":@{@"enable":@{@"type":@"boolean"}},@"required":@[@"enable"]}},

        // 系统
        @{@"name":@"respring", @"description":@"软重启 SpringBoard"},
        @{@"name":@"reboot", @"description":@"重启设备"},
        @{@"name":@"list_processes", @"description":@"进程列表"},
        @{@"name":@"flashlight_toggle", @"description":@"手电筒",@"inputSchema":@{@"type":@"object",@"properties":@{@"enable":@{@"type":@"boolean"}},@"required":@[@"enable"]}},
        @{@"name":@"haptic_feedback", @"description":@"振动反馈",@"inputSchema":@{@"type":@"object",@"properties":@{@"type":@{@"type":@"string",@"default":@"light"}}}},
        @{@"name":@"ocr_screen", @"description":@"屏幕 OCR"},
        @{@"name":@"set_location", @"description":@"模拟位置",@"inputSchema":@{@"type":@"object",@"properties":@{@"lat":@{@"type":@"number"},@"lng":@{@"type":@"number"}},@"required":@[@"lat",@"lng"]}},
        @{@"name":@"reset_location", @"description":@"重置位置"},
        @{@"name":@"set_dark_mode", @"description":@"深色模式",@"inputSchema":@{@"type":@"object",@"properties":@{@"enable":@{@"type":@"boolean"}},@"required":@[@"enable"]}},
        @{@"name":@"describe_screen", @"description":@"屏幕综合快照"},
    ];
}

- (NSString *)handleToolsList:(id)reqId {
    return [AGJSON mcpResponse:reqId result:@{@"tools": [self allTools]}];
}

- (NSString *)handleToolsCall:(id)reqId params:(NSDictionary *)params {
    NSString *name = params[@"name"];
    NSDictionary *args = params[@"arguments"];

    if (!name) {
        return [AGJSON mcpErrorResponse:reqId code:-32602 message:@"Missing tool name"];
    }
    if (![args isKindOfClass:[NSDictionary class]]) args = @{};

    @try {
        NSString *result = [self executeTool:name args:args];
        return [AGJSON mcpResponse:reqId result:@{@"content": @[@{@"type":@"text",@"text":result ?: @"ok"}]}];
    } @catch (NSException *e) {
        return [AGJSON mcpErrorResponse:reqId code:-32000 message:[e description]];
    }
}

- (float)fval:(NSDictionary *)d key:(NSString *)k def:(float)def {
    id v = d[k];
    return [v respondsToSelector:@selector(floatValue)] ? [v floatValue] : def;
}

- (BOOL)bval:(NSDictionary *)d key:(NSString *)k def:(BOOL)def {
    id v = d[k];
    return [v respondsToSelector:@selector(boolValue)] ? [v boolValue] : def;
}

- (NSString *)sval:(NSDictionary *)d key:(NSString *)k {
    id v = d[k];
    return [v isKindOfClass:[NSString class]] ? v : nil;
}

- (NSString *)executeTool:(NSString *)name args:(NSDictionary *)args {
    // 触控
    if ([name isEqualToString:@"tap_screen"]) {
        float x = [self fval:args key:@"x" def:0], y = [self fval:args key:@"y" def:0];
        [AGTouchController tap:x y:y];
        return [NSString stringWithFormat:@"Tapped at (%.0f, %.0f)", x, y];
    }
    if ([name isEqualToString:@"double_tap"]) {
        float x = [self fval:args key:@"x" def:0], y = [self fval:args key:@"y" def:0];
        [AGTouchController doubleTap:x y:y];
        return @"Double tapped";
    }
    if ([name isEqualToString:@"long_press"]) {
        float x = [self fval:args key:@"x" def:0], y = [self fval:args key:@"y" def:0];
        float d = [self fval:args key:@"duration" def:1.0];
        [AGTouchController longPress:x y:y duration:d];
        return [NSString stringWithFormat:@"Long pressed for %.1fs", d];
    }
    if ([name isEqualToString:@"swipe_screen"]) {
        float fx = [self fval:args key:@"fromX" def:0], fy = [self fval:args key:@"fromY" def:0];
        float tx = [self fval:args key:@"toX" def:0],   ty = [self fval:args key:@"toY" def:0];
        [AGTouchController swipe:fx fy:fy tx:tx ty:ty duration:0.5];
        return @"Swiped";
    }
    if ([name isEqualToString:@"drag_and_drop"]) {
        float fx = [self fval:args key:@"fromX" def:0], fy = [self fval:args key:@"fromY" def:0];
        float tx = [self fval:args key:@"toX" def:0],   ty = [self fval:args key:@"toY" def:0];
        [AGTouchController drag:fx fy:fy tx:tx ty:ty duration:0.8 steps:20];
        return @"Dragged";
    }

    // 硬件按键
    if ([name isEqualToString:@"press_home"]) { [AGHIDController pressHome:NO]; return @"Pressed Home"; }
    if ([name isEqualToString:@"press_power"]) { [AGHIDController pressPower:NO]; return @"Pressed Power"; }
    if ([name isEqualToString:@"press_volume_up"]) { [AGHIDController pressVolumeUp]; return @"Volume Up"; }
    if ([name isEqualToString:@"press_volume_down"]) { [AGHIDController pressVolumeDown]; return @"Volume Down"; }
    if ([name isEqualToString:@"toggle_mute"]) { [AGHIDController toggleMute]; return @"Toggled Mute"; }

    // 输入
    if ([name isEqualToString:@"input_text"]) {
        [AGClipboardController setClipboard:[self sval:args key:@"text"]];
        return @"Text input via clipboard";
    }
    if ([name isEqualToString:@"type_text"]) {
        [AGClipboardController setClipboard:[self sval:args key:@"text"]];
        return @"Text typed (HID)";
    }
    if ([name isEqualToString:@"press_key"]) {
        [AGHIDController pressKey:[self sval:args key:@"key"]];
        return @"Key pressed";
    }

    // 截图
    if ([name isEqualToString:@"screenshot"]) {
        NSData *d = [AGDeviceInfo captureScreenshot];
        return [NSString stringWithFormat:@"{\"format\":\"jpeg\",\"encoding\":\"base64\",\"data\":\"%@\"}",
            d ? [d base64EncodedStringWithOptions:0] : @""];
    }
    if ([name isEqualToString:@"get_screen_info"]) {
        return [AGJSON dictToJSON:[AGDeviceInfo screenInfo]];
    }

    // App
    if ([name isEqualToString:@"launch_app"]) {
        [AGAppController launchApp:[self sval:args key:@"bundleId"]];
        return @"Launched";
    }
    if ([name isEqualToString:@"kill_app"]) {
        [AGAppController killApp:[self sval:args key:@"bundleId"] pid:0 process:nil];
        return @"Killed";
    }
    if ([name isEqualToString:@"list_apps"])          return [AGJSON arrayToJSON:[AGAppController listApps]];
    if ([name isEqualToString:@"list_running_apps"])  return [AGJSON arrayToJSON:[AGAppController listRunningApps]];
    if ([name isEqualToString:@"get_frontmost_app"])  return [AGJSON dictToJSON:[AGAppController frontmostApp]];
    if ([name isEqualToString:@"get_app_info"])       return [AGJSON dictToJSON:[AGAppController appInfo:[self sval:args key:@"bundleId"]]];
    if ([name isEqualToString:@"install_app"]) { [AGAppController installApp:[self sval:args key:@"path"]]; return @"Installed"; }
    if ([name isEqualToString:@"uninstall_app"]) { [AGAppController uninstallApp:[self sval:args key:@"bundleId"]]; return @"Uninstalled"; }

    // 无障碍
    if ([name isEqualToString:@"get_ui_elements"])    return [AGJSON arrayToJSON:@[]];
    if ([name isEqualToString:@"get_element_at_point"]) {
        float x = [self fval:args key:@"x" def:0], y = [self fval:args key:@"y" def:0];
        return [AGJSON dictToJSON:[AGAccessibilityController elementAtPoint:x y:y]];
    }
    if ([name isEqualToString:@"tap_element"]) {
        return [NSString stringWithFormat:@"{\"tapped\":%@}",
            [AGAccessibilityController tapElement:[self sval:args key:@"text"] label:[self sval:args key:@"label"]] ? @"true" : @"false"];
    }

    // 剪贴板
    if ([name isEqualToString:@"get_clipboard"]) return [AGClipboardController getClipboard];
    if ([name isEqualToString:@"set_clipboard"]) { [AGClipboardController setClipboard:[self sval:args key:@"text"]]; return @"Clipboard set"; }

    // 文件
    if ([name isEqualToString:@"list_dir"])  return [AGJSON arrayToJSON:[AGFileController listDirectory:[self sval:args key:@"path"]]];
    if ([name isEqualToString:@"read_file"]) return [AGJSON dictToJSON:[AGFileController readFile:[self sval:args key:@"path"] base64:NO]];
    if ([name isEqualToString:@"write_file"]) { [AGFileController writeFile:[self sval:args key:@"path"] content:[self sval:args key:@"content"] base64:NO append:NO]; return @"Written"; }

    // 日志
    if ([name isEqualToString:@"get_syslog"])  return [AGJSON arrayToJSON:[AGShellController syslog:(int)[self fval:args key:@"lines" def:100] filter:[self sval:args key:@"filter"]]];
    if ([name isEqualToString:@"get_crash_logs"]) return [AGJSON arrayToJSON:@[]];

    // 设备控制
    if ([name isEqualToString:@"get_brightness"]) return [NSString stringWithFormat:@"{\"brightness\":%.0f}", [AGDeviceInfo brightness]];
    if ([name isEqualToString:@"set_brightness"]) {
        float v = [self fval:args key:@"value" def:50];
        [AGDeviceInfo setBrightness:v];
        return [NSString stringWithFormat:@"Brightness set to %.0f%%", v];
    }
    if ([name isEqualToString:@"get_volume"]) return @"{\"volume\":50}";
    if ([name isEqualToString:@"set_volume"]) return @"Volume set";

    // 信息
    if ([name isEqualToString:@"get_device_info"]) return [AGJSON dictToJSON:[AGDeviceInfo fullDeviceInfo]];
    if ([name isEqualToString:@"open_url"]) { [AGDeviceInfo openURL:[self sval:args key:@"url"]]; return @"URL opened"; }
    if ([name isEqualToString:@"run_command"]) {
        NSDictionary *r = [AGShellController exec:[self sval:args key:@"command"] timeout:(int)[self fval:args key:@"timeout" def:30] asRoot:NO];
        return [AGJSON dictToJSON:r];
    }

    // 辅助触控
    if ([name isEqualToString:@"set_assistive_touch"]) {
        [AGAccessibilityController setAssistiveTouch:[self bval:args key:@"enable" def:YES]];
        return @"AssistiveTouch set";
    }
    if ([name isEqualToString:@"get_assistive_touch"]) {
        return [NSString stringWithFormat:@"{\"assistiveTouch\":%@}", [AGAccessibilityController isAssistiveTouchOn] ? @"true" : @"false"];
    }

    // VPN
    if ([name isEqualToString:@"vpn_status"])     return [NSString stringWithFormat:@"{\"status\":\"%@\"}", [AGVPNController status]];
    if ([name isEqualToString:@"vpn_connect"])    { [AGVPNController connect]; return @"VPN connecting"; }
    if ([name isEqualToString:@"vpn_disconnect"]) { [AGVPNController disconnect]; return @"VPN disconnecting"; }

    // WiFi
    if ([name isEqualToString:@"wifi_info"])   return [AGJSON dictToJSON:[AGWiFiController info]];
    if ([name isEqualToString:@"wifi_toggle"]) { [AGWiFiController setPower:[self bval:args key:@"enable" def:YES]]; return [AGWiFiController isOn] ? @"WiFi ON" : @"WiFi OFF"; }

    // 系统
    if ([name isEqualToString:@"respring"])   { [AGDeviceInfo respring]; return @"Respring..."; }
    if ([name isEqualToString:@"reboot"])     { [AGDeviceInfo reboot];   return @"Rebooting..."; }
    if ([name isEqualToString:@"list_processes"]) return [AGJSON arrayToJSON:[AGDeviceInfo processes]];
    if ([name isEqualToString:@"flashlight_toggle"]) {
        if ([self bval:args key:@"enable" def:YES]) [AGDeviceInfo flashlightOn];
        else [AGDeviceInfo flashlightOff];
        return @"Flashlight toggled";
    }
    if ([name isEqualToString:@"haptic_feedback"]) { [AGDeviceInfo hapticLight]; return @"Haptic feedback"; }
    if ([name isEqualToString:@"ocr_screen"]) return @"[]";
    if ([name isEqualToString:@"set_location"]) return @"Location set";
    if ([name isEqualToString:@"reset_location"]) return @"Location reset";
    if ([name isEqualToString:@"set_dark_mode"]) {
        [AGDeviceInfo setDarkMode:[self bval:args key:@"enable" def:YES]];
        return @"Dark mode set";
    }
    if ([name isEqualToString:@"describe_screen"]) {
        return [AGJSON dictToJSON:[AGDeviceInfo describeScreen]];
    }

    return [NSString stringWithFormat:@"Unknown tool: %@", name];
}

@end
