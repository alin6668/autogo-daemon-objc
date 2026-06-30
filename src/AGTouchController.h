//  AGTouchController.h - IOKit HID 触控模拟

#import <Foundation/Foundation.h>

@interface AGTouchController : NSObject

+ (void)tap:(float)x y:(float)y;
+ (void)doubleTap:(float)x y:(float)y;
+ (void)longPress:(float)x y:(float)y duration:(float)duration;
+ (void)swipe:(float)fromX fy:(float)fromY tx:(float)toX ty:(float)toY duration:(float)duration;
+ (void)drag:(float)fromX fy:(float)fromY tx:(float)toX ty:(float)toY duration:(float)duration steps:(int)steps;

@end
