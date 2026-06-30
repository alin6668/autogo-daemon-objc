//  AGJailbreak.h - 越狱环境检测
//  动态解析 rootless 越狱根路径（支持 Dopamine hideroot 随机路径）

#import <Foundation/Foundation.h>

/// 获取 rootless 越狱根路径
/// 检测顺序:
///   1. JBROOT 环境变量
///   2. /var/jb 符号链接 → 解析真实路径
///   3. /var/jb 存在即使用
///   4. 扫描 /private/var/containers/Bundle/Application/.jbroot-*
///   5. 回退到 /var/jb
NSString *ag_jbroot(void);

/// 拼接越狱路径: ag_jbpath(@"Applications") → /var/jb/Applications
NSString *ag_jbpath(NSString *subpath);

@end
