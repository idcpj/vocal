import 'package:flutter/material.dart';
import 'package:nsd/nsd.dart' as nsd;
import 'package:vocal/i18n/app_strings.dart';
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
    final strings = AppStrings.current;
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
              Text(
                strings.discoveredDevices,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                strings.chooseMac,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(child: _buildDeviceList()),
              _buildScanStatus(),
              const SizedBox(height: 12),
              _buildManualConnectButton(),
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
    final strings = AppStrings.current;
    return SizedBox(
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Row(
              children: [
                const Icon(Icons.chevron_left, color: Color(0xFF22D3EE), size: 24),
                const SizedBox(width: 4),
                Text(
                  strings.back,
                  style: const TextStyle(
                    color: Color(0xFF22D3EE),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            strings.selectDevice,
            style: const TextStyle(
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
    final strings = AppStrings.current;
    final services = _ctrl.discoveredServices;
    if (services.isEmpty) {
      return Center(
        child: Text(
          strings.searchingDevices,
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
    final strings = AppStrings.current;
    final name = service.name ?? strings.unknownDevice;
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
    final strings = AppStrings.current;
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
          strings.scanning,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildManualConnectButton() {
    final strings = AppStrings.current;
    return GestureDetector(
      onTap: _showManualConnectDialog,
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF22D3EE).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF22D3EE).withValues(alpha: 0.3)),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.settings_ethernet_rounded, color: Color(0xFF22D3EE), size: 18),
            const SizedBox(width: 8),
            Text(
              strings.manualConnect,
              style: const TextStyle(
                color: Color(0xFF22D3EE),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showManualConnectDialog() {
    final strings = AppStrings.current;
    final ipCtrl = TextEditingController();
    final portCtrl = TextEditingController(text: '8888');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          title: Text(
            strings.manualConnect,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ipCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: strings.enterMacIp,
                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                  hintText: strings.enterMacIpHint,
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25)),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF22D3EE)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: portCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: strings.port,
                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF22D3EE)),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                strings.cancel,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
              ),
            ),
            TextButton(
              onPressed: () {
                final ip = ipCtrl.text.trim();
                final port = int.tryParse(portCtrl.text.trim()) ?? 8888;
                if (ip.isNotEmpty) {
                  Navigator.pop(ctx);
                  _ctrl.connectDirect(ip, port).catchError((_) {});
                  Navigator.pop(context);
                }
              },
              child: Text(
                strings.connect,
                style: const TextStyle(
                  color: Color(0xFF22D3EE),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    ).whenComplete(() {
      ipCtrl.dispose();
      portCtrl.dispose();
    });
  }

  Widget _buildCancelButton() {
    final strings = AppStrings.current;
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
        child: Text(
          strings.cancel,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
