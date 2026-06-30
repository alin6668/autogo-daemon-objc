//  AGClipboardController.m - 剪贴板实现

#import "AGClipboardController.h"
#import <UIKit/UIKit.h>

@implementation AGClipboardController

+ (NSString *)getClipboard {
    return [UIPasteboard generalPasteboard].string ?: @"";
}

+ (void)setClipboard:(NSString *)text {
    if (text) {
        [UIPasteboard generalPasteboard].string = text;
    }
}

@end
