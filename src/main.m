//  main.m - AutoGo Daemon 入口
//  综合 iOS 设备控制守护进程 (Objective-C)
//  集成 ios-mcp + go-ios 全部功能

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <signal.h>
#import <sys/stat.h>
#import "AGHTTPServer.h"
#import "AGRouter.h"

static AGHTTPServer *server = nil;

static void signal_handler(int sig) {
    NSLog(@"收到信号 %d，正在关闭...", sig);
    [server stop];
    server = nil;
    exit(0);
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        // 信号处理
        signal(SIGINT, signal_handler);
        signal(SIGTERM, signal_handler);
        signal(SIGHUP, signal_handler);

        // 确保数据目录
        NSArray *dirs = @[
            @"/var/mobile/Documents/autogo",
            @"/var/mobile/Documents/autogo/screenshots",
            @"/var/mobile/Documents/autogo/logs",
            @"/var/mobile/Documents/autogo/crash",
            @"/var/mobile/Documents/autogo/data"
        ];
        for (NSString *d in dirs) {
            mkdir([d UTF8String], 0755);
        }

        int port = 8888;
        if (argc >= 2) {
            port = atoi(argv[1]);
        }
        if (port <= 0 || port > 65535) port = 8888;

        NSLog(@"====================================");
        NSLog(@"AutoGo Daemon v1.0.0 (ObjC 原生)");
        NSLog(@"集成: ios-mcp + go-ios + AutoGo");
        NSLog(@"端口: %d", port);
        NSLog(@"Web 控制台: http://设备IP:%d", port);
        NSLog(@"健康检查: http://设备IP:%d/health", port);
        NSLog(@"API 文档: http://设备IP:%d/api/docs", port);
        NSLog(@"MCP 端点: http://设备IP:%d/mcp", port);
        NSLog(@"====================================");

        server = [[AGHTTPServer alloc] initWithPort:port];
        [server setRouteHandler:[AGRouter sharedRouter]];

        NSError *err = nil;
        if (![server start:&err]) {
            NSLog(@"启动失败: %@", err);
            return 1;
        }

        // 保持运行
        [[NSRunLoop mainRunLoop] run];
    }
    return 0;
}
