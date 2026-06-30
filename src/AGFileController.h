//  AGFileController.h - 文件系统操作

#import <Foundation/Foundation.h>

@interface AGFileController : NSObject

+ (NSArray *)listDirectory:(NSString *)path;
+ (NSDictionary *)readFile:(NSString *)path base64:(BOOL)base64;
+ (void)writeFile:(NSString *)path content:(NSString *)content base64:(BOOL)base64 append:(BOOL)append;
+ (void)deleteFile:(NSString *)path;
+ (BOOL)fileExists:(NSString *)path;

@end
