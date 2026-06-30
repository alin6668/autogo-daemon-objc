//  AGShellController.m - Shell 执行实现

#import "AGShellController.h"
#import "AGJailbreak.h"
#import <spawn.h>
#import <sys/wait.h>

/// 在 rootless 越狱环境下安全执行 shell 命令
/// 依次尝试: posix_spawnp("sh") → jbroot/bin/sh → /bin/sh
static int ag_run_cmd(const char *cmd) {
    pid_t pid;
    char *argv[] = {"sh", "-c", (char *)cmd, NULL};
    extern char **environ;

    // 策略1: posix_spawnp 从 PATH 搜索 sh (rootless 下通常可用)
    if (posix_spawnp(&pid, "sh", NULL, NULL, argv, environ) == 0) {
        int status;
        waitpid(pid, &status, 0);
        return WIFEXITED(status) ? WEXITSTATUS(status) : -1;
    }

    // 策略2: jbroot/bin/sh
    NSString *jbSh = [ag_jbroot() stringByAppendingPathComponent:@"bin/sh"];
    if ([[NSFileManager defaultManager] isExecutableFileAtPath:jbSh]) {
        const char *shPath = [jbSh UTF8String];
        char *jbArgv[] = {(char *)shPath, "-c", (char *)cmd, NULL};
        if (posix_spawn(&pid, shPath, NULL, NULL, jbArgv, environ) == 0) {
            int status;
            waitpid(pid, &status, 0);
            return WIFEXITED(status) ? WEXITSTATUS(status) : -1;
        }
    }

    // 策略3: /bin/sh (回退)
    char *fallbackArgv[] = {"/bin/sh", "-c", (char *)cmd, NULL};
    if (posix_spawn(&pid, "/bin/sh", NULL, NULL, fallbackArgv, environ) == 0) {
        int status;
        waitpid(pid, &status, 0);
        return WIFEXITED(status) ? WEXITSTATUS(status) : -1;
    }

    return -1;
}

/// 在 rootless 环境下安全的 popen 替代
static FILE *ag_popen(const char *cmd, const char *mode) {
    // 策略1: 标准 popen (依赖 /bin/sh)
    FILE *fp = popen(cmd, mode);
    if (fp) return fp;

    // 策略2: 用 jbroot/bin/sh 构造完整命令重试
    NSString *jbSh = [ag_jbroot() stringByAppendingPathComponent:@"bin/sh"];
    if ([[NSFileManager defaultManager] isExecutableFileAtPath:jbSh]) {
        NSString *fullCmd = [NSString stringWithFormat:@"%s -c '%s'",
                             [jbSh UTF8String], cmd];
        fp = popen([fullCmd UTF8String], mode);
    }
    return fp;
}

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

    int ret = ag_run_cmd([cmd UTF8String]);

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

    FILE *fp = ag_popen([cmd UTF8String], "r");
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
