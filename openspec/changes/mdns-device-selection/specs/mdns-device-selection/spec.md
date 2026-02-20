## ADDED Requirements

### Requirement: Device Discovery List
系统 SHALL 在 mDNS 发现服务时将所有发现的 `_vocal._tcp` 服务收集到一个列表中，而非自动连接第一个。

#### Scenario: Multiple devices discovered
- **WHEN** mDNS 发现了多个 VocalHost 服务
- **THEN** 所有服务 SHALL 被添加到 `discoveredServices` 列表并通知 UI 更新

#### Scenario: New device appears during scanning
- **WHEN** 用户在设备选择页时有新设备被发现
- **THEN** 新设备 SHALL 自动出现在列表中

### Requirement: Device Selection Page
系统 SHALL 提供一个设备选择页面，显示所有已发现的 Mac 设备列表。

#### Scenario: Navigate to device selection
- **WHEN** 用户点击首页 Header 中的红色设备数量 badge
- **THEN** 系统 SHALL 导航到设备选择页面，显示所有已发现的设备

#### Scenario: Device list display
- **WHEN** 设备选择页面展示时
- **THEN** 每个设备卡片 SHALL 显示设备名称（service.name）和地址（host:port）

#### Scenario: Select a device
- **WHEN** 用户点击某个设备卡片
- **THEN** 系统 SHALL 连接到该设备并返回首页

#### Scenario: Cancel selection
- **WHEN** 用户点击返回按钮或取消按钮
- **THEN** 系统 SHALL 返回首页，不改变当前连接状态

### Requirement: Device Count Badge
首页 Header SHALL 在 Online 徽章右侧显示红色设备数量 badge，反映当前已发现的设备数量。

#### Scenario: Device count display
- **WHEN** mDNS 发现了 N 个设备
- **THEN** 红色 badge SHALL 显示数字 N

#### Scenario: Badge tap navigation
- **WHEN** 用户点击红色设备数量 badge
- **THEN** 系统 SHALL 导航到设备选择页面

### Requirement: Scanning Status
设备选择页 SHALL 显示扫描状态指示器。

#### Scenario: Active scanning
- **WHEN** mDNS 发现正在运行且设备列表为空
- **THEN** 页面 SHALL 显示「正在扫描...」状态提示

#### Scenario: Devices found
- **WHEN** 设备列表不为空
- **THEN** 页面 SHALL 同时显示设备列表和扫描状态
