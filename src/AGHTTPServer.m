//  AGHTTPServer.m - 轻量 HTTP 服务器实现
//  使用 BSD socket + GCD dispatch_source 实现高并发

#import "AGHTTPServer.h"
#import "AGRouter.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <unistd.h>
#import <fcntl.h>

@interface AGHTTPServer ()
@property (nonatomic, assign) int listenFd;
@property (nonatomic, assign) int port;
@property (nonatomic, strong) dispatch_source_t acceptSource;
@property (nonatomic, strong) dispatch_queue_t serverQueue;
@property (nonatomic, assign) BOOL running;
@end

@implementation AGHTTPServer

- (instancetype)initWithPort:(int)port {
    self = [super init];
    if (self) {
        _port = port;
        _serverQueue = dispatch_queue_create("com.autogo.server", DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

- (BOOL)start:(NSError **)error {
    _listenFd = socket(AF_INET, SOCK_STREAM, 0);
    if (_listenFd < 0) {
        if (error) *error = [NSError errorWithDomain:@"AGServer" code:-1
            userInfo:@{NSLocalizedDescriptionKey: @"socket() 失败"}];
        return NO;
    }

    int reuse = 1;
    setsockopt(_listenFd, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons(_port);

    if (bind(_listenFd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        close(_listenFd);
        if (error) *error = [NSError errorWithDomain:@"AGServer" code:-2
            userInfo:@{NSLocalizedDescriptionKey:
                [NSString stringWithFormat:@"bind(:%d) 失败", _port]}];
        return NO;
    }

    if (listen(_listenFd, SOMAXCONN) < 0) {
        close(_listenFd);
        if (error) *error = [NSError errorWithDomain:@"AGServer" code:-3
            userInfo:@{NSLocalizedDescriptionKey: @"listen() 失败"}];
        return NO;
    }

    // 非阻塞 IO
    fcntl(_listenFd, F_SETFL, O_NONBLOCK);

    _acceptSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ,
        (uintptr_t)_listenFd, 0, _serverQueue);

    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(_acceptSource, ^{
        [weakSelf acceptConnection];
    });

    dispatch_source_set_cancel_handler(_acceptSource, ^{
        close(weakSelf.listenFd);
    });

    dispatch_resume(_acceptSource);
    _running = YES;

    NSLog(@"HTTP 服务已启动，监听端口 %d", _port);
    return YES;
}

- (void)stop {
    _running = NO;
    if (_acceptSource) {
        dispatch_source_cancel(_acceptSource);
        _acceptSource = nil;
    }
}

- (void)acceptConnection {
    struct sockaddr_in clientAddr;
    socklen_t addrLen = sizeof(clientAddr);
    int clientFd = accept(_listenFd, (struct sockaddr *)&clientAddr, &addrLen);

    if (clientFd < 0) {
        if (errno != EAGAIN && errno != EWOULDBLOCK) {
            NSLog(@"accept 失败: %s", strerror(errno));
        }
        return;
    }

    dispatch_async(_serverQueue, ^{
        [self handleConnection:clientFd];
    });
}

- (void)handleConnection:(int)clientFd {
    // 设置 socket 超时
    struct timeval tv = {5, 0};
    setsockopt(clientFd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
    setsockopt(clientFd, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof(tv));

    // 读取 HTTP 请求
    char buf[65536];
    memset(buf, 0, sizeof(buf));
    ssize_t totalRead = 0;

    while (totalRead < (ssize_t)sizeof(buf) - 1) {
        ssize_t n = read(clientFd, buf + totalRead, sizeof(buf) - 1 - totalRead);
        if (n <= 0) break;
        totalRead += n;
        // 检查是否读完 headers
        if (strstr(buf, "\r\n\r\n")) break;
    }

    if (totalRead <= 0) {
        close(clientFd);
        return;
    }
    buf[totalRead] = '\0';

    // 解析请求
    NSString *requestStr = [[NSString alloc] initWithUTF8String:buf];
    NSArray *lines = [requestStr componentsSeparatedByString:@"\r\n"];
    if (lines.count < 1) { close(clientFd); return; }

    // 解析请求行: METHOD /path HTTP/1.x
    NSArray *reqLine = [lines[0] componentsSeparatedByString:@" "];
    if (reqLine.count < 2) { close(clientFd); return; }

    NSString *method = reqLine[0];
    NSString *path = [reqLine[1]
        stringByRemovingPercentEncoding];
    if (!path) path = reqLine[1];

    // 解析 headers
    NSMutableDictionary *headers = [NSMutableDictionary dictionary];
    int contentLength = 0;
    BOOL bodyStart = NO;
    for (NSInteger i = 1; i < (NSInteger)lines.count; i++) {
        NSString *line = lines[i];
        if (line.length == 0) { bodyStart = YES; continue; }
        if (!bodyStart) {
            NSRange colon = [line rangeOfString:@":"];
            if (colon.location != NSNotFound) {
                NSString *key = [[line substringToIndex:colon.location]
                    stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                NSString *val = [[line substringFromIndex:colon.location + 1]
                    stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                headers[[key lowercaseString]] = val;
                if ([key caseInsensitiveCompare:@"Content-Length"] == NSOrderedSame) {
                    contentLength = [val intValue];
                }
            }
        }
    }

    // 解析 body
    NSString *body = @"";
    if (contentLength > 0) {
        const char *bodyStart = strstr(buf, "\r\n\r\n");
        if (bodyStart) {
            bodyStart += 4;
            body = [[NSString alloc] initWithBytes:bodyStart
                length:MIN(contentLength, totalRead - (bodyStart - buf))
                encoding:NSUTF8StringEncoding];
            if (!body) body = @"";
        }
    }

    // 路由分发
    NSDictionary *request = @{
        @"method": method ?: @"GET",
        @"path": path ?: @"/",
        @"headers": headers,
        @"body": body ?: @"",
        @"contentLength": @(contentLength)
    };

    NSDictionary *response = [[AGRouter sharedRouter] handleRequest:request];

    // 构建 HTTP 响应
    int statusCode = [response[@"status"] intValue] ?: 200;
    NSString *statusText = [AGHTTPServer statusTextForCode:statusCode];
    NSString *contentType = response[@"contentType"] ?: @"application/json; charset=utf-8";
    NSString *responseBody = response[@"body"] ?: @"";
    NSData *bodyData = [responseBody dataUsingEncoding:NSUTF8StringEncoding];

    // CORS headers
    NSMutableString *resp = [NSMutableString string];
    [resp appendFormat:@"HTTP/1.1 %d %@\r\n", statusCode, statusText];
    [resp appendFormat:@"Content-Type: %@\r\n", contentType];
    [resp appendFormat:@"Content-Length: %lu\r\n", (unsigned long)bodyData.length];
    [resp appendString:@"Access-Control-Allow-Origin: *\r\n"];
    [resp appendString:@"Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS\r\n"];
    [resp appendString:@"Access-Control-Allow-Headers: Content-Type, Authorization\r\n"];
    [resp appendString:@"Connection: close\r\n"];
    [resp appendString:@"Server: AutoGo-Daemon/1.0\r\n"];
    [resp appendString:@"\r\n"];

    write(clientFd, [resp UTF8String], [resp lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
    write(clientFd, bodyData.bytes, bodyData.length);
    close(clientFd);
}

+ (NSString *)statusTextForCode:(int)code {
    switch (code) {
        case 200: return @"OK";
        case 201: return @"Created";
        case 204: return @"No Content";
        case 400: return @"Bad Request";
        case 404: return @"Not Found";
        case 405: return @"Method Not Allowed";
        case 500: return @"Internal Server Error";
        default:  return @"Unknown";
    }
}

@end
