//  AGAppController.m - App 管理实现

#import "AGAppController.h"
#import "AGJailbreak.h"
#import <UIKit/UIKit.h>
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

@implementation AGAppController

+ (NSArray *)listApps {
    NSMutableArray *apps = [NSMutableArray array];
    NSArray *dirs = @[@"/Applications", ag_jbpath(@"Applications")];

    for (NSString *dir in dirs) {
        NSArray *entries = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nil];
        for (NSString *e in entries) {
            if ([e hasSuffix:@".app"]) {
                NSString *plist = [dir stringByAppendingPathComponent:
                    [e stringByAppendingPathComponent:@"Info.plist"]];
                NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:plist];
                NSString *bid = info[@"CFBundleIdentifier"] ?: @"";
                NSString *name = info[@"CFBundleDisplayName"] ?: info[@"CFBundleName"] ?: [e stringByDeletingPathExtension];
                [apps addObject:@{
                    @"bundleId": bid,
                    @"name": name,
                    @"path": [dir stringByAppendingPathComponent:e]
                }];
            }
        }
    }
    return apps;
}

+ (NSArray *)listRunningApps {
    NSMutableArray *apps = [NSMutableArray array];
    FILE *fp = ag_popen("ps ax 2>/dev/null", "r");
    if (!fp) return apps;
    char buf[1024];
    while (fgets(buf, sizeof(buf), fp)) {
        NSString *line = [NSString stringWithUTF8String:buf];
        if ([line containsString:@"/Applications/"] && [line containsString:@".app/"]) {
            NSArray *parts = [[line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
                componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if (parts.count >= 5) {
                [apps addObject:@{@"pid": parts[0], @"process": parts[4]}];
            }
        }
    }
    pclose(fp);
    return apps;
}

+ (NSDictionary *)frontmostApp {
    FILE *fp = ag_popen("activator current-app 2>/dev/null", "r");
    NSString *bid = @"";
    if (fp) {
        char buf[256] = {0};
        fgets(buf, sizeof(buf), fp);
        pclose(fp);
        bid = [[NSString stringWithUTF8String:buf]
            stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    return @{@"bundleId": bid ?: @""};
}

+ (void)launchApp:(NSString *)bundleID {
    [[UIApplication sharedApplication] openURL:
        [NSURL URLWithString:[NSString stringWithFormat:@"%@:", bundleID]]
        options:@{} completionHandler:nil];
}

+ (void)killApp:(NSString *)bundleID pid:(int)pid process:(NSString *)process {
    if (pid > 0) {
        kill(pid, SIGKILL);
    } else if (process.length > 0) {
        ag_run_cmd([[NSString stringWithFormat:@"killall -9 %@ 2>/dev/null", process] UTF8String]);
    } else if (bundleID.length > 0) {
        ag_run_cmd([[NSString stringWithFormat:
            @"ps ax | grep '%@' | grep -v grep | awk '{print $1}' | xargs kill -9 2>/dev/null",
            bundleID] UTF8String]);
    }
}

+ (NSDictionary *)appInfo:(NSString *)bundleID {
    // 搜索 Data 容器
    NSString *dataPath = @"";
    NSArray *entries = [[NSFileManager defaultManager]
        contentsOfDirectoryAtPath:@"/var/mobile/Containers/Data/Application" error:nil];
    for (NSString *e in entries) {
        NSString *meta = [NSString stringWithFormat:
            @"/var/mobile/Containers/Data/Application/%@/.com.apple.mobile_container_manager.metadata.plist",
            e];
        NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:meta];
        if ([d[@"MCMMetadataIdentifier"] isEqualToString:bundleID]) {
            dataPath = [NSString stringWithFormat:@"/var/mobile/Containers/Data/Application/%@", e];
            break;
        }
    }
    return @{@"bundleId": bundleID, @"dataPath": dataPath};
}

+ (void)installApp:(NSString *)path {
    if ([path hasSuffix:@".ipa"]) {
        NSString *tmp = [NSString stringWithFormat:@"/tmp/ipa_install_%d", getpid()];
        ag_run_cmd([[NSString stringWithFormat:@"unzip -o '%@' -d '%@' 2>/dev/null && cp -r '%@'/Payload/*.app /Applications/ 2>/dev/null && uicache -a 2>/dev/null && rm -rf '%@'", path, tmp, tmp, tmp] UTF8String]);
    } else if ([path hasSuffix:@".deb"]) {
        ag_run_cmd([[NSString stringWithFormat:@"dpkg -i '%@' 2>/dev/null", path] UTF8String]);
    }
}

+ (void)uninstallApp:(NSString *)bundleID {
    ag_run_cmd([[NSString stringWithFormat:
        @"find /Applications -name '*.app' | while read app; do "
        @"plutil -p \"$app/Info.plist\" 2>/dev/null | grep -q '%@' && rm -rf \"$app\"; done; "
        @"uicache -a 2>/dev/null", bundleID] UTF8String]);
}

@end
