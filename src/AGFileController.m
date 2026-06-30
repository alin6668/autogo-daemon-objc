//  AGFileController.m - 文件系统操作实现

#import "AGFileController.h"

@implementation AGFileController

+ (NSArray *)listDirectory:(NSString *)path {
    if (!path || path.length == 0) path = @"/var/mobile/Documents";
    NSError *err = nil;
    NSArray *entries = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:&err];
    if (err) return @[];

    NSMutableArray *result = [NSMutableArray array];
    for (NSString *e in entries) {
        NSString *full = [path stringByAppendingPathComponent:e];
        NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:full error:nil];
        BOOL isDir = [attrs[NSFileType] isEqualToString:NSFileTypeDirectory];
        [result addObject:@{
            @"name": e,
            @"size": attrs[NSFileSize] ?: @0,
            @"isDir": @(isDir),
            @"modTime": [NSString stringWithFormat:@"%@", attrs[NSFileModificationDate] ?: @""]
        }];
    }
    return result;
}

+ (NSDictionary *)readFile:(NSString *)path base64:(BOOL)base64 {
    NSError *err = nil;
    NSData *raw = [NSData dataWithContentsOfFile:path options:0 error:&err];
    if (err || !raw) return @{@"error": err.localizedDescription ?: @"read failed"};
    if (base64) {
        return @{@"path": path, @"encoding": @"base64", @"binary": @YES,
            @"data": [raw base64EncodedStringWithOptions:0]};
    }
    // 检测二进制
    const uint8_t *bytes = raw.bytes;
    BOOL isBinary = NO;
    for (NSUInteger i = 0; i < raw.length && i < 8000; i++) {
        if (bytes[i] == 0) { isBinary = YES; break; }
    }
    if (isBinary) {
        return @{@"path": path, @"encoding": @"base64", @"binary": @YES,
            @"data": [raw base64EncodedStringWithOptions:0]};
    }
    return @{@"path": path, @"binary": @NO,
        @"data": [[NSString alloc] initWithData:raw encoding:NSUTF8StringEncoding] ?: @""};
}

+ (void)writeFile:(NSString *)path content:(NSString *)content base64:(BOOL)base64 append:(BOOL)append {
    [[NSFileManager defaultManager] createDirectoryAtPath:[path stringByDeletingLastPathComponent]
        withIntermediateDirectories:YES attributes:nil error:nil];

    NSData *data;
    if (base64) {
        data = [[NSData alloc] initWithBase64EncodedString:content options:0];
    } else {
        data = [content dataUsingEncoding:NSUTF8StringEncoding];
    }
    if (!data) return;

    if (append) {
        NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
        if (!fh) {
            [data writeToFile:path atomically:YES];
        } else {
            [fh seekToEndOfFile];
            [fh writeData:data];
            [fh closeFile];
        }
    } else {
        [data writeToFile:path atomically:YES];
    }
}

+ (void)deleteFile:(NSString *)path {
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
}

+ (BOOL)fileExists:(NSString *)path {
    return [[NSFileManager defaultManager] fileExistsAtPath:path ?: @""];
}

@end
