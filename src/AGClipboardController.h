//  AGClipboardController.h - 剪贴板读写

#import <Foundation/Foundation.h>

@interface AGClipboardController : NSObject

+ (NSString *)getClipboard;
+ (void)setClipboard:(NSString *)text;

@end
