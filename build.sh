#!/bin/bash
# AutoGo Daemon (ObjC) 构建脚本 - Rootless (Dopamine)
# 使用 theos 编译; 若无 theos，可用 clang 手动编译

set -e

DAEMON="ios-autogo"
OUTDIR="build"
SDK_MIN="15.0"

# 检测 theos
if [ -n "$THEOS" ] && [ -f "$THEOS/makefiles/common.mk" ]; then
    echo "=== 使用 theos (Rootless) 编译 ==="
    make package
    echo "DEB 包在 packages/ 目录"
    exit 0
fi

# 手动编译 (macOS + Xcode)
echo "=== 手动编译 (clang + SDK, Rootless) ==="

SDK_PATH="${SDK_PATH:-$(xcrun --sdk iphoneos --show-sdk-path 2>/dev/null)}"
if [ -z "$SDK_PATH" ]; then
    echo "错误: 找不到 iPhoneOS SDK. 请安装 Xcode."
    echo "或者设置 SDK_PATH 环境变量."
    exit 1
fi

echo "SDK: $SDK_PATH"
echo "最低 iOS: $SDK_MIN"

mkdir -p "$OUTDIR"

# 架构
ARCHS="arm64 arm64e"
for ARCH in $ARCHS; do
    echo "编译 $ARCH..."

    # 编译所有 .m 文件为 .o
    OBJS=""
    for f in src/*.m; do
        obj="$OUTDIR/$(basename $f .m)_${ARCH}.o"
        clang -arch "$ARCH" \
            -isysroot "$SDK_PATH" \
            -miphoneos-version-min="$SDK_MIN" \
            -fobjc-arc \
            -fmodules \
            -I"$SDK_PATH/usr/include" \
            -c "$f" -o "$obj"
        OBJS="$OBJS $obj"
    done

    # 链接
    BIN="$OUTDIR/${DAEMON}_${ARCH}"
    clang -arch "$ARCH" \
        -isysroot "$SDK_PATH" \
        -miphoneos-version-min="$SDK_MIN" \
        -framework Foundation \
        -framework CoreFoundation \
        -framework UIKit \
        -framework CoreGraphics \
        -framework IOKit \
        -framework Security \
        -framework NetworkExtension \
        -ldl \
        $OBJS \
        -o "$BIN"

    echo "  生成: $BIN"
done

# 合并为 fat binary
if [ -f "$OUTDIR/${DAEMON}_arm64" ] && [ -f "$OUTDIR/${DAEMON}_arm64e" ]; then
    lipo -create "$OUTDIR/${DAEMON}_arm64" "$OUTDIR/${DAEMON}_arm64e" \
        -output "$OUTDIR/$DAEMON"
elif [ -f "$OUTDIR/${DAEMON}_arm64" ]; then
    cp "$OUTDIR/${DAEMON}_arm64" "$OUTDIR/$DAEMON"
fi

# 签名
if command -v ldid >/dev/null 2>&1; then
    ldid -S "$OUTDIR/$DAEMON"
fi

echo "=== 编译完成: $OUTDIR/$DAEMON ==="
ls -lh "$OUTDIR/$DAEMON"

# ============================================================
# 编译 Dashboard App (SpringBoard 可见应用, arm64+arm64e fat)
# ============================================================
echo ""
echo "=== 编译 Dashboard App (arm64+arm64e fat) ==="
APP_FAT_BIN="$OUTDIR/AutoGo"
APP_BINS=""
for ARCH in $ARCHS; do
    echo "  架构: $ARCH"
    APP_OBJS=""
    for f in app/*.m; do
        obj="$OUTDIR/$(basename $f .m)_${ARCH}_app.o"
        echo "编译 $f ($ARCH)..."
        clang -arch "$ARCH" \
            -isysroot "$SDK_PATH" \
            -miphoneos-version-min="$SDK_MIN" \
            -fobjc-arc \
            -fmodules \
            -fPIE \
            -I"$SDK_PATH/usr/include" \
            -Iapp \
            -c "$f" -o "$obj"
        APP_OBJS="$APP_OBJS $obj"
    done

    APP_BIN="$OUTDIR/AutoGo_${ARCH}"
    echo "链接 App ($ARCH)..."
    clang -arch "$ARCH" \
        -isysroot "$SDK_PATH" \
        -miphoneos-version-min="$SDK_MIN" \
        -pie \
        -framework UIKit \
        -framework Foundation \
        -framework CoreGraphics \
        $APP_OBJS \
        -o "$APP_BIN"
    APP_BINS="$APP_BINS $APP_BIN"
done

# 合并为 fat binary
if [ "$(echo "$APP_BINS" | wc -w)" -ge 2 ]; then
    lipo -create $APP_BINS -output "$APP_FAT_BIN"
else
    cp $APP_BINS "$APP_FAT_BIN"
fi
chmod 755 "$APP_FAT_BIN"

# 使用 entitlement 签名 (解决闪退问题)
if [ -f app/entitlements.plist ]; then
    ldid -Sapp/entitlements.plist "$APP_FAT_BIN"
    echo "App 已使用 entitlements.plist 签名"
else
    ldid -S "$APP_FAT_BIN" 2>/dev/null || echo "App 签名跳过"
fi
echo "App 编译完成: $APP_FAT_BIN"
ls -lh "$APP_FAT_BIN"

# ============================================================
# 组装 DEB (Rootless 结构)
# ============================================================
echo ""
echo "=== 组装 DEB 包 (Rootless / iphoneos-arm64e) ==="
DEB_ROOT="$OUTDIR/deb_root"
rm -rf "$DEB_ROOT"
mkdir -p "$DEB_ROOT/DEBIAN"
mkdir -p "$DEB_ROOT/var/jb/usr/bin"
mkdir -p "$DEB_ROOT/var/jb/Library/LaunchDaemons"
mkdir -p "$DEB_ROOT/var/jb/Applications/AutoGo.app"

cp "$OUTDIR/$DAEMON" "$DEB_ROOT/var/jb/usr/bin/"
chmod 755 "$DEB_ROOT/var/jb/usr/bin/$DAEMON"

# Dashboard App (fat binary + signed with entitlements)
cp "$APP_FAT_BIN" "$DEB_ROOT/var/jb/Applications/AutoGo.app/AutoGo"
chmod 755 "$DEB_ROOT/var/jb/Applications/AutoGo.app/AutoGo"
cp app/Info.plist "$DEB_ROOT/var/jb/Applications/AutoGo.app/Info.plist"
cp app/entitlements.plist "$DEB_ROOT/var/jb/Applications/AutoGo.app/entitlements.plist"

# 复制 App 图标 (解决白图标问题)
if [ -f resources/META-INF/appicon.png ]; then
    cp resources/META-INF/appicon.png "$DEB_ROOT/var/jb/Applications/AutoGo.app/AppIcon60x60@2x.png"
    cp resources/META-INF/appicon.png "$DEB_ROOT/var/jb/Applications/AutoGo.app/AppIcon60x60.png"
    echo "App 图标已复制"
else
    echo "警告: 未找到 resources/META-INF/appicon.png"
fi

cp DEBIAN/control "$DEB_ROOT/DEBIAN/"
cp DEBIAN/postinst "$DEB_ROOT/DEBIAN/"
cp DEBIAN/prerm "$DEB_ROOT/DEBIAN/"
chmod 755 "$DEB_ROOT/DEBIAN/postinst" "$DEB_ROOT/DEBIAN/prerm"
cp Library/LaunchDaemons/com.autogo.daemon.plist "$DEB_ROOT/var/jb/Library/LaunchDaemons/"

DEB_NAME="com.autogo.daemon_1.0.0_iphoneos-arm64e.deb"
if command -v dpkg-deb >/dev/null 2>&1; then
    dpkg-deb -b "$DEB_ROOT" "$OUTDIR/$DEB_NAME"
elif command -v dpkg >/dev/null 2>&1; then
    dpkg -b "$DEB_ROOT" "$OUTDIR/$DEB_NAME"
else
    (cd "$DEB_ROOT" && tar czf "../$DEB_NAME.tar.gz" .)
fi

echo "DEB: $OUTDIR/$DEB_NAME"
ls -lh "$OUTDIR/$DEB_NAME" 2>/dev/null || true
