//  AGVPNController.m - VPN 控制实现

#import "AGVPNController.h"
#import <NetworkExtension/NetworkExtension.h>

@implementation AGVPNController

+ (NSString *)status {
    __block NSString *s = @"unavailable";
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);

    [NEVPNManager sharedManager].enabled = YES;
    [[NEVPNManager sharedManager] loadFromPreferencesWithCompletionHandler:^(NSError *err) {
        if (!err) {
            NEVPNStatus st = [NEVPNManager sharedManager].connection.status;
            switch (st) {
                case NEVPNStatusInvalid:       s = @"invalid"; break;
                case NEVPNStatusDisconnected:  s = @"disconnected"; break;
                case NEVPNStatusConnecting:    s = @"connecting"; break;
                case NEVPNStatusConnected:     s = @"connected"; break;
                case NEVPNStatusDisconnecting: s = @"disconnecting"; break;
                case NEVPNStatusReasserting:   s = @"reasserting"; break;
                default: s = @"unknown";
            }
        }
        dispatch_semaphore_signal(sem);
    }];
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
    return s;
}

+ (BOOL)connect {
    __block BOOL ok = NO;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);

    [[NEVPNManager sharedManager] loadFromPreferencesWithCompletionHandler:^(NSError *err) {
        if (!err) {
            [[NEVPNManager sharedManager] setEnabled:YES];
            NSError *startErr = nil;
            [[NEVPNManager sharedManager].connection startVPNTunnelAndReturnError:&startErr];
            ok = (startErr == nil);
        }
        dispatch_semaphore_signal(sem);
    }];
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC));
    return ok;
}

+ (BOOL)disconnect {
    __block BOOL ok = NO;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);

    [[NEVPNManager sharedManager] loadFromPreferencesWithCompletionHandler:^(NSError *err) {
        if (!err) {
            [[NEVPNManager sharedManager].connection stopVPNTunnel];
            ok = YES;
        }
        dispatch_semaphore_signal(sem);
    }];
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
    return ok;
}

+ (NSString *)createIKEv2:(NSString *)name server:(NSString *)server
    remoteID:(NSString *)remoteID localID:(NSString *)localID
    username:(NSString *)username password:(NSString *)password {
    __block NSString *result = @"error";

    if (!name) name = @"AutoGo VPN";
    if (!remoteID) remoteID = server;

    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    NEVPNManager *mgr = [NEVPNManager sharedManager];
    mgr.enabled = YES;

    // IKEv2 协议
    NEVPNProtocolIKEv2 *proto = [[NEVPNProtocolIKEv2 alloc] init];
    proto.serverAddress = server;
    proto.remoteIdentifier = remoteID;
    if (localID) proto.localIdentifier = localID;
    proto.username = username;
    proto.passwordReference = [self persistentRefForPassword:password];
    proto.authenticationMethod = NEVPNIKEAuthenticationMethodNone;
    proto.useExtendedAuthentication = YES;
    proto.disconnectOnSleep = NO;

    mgr.protocolConfiguration = proto;
    mgr.localizedDescription = name;

    [mgr saveToPreferencesWithCompletionHandler:^(NSError *err) {
        result = err ? [NSString stringWithFormat:@"error: %@", err.localizedDescription] : @"ok";
        dispatch_semaphore_signal(sem);
    }];
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC));
    return result;
}

+ (NSData *)persistentRefForPassword:(NSString *)password {
    if (!password) return nil;
    NSMutableDictionary *query = [NSMutableDictionary dictionary];
    query[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;
    query[(__bridge id)kSecAttrService] = @"AutoGo VPN";
    query[(__bridge id)kSecAttrAccount] = @"vpnPassword";
    query[(__bridge id)kSecValueData] = [password dataUsingEncoding:NSUTF8StringEncoding];
    query[(__bridge id)kSecReturnPersistentRef] = @YES;

    CFTypeRef ref = NULL;
    OSStatus st = SecItemAdd((__bridge CFDictionaryRef)query, &ref);
    if (st == errSecDuplicateItem) {
        // 更新
        NSMutableDictionary *upd = [NSMutableDictionary dictionary];
        upd[(__bridge id)kSecValueData] = [password dataUsingEncoding:NSUTF8StringEncoding];
        SecItemUpdate((__bridge CFDictionaryRef)@{
            (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
            (__bridge id)kSecAttrService: @"AutoGo VPN",
            (__bridge id)kSecAttrAccount: @"vpnPassword"
        }, (__bridge CFDictionaryRef)upd);
        // 重新读取
        NSMutableDictionary *get = [NSMutableDictionary dictionary];
        get[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;
        get[(__bridge id)kSecAttrService] = @"AutoGo VPN";
        get[(__bridge id)kSecAttrAccount] = @"vpnPassword";
        get[(__bridge id)kSecReturnPersistentRef] = @YES;
        CFTypeRef r2 = NULL;
        SecItemCopyMatching((__bridge CFDictionaryRef)get, &r2);
        return (__bridge_transfer NSData *)r2;
    }
    return (__bridge_transfer NSData *)ref;
}

+ (void)removeConfig {
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [[NEVPNManager sharedManager] removeFromPreferencesWithCompletionHandler:^(NSError *err) {
        dispatch_semaphore_signal(sem);
    }];
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
}

@end
