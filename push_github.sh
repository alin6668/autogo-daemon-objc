#!/bin/bash
# AutoGo Daemon - Git 初始化并推送到 GitHub
# 用法: bash push_github.sh <你的GitHub仓库URL>
# 例如: bash push_github.sh git@github.com:yourname/autogo-daemon-objc.git

set -e

REPO_URL="$1"

if [ -z "$REPO_URL" ]; then
    echo "用法: bash push_github.sh <GitHub仓库URL>"
    echo ""
    echo "示例:"
    echo "  bash push_github.sh git@github.com:myuser/autogo-daemon-objc.git"
    echo "  bash push_github.sh https://github.com/myuser/autogo-daemon-objc.git"
    echo ""
    echo "请先在 GitHub 上创建空仓库 (不要勾选 README/LICENSE/gitignore)"
    exit 1
fi

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

echo "=== AutoGo Daemon 推送到 GitHub ==="
echo "项目目录: $PROJECT_DIR"
echo "远程仓库: $REPO_URL"
echo ""

# Git 全局配置检查
if ! git config --global user.name >/dev/null 2>&1; then
    echo "请输入你的名字 (git config):"
    read -r GIT_NAME
    git config --global user.name "$GIT_NAME"
fi

if ! git config --global user.email >/dev/null 2>&1; then
    echo "请输入你的邮箱 (git config):"
    read -r GIT_EMAIL
    git config --global user.email "$GIT_EMAIL"
fi

# 初始化 Git (如果还未初始化)
if [ ! -d ".git" ]; then
    echo "[1/4] 初始化 Git 仓库..."
    git init
    git checkout -b main 2>/dev/null || git checkout -b master
else
    echo "[1/4] Git 仓库已存在"
fi

# 确保 .gitattributes 有正确的行尾处理
echo "[2/4] 配置 .gitattributes..."
cat > .gitattributes << 'EOF'
# 文本文件统一 LF 行尾
*.m text eol=lf
*.h text eol=lf
*.plist text eol=lf
*.sh text eol=lf
*.md text eol=lf
*.yml text eol=lf
*.yaml text eol=lf

# 二进制
*.png binary
*.dylib binary
*.deb binary
EOF

# 添加所有文件
echo "[3/4] 添加文件并提交..."
git add -A
git status

echo ""
echo "准备提交以下内容:"
git diff --cached --stat

echo ""
echo "确认推送? (y/n)"
read -r CONFIRM

if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "已取消"
    exit 0
fi

git commit -m "feat: AutoGo Daemon - iOS 综合设备控制守护进程

- 纯 Objective-C 原生实现
- HTTP REST API (60+ 端点) + MCP 协议 (50+ Tools)
- 集成 ios-mcp & go-ios 全部功能
- 编译目标: arm64 + arm64e, iOS 13.0+
- GitHub Actions CI/CD 自动编译 DEB"

# Push
echo "[4/4] 推送到 GitHub..."
git remote remove origin 2>/dev/null || true
git remote add origin "$REPO_URL"
git push -u origin main 2>/dev/null || git push -u origin master

echo ""
echo "=== 推送完成! ==="
echo ""
echo "查看 GitHub Actions 编译状态:"
echo "  ${REPO_URL%.git}/actions"
echo ""
echo "下载编译产物:"
echo "  Actions 页面 → 选择最新 workflow run → Artifacts → com.autogo.daemon-xxx"
echo ""
