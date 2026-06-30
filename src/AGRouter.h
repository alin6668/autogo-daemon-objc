//  AGRouter.h - API 路由分发

#import <Foundation/Foundation.h>

@interface AGRouter : NSObject

+ (instancetype)sharedRouter;
- (NSDictionary *)handleRequest:(NSDictionary *)request;

@end
