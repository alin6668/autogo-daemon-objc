//  AGAccessibilityController.m - 辅助触控 & 无障碍实现

#import "AGAccessibilityController.h"
#import "AGJailbreak.h"
#import <notify.h>

@implementation AGAccessibilityController

#pragma mark - AssistiveTouch

+ (void)setAssistiveTouch:(BOOL)on {
    id val = on ? (id)kCFBooleanTrue : (id)kCFBooleanFalse;
    // CFPreferences 写入
    CFPreferencesSetAppValue(CFSTR("AssistiveTouchEnabledByiTunes"), (__bridge CFPropertyListRef)val,
        CFSTR("com.apple.Accessibility"));
    CFPreferencesSetAppValue(CFSTR("AssistiveTouchEnabled"), (__bridge CFPropertyListRef)val,
        CFSTR("com.apple.Accessibility"));
    CFPreferencesAppSynchronize(CFSTR("com.apple.Accessibility"));

    CFPreferencesSetAppValue(CFSTR("AssistiveTouchEnabledByiTunes"), (__bridge CFPropertyListRef)val,
        CFSTR("com.apple.mobile.accessibility"));
    CFPreferencesAppSynchronize(CFSTR("com.apple.mobile.accessibility"));

    // 直接写 plist
    [self writeATPLists:on];

    // Darwin 通知
    notify_post("com.apple.accessibility.cache");
    notify_post("com.apple.Accessibility.SettingsChanged");
}

+ (BOOL)isAssistiveTouchOn {
    CFBooleanRef v = CFPreferencesCopyAppValue(CFSTR("AssistiveTouchEnabledByiTunes"),
        CFSTR("com.apple.Accessibility"));
    BOOL on = v ? CFBooleanGetValue(v) : NO;
    if (v) CFRelease(v);
    return on;
}

+ (void)writeATPLists:(BOOL)on {
    NSArray *paths = @[
        @"/var/mobile/Library/Preferences/com.apple.Accessibility.plist",
        ag_jbpath(@"var/mobile/Library/Preferences/com.apple.Accessibility.plist")
    ];

    for (NSString *path in paths) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:path];
        if (!dict) dict = [NSMutableDictionary dictionary];
        dict[@"AssistiveTouchEnabledByiTunes"] = @(on);
        dict[@"AssistiveTouchEnabled"] = @(on);
        [dict writeToFile:path atomically:YES];
    }
}

#pragma mark - 无障碍

+ (NSArray *)uiElements:(NSString *)bundleID {
    // 需要 AccessibilityUtilities 私有框架
    // 参考 ios-mcp AccessibilityManager 实现
    return @[];
}

+ (NSDictionary *)elementAtPoint:(float)x y:(float)y {
    return @{@"x":@(x), @"y":@(y)};
}

+ (BOOL)tapElement:(NSString *)text label:(NSString *)label {
    return NO;
}

@end
