//  AGHIDController.m - 硬件按键实现 (通过 activator 或 shell)

#import "AGHIDController.h"

@implementation AGHIDController

+ (void)pressHome:(BOOL)doubleClick {
    if (doubleClick) {
        [self activatorEvent:@"libactivator.system.home-button"];
        usleep(100000);
        [self activatorEvent:@"libactivator.system.home-button"];
    } else {
        [self activatorEvent:@"libactivator.system.home-button"];
    }
}

+ (void)pressPower:(BOOL)longPress {
    if (longPress) {
        [self activatorEvent:@"libactivator.system.sleep-button.long-hold"];
    } else {
        [self activatorEvent:@"libactivator.system.sleep-button"];
    }
}

+ (void)pressVolumeUp {
    [self activatorEvent:@"libactivator.system.volume-up"];
}

+ (void)pressVolumeDown {
    [self activatorEvent:@"libactivator.system.volume-down"];
}

+ (void)toggleMute {
    [self activatorEvent:@"libactivator.system.mute-switch"];
}

+ (void)pressKey:(NSString *)key {
    if (!key) return;
    NSString *event = nil;
    if ([key isEqualToString:@"enter"] || [key isEqualToString:@"return"]) {
        event = @"libactivator.system.return-key";
    } else if ([key isEqualToString:@"backspace"] || [key isEqualToString:@"delete"]) {
        event = @"libactivator.system.backspace-key";
    } else if ([key isEqualToString:@"tab"]) {
        event = @"libactivator.system.tab-key";
    } else if ([key isEqualToString:@"escape"]) {
        event = @"libactivator.system.escape-key";
    } else if ([key isEqualToString:@"space"]) {
        event = @"libactivator.system.space-key";
    }
    if (event) {
        [self activatorEvent:event];
    }
}

+ (void)activatorEvent:(NSString *)event {
    // 方式 1: activator 命令行
    system([[NSString stringWithFormat:@"activator send %@ 2>/dev/null", event] UTF8String]);

    // 方式 2: 直接使用 GSEvent (春秋兼容)
    // GSSendSystemEvent 在 CoreGraphics 中，也可使用
}

@end
