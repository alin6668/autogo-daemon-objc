//  AGHTTPServer.h - 轻量 HTTP 服务器 (BSD socket + GCD)

#import <Foundation/Foundation.h>

@class AGRouter;

@interface AGHTTPServer : NSObject

@property (nonatomic, weak) AGRouter *routeHandler;

- (instancetype)initWithPort:(int)port;
- (BOOL)start:(NSError **)error;
- (void)stop;

@end
