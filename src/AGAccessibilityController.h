//  AGAccessibilityController.h - 辅助触控 & 无障碍

#import <Foundation/Foundation.h>

@interface AGAccessibilityController : NSObject

// AssistiveTouch
+ (void)setAssistiveTouch:(BOOL)on;
+ (BOOL)isAssistiveTouchOn;

// 无障碍
+ (NSArray *)uiElements:(NSString *)bundleID;
+ (NSDictionary *)elementAtPoint:(float)x y:(float)y;
+ (BOOL)tapElement:(NSString *)text label:(NSString *)label;

@end
