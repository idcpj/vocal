import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vocal/i18n/app_strings.dart';
import 'package:vocal/page/device_selection_page.dart';
import 'package:vocal/page/locale_selection_sheet.dart';
import 'package:vocal/page/vocal_home_controller.dart';

class VocalHomeScreen extends StatefulWidget {
  final VocalHomeController? controller;

  const VocalHomeScreen({super.key, this.controller});

  @override
  State<VocalHomeScreen> createState() => _VocalHomeScreenState();
}

class _VocalHomeScreenState extends State<VocalHomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final VocalHomeController _ctrl;
  bool _ownsController = false;
  late final AnimationController _animController;
  late final TextEditingController _textController;
  final FocusNode _focusNode = FocusNode();
  final ScrollController _historyScrollController = ScrollController();
  final TextEditingController _pinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.controller != null) {
      _ctrl = widget.controller!;
      _ownsController = false;
    } else {
      _ctrl = VocalHomeController();
      _ownsController = true;
    }
    _textController = TextEditingController();
    _ctrl.addListener(_onControllerUpdate);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    // Synchronize text from speech recognition to the TextField without breaking user cursor
    if (_textController.text != _ctrl.textDraft) {
      _textController.value = TextEditingValue(
        text: _ctrl.textDraft,
        selection: TextSelection.collapsed(offset: _ctrl.textDraft.length),
      );
    }
    final errMsg = _ctrl.speechErrorMessage;
    if (errMsg != null && errMsg.isNotEmpty) {
      // Non-blocking toast feedback for speech degradation
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _ctrl.speechErrorMessage != null) {
          _showDarkToast(context, errMsg, isSuccess: false);
          _ctrl.clearSpeechError();
        }
      });
    }
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _ctrl.handleAppLifecycleState(state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ctrl.removeListener(_onControllerUpdate);
    if (_ownsController) {
      _ctrl.dispose();
    }
    _animController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    _historyScrollController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  // ─── Build ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hasText = _textController.text.trim().isNotEmpty;
    final canSend = _ctrl.isConnected && hasText;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final isOccupied = _ctrl.connectionState == VocalConnectionState.occupied;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (isOccupied)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                child: _buildOccupiedBanner(),
              ),
            if (_ctrl.isPinRequired)
              Expanded(
                child: _buildPinPairingOverlay(),
              )
            else ...[
              // 1. History Section at Top (Collapses smoothly when keyboard opens)
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState: isKeyboardOpen
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
                  child: GestureDetector(
                    onTap: () => FocusScope.of(context).unfocus(),
                    behavior: HitTestBehavior.translucent,
                    child: _buildHistorySection(),
                  ),
                ),
                secondChild: const SizedBox(width: double.infinity, height: 0),
              ),
              // 2. Draft Editor Card at Bottom (Always single stable tree, zero rebuild flicker)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: _buildEditorCard(hasText: hasText),
                ),
              ),
              const SizedBox(height: 8),
              // 3. Dual-Action Bottom Bar (Voice + Send / Dismiss Keyboard + Send)
              _buildBottomActionBar(canSend, isKeyboardOpen),
            ],
          ],
        ),
      ),
    );
  }

  // ─── PIN Pairing View ─────────────────────────────────────

  Widget _buildPinPairingOverlay() {
    final strings = AppStrings.current;
    final errMsg = _ctrl.pinErrorMessage;
    final remaining = _ctrl.pinRemainingAttempts;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 345),
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFF22D3EE).withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF22D3EE).withValues(alpha: 0.12),
                blurRadius: 28,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFF22D3EE).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF22D3EE).withValues(alpha: 0.25),
                  ),
                ),
                child: const Center(
                  child: Text(
                    '🔐',
                    style: TextStyle(fontSize: 26),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Target Device Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.desktop_mac_rounded,
                      size: 13,
                      color: Color(0xFFE2E8F0),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _ctrl.statusText.contains('Connected to')
                          ? 'Mac Host'
                          : '局域网 Mac 主机',
                      style: const TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                strings.pinDialogTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                strings.pinDialogSub,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              // 4-digit PIN input container
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: errMsg != null
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF22D3EE),
                    width: 1.5,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: TextField(
                  controller: _pinController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF22D3EE),
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 10,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                    hintText: strings.pinInputHint,
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.2),
                      fontSize: 15,
                      letterSpacing: 2,
                    ),
                  ),
                  onChanged: (val) {
                    if (val.length == 4) {
                      HapticFeedback.selectionClick();
                      _ctrl.verifyPin(val);
                    }
                  },
                ),
              ),
              if (errMsg != null) ...[
                const SizedBox(height: 10),
                Text(
                  '$errMsg (${strings.remainingAttempts(remaining)})',
                  style: const TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              // Security tip badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 13,
                      color: Color(0xFF4ADE80),
                    ),
                    SizedBox(width: 5),
                    Text(
                      '局域网端到端鉴权 · 仅首次配对需输码',
                      style: TextStyle(
                        color: Color(0xFF4ADE80),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white.withValues(alpha: 0.6),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: () {
                        _pinController.clear();
                        _ctrl.cancelPinVerification();
                      },
                      child: Text(strings.cancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22D3EE),
                        foregroundColor: const Color(0xFF0F172A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        elevation: 0,
                      ),
                      onPressed: () {
                        if (_pinController.text.trim().isNotEmpty) {
                          HapticFeedback.selectionClick();
                          _ctrl.verifyPin(_pinController.text.trim());
                        }
                      },
                      child: Text(
                        strings.confirmPair,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
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
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF22D3EE).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'MANUAL',
                  style: TextStyle(
                    color: Color(0xFF22D3EE),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
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

  Widget _buildOccupiedBanner() {
    final strings = AppStrings.current;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0x4078350F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0x4DF59E0B),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                const Icon(
                  Icons.shield_outlined,
                  size: 20,
                  color: Color(0xFFF59E0B),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        strings.hostOccupiedPrompt,
                        style: const TextStyle(
                          color: Color(0xFFFDE68A),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        strings.hostOccupiedSub,
                        style: TextStyle(
                          color: const Color(0xFFFBBF24).withValues(alpha: 0.7),
                          fontSize: 10,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              _ctrl.retryConnection();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.refresh_rounded,
                    size: 12,
                    color: Color(0xFFFDE68A),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    strings.retryConnect,
                    style: const TextStyle(
                      color: Color(0xFFFDE68A),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionBadge() {
    final strings = AppStrings.current;
    final isOccupied = _ctrl.connectionState == VocalConnectionState.occupied;
    final isConnected = _ctrl.isConnected;

    final Color color;
    final String label;

    if (isOccupied) {
      color = const Color(0xFFF59E0B);
      label = strings.occupied;
    } else if (_ctrl.isPinRequired) {
      color = const Color(0xFFEAB308);
      label = strings.isChinese ? '待配对' : 'PAIRING';
    } else if (isConnected) {
      color = const Color(0xFF22C55E);
      label = strings.online;
    } else {
      color = const Color(0xFFEF4444);
      label = strings.offline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: isOccupied
            ? Border.all(color: color.withValues(alpha: 0.4), width: 1)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
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
          mainAxisSize: MainAxisSize.min,
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

  // ─── Text Editor Card (with in-card options) ──────────────

  Widget _buildEditorCard({required bool hasText}) {
    final strings = AppStrings.current;
    final isListening = _ctrl.isListening;

    return GestureDetector(
      onTap: () {
        if (!_focusNode.hasFocus) {
          _focusNode.requestFocus();
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isListening
                ? const Color(0xFF22D3EE)
                : (hasText
                    ? const Color(0xFF22D3EE).withValues(alpha: 0.35)
                    : Colors.white.withValues(alpha: 0.08)),
            width: isListening ? 1.5 : 1.0,
          ),
          boxShadow: [
            if (isListening)
              BoxShadow(
                color: const Color(0xFF22D3EE).withValues(alpha: 0.18),
                blurRadius: 18,
                spreadRadius: 2,
              )
            else if (hasText)
              BoxShadow(
                color: const Color(0xFF22D3EE).withValues(alpha: 0.05),
                blurRadius: 14,
                spreadRadius: 1,
              ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Top Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.edit_note_rounded,
                      size: 16,
                      color: isListening ? const Color(0xFF22D3EE) : const Color(0xFF38BDF8),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isListening ? strings.listeningStatus : strings.draftTitle,
                      style: TextStyle(
                        color: isListening
                            ? const Color(0xFF22D3EE)
                            : Colors.white.withValues(alpha: 0.75),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                if (hasText)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _ctrl.clearText();
                      _textController.clear();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.close_rounded,
                            size: 12,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            strings.clearDraft,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Text Field (Single stable node, vertically expands naturally)
            Expanded(
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Colors.white,
                  fontWeight: FontWeight.w400,
                ),
                cursorColor: const Color(0xFF22D3EE),
                onChanged: (val) {
                  _ctrl.updateText(val);
                },
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  hintText: strings.editorHint,
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.25),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Divider
            Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
            const SizedBox(height: 10),

            // Card In-Line Metadata Bar (Language & Auto-Enter Switch)
            _buildDraftMetaBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildDraftMetaBar() {
    final strings = AppStrings.current;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left: Language Capsule
        _buildLocaleSelector(),

        // Right: Character count & Auto-Enter Toggle
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              strings.charCount(_textController.text.length),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 11,
              ),
            ),
            const SizedBox(width: 10),
            _buildAutoEnterToggle(),
          ],
        ),
      ],
    );
  }

  Widget _buildLocaleSelector() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        LocaleSelectionSheet.show(context, _ctrl);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF22D3EE).withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.translate_rounded,
              size: 12,
              color: Color(0xFF22D3EE),
            ),
            const SizedBox(width: 5),
            Text(
              _ctrl.currentLocaleDisplayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 3),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 14,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoEnterToggle() {
    final strings = AppStrings.current;
    final enabled = _ctrl.autoPressEnter;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _ctrl.toggleAutoPressEnter();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: enabled
              ? const Color(0xFF22D3EE).withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled
                ? const Color(0xFF22D3EE).withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.keyboard_return_rounded,
              size: 12,
              color: enabled ? const Color(0xFF22D3EE) : Colors.white.withValues(alpha: 0.35),
            ),
            const SizedBox(width: 4),
            Text(
              enabled ? strings.autoEnterOn : strings.autoEnterOff,
              style: TextStyle(
                color: enabled ? const Color(0xFF22D3EE) : Colors.white.withValues(alpha: 0.4),
                fontSize: 11,
                fontWeight: enabled ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Dual-Action Bottom Bar (Voice + Send) ────────────────

  Widget _buildBottomActionBar(bool canSend, bool isKeyboardOpen) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1C),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Left: Voice Input Button / Dismiss Keyboard Button
          Expanded(
            flex: 6,
            child: isKeyboardOpen
                ? _buildDismissKeyboardButton()
                : _buildVoiceInputButton(),
          ),
          const SizedBox(width: 12),
          // Right: Send Button
          Expanded(
            flex: 4,
            child: _buildSendButton(canSend),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceInputButton() {
    final strings = AppStrings.current;
    final isListening = _ctrl.isListening;

    return GestureDetector(
      onTap: () async {
        HapticFeedback.mediumImpact();
        if (_ctrl.isListening) {
          _ctrl.stopListening();
        } else {
          final started = await _ctrl.startListening();
          if (!started && mounted) {
            _showDarkToast(
              context,
              _ctrl.speechErrorMessage ?? strings.speechUnavailable,
              isSuccess: false,
            );
          }
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isListening
              ? const Color(0xFF22D3EE)
              : const Color(0xFF22D3EE).withValues(alpha: 0.12),
          border: Border.all(
            color: isListening
                ? const Color(0xFF22D3EE)
                : const Color(0xFF22D3EE).withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: [
            if (isListening)
              BoxShadow(
                color: const Color(0xFF22D3EE).withValues(alpha: 0.4),
                blurRadius: 14,
                spreadRadius: 2,
              ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isListening ? Icons.stop_rounded : Icons.mic_rounded,
              size: 20,
              color: isListening ? const Color(0xFF0A0F1C) : const Color(0xFF22D3EE),
            ),
            const SizedBox(width: 8),
            Text(
              isListening ? strings.recordingStop : strings.tapToSpeak,
              style: TextStyle(
                color: isListening ? const Color(0xFF0A0F1C) : const Color(0xFF22D3EE),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDismissKeyboardButton() {
    final strings = AppStrings.current;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        FocusScope.of(context).unfocus();
      },
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withValues(alpha: 0.06),
          border: Border.all(
            color: const Color(0xFF22D3EE).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.keyboard_hide_rounded,
              size: 18,
              color: Color(0xFF22D3EE),
            ),
            const SizedBox(width: 8),
            Text(
              strings.dismissKeyboard,
              style: const TextStyle(
                color: Color(0xFF22D3EE),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSendButton(bool canSend) {
    final strings = AppStrings.current;
    return GestureDetector(
      onTap: canSend
          ? () {
              HapticFeedback.mediumImpact();
              final willPressEnter = _ctrl.autoPressEnter;
              final success = _ctrl.sendCurrentDraft(_textController.text);
              if (success) {
                _textController.clear();
                if (_historyScrollController.hasClients) {
                  _historyScrollController.animateTo(
                    0.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                  );
                }
                _showDarkToast(
                  context,
                  willPressEnter ? strings.sentWithEnter : strings.sent,
                  isSuccess: true,
                );
              }
            }
          : () {
              if (!_ctrl.isConnected) {
                HapticFeedback.selectionClick();
                _showDarkToast(
                  context,
                  strings.connectFirst,
                  isSuccess: false,
                );
              }
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: canSend
              ? const LinearGradient(
                  colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
                )
              : null,
          color: canSend ? null : Colors.white.withValues(alpha: 0.08),
          boxShadow: [
            if (canSend)
              BoxShadow(
                color: const Color(0xFF06B6D4).withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.send_rounded,
              size: 16,
              color: canSend ? Colors.white : Colors.white.withValues(alpha: 0.25),
            ),
            const SizedBox(width: 6),
            Text(
              strings.send,
              style: TextStyle(
                color: canSend ? Colors.white : Colors.white.withValues(alpha: 0.25),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Dark Neon Toast (HUD) ───────────────────────────────

  void _showDarkToast(BuildContext context, String message, {bool isSuccess = true}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        duration: const Duration(seconds: 2),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xE60F172A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSuccess
                  ? const Color(0x6622C55E)
                  : const Color(0x66EAB308),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSuccess ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                color: isSuccess ? const Color(0xFF22C55E) : const Color(0xFFEAB308),
                size: 16,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── History Section ─────────────────────────────────────

  Widget _buildHistorySection() {
    final strings = AppStrings.current;
    final hasHistory = _ctrl.historyList.isNotEmpty;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 13,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    strings.historyTitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (hasHistory) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_ctrl.historyList.length}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (hasHistory)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _ctrl.clearHistory();
                  },
                  child: Text(
                    strings.clearHistory,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (!hasHistory)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 22,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      strings.emptyHistoryTitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      strings.emptyHistorySub,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.25),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 120,
              ),
              child: RawScrollbar(
                controller: _historyScrollController,
                thumbVisibility: _ctrl.historyList.length > 3,
                thickness: 3,
                radius: const Radius.circular(2),
                thumbColor: Colors.white.withValues(alpha: 0.2),
                child: ListView.separated(
                  controller: _historyScrollController,
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(right: 6),
                  itemCount: _ctrl.historyList.length,
                  separatorBuilder: (context, index) =>
                      const Divider(color: Color(0x0DFFFFFF), height: 10),
                  itemBuilder: (context, index) {
                    final itemText = _ctrl.historyList[index];
                    return InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _ctrl.setText(itemText);
                        _textController.text = itemText;
                        _textController.selection = TextSelection.collapsed(
                          offset: itemText.length,
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                        child: Row(
                          children: [
                            Icon(
                              Icons.subdirectory_arrow_right_rounded,
                              size: 13,
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                itemText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.north_west_rounded,
                              size: 11,
                              color: const Color(0xFF22D3EE).withValues(alpha: 0.5),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
