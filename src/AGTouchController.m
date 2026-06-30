//  AGTouchController.m - IOKit HID 触控模拟实现
//  参考 ios-mcp HIDManager 实现，通过 IOKit IOHIDEvent 模拟触控

#import "AGTouchController.h"
#import <IOKit/IOKitLib.h>
#import <dlfcn.h>
#import <unistd.h>

// ---- IOKit HID 私有类型 ----
typedef struct __IOHIDEvent *IOHIDEventRef;
typedef struct __IOHIDEventSystemClient *IOHIDEventSystemClientRef;
typedef void *IOHIDEventSystemConnectionRef;

// 函数指针
static IOHIDEventRef (*IOHIDEventCreateDigitizerEvent)(
    CFAllocatorRef, uint64_t, uint32_t, uint32_t, uint32_t, ...) = NULL;
static void (*IOHIDEventSetFloatValue)(IOHIDEventRef, int32_t, float) = NULL;
static IOHIDEventSystemClientRef (*IOHIDEventSystemClientCreate)(CFAllocatorRef) = NULL;
static int (*IOHIDEventSystemClientDispatchEvent)(IOHIDEventSystemClientRef, IOHIDEventRef) = NULL;

// 常量
#define TRANSDUCER_FINGER 2
#define DIGITIZER_LIFT    30
#define DIGITIZER_TOUCH   1
#define DIGITIZER_PATH    25

#define EVT_RANGE_MASK    (1 << 2)
#define EVT_TOUCH_MASK    (1 << 0)

#define FIELD_X           0x1000001
#define FIELD_Y           0x1000002

static BOOL hidLoaded = NO;
static IOHIDEventSystemClientRef hidClient = NULL;

__attribute__((constructor))
static void loadHIDFunctions(void) {
    void *io = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY);
    if (!io) io = dlopen("/System/Library/Frameworks/IOKit.framework/Versions/A/IOKit", RTLD_LAZY);
    if (!io) return;

    IOHIDEventCreateDigitizerEvent = dlsym(io, "IOHIDEventCreateDigitizerEvent");
    IOHIDEventSetFloatValue = dlsym(io, "IOHIDEventSetFloatValue");
    IOHIDEventSystemClientCreate = dlsym(io, "IOHIDEventSystemClientCreate");
    IOHIDEventSystemClientDispatchEvent = dlsym(io, "IOHIDEventSystemClientDispatchEvent");

    if (IOHIDEventCreateDigitizerEvent && IOHIDEventSetFloatValue &&
        IOHIDEventSystemClientCreate && IOHIDEventSystemClientDispatchEvent) {
        hidLoaded = YES;
        hidClient = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    }
}

static void sendDigitizer(int x, int y, int touchType, int eventMask) {
    if (!hidLoaded || !hidClient) return;

    IOHIDEventRef ev = IOHIDEventCreateDigitizerEvent(
        kCFAllocatorDefault, 0, TRANSDUCER_FINGER, 0, touchType,
        EVT_RANGE_MASK | eventMask, 0, x, y, 0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 0, 1.0);

    if (ev) {
        IOHIDEventSetFloatValue(ev, FIELD_X, (float)x);
        IOHIDEventSetFloatValue(ev, FIELD_Y, (float)y);
        IOHIDEventSystemClientDispatchEvent(hidClient, ev);
        CFRelease(ev);
    }
}

@implementation AGTouchController

+ (void)tap:(float)x y:(float)y {
    sendDigitizer((int)x, (int)y, DIGITIZER_TOUCH, EVT_TOUCH_MASK);
    usleep(50000);
    sendDigitizer((int)x, (int)y, DIGITIZER_LIFT, EVT_TOUCH_MASK);
}

+ (void)doubleTap:(float)x y:(float)y {
    [self tap:x y:y];
    usleep(100000);
    [self tap:x y:y];
}

+ (void)longPress:(float)x y:(float)y duration:(float)duration {
    sendDigitizer((int)x, (int)y, DIGITIZER_TOUCH, EVT_TOUCH_MASK);
    usleep((useconds_t)(duration * 1000000));
    sendDigitizer((int)x, (int)y, DIGITIZER_LIFT, EVT_TOUCH_MASK);
}

+ (void)swipe:(float)fromX fy:(float)fromY tx:(float)toX ty:(float)toY duration:(float)duration {
    int steps = 20;
    float dx = (toX - fromX) / steps;
    float dy = (toY - fromY) / steps;
    useconds_t stepUs = (useconds_t)(duration * 1000000 / steps);

    sendDigitizer((int)fromX, (int)fromY, DIGITIZER_TOUCH, EVT_TOUCH_MASK);
    for (int i = 1; i <= steps; i++) {
        usleep(stepUs);
        sendDigitizer((int)(fromX + dx * i), (int)(fromY + dy * i), DIGITIZER_PATH, EVT_TOUCH_MASK);
    }
    usleep(10000);
    sendDigitizer((int)toX, (int)toY, DIGITIZER_LIFT, EVT_TOUCH_MASK);
}

+ (void)drag:(float)fromX fy:(float)fromY tx:(float)toX ty:(float)toY duration:(float)duration steps:(int)steps {
    [self swipe:fromX fy:fromY tx:toX ty:toY duration:duration];
}

@end
