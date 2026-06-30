//  AGDeviceInfo.m - iOS 设备信息与控制实现

#import "AGDeviceInfo.h"
#import "AGJailbreak.h"
#import <UIKit/UIKit.h>
#import <sys/sysctl.h>
#import <sys/utsname.h>
#import <mach/mach.h>
#import <mach/host_info.h>
#import <dlfcn.h>
#import <notify.h>
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
/// 使用 posix_spawnp + pipe 实现，不依赖 /bin/sh
static FILE *ag_popen(const char *cmd, const char *mode) {
    int pipefd[2];
    if (pipe(pipefd) != 0) return NULL;

    pid_t pid;
    char *argv[] = {"sh", "-c", (char *)cmd, NULL};
    extern char **environ;

    posix_spawn_file_actions_t actions;
    posix_spawn_file_actions_init(&actions);

    if (mode[0] == 'r') {
        posix_spawn_file_actions_adddup2(&actions, pipefd[1], STDOUT_FILENO);
        posix_spawn_file_actions_adddup2(&actions, pipefd[1], STDERR_FILENO);
        posix_spawn_file_actions_addclose(&actions, pipefd[0]);
    } else {
        posix_spawn_file_actions_adddup2(&actions, pipefd[0], STDIN_FILENO);
        posix_spawn_file_actions_addclose(&actions, pipefd[1]);
    }

    // 策略1: posix_spawnp 从 PATH 搜索 sh
    int spawnRet = posix_spawnp(&pid, "sh", &actions, NULL, argv, environ);

    // 策略2: jbroot/bin/sh
    if (spawnRet != 0) {
        NSString *jbSh = [ag_jbroot() stringByAppendingPathComponent:@"bin/sh"];
        if ([[NSFileManager defaultManager] isExecutableFileAtPath:jbSh]) {
            const char *shPath = [jbSh UTF8String];
            char *jbArgv[] = {(char *)shPath, "-c", (char *)cmd, NULL};
            spawnRet = posix_spawn(&pid, shPath, &actions, NULL, jbArgv, environ);
        }
    }

    // 策略3: /bin/sh 回退
    if (spawnRet != 0) {
        char *fallbackArgv[] = {"/bin/sh", "-c", (char *)cmd, NULL};
        spawnRet = posix_spawn(&pid, "/bin/sh", &actions, NULL, fallbackArgv, environ);
    }

    posix_spawn_file_actions_destroy(&actions);

    if (spawnRet != 0) {
        close(pipefd[0]);
        close(pipefd[1]);
        return NULL;
    }

    // 父进程关闭不需要的一端
    if (mode[0] == 'r') {
        close(pipefd[1]);
        return fdopen(pipefd[0], "r");
    } else {
        close(pipefd[0]);
        return fdopen(pipefd[1], "w");
    }
}

@interface UIScreen (Private)
- (void)setUserInterfaceStyle:(NSInteger)style;
@end

@implementation AGDeviceInfo

#pragma mark - 设备标识

+ (NSString *)deviceName {
    return [[UIDevice currentDevice] name] ?: @"Unknown";
}

+ (NSString *)deviceModel {
    struct utsname systemInfo;
    uname(&systemInfo);
    return [NSString stringWithUTF8String:systemInfo.machine];
}

+ (NSString *)systemVersion {
    return [[UIDevice currentDevice] systemVersion] ?: @"Unknown";
}

+ (NSString *)localIP {
    // 通过 shell 获取
    FILE *fp = ag_popen("ifconfig en0 2>/dev/null | grep 'inet ' | awk '{print $2}'", "r");
    if (!fp) return @"";
    char buf[128] = {0};
    fgets(buf, sizeof(buf), fp);
    pclose(fp);
    NSString *ip = [NSString stringWithUTF8String:buf];
    return [ip stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"";
}

#pragma mark - 电池

+ (float)batteryLevel {
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    return [UIDevice currentDevice].batteryLevel;
}

+ (NSString *)batteryState {
    switch ([UIDevice currentDevice].batteryState) {
        case UIDeviceBatteryStateUnplugged: return @"unplugged";
        case UIDeviceBatteryStateCharging:  return @"charging";
        case UIDeviceBatteryStateFull:      return @"full";
        default:                             return @"unknown";
    }
}

+ (BOOL)isCharging {
    return [UIDevice currentDevice].batteryState == UIDeviceBatteryStateCharging ||
           [UIDevice currentDevice].batteryState == UIDeviceBatteryStateFull;
}

#pragma mark - 存储

+ (NSDictionary *)storageInfo {
    NSError *err = nil;
    NSDictionary *attrs = [[NSFileManager defaultManager]
        attributesOfFileSystemForPath:@"/" error:&err];
    if (!attrs) return @{@"total":@0,@"free":@0,@"used":@0};

    uint64_t total = [attrs[NSFileSystemSize] unsignedLongLongValue];
    uint64_t free  = [attrs[NSFileSystemFreeSize] unsignedLongLongValue];
    return @{@"total":@(total),@"free":@(free),@"used":@(total - free)};
}

#pragma mark - 屏幕

+ (NSDictionary *)screenInfo {
    UIScreen *screen = [UIScreen mainScreen];
    CGRect bounds = screen.bounds;
    CGFloat scale = screen.scale;
    return @{
        @"width":  @((int)(bounds.size.width * scale)),
        @"height": @((int)(bounds.size.height * scale)),
        @"scale":  @(scale)
    };
}

+ (float)brightness {
    return [UIScreen mainScreen].brightness * 100.0;
}

+ (void)setBrightness:(float)percent {
    [[UIScreen mainScreen] setBrightness:MAX(0, MIN(100, percent)) / 100.0];
}

+ (NSData *)captureScreenshot {
    // 使用系统截图命令
    NSString *tmpPath = @"/var/mobile/Documents/autogo/screenshots/screenshot.jpg";
    [[NSFileManager defaultManager] createDirectoryAtPath:
        [tmpPath stringByDeletingLastPathComponent]
        withIntermediateDirectories:YES attributes:nil error:nil];
    ag_run_cmd([[NSString stringWithFormat:@"screencapture %@ 2>/dev/null", tmpPath] UTF8String]);
    return [NSData dataWithContentsOfFile:tmpPath];
}

+ (void)keepScreenOn {
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
}

+ (void)allowScreenOff {
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
}

+ (BOOL)isScreenKeptOn {
    return [[UIApplication sharedApplication] isIdleTimerDisabled];
}

+ (void)lockOrientation:(BOOL)lock {
    // 通过 shell
    if (lock) {
        ag_run_cmd("activator send libactivator.orientation.portrait 2>/dev/null");
    }
}

+ (BOOL)isDarkMode {
    if (@available(iOS 13.0, *)) {
        return [UITraitCollection currentTraitCollection].userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    return NO;
}

+ (void)setDarkMode:(BOOL)on {
    if (@available(iOS 13.0, *)) {
        UIScreen *screen = [UIScreen mainScreen];
        [screen setUserInterfaceStyle:on ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight];
    }
}

#pragma mark - 系统控制

+ (void)respring { ag_run_cmd("sbreload 2>/dev/null || killall -9 SpringBoard 2>/dev/null"); }
+ (void)reboot   { ag_run_cmd("reboot"); }

+ (NSArray *)processes {
    NSMutableArray *list = [NSMutableArray array];
    FILE *fp = ag_popen("ps axo pid=,rss=,comm=", "r");
    if (!fp) return list;
    char buf[1024];
    while (fgets(buf, sizeof(buf), fp)) {
        NSString *line = [NSString stringWithUTF8String:buf];
        NSArray *parts = [[line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
            componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (parts.count >= 2) {
            [list addObject:@{
                @"pid": parts[0],
                @"rssKB": parts.count > 1 ? parts[1] : @"0",
                @"command": parts.count > 2 ? parts[2] : @""
            }];
        }
    }
    pclose(fp);
    return list;
}

+ (NSDictionary *)memoryInfo {
    mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
    vm_statistics64_data_t vmStat;
    vm_size_t pageSize;
    host_page_size(mach_host_self(), &pageSize);

    if (host_statistics64(mach_host_self(), HOST_VM_INFO64, (host_info64_t)&vmStat, &count) == KERN_SUCCESS) {
        unsigned long long used = (unsigned long long)(vmStat.active_count + vmStat.inactive_count + vmStat.wire_count) * pageSize;
        unsigned long long free = (unsigned long long)(vmStat.free_count + vmStat.speculative_count) * pageSize;
        unsigned long long total = 0;
        size_t sz = sizeof(total);
        sysctlbyname("hw.memsize", &total, &sz, NULL, 0);
        return @{@"total":@(total),@"used":@(used),@"free":@(free)};
    }
    return @{@"total":@0,@"used":@0,@"free":@0};
}

+ (NSString *)language {
    return [[NSLocale preferredLanguages] firstObject] ?: @"en";
}

+ (NSString *)locale {
    return [[NSLocale currentLocale] localeIdentifier] ?: @"en_US";
}

+ (NSString *)timeFormat {
    NSLocale *loc = [NSLocale currentLocale];
    NSString *format = [NSDateFormatter dateFormatFromTemplate:@"j"
        options:0 locale:loc];
    return [format containsString:@"a"] ? @"12h" : @"24h";
}

+ (NSDictionary *)dateTime {
    NSDateFormatter *f = [[NSDateFormatter alloc] init];
    f.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss";
    f.timeZone = [NSTimeZone localTimeZone];
    return @{@"datetime":[f stringFromDate:[NSDate date]]};
}

#pragma mark - 手电筒

+ (void)flashlightOn  { ag_run_cmd("activator send libactivator.flashlight.on 2>/dev/null"); }
+ (void)flashlightOff { ag_run_cmd("activator send libactivator.flashlight.off 2>/dev/null"); }
+ (BOOL)isFlashlightOn { return NO; }

#pragma mark - URL

+ (void)openURL:(NSString *)url {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]
        options:@{} completionHandler:nil];
}

#pragma mark - 振动

+ (void)hapticLight {
    ag_run_cmd("activator send libactivator.vibrate 2>/dev/null");
}

+ (void)hapticHeavy {
    [self hapticLight];
    usleep(50000);
    [self hapticLight];
    usleep(50000);
    [self hapticLight];
}

#pragma mark - 位置

+ (void)setLocation:(float)lat lng:(float)lng {
    // 需要 LocationSimulation 支持
}

+ (void)resetLocation {}

#pragma mark - 通知

+ (NSString *)notificationStatus {
    return @"unknown";
}

#pragma mark - 综合

+ (NSDictionary *)fullDeviceInfo {
    return @{
        @"name": [self deviceName],
        @"model": [self deviceModel],
        @"osVersion": [self systemVersion],
        @"battery": @([self batteryLevel]),
        @"charging": @([self isCharging]),
        @"screen": [self screenInfo],
        @"storage": [self storageInfo],
        @"memory": [self memoryInfo],
        @"darkMode": @([self isDarkMode]),
        @"localIP": [self localIP],
        @"language": [self language],
        @"locale": [self locale],
        @"timeFormat": [self timeFormat]
    };
}

+ (NSDictionary *)describeScreen {
    return @{
        @"screen": [self screenInfo],
        @"brightness": @([self brightness]),
        @"darkMode": @([self isDarkMode])
    };
}

@end
