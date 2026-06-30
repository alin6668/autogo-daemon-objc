# AutoGo Daemon - iOS 综合设备控制守护进程
# 编译: make 或 make package

ARCHS = arm64 arm64e
TARGET = iphone:clang:13.0:13.0

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

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
ios-autogo_INSTALL_PATH = /usr/bin

include $(THEOS_MAKE_PATH)/tool.mk

# DEB 打包
internal-package::
	@echo "==> 组装 DEB 包"
	cp -r DEBIAN $(THEOS_STAGING_DIR)/
	cp -r Library $(THEOS_STAGING_DIR)/
	cp -r layout/var $(THEOS_STAGING_DIR)/
	chmod 755 $(THEOS_STAGING_DIR)/DEBIAN/postinst
	chmod 755 $(THEOS_STAGING_DIR)/DEBIAN/prerm
	@echo "  DEB 包准备就绪"

# 直接打包
package::
	$(MAKE) internal-package
