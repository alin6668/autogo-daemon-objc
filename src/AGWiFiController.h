//  AGWiFiController.h - WiFi 控制 (MobileWiFi 私有框架)

#import <Foundation/Foundation.h>

@interface AGWiFiController : NSObject

+ (BOOL)isOn;
+ (void)setPower:(BOOL)on;
+ (NSDictionary *)info;

@end
