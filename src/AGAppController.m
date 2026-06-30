//  AGAppController.m - App 管理实现

#import "AGAppController.h"
#import <UIKit/UIKit.h>

@implementation AGAppController

+ (NSArray *)listApps {
    NSMutableArray *apps = [NSMutableArray array];
    NSArray *dirs = @[@"/Applications", @"/var/jb/Applications"];

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
    FILE *fp = popen("ps ax 2>/dev/null", "r");
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
    FILE *fp = popen("activator current-app 2>/dev/null", "r");
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
        system([[NSString stringWithFormat:@"killall -9 %@ 2>/dev/null", process] UTF8String]);
    } else if (bundleID.length > 0) {
        system([[NSString stringWithFormat:
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
        system([[NSString stringWithFormat:@"unzip -o '%@' -d '%@' 2>/dev/null && cp -r '%@'/Payload/*.app /Applications/ 2>/dev/null && uicache -a 2>/dev/null && rm -rf '%@'", path, tmp, tmp, tmp] UTF8String]);
    } else if ([path hasSuffix:@".deb"]) {
        system([[NSString stringWithFormat:@"dpkg -i '%@' 2>/dev/null", path] UTF8String]);
    }
}

+ (void)uninstallApp:(NSString *)bundleID {
    system([[NSString stringWithFormat:
        @"find /Applications -name '*.app' | while read app; do "
        @"plutil -p \"$app/Info.plist\" 2>/dev/null | grep -q '%@' && rm -rf \"$app\"; done; "
        @"uicache -a 2>/dev/null", bundleID] UTF8String]);
}

@end
