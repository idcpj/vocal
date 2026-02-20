import 'package:flutter/material.dart';
import 'package:nsd/nsd.dart' as nsd;
import 'vocal_home_controller.dart';

class DeviceSelectionPage extends StatefulWidget {
  final VocalHomeController controller;

  const DeviceSelectionPage({super.key, required this.controller});

  @override
  State<DeviceSelectionPage> createState() => _DeviceSelectionPageState();
}

class _DeviceSelectionPageState extends State<DeviceSelectionPage> {
  VocalHomeController get _ctrl => widget.controller;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onUpdate);
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              _buildWifiIcon(),
              const SizedBox(height: 24),
              const Text(
                '发现以下设备',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '选择要连接的 Mac',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(child: _buildDeviceList()),
              _buildScanStatus(),
              const SizedBox(height: 12),
              _buildCancelButton(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Row(
              children: [
                Icon(Icons.chevron_left, color: Color(0xFF22D3EE), size: 24),
                SizedBox(width: 4),
                Text(
                  '返回',
                  style: TextStyle(
                    color: Color(0xFF22D3EE),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Text(
            '选择设备',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 60), // spacer to balance layout
        ],
      ),
    );
  }

  Widget _buildWifiIcon() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF22D3EE).withValues(alpha: 0.1),
      ),
      child: const Icon(Icons.wifi, color: Color(0xFF22D3EE), size: 40),
    );
  }

  Widget _buildDeviceList() {
    final services = _ctrl.discoveredServices;
    if (services.isEmpty) {
      return Center(
        child: Text(
          '正在搜索设备...',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 16,
          ),
        ),
      );
    }
    return ListView.separated(
      itemCount: services.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final service = services[index];
        return _buildDeviceCard(service);
      },
    );
  }

  Widget _buildDeviceCard(nsd.Service service) {
    final name = service.name ?? 'Unknown Device';
    final address = '${service.host ?? '?'}:${service.port ?? '?'}';

    // Pick icon based on name
    IconData icon = Icons.computer;
    if (name.toLowerCase().contains('macbook') ||
        name.toLowerCase().contains('laptop')) {
      icon = Icons.laptop_mac;
    } else if (name.toLowerCase().contains('imac')) {
      icon = Icons.desktop_mac;
    }

    return GestureDetector(
      onTap: () {
        _ctrl.connectToService(service);
        Navigator.pop(context);
      },
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF22D3EE), size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                      fontFamily: 'JetBrains Mono',
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF475569), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildScanStatus() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF22D3EE),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '正在扫描...',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildCancelButton() {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF475569)),
        ),
        alignment: Alignment.center,
        child: const Text(
          '取消',
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
