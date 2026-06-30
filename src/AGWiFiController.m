//  AGWiFiController.m - WiFi 控制 (MobileWiFi 私有框架)

#import "AGWiFiController.h"
#import <dlfcn.h>

static void *(*WFClientCreate)(CFAllocatorRef) = NULL;
static int   (*WFClientSetPower)(void *, CFBooleanRef) = NULL;
static Boolean (*WFClientGetPower)(void *, Boolean *) = NULL;
static CFStringRef (*WFClientCopySSID)(void *) = NULL;
static CFStringRef (*WFClientCopyBSSID)(void *) = NULL;

__attribute__((constructor))
static void loadWiFiFunctions(void) {
    void *fw = dlopen("/System/Library/PrivateFrameworks/MobileWiFi.framework/MobileWiFi", RTLD_LAZY);
    if (!fw) return;

    WFClientCreate   = dlsym(fw, "WiFiManagerClientCreate");
    WFClientSetPower = dlsym(fw, "WiFiManagerClientSetPower");
    WFClientGetPower = dlsym(fw, "WiFiManagerClientGetPower");
    WFClientCopySSID = dlsym(fw, "WiFiManagerClientCopySSID");
    WFClientCopyBSSID = dlsym(fw, "WiFiManagerClientCopyBSSID");
}

static void *getClient(void) {
    if (!WFClientCreate) return NULL;
    return WFClientCreate(kCFAllocatorDefault);
}

@implementation AGWiFiController

+ (BOOL)isOn {
    void *client = getClient();
    if (!client || !WFClientGetPower) return NO;
    Boolean on = NO;
    WFClientGetPower(client, &on);
    return (BOOL)on;
}

+ (void)setPower:(BOOL)on {
    void *client = getClient();
    if (client && WFClientSetPower) {
        WFClientSetPower(client, on ? kCFBooleanTrue : kCFBooleanFalse);
    }
}

+ (NSDictionary *)info {
    void *client = getClient();
    if (!client) return @{@"ssid": @"", @"bssid": @"", @"on": @([self isOn])};

    NSString *ssid = @"";
    NSString *bssid = @"";

    if (WFClientCopySSID) {
        CFStringRef s = WFClientCopySSID(client);
        if (s) { ssid = (__bridge_transfer NSString *)s; }
    }
    if (WFClientCopyBSSID) {
        CFStringRef b = WFClientCopyBSSID(client);
        if (b) { bssid = (__bridge_transfer NSString *)b; }
    }

    return @{@"ssid": ssid ?: @"", @"bssid": bssid ?: @"", @"on": @([self isOn])};
}

@end
