//  AGShellController.m - Shell 执行实现

#import "AGShellController.h"

@implementation AGShellController

+ (NSDictionary *)exec:(NSString *)command timeout:(int)timeout asRoot:(BOOL)asRoot {
    if (!command) return @{@"stdout":@"",@"stderr":@"",@"exitCode":@(-1),@"error":@"no command"};

    NSString *tmpOut = [NSString stringWithFormat:@"/tmp/autogo_out_%d", getpid()];
    NSString *tmpErr = [NSString stringWithFormat:@"/tmp/autogo_err_%d", getpid()];

    NSString *cmd;
    if (asRoot) {
        cmd = [NSString stringWithFormat:@"%@ > %@ 2> %@", command, tmpOut, tmpErr];
    } else {
        cmd = [NSString stringWithFormat:@"%@ > %@ 2> %@", command, tmpOut, tmpErr];
    }

    // 添加超时
    if (timeout > 0) {
        cmd = [NSString stringWithFormat:@"timeout %d %@", timeout, cmd];
    }

    int ret = system([cmd UTF8String]);

    NSString *stdout = [NSString stringWithContentsOfFile:tmpOut encoding:NSUTF8StringEncoding error:nil] ?: @"";
    NSString *stderr = [NSString stringWithContentsOfFile:tmpErr encoding:NSUTF8StringEncoding error:nil] ?: @"";

    [[NSFileManager defaultManager] removeItemAtPath:tmpOut error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:tmpErr error:nil];

    return @{
        @"stdout": stdout,
        @"stderr": stderr,
        @"exitCode": @(WEXITSTATUS(ret))
    };
}

+ (NSArray *)syslog:(int)lines filter:(NSString *)filter {
    NSMutableArray *logs = [NSMutableArray array];
    NSString *cmd;
    if (filter.length > 0) {
        cmd = [NSString stringWithFormat:
            @"log show --last 1h --predicate 'process contains \"%@\"' 2>/dev/null | tail -%d", filter, lines];
    } else {
        cmd = [NSString stringWithFormat:@"log show --last 30m 2>/dev/null | tail -%d", lines];
    }

    FILE *fp = popen([cmd UTF8String], "r");
    if (!fp) return logs;
    char buf[4096];
    while (fgets(buf, sizeof(buf), fp)) {
        NSString *line = [[NSString stringWithUTF8String:buf]
            stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (line.length > 0) [logs addObject:line];
    }
    pclose(fp);
    return logs;
}

@end
