import 'package:flutter/material.dart';
import 'package:vocal/page/device_selection_page.dart';
import 'package:vocal/page/vocal_home_controller.dart';

class VocalHomeScreen extends StatefulWidget {
  const VocalHomeScreen({super.key});

  @override
  State<VocalHomeScreen> createState() => _VocalHomeScreenState();
}

class _VocalHomeScreenState extends State<VocalHomeScreen>
    with SingleTickerProviderStateMixin {
  late final VocalHomeController _ctrl;
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _ctrl = VocalHomeController();
    _ctrl.addListener(_onControllerUpdate);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onControllerUpdate);
    _ctrl.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ─── Build ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildMicArea(),
            if (_ctrl.historyList.isNotEmpty) _buildHistorySection(),
            _buildTranscriptionBlock(),
          ],
        ),
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'VOCAL',
            style: TextStyle(
              color: Color(0xFF22D3EE),
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          Row(
            children: [
              _buildConnectionBadge(),
              if (_ctrl.discoveredServices.isNotEmpty) ...[
                const SizedBox(width: 8),
                _buildDeviceCountBadge(),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionBadge() {
    final color = _ctrl.isConnected ? Colors.green : Colors.red;
    final label = _ctrl.isConnected ? 'ONLINE' : 'OFFLINE';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 3, backgroundColor: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCountBadge() {
    final count = _ctrl.discoveredServices.length;
    const badgeColor = Color(0xFFEAB308); // Amber/Yellow
    return GestureDetector(
      onTap: _navigateToDeviceSelection,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.computer, color: badgeColor, size: 14),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: const TextStyle(
                color: badgeColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToDeviceSelection() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DeviceSelectionPage(controller: _ctrl),
      ),
    );
  }

  // ─── Mic Button Area ─────────────────────────────────────

  Widget _buildMicArea() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _ctrl.statusText.toUpperCase(),
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 12,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 48),
            _buildMicButton(),
            const SizedBox(height: 32),
            Text(
              _ctrl.isListening ? 'LISTENING...' : 'PUSH TO TALK',
              style: const TextStyle(
                color: Color(0xFF22D3EE),
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMicButton() {
    return GestureDetector(
      onTap: () {
        if (_ctrl.isListening) {
          _ctrl.stopListening();
        } else {
          _ctrl.startListening();
        }
      },
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          return Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF22D3EE).withOpacity(0.05),
              border: Border.all(
                color: const Color(
                  0xFF22D3EE,
                ).withOpacity(0.3 + (_animController.value * 0.4)),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0xFF22D3EE,
                  ).withOpacity(_ctrl.isListening ? 0.2 : 0.05),
                  blurRadius: 20 + (_animController.value * 20),
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              _ctrl.isListening ? Icons.mic : Icons.mic_none,
              size: 48,
              color: const Color(0xFF22D3EE),
            ),
          );
        },
      ),
    );
  }

  // ─── History Section ─────────────────────────────────────

  Widget _buildHistorySection() {
    return Container(
      height: 120,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HISTORY',
            style: TextStyle(
              color: Colors.white.withOpacity(0.2),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _ctrl.historyList.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    _ctrl.historyList[index],
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 13,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── Transcription Block ─────────────────────────────────

  Widget _buildTranscriptionBlock() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 180),
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notes, size: 14, color: Colors.white.withOpacity(0.3)),
              const SizedBox(width: 8),
              Text(
                'LIVE TRANSCRIPTION',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTranscriptionText(),
        ],
      ),
    );
  }

  Widget _buildTranscriptionText() {
    final sent = _ctrl.lastSentWords;
    final full = _ctrl.lastWords;

    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 16, height: 1.5, fontFamily: 'Inter'),
        children: [
          if (sent.isNotEmpty && full.startsWith(sent)) ...[
            TextSpan(
              text: sent,
              style: TextStyle(
                color: Colors.greenAccent.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
            TextSpan(
              text: full.substring(sent.length),
              style: TextStyle(color: Colors.white.withOpacity(0.9)),
            ),
          ] else ...[
            TextSpan(
              text: full,
              style: TextStyle(color: Colors.white.withOpacity(0.9)),
            ),
          ],
          if (full.isEmpty)
            TextSpan(
              text: 'Transcription will appear here...',
              style: TextStyle(color: Colors.white.withOpacity(0.2)),
            ),
        ],
      ),
    );
  }
}
