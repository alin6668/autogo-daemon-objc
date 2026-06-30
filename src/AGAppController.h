//  AGAppController.h - App 管理 (启动/终止/安装/卸载/查询)

#import <Foundation/Foundation.h>

@interface AGAppController : NSObject

+ (NSArray *)listApps;
+ (NSArray *)listRunningApps;
+ (NSDictionary *)frontmostApp;
+ (void)launchApp:(NSString *)bundleID;
+ (void)killApp:(NSString *)bundleID pid:(int)pid process:(NSString *)process;
+ (NSDictionary *)appInfo:(NSString *)bundleID;
+ (void)installApp:(NSString *)path;
+ (void)uninstallApp:(NSString *)bundleID;

@end
