# AutoGo Daemon - iOS 综合设备控制守护进程 (Rootless / 多巴胺)
# 编译: make 或 make package

ARCHS = arm64 arm64e
TARGET = iphone:clang:15.0:15.0

# Rootless theos 配置
THEOS_PACKAGE_SCHEME = rootless

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

# === 守护进程 (后台服务) ===
TOOL_NAME = ios-autogo

ios-autogo_FILES = \
	src/main.m \
	src/AGHTTPServer.m \
	src/AGRouter.m \
	src/AGDeviceInfo.m \
	src/AGTouchController.m \
	src/AGAppController.m \
	src/AGFileController.m \
	src/AGVPNController.m \
	src/AGWiFiController.m \
	src/AGShellController.m \
	src/AGClipboardController.m \
	src/AGAccessibilityController.m \
	src/AGHIDController.m \
	src/AGMCPHandler.m \
	src/AGJSON.m

ios-autogo_FRAMEWORKS = Foundation CoreFoundation UIKit CoreGraphics IOKit Security
ios-autogo_LDFLAGS = -ldl
ios-autogo_CFLAGS = -fobjc-arc
ios-autogo_INSTALL_PATH = /var/jb/usr/bin

# === Dashboard App (SpringBoard 可见应用) ===
APPLICATION_NAME = AutoGo

AutoGo_FILES = \
	app/main.m \
	app/AGAppDelegate.m

AutoGo_FRAMEWORKS = UIKit Foundation CoreGraphics
AutoGo_CFLAGS = -fobjc-arc
AutoGo_INSTALL_PATH = /var/jb/Applications

include $(THEOS_MAKE_PATH)/tool.mk
include $(THEOS_MAKE_PATH)/application.mk

# DEB 打包 (Rootless: 不打包 /var/mobile 用户数据)
internal-package::
	@echo "==> 组装 DEB 包 (Rootless)"
	cp -r DEBIAN $(THEOS_STAGING_DIR)/
	cp -r Library $(THEOS_STAGING_DIR)/
	chmod 755 $(THEOS_STAGING_DIR)/DEBIAN/postinst
	chmod 755 $(THEOS_STAGING_DIR)/DEBIAN/prerm
	@echo "  DEB 包准备就绪 (iphoneos-arm64e)"

# 直接打包
package::
	$(MAKE) internal-package
