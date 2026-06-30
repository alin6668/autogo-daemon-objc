//  AGJSON.m - 轻量 JSON 构造器实现

#import "AGJSON.h"

@implementation AGJSON

+ (NSString *)escapeString:(NSString *)s {
    if (!s) return @"null";
    NSMutableString *ms = [s mutableCopy];
    [ms replaceOccurrencesOfString:@"\\" withString:@"\\\\" options:0 range:NSMakeRange(0, ms.length)];
    [ms replaceOccurrencesOfString:@"\"" withString:@"\\\"" options:0 range:NSMakeRange(0, ms.length)];
    [ms replaceOccurrencesOfString:@"\n" withString:@"\\n" options:0 range:NSMakeRange(0, ms.length)];
    [ms replaceOccurrencesOfString:@"\r" withString:@"\\r" options:0 range:NSMakeRange(0, ms.length)];
    [ms replaceOccurrencesOfString:@"\t" withString:@"\\t" options:0 range:NSMakeRange(0, ms.length)];
    return ms;
}

+ (NSString *)anyToJSON:(id)obj {
    if (!obj || [obj isKindOfClass:[NSNull class]]) return @"null";
    if ([obj isKindOfClass:[NSString class]]) {
        return [NSString stringWithFormat:@"\"%@\"", [self escapeString:obj]];
    }
    if ([obj isKindOfClass:[NSNumber class]]) {
        NSNumber *n = obj;
        if (strcmp([n objCType], @encode(BOOL)) == 0) return [n boolValue] ? @"true" : @"false";
        return [n stringValue];
    }
    if ([obj isKindOfClass:[NSDictionary class]]) {
        return [self dictToJSON:obj];
    }
    if ([obj isKindOfClass:[NSArray class]]) {
        return [self arrayToJSON:obj];
    }
    if ([obj isKindOfClass:[NSData class]]) {
        return [NSString stringWithFormat:@"\"%@\"", [obj base64EncodedStringWithOptions:0]];
    }
    return [NSString stringWithFormat:@"\"%@\"", [self escapeString:[obj description]]];
}

+ (NSString *)dictToJSON:(NSDictionary *)dict {
    if (!dict || [dict count] == 0) return @"{}";
    NSMutableArray *pairs = [NSMutableArray array];
    for (id key in dict) {
        NSString *k = [self anyToJSON:[key description]];
        NSString *v = [self anyToJSON:dict[key]];
        [pairs addObject:[NSString stringWithFormat:@"%@:%@", k, v]];
    }
    return [NSString stringWithFormat:@"{%@}", [pairs componentsJoinedByString:@","]];
}

+ (NSString *)arrayToJSON:(NSArray *)array {
    if (!array || [array count] == 0) return @"[]";
    NSMutableArray *items = [NSMutableArray array];
    for (id obj in array) {
        [items addObject:[self anyToJSON:obj]];
    }
    return [NSString stringWithFormat:@"[%@]", [items componentsJoinedByString:@","]];
}

+ (NSString *)successResponse:(id)data {
    NSDictionary *resp = @{
        @"success": @YES,
        @"data": data ?: [NSNull null]
    };
    return [self dictToJSON:resp];
}

+ (NSString *)errorResponse:(NSString *)msg code:(int)code {
    NSDictionary *resp = @{
        @"success": @NO,
        @"error": msg ?: @"Unknown error",
        @"code": @(code)
    };
    return [self dictToJSON:resp];
}

+ (NSString *)mcpResponse:(id)reqId result:(id)result {
    NSMutableDictionary *resp = [NSMutableDictionary dictionary];
    resp[@"jsonrpc"] = @"2.0";
    if (reqId) resp[@"id"] = reqId;
    resp[@"result"] = result ?: @{};
    return [self dictToJSON:resp];
}

+ (NSString *)mcpErrorResponse:(id)reqId code:(int)code message:(NSString *)msg {
    NSDictionary *error = @{@"code": @(code), @"message": msg ?: @""};
    NSMutableDictionary *resp = [NSMutableDictionary dictionary];
    resp[@"jsonrpc"] = @"2.0";
    if (reqId) resp[@"id"] = reqId;
    resp[@"error"] = error;
    return [self dictToJSON:resp];
}

@end
