#!/bin/bash
# AutoGo Daemon (ObjC) 构建脚本
# 使用 theos 编译; 若无 theos，可用 clang 手动编译

set -e

DAEMON="ios-autogo"
OUTDIR="build"

# 检测 theos
if [ -n "$THEOS" ] && [ -f "$THEOS/makefiles/common.mk" ]; then
    echo "=== 使用 theos 编译 ==="
    make package
    echo "DEB 包在 packages/ 目录"
    exit 0
fi

# 手动编译 (macOS + Xcode)
echo "=== 手动编译 (clang + SDK) ==="

SDK_PATH="${SDK_PATH:-$(xcrun --sdk iphoneos --show-sdk-path 2>/dev/null)}"
if [ -z "$SDK_PATH" ]; then
    echo "错误: 找不到 iPhoneOS SDK. 请安装 Xcode."
    echo "或者设置 SDK_PATH 环境变量."
    exit 1
fi

echo "SDK: $SDK_PATH"

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
            -miphoneos-version-min=13.0 \
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
        -miphoneos-version-min=13.0 \
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

# 组装 DEB
echo ""
echo "=== 组装 DEB 包 ==="
DEB_ROOT="$OUTDIR/deb_root"
rm -rf "$DEB_ROOT"
mkdir -p "$DEB_ROOT/DEBIAN"
mkdir -p "$DEB_ROOT/usr/bin"
mkdir -p "$DEB_ROOT/Library/LaunchDaemons"
mkdir -p "$DEB_ROOT/var/mobile/Documents/autogo/screenshots"
mkdir -p "$DEB_ROOT/var/mobile/Documents/autogo/logs"

cp "$OUTDIR/$DAEMON" "$DEB_ROOT/usr/bin/"
chmod 755 "$DEB_ROOT/usr/bin/$DAEMON"
cp DEBIAN/control "$DEB_ROOT/DEBIAN/"
cp DEBIAN/postinst "$DEB_ROOT/DEBIAN/"
cp DEBIAN/prerm "$DEB_ROOT/DEBIAN/"
chmod 755 "$DEB_ROOT/DEBIAN/postinst" "$DEB_ROOT/DEBIAN/prerm"
cp Library/LaunchDaemons/com.autogo.daemon.plist "$DEB_ROOT/Library/LaunchDaemons/"

DEB_NAME="com.autogo.daemon_1.0.0_iphoneos-arm.deb"
if command -v dpkg-deb >/dev/null 2>&1; then
    dpkg-deb -b "$DEB_ROOT" "$OUTDIR/$DEB_NAME"
elif command -v dpkg >/dev/null 2>&1; then
    dpkg -b "$DEB_ROOT" "$OUTDIR/$DEB_NAME"
else
    (cd "$DEB_ROOT" && tar czf "../$DEB_NAME.tar.gz" .)
fi

echo "DEB: $OUTDIR/$DEB_NAME"
ls -lh "$OUTDIR/$DEB_NAME" 2>/dev/null || true
