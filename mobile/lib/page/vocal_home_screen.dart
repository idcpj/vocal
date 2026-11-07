import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vocal/i18n/app_strings.dart';
import 'package:vocal/page/device_selection_page.dart';
import 'package:vocal/page/locale_selection_sheet.dart';
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
  late final TextEditingController _textController;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _ctrl = VocalHomeController();
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
    setState(() {});
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onControllerUpdate);
    _ctrl.dispose();
    _animController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ─── Build ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hasText = _textController.text.trim().isNotEmpty;
    final canSend = _ctrl.isConnected && hasText;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: IntrinsicHeight(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 8),
                              // 1. History Section at Top (Always visible with empty state)
                              _buildHistorySection(),
                              const SizedBox(height: 14),
                              // Spacer keeps the editor card docked at the bottom when content is short
                              const Spacer(),
                              // 2. Draft Editor Card at Bottom (Thumb Heat Zone)
                              _buildEditorCard(hasText: hasText),
                              const SizedBox(height: 14),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // 3. Dual-Action Bottom Bar (Voice + Send)
              _buildBottomActionBar(canSend, isKeyboardOpen),
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

  Widget _buildConnectionBadge() {
    final strings = AppStrings.current;
    final color = _ctrl.isConnected ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    final label = _ctrl.isConnected ? strings.online : strings.offline;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
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

    return Container(
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

          // Text Field (Thumb Zone Interactive Area)
          TextField(
            controller: _textController,
            focusNode: _focusNode,
            maxLines: 6,
            minLines: 3,
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
          const SizedBox(height: 12),

          // Divider
          Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
          const SizedBox(height: 10),

          // Card In-Line Metadata Bar (Language & Auto-Enter Switch)
          _buildDraftMetaBar(),
        ],
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
      onTap: () {
        HapticFeedback.mediumImpact();
        if (_ctrl.isListening) {
          _ctrl.stopListening();
        } else {
          _ctrl.startListening();
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
              final success = _ctrl.sendCurrentDraft();
              if (success) {
                _textController.clear();
                FocusScope.of(context).unfocus();
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
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _ctrl.historyList.length > 3 ? 3 : _ctrl.historyList.length,
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
        ],
      ),
    );
  }
}
