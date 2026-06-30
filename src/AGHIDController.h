//  AGHIDController.h - 硬件按键模拟

#import <Foundation/Foundation.h>

@interface AGHIDController : NSObject

+ (void)pressHome:(BOOL)doubleClick;
+ (void)pressPower:(BOOL)longPress;
+ (void)pressVolumeUp;
+ (void)pressVolumeDown;
+ (void)toggleMute;
+ (void)pressKey:(NSString *)key;

@end
