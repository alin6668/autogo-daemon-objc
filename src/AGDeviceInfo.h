//  AGDeviceInfo.h - 设备信息/屏幕/电池/存储/系统控制

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface AGDeviceInfo : NSObject

// 设备标识
+ (NSString *)deviceName;
+ (NSString *)deviceModel;
+ (NSString *)systemVersion;
+ (NSString *)localIP;

// 电池
+ (float)batteryLevel;
+ (NSString *)batteryState;
+ (BOOL)isCharging;

// 存储
+ (NSDictionary *)storageInfo;

// 屏幕
+ (NSDictionary *)screenInfo;
+ (float)brightness;
+ (void)setBrightness:(float)percent;
+ (NSData *)captureScreenshot;
+ (void)keepScreenOn;
+ (void)allowScreenOff;
+ (BOOL)isScreenKeptOn;
+ (void)lockOrientation:(BOOL)lock;
+ (BOOL)isDarkMode;
+ (void)setDarkMode:(BOOL)on;

// 系统控制
+ (void)respring;
+ (void)reboot;
+ (NSArray *)processes;
+ (NSDictionary *)memoryInfo;
+ (NSString *)language;
+ (NSString *)locale;
+ (NSString *)timeFormat;
+ (NSDictionary *)dateTime;

// 手电筒
+ (void)flashlightOn;
+ (void)flashlightOff;
+ (BOOL)isFlashlightOn;

// URL
+ (void)openURL:(NSString *)url;

// 振动
+ (void)hapticLight;
+ (void)hapticHeavy;

// 位置
+ (void)setLocation:(float)lat lng:(float)lng;
+ (void)resetLocation;

// 通知
+ (NSString *)notificationStatus;

// 综合
+ (NSDictionary *)fullDeviceInfo;
+ (NSDictionary *)describeScreen;

@end
