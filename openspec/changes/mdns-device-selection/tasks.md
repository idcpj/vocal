## 1. Controller 层 — 设备发现重构

- [x] 1.1 在 `VocalHomeController` 中添加 `_discoveredServices` 列表和 `discoveredServices` getter
- [x] 1.2 重构 `discoverServices()` 方法：收集所有服务到列表，不再自动连接
- [x] 1.3 添加 `connectToService(nsd.Service service)` 公开方法供 UI 调用
- [x] 1.4 添加 `stopDiscovery()` 方法用于停止扫描

## 2. 设备选择页面 UI

- [x] 2.1 创建 `DeviceSelectionPage` Widget（独立文件 `device_selection_page.dart`）
- [x] 2.2 实现返回按钮 + 居中标题「选择设备」Header
- [x] 2.3 实现 WiFi 图标 + 「发现以下设备」标题 + 副标题
- [x] 2.4 实现设备卡片列表（设备名、地址、箭头图标）— 使用 `ListenableBuilder` 监听 controller
- [x] 2.5 实现底部扫描状态指示器 + 取消按钮

## 3. 首页集成

- [x] 3.1 在首页 Header 添加红色设备数量 badge（显示 discoveredServices.length）
- [x] 3.2 badge 点击事件：Navigator.push 到 DeviceSelectionPage
- [x] 3.3 处理 DeviceSelectionPage 返回值：连接所选设备

## 4. 验证

- [x] 4.1 Flutter analyze 编译通过
- [ ] 4.2 手动测试：启动 → 扫描 → 显示设备列表 → 选择连接
