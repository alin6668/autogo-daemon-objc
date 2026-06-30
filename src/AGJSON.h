//  AGJSON.h - 轻量 JSON 构造器
//  不依赖外部库，仅使用 Foundation

#import <Foundation/Foundation.h>

@interface AGJSON : NSObject

// 构造 JSON 字符串
+ (NSString *)dictToJSON:(NSDictionary *)dict;
+ (NSString *)arrayToJSON:(NSArray *)array;
+ (NSString *)escapeString:(NSString *)s;

// API 响应
+ (NSString *)successResponse:(id)data;
+ (NSString *)errorResponse:(NSString *)msg code:(int)code;

// MCP 响应
+ (NSString *)mcpResponse:(id)reqId result:(id)result;
+ (NSString *)mcpErrorResponse:(id)reqId code:(int)code message:(NSString *)msg;

@end
