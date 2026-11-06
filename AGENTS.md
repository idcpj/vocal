# AGENTS.md - Vocal 项目开发与协作指南

本指南专为 AI Agent（以及协同开发人员）编写，旨在帮助 Agent 快速理解 **Vocal** 项目的整体架构、核心通信协议、环境配置、构建命令及开发陷阱。

---

## 1. 项目简介与核心愿景

**Vocal** 是一个基于 iPhone 的 Mac 高速、低延迟语音录入键盘。
它将 iPhone 转换为专业的远程麦克风/听写键盘：
1. iPhone 端利用 Apple 原生 `SFSpeechRecognizer` 进行高精度本地语音听写；
2. 识别到的文本通过局域网内低延迟 WebSocket 连接实时推送到 Mac 宿主；
3. Mac 宿主程序接收文本并通过 macOS 辅助功能 API（Accessibility Event）将字符无缝注入到当前活跃的光标焦点应用中。

---

## 2. 架构与通信协议

### 2.1 整体数据流

```mermaid
graph LR
    subgraph iPhone [iPhone Client (Flutter)]
        STT[SFSpeechRecognizer 听写引擎] --> Controller[VocalHomeController]
        Discovery[nsd mDNS 发现] --> Controller
        Controller --> WSClient[WebSocketClient]
    end

    subgraph Mac [Mac Host (Swift)]
        Bonjour[NetService 广播 _vocal._tcp]
        WSServer[NWListener 端口 8888]
        Inject[CGEvent Unicode 注入]
        WSServer --> Inject
    end

    Discovery -.->|1. 发现服务| Bonjour
    WSClient ===|2. WebSocket 长连接| WSServer
    Inject ==>|3. 键盘按键模拟| ActiveApp[当前活跃的 macOS 应用]
```

### 2.2 通信协议标准

1. **服务发现 (mDNS / Bonjour)**:
   - 域名/域：`local.`
   - 服务类型：`_vocal._tcp`
   - 端口：`8888`
   - 服务名：Mac 主机名称（默认由 `Host.current().localizedName` 获取，如 `VocalHost`）
2. **WebSocket 传输**:
   - 协议：`ws://<Mac_IP>:8888`
   - 业务文本传输（双向与向下兼容）：
     - 结构化 JSON（当前标准）：`{"type": "text", "text": "...", "pressEnter": true/false}`，当 `pressEnter` 为 `true` 时，Mac 端输入完 Unicode 字符后自动模拟按下 `kVK_Return`（虚拟键码 `0x24`）。
     - 纯文本降级（兼容模式）：若收到非 JSON 纯字符串，Mac 端直接执行 Unicode 文本注入，不触发回车。
   - 心跳保活 (Heartbeat)：
     - Mac 端作为 Server，每 5 秒发送 Ping：`{"type": "ping"}`
     - iOS 端接收后应答 Pong：`{"type": "pong"}`
     - iOS 端若超过 15 秒未收到 Ping 则判定连接超时并断开重连。
3. **文本输入、手动发送与自动回车机制**:
   - 手机端采用“本地草稿累加 + 用户手动确认发送”模式。
   - 语音识别（`speech_to_text`）或软键盘输入的文字会实时保存在本地草稿输入框（`textDraft`）中，用户可自由审阅、修改错别字或追加内容。
   - 语音静音（900ms）或单句结束时仅停止麦克风，**不会自动触发网络传输**。
   - 手机端提供“回车”切换开关（`autoPressEnter`）。开启时，点击“发送到 Mac”会在 Mac 焦点窗口完成打字后紧接着模拟触发回车键，实现一键发送聊天消息/执行终端命令；关闭时仅注入文字不敲回车。

---

## 3. 技术栈与目录结构

### 3.1 技术栈

| 模块 | 技术栈 / 依赖 | 说明 |
| :--- | :--- | :--- |
| **Mac 端 (Host)** | Swift, Cocoa, `Network.framework`, `NetService`, Accessibility API | 轻量无 Dock 常驻菜单栏应用（Accessory） |
| **iOS 端 (Client)** | Flutter (`3.41.2`), FVM, Dart (`^3.8.1`) | `speech_to_text`, `nsd`, `web_socket_channel` |
| **规范体系** | OpenSpec (`openspec/`), `.agent/` | Spec 驱动开发与变更管理 |

### 3.2 目录结构

```text
/Users/idcpj/workspace/vocal/
├── AGENTS.md               # [本文档] AI Agent 协作与架构指南
├── README_zh.md / README.md# 项目中英文说明文档
├── DEBUG.md                # 关键调试备忘录与运行命令
├── TODO.md                 # 待办特性列表
├── vocal.pen               # UI/原型设计工程文件 (Pencil 原型)
├── mac/                    # macOS 宿主程序工程
│   ├── VocalHostApp.swift  # Mac 端核心 Swift 源码（单文件自包含）
│   ├── Info.plist          # Mac 应用元信息
│   ├── AppIcon.icns        # Mac 应用图标
│   └── build_macos.sh      # 编译独立 Bundle 并打包 DMG 脚本
├── mobile/                 # Flutter 客户端源码
│   ├── lib/
│   │   ├── main.dart       # 应用入口
│   │   └── page/
│   │       ├── vocal_home_screen.dart      # 主界面（状态指示、动效、历史记录）
│   │       ├── vocal_home_controller.dart  # 业务控制器（STT、mDNS、WS、去抖）
│   │       └── device_selection_page.dart  # 多设备扫描与连接选择页
│   ├── pubspec.yaml        # Flutter 依赖配置
│   └── test/               # 单元测试与 Widget 测试
├── docs/imgs/              # 界面效果预览截图
├── website/                # 开源官方落地页/介绍网站 (纯静态暗黑科技风)
│   ├── index.html          # 官网主页 (双端截图、特性网格、工作原理、FAQ)
│   ├── style.css           # 现代化高质感暗色与毛玻璃样式
│   ├── main.js             # 终端复制与交互脚本
│   └── images/             # 官网素材与真机截图
├── openspec/               # OpenSpec 规范与变更集
└── .agent/                 # Agent 技能库与工作流
```

---

## 4. 关键陷阱与开发约束 (CRITICAL)

> [!CAUTION]
> **1. iOS 26 真机严禁使用 Debug 模式运行！**
> 由于 iOS 26 内存保护限制，Flutter 的 Debug 模式真机运行会触发 `EXC_BAD_ACCESS` 崩溃。
> 真机调试和安装时，必须强制指定 `--profile` 或 `--release`：
> ```bash
> fvm flutter run -d <DEVICE_ID> --profile
> ```

> [!IMPORTANT]
> **2. Mac 端辅助功能 (Accessibility) 权限限制**
> - Mac 注入文本依赖 `CGEvent.post(tap: .cgAnnotatedSessionEventTap)`。
> - 必须在 `系统设置 > 隐私与安全性 > 辅助功能` 中勾选授权 **VocalHost**。
> - 若使用终端直接运行可执行文件，则需要授权运行该程序的终端终端（如 `Terminal` / `iTerm2`）。

> [!WARNING]
> **3. 局域网防火墙与网络隔离**
> - iPhone 与 Mac 必须在同一局域网（同一 Wi-Fi 子网）。
> - 路由器若开启 AP 隔离将导致 mDNS 发现失败以及 WebSocket 无法建连。

---

## 5. 常用开发与构建命令

### 5.1 Mac 宿主端

- **直接编译并运行测试**:
  ```bash
  swiftc -o VocalHost mac/VocalHostApp.swift -parse-as-library && ./VocalHost
  ```
- **构建 DMG 发布包**:
  ```bash
  ./mac/build_macos.sh
  ```
  打包产物将位于 `build_macos/VocalHost.dmg`。

### 5.2 iOS 客户端

- **Flutter 版本管理**:
  本项目使用 [FVM](https://fvm.app/)，Flutter 固定版本为 `3.41.2`。所有 flutter 相关命令优先使用 `fvm flutter`：
  ```bash
  cd mobile
  fvm flutter pub get
  ```
- **查看连接设备列表**:
  ```bash
  fvm flutter devices
  ```
- **真机 Profile 模式运行 (严禁 Debug)**:
  ```bash
  fvm flutter run -d <DEVICE_ID> --profile
  ```
- **运行单元/组件测试**:
  ```bash
  cd mobile && fvm flutter test
  ```

---

## 6. Agent 协作与代码规范

1. **语言规则**:
   - 必须使用**中文**回答用户问题。
   - Git Commit Message 必须使用**中文**（如 `feat: 新增设备连接 PIN 码验证支持`）。
2. **终端与文件操作规则**:
   - 优先使用 IDE 内置工具（`view_file`, `write_to_file`, `replace_file_content`），避免使用终端重定向命令。
   - 文件保持 `UTF-8 无 BOM` 编码。
   - 禁止在终端中运行需要交互输入的命令（如卡住终端的 `read`, 交互式 prompt 等）。
3. **架构与状态保持**:
   - 保持 `mobile` 端 Controller 与 UI 的清晰解耦（UI 由 `VocalHomeScreen` 负责，连接、STT 状态及去抖逻辑统一封装于 `VocalHomeController`）。
   - 变更通讯协议（如添加加密、PIN 码配对、快捷键触发）时，必须同时兼顾 `mac/VocalHostApp.swift` 与 `mobile/lib/page/vocal_home_controller.dart` 两侧的双向兼容。
