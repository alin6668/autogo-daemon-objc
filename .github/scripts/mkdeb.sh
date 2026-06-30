#!/bin/bash
# 在 macOS 上构建 .deb 包 (不依赖 dpkg)
# 用法: mkdeb.sh <deb_root> <output.deb>

set -e

ROOT="$1"
OUTPUT="$2"

if [ -z "$ROOT" ] || [ -z "$OUTPUT" ]; then
    echo "用法: $0 <deb_root> <output.deb>"
    exit 1
fi

TMPDIR=$(mktemp -d -t debbuild)

# 1. 创建控制文件 tar
mkdir -p "$TMPDIR/control"
cp -r "$ROOT/DEBIAN/"* "$TMPDIR/control/"
(cd "$TMPDIR/control" && tar czf "$TMPDIR/control.tar.gz" .)

# 2. 创建数据文件 tar
(cd "$ROOT" && find . -type f ! -path './DEBIAN/*' -print | sort | \
    xargs tar czf "$TMPDIR/data.tar.gz" --exclude='./DEBIAN')

# 3. 创建 debian-binary
echo "2.0" > "$TMPDIR/debian-binary"

# 4. 用 ar 打包成 .deb
(cd "$TMPDIR" && ar cr "$(basename "$OUTPUT")" \
    debian-binary control.tar.gz data.tar.gz)

mv "$TMPDIR/$(basename "$OUTPUT")" "$OUTPUT"
rm -rf "$TMPDIR"

echo "DEB 创建成功: $OUTPUT"
ls -lh "$OUTPUT"
