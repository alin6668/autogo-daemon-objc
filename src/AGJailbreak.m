//  AGJailbreak.m - 越狱环境检测实现

#import "AGJailbreak.h"

NSString *ag_jbroot(void) {
    static NSString *root = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 1. 环境变量 (手动设置或 theos 注入)
        const char *env = getenv("JBROOT");
        if (env && strlen(env) > 0) {
            root = [NSString stringWithUTF8String:env];
            return;
        }

        NSFileManager *fm = [NSFileManager defaultManager];
        NSError *err = nil;

        // 2. /var/jb 是符号链接 → 解析真实路径
        NSString *symlinkTarget = [fm destinationOfSymbolicLinkAtPath:@"/var/jb" error:&err];
        if (symlinkTarget && !err) {
            root = symlinkTarget;
            return;
        }

        // 3. /var/jb 存在且是目录
        BOOL isDir = NO;
        if ([fm fileExistsAtPath:@"/var/jb" isDirectory:&isDir] && isDir) {
            root = @"/var/jb";
            return;
        }

        // 4. Dopamine hideroot: 扫描 /private/var/containers/Bundle/Application/.jbroot-*
        NSString *containerPath = @"/private/var/containers/Bundle/Application";
        NSArray *entries = [fm contentsOfDirectoryAtPath:containerPath error:nil];
        for (NSString *e in entries) {
            if ([e hasPrefix:@".jbroot-"]) {
                root = [containerPath stringByAppendingPathComponent:e];
                return;
            }
        }

        // 5. 回退
        root = @"/var/jb";
    });
    return root;
}

NSString *ag_jbpath(NSString *subpath) {
    if (!subpath || subpath.length == 0) {
        return ag_jbroot();
    }
    return [ag_jbroot() stringByAppendingPathComponent:subpath];
}
