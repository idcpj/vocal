## Why

当前 mDNS 发现服务后会自动连接第一个发现的 Mac，用户无法选择目标设备。在多台 Mac 同时运行 VocalHost 的环境中（如办公室），用户需要能够选择具体连接哪台设备。

## What Changes

- **新增设备选择页面**：mDNS 发现到多个服务时，显示设备列表供用户选择，而非自动连接第一个
- **修改 mDNS 发现逻辑**：收集所有发现的服务到列表，不再发现即连接
- **首页 Header 添加设备数量提示**：在 Online 徽章右侧显示红色设备数量 badge，点击跳转到设备选择页
- **设备选择页 UI**：
  - 顶部「← 返回」按钮 + 居中标题「选择设备」
  - WiFi 图标 + 标题「发现以下设备」
  - 设备卡片列表（显示设备名称、地址、图标）
  - 底部扫描状态指示 + 取消按钮
- **点击设备卡片**：连接到所选 Mac 并返回首页

## Capabilities

### New Capabilities
- `mdns-device-selection`: mDNS 发现的设备列表展示与用户选择功能，包括 UI 页面、导航逻辑和设备选择后的连接流程

### Modified Capabilities
_(无已有 spec 需修改)_

## Impact

- **`mobile/lib/vocal_home_controller.dart`**：重构 `discoverServices()` — 从自动连接改为收集服务列表并通知 UI
- **`mobile/lib/main.dart`**：添加设备数量 badge 到 Header、新增设备选择页面路由和 UI
- **用户体验**：从「自动连接第一个」变为「扫描 → 展示列表 → 用户选择 → 连接」
- **无 breaking change**：如果只发现一个设备，可以仍然自动连接（可选优化）
