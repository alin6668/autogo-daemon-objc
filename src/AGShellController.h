//  AGShellController.h - Shell 命令执行与系统日志

#import <Foundation/Foundation.h>

@interface AGShellController : NSObject

+ (NSDictionary *)exec:(NSString *)command timeout:(int)timeout asRoot:(BOOL)asRoot;
+ (NSArray *)syslog:(int)lines filter:(NSString *)filter;

@end
