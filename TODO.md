## TODO

- [x] 生成一个网站用来介绍这个项目，你先调研下用什么技术栈处理， 并使用 docs 中的截图
- [x] 文字发送方式改为手动发送,先在手机端输入文字,自由点击发送时,才会发送到mac上,避免了实时发送导致的文字内容不一致的问题
- [x] 移动端但只有检测到一个设备时，自动连接
- [x] 手机端支持“自动回车”开关，发送文本到 Mac 后自动触发回车
- [x] 多语言实时切换支持
- [ ] 设备配对通过输入mac上的pin码进行配对，

### 待开发新功能与任务清单

- [x] **跨端自动化集成测试 (E2E Cross-platform Integration Tests)**
  - [x] 编写跨端模拟测试套件：模拟移动端 (iOS/Android) 建立 WebSocket 直连与 mDNS 握手流程
  - [x] 状态同步校验：断言验证 Mac 宿主端在有设备连接/断开时，状态栏及管理面板状态是否准确显示为“连接中 / 已连接 / 设备断开”
  - [x] 输入注入与通信链路断言：模拟传输文本、回车控制指令，校验消息收发协议格式及 Mac 端注入逻辑
  - [x] 容错与重连测试：模拟网络偶发断开、心跳超时与自动重连，验证双端状态机自愈能力

- [ ] **多渠道版本更新提示机制 (Update Notification)**
  - [ ] Mac 端新增版本检测服务与菜单项（“检查新版本...”）
  - [ ] 支持 GitHub Releases 检查更新：通过 GitHub API 获取最新 Release 版本号与 Release Notes，提供更新弹窗与一键跳转下载
  - [ ] 支持 Mac App Store (MAS) 检查更新：适配 App Store 渠道构建，提供商店应用更新检测与跳转
  - [ ] 更新交互与设置：支持自动检查更新开关、忽略特定版本、新版本徽标提示

- [ ] **Windows 原生宿主端开发 (Windows Host Support)**
  - [ ] 核心功能与 Mac 端保持完全一致：实现局域网 mDNS/Bonjour 广播与 WebSocket 服务端（默认 8888 端口）
  - [ ] 采用原生 Windows 语言与技术栈开发（如 C# / WinUI 3 / WPF 或 C++ / Rust），保证轻量、低内存占用与高执行效率
  - [ ] 焦点字符注入：调用 Windows 底层 `SendInput` API，精准将接收到的文本与回车无缝输入到当前焦点窗口
  - [ ] Windows 托盘生态：实现系统托盘常驻图标 (System Tray)、连接状态指示灯、右键菜单与设置面板

- [ ] **Android 客户端适配与测试 (Android Mobile Support)**
  - [ ] 基于现有 Flutter 架构适配 Android 端权限（麦克风录音、局域网多播 `CHANGE_WIFI_MULTICAST_STATE`）
  - [ ] 语音识别层调优：适配 Android 原生语音听写引擎（处理 Google 语音识别服务依赖、离线语音模型与错误容灾）
  - [ ] 局域网服务发现兼容：处理 Android 系统下的 NSD 多播锁 (MulticastLock) 机制，确保快速发现局域网宿主
  - [ ] 使用本地 Android Studio 模拟器/真机环境，完成编译、全链路功能自测与打包验证

- [ ] **全新趣味现代化产品官网 (Modern & Interactive Landing Page)**
  - [ ] 现代化视觉重塑：采用极简科技暗黑风、流畅平滑滚动与声波/流体动效
  - [ ] 趣味互动体验区：打造网页端交互式“语音输入到 Mac”实时打字模拟演示器，直观展示低延迟特性
  - [ ] 全平台矩阵展示：展示 iOS、Android、macOS、Windows 四端协同生态与功能亮点
  - [ ] 完善文档与下载中心：聚合 GitHub Release 下载、App Store / Google Play 预热链接、局域网安全与隐私说明

