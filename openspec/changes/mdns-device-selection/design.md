## Context

Vocal 应用当前的 mDNS 发现逻辑（`vocal_home_controller.dart` line 68-98）在发现第一个 `_vocal._tcp` 服务后立即自动连接。在多 Mac 环境中用户无法选择目标设备。

UI 设计已在 `vocal.pen` 完成：
- **首页（t0xxC）**：Header 右侧有绿色 Online badge + 红色设备数量 badge
- **设备选择页（FmSgu）**：返回按钮 + 设备卡片列表 + 扫描状态 + 取消按钮

## Goals / Non-Goals

**Goals:**
- 用户可以从发现的设备列表中选择要连接的 Mac
- 设备列表实时更新（新设备出现时自动添加）
- 首页显示可用设备数量，点击跳转到选择页
- 选择设备后连接并返回首页

**Non-Goals:**
- 记住上次连接的设备（不做自动重连偏好）
- 设备分组或排序
- 多设备同时连接

## Decisions

### 1. 状态管理：在 Controller 中增加 discoveredServices 列表

**选择**: 在 `VocalHomeController` 中添加 `List<nsd.Service> _discoveredServices` 和对应 getter。

**理由**: 保持现有单 Controller 架构不变，只扩展状态。compared to 新建独立的 DiscoveryController——增加复杂度但收益小。

### 2. 页面导航：Flutter Navigator push/pop

**选择**: 使用 `Navigator.push` 从首页跳转到设备选择页，选择后 `Navigator.pop(selectedService)` 返回。

**理由**: 
- 应用只有两个页面，无需 GoRouter 等路由库
- `pop` 返回 service 对象，调用方直接连接

### 3. 发现策略：持续扫描直到用户选择

**选择**: 
- 启动时开始 mDNS 发现，收集所有服务到列表
- 不再自动连接第一个
- 用户选择后停止发现、连接所选设备

**理由**: 给用户完整的选择权。避免竞态条件（自动连接 vs 用户选择）。

### 4. UI 实现：独立 StatelessWidget 页面

**选择**: 新建 `DeviceSelectionPage` 作为独立 Widget，接收 `VocalHomeController` 通过 `ChangeNotifierProvider`/`ListenableBuilder`。

**理由**: 复用现有 controller 和 notifyListeners 机制，设备列表更新自动刷新 UI。

## Risks / Trade-offs

- **设备消失处理**：mDNS 服务可能消失（Mac 关机）→ 暂不处理，列表只增不减，简化实现
- **单设备优化缺失**：即使只有一个设备，仍需用户手动选择 → 保持一致性，避免边界条件复杂化
- **发现延迟**：mDNS 发现可能需要几秒 → UI 显示「正在扫描...」状态提示
