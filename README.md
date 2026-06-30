# AutoGo Daemon (ObjC) — Rootless 版

iOS 综合设备控制守护进程，纯 Objective-C 原生实现。适配 **Dopamine (多巴胺)** 等 **Rootless 无根越狱**，运行在 `/var/jb` 环境下，提供 **HTTP REST API** 和 **MCP 协议** 双接口。

集成 [ios-mcp](https://github.com/witchan/ios-mcp) 和 [go-ios](https://github.com/danielpaulus/go-ios) 全部功能，并为 AI Agent 提供 50+ MCP Tools。

> **架构**: `iphoneos-arm64` (Rootless) · **最低 iOS**: 15.0 · **端口**: 8888

---

## 📱 Dashboard App

安装后在 SpringBoard 可见 **AutoGo** 应用图标，点击打开可查看：

- **服务状态**：实时检测守护进程是否激活（绿/红状态指示）
- **设备信息**：设备型号、iOS 版本、IP 地址
- **快捷操作**：一键打开 Web 控制台、API 文档
- **自动刷新**：每 10 秒自动检测服务状态

同时内置 **Web 控制台** (`http://设备IP:8888`) 提供完整的深色主题仪表盘。

---

## 功能特性

| 模块 | 功能 |
|------|------|
| 🖐 **触控手势** | tap, swipe, longpress, drag, 多点触控, 滑动路径 |
| ⌨️ **硬件按键** | Home, Power, Volume Up/Down, Mute, Siri, 组合键 |
| ✍️ **文字输入** | 文本输入, 按键事件, 剪贴板粘贴 |
| 📸 **截图** | PNG/JPEG 截图, GPU 图层截取, 缩放 |
| 📱 **App 管理** | 安装/卸载 ipa, 启动/终止 App, 列出已安装 App |
| ♿ **无障碍** | AssistiveTouch, 元素树获取, 元素点击, 属性读取 |
| 📋 **剪贴板** | 读/写系统剪贴板 |
| 📁 **文件系统** | 文件列表, 读写, 删除, 目录创建 |
| 📝 **系统日志** | syslog 读取, 进程列表, 崩溃日志 |
| 🔧 **设备控制** | 重启/关机/注销, 锁定, 手电筒, 振动, 深色模式 |
| 📶 **WiFi** | WiFi 开关/扫描/连接 (MobileWiFi 私有框架) |
| 🔒 **VPN** | IKEv2 VPN 创建/管理/连接/断开 |
| 💻 **Shell** | 任意命令执行, 超时控制, 环境变量 |
| 🌐 **URL** | URL Scheme 打开, 浏览器跳转 |
| 📐 **设备信息** | 型号, iOS 版本, 屏幕, 电池, 存储, 网络, 时间, 区域, 语言 |
| 🤖 **MCP 协议** | JSON-RPC 2.0, tools/list, tools/call, 50+ Tools |

---

## API 总览 (60+ 端点)

### 无障碍
```
GET  /api/accessibility/tree          # 获取元素树
POST /api/accessibility/element/click # 点击元素
POST /api/accessibility/element/set   # 设置元素值
POST /api/assistive-touch/enable      # 启用 AssistiveTouch
POST /api/assistive-touch/disable     # 禁用 AssistiveTouch
```

### App 管理
```
GET  /api/apps/list                   # 列出所有 App
POST /api/apps/launch                 # 启动 App
POST /api/apps/kill                   # 终止 App
POST /api/apps/install                # 安装 ipa
POST /api/apps/uninstall              # 卸载 App
```

### 剪贴板
```
GET  /api/clipboard/get               # 读取剪贴板
POST /api/clipboard/set               # 设置剪贴板
```

### 设备信息 & 控制
```
GET  /api/device/info                 # 完整设备信息
GET  /api/device/screen               # 屏幕信息
GET  /api/device/battery              # 电池详情
GET  /api/device/storage              # 存储用量
GET  /api/device/processes            # 进程列表
POST /api/device/flashlight           # 手电筒
POST /api/device/vibrate              # 振动
POST /api/device/screenshot           # 截图
POST /api/device/reboot               # 重启
POST /api/device/shutdown             # 关机
POST /api/device/lock                 # 锁屏
POST /api/device/setlang              # 设置语言
POST /api/device/setlocale            # 设置区域
POST /api/device/settime              # 设置时间
POST /api/url/open                    # 打开 URL
```

### 文件系统
```
GET  /api/files/list                  # 列出文件
POST /api/files/read                  # 读取文件
POST /api/files/write                 # 写入文件
POST /api/files/delete                # 删除文件
```

### 硬件按键
```
POST /api/hid/press                   # 按键按下
POST /api/hid/home                    # Home 键
POST /api/hid/power                   # 电源键
POST /api/hid/volume/up               # 音量+
POST /api/hid/volume/down             # 音量-
POST /api/hid/mute                    # 静音
POST /api/hid/siri                    # Siri
POST /api/hid/type                    # 输入文本
```

### Shell
```
POST /api/shell/exec                  # 执行命令
GET  /api/syslog                      # 获取 syslog
GET  /api/logs                        # 获取崩溃日志
```

### 触控手势
```
POST /api/touch/tap                   # 单击
POST /api/touch/doubletap             # 双击
POST /api/touch/longpress             # 长按
POST /api/touch/swipe                 # 滑动
POST /api/touch/drag                  # 拖拽
POST /api/touch/path                  # 路径滑动
POST /api/touch/multitouch            # 多点触控
```

### VPN
```
POST /api/vpn/create                  # 创建 IKEv2 VPN
POST /api/vpn/connect                 # 连接
POST /api/vpn/disconnect              # 断开
GET  /api/vpn/status                  # 状态
GET  /api/vpn/list                    # 列出现有
POST /api/vpn/delete                  # 删除
```

### WiFi
```
GET  /api/wifi/status                 # WiFi 状态
POST /api/wifi/toggle                 # 开关 WiFi
GET  /api/wifi/scan                   # 扫描网络
POST /api/wifi/connect                # 连接网络
```

### MCP 协议
```
POST /mcp                             # JSON-RPC 2.0 MCP 协议
     tools/list                       # 列出所有 50+ Tools
     tools/call                       # 调用任意 Tool
```

---

## 编译

### 方式 1: GitHub Actions (推荐)
推送代码到 GitHub 后自动编译，在 Actions 页面下载 `com.autogo.daemon-[sha].deb` 产物。

### 方式 2: macOS 本地编译

```bash
# 安装 theos
git clone https://github.com/theos/theos.git ~/theos

# 编译
cd autogo-daemon-objc
export THEOS=~/theos
make package

# DEB 包在 packages/ 目录
```

### 方式 3: clang 手动编译 (无 theos)

```bash
bash build.sh
```

---

### 安装到 iOS 设备 (Rootless)

```bash
# 上传 DEB
scp build/com.autogo.daemon_1.0.0_iphoneos-arm64.deb root@<设备IP>:/var/root/

# SSH 到设备安装
ssh root@<设备IP>
dpkg -i /var/root/com.autogo.daemon_1.0.0_iphoneos-arm64.deb

# 手动启动 (安装后自动启动)
launchctl load /var/jb/Library/LaunchDaemons/com.autogo.daemon.plist

# 验证
curl http://localhost:8888/health
```

### 通过 Sileo/Zebra 安装

在包管理器添加源 (或直接安装 DEB)，搜索 `AutoGo Daemon` 安装即可。包标记为 `iphoneos-arm64`，兼容 Dopamine 等 Rootless 环境。

---

## 使用示例

### REST API

```bash
# 健康检查
curl http://<设备IP>:8888/health

# 获取设备信息
curl http://<设备IP>:8888/api/device/info

# 截图
curl -X POST http://<设备IP>:8888/api/device/screenshot \
  -H "Content-Type: application/json" \
  -d '{"format":"png"}' > screenshot.png

# 单击坐标
curl -X POST http://<设备IP>:8888/api/touch/tap \
  -H "Content-Type: application/json" \
  -d '{"x":300,"y":500}'

# 滑动
curl -X POST http://<设备IP>:8888/api/touch/swipe \
  -H "Content-Type: application/json" \
  -d '{"fromX":100,"fromY":800,"toX":100,"toY":200,"duration":0.3}'

# 返回主屏幕
curl -X POST http://<设备IP>:8888/api/hid/home

# 启动 App
curl -X POST http://<设备IP>:8888/api/apps/launch \
  -H "Content-Type: application/json" \
  -d '{"bundleId":"com.apple.mobilesafari"}'

# 执行 Shell 命令
curl -X POST http://<设备IP>:8888/api/shell/exec \
  -H "Content-Type: application/json" \
  -d '{"command":"uptime"}'
```

### MCP 协议 (AI Agent 调用)

```bash
# 列出所有工具
curl -X POST http://<设备IP>:8888/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/list","id":1}'

# 调用工具 - 截图
curl -X POST http://<设备IP>:8888/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc":"2.0",
    "method":"tools/call",
    "params":{
      "name":"screenshot",
      "arguments":{}
    },
    "id":2
  }'
```

---

## 守护进程管理

```bash
# 加载 (开机自启)
launchctl load /var/jb/Library/LaunchDaemons/com.autogo.daemon.plist

# 卸载
launchctl unload /var/jb/Library/LaunchDaemons/com.autogo.daemon.plist

# 查看日志
tail -f /var/mobile/Documents/autogo/logs/daemon.log

# 查看状态
curl http://localhost:8888/health
```

---

## 项目结构

```
autogo-daemon-objc/
├── .github/workflows/build.yml     # GitHub Actions CI/CD (Rootless)
├── .gitignore
├── Makefile                        # theos 编译配置 (rootless scheme)
├── build.sh                        # clang 手动编译脚本
├── README.md
├── DEBIAN/
│   ├── control                     # DEB 包元数据 (iphoneos-arm64)
│   ├── postinst                    # 安装后脚本 (Rootless)
│   └── prerm                       # 卸载前脚本
├── Library/LaunchDaemons/
│   └── com.autogo.daemon.plist     # 守护进程配置 (var/jb 路径)
├── app/                            # Dashboard App (SpringBoard 可见)
│   ├── main.m                      # App 入口
│   ├── AGAppDelegate.h/m           # App 界面 (服务状态/设备信息)
│   └── Info.plist                  # App 元数据
└── src/                            # Objective-C 源码
    ├── main.m                      # 入口
    ├── AGJSON.h/m                  # JSON 序列化
    ├── AGHTTPServer.h/m            # BSD socket HTTP 服务器
    ├── AGRouter.h/m                # API 路由分发
    ├── AGDeviceInfo.h/m            # 设备信息 & 控制
    ├── AGTouchController.h/m       # IOKit HID 触控
    ├── AGAppController.h/m         # App 管理
    ├── AGFileController.h/m        # 文件系统
    ├── AGVPNController.h/m         # VPN 控制
    ├── AGWiFiController.h/m        # WiFi 控制
    ├── AGShellController.h/m       # Shell 命令
    ├── AGClipboardController.h/m   # 剪贴板
    ├── AGAccessibilityController.h/m # 无障碍
    ├── AGHIDController.h/m         # 硬件按键
    └── AGMCPHandler.h/m            # MCP 协议 (50+ Tools)
```

## Rootless (无根) 适配说明

本项目已完成 **Dopamine / 多巴胺** Rootless 无根越狱适配：

| 项目 | 修改 |
|------|------|
| `Architecture` | `iphoneos-arm` → `iphoneos-arm64` |
| 安装路径 | `/usr/bin/` → `/var/jb/usr/bin/` |
| LaunchDaemon | `/Library/` → `/var/jb/Library/` |
| 用户数据 | `/var/mobile/Documents/autogo/` (无 /var/jb 前缀) |
| 最低 iOS | 13.0 → 15.0 |
| DEB 包名 | `*_iphoneos-arm64.deb` |
| 默认端口 | 8090 → **8888** |
| Dashboard App | 无 → **SpringBoard 可见 App + Web 控制台** |

---
## 协议与许可

纯 Objective-C 实现，无第三方依赖。作为 root LaunchDaemon 在 Rootless 越狱设备 (`/var/jb`) 上运行，端口 8888。
