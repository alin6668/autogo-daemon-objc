//  AGMCPHandler.h - MCP 协议实现 (Model Context Protocol)

#import <Foundation/Foundation.h>

@interface AGMCPHandler : NSObject

- (NSString *)handleRequest:(NSString *)jsonBody;

@end
