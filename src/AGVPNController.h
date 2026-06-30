//  AGVPNController.h - VPN 控制 (IKEv2 创建/连接/断开)

#import <Foundation/Foundation.h>

@interface AGVPNController : NSObject

+ (NSString *)status;
+ (BOOL)connect;
+ (BOOL)disconnect;
+ (NSString *)createIKEv2:(NSString *)name server:(NSString *)server
    remoteID:(NSString *)remoteID localID:(NSString *)localID
    username:(NSString *)username password:(NSString *)password;
+ (void)removeConfig;

@end
