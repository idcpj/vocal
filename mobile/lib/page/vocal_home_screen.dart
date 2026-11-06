import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final ScrollController _scrollController = ScrollController();

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

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted && _scrollController.hasClients) {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
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
    _scrollController.dispose();
    super.dispose();
  }

  // ─── Build ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardOpen = bottomInset > 0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      SizedBox(height: isKeyboardOpen ? 6 : 12),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: isKeyboardOpen
                            ? KeyedSubtree(
                                key: const ValueKey('mini_mic'),
                                child: _buildMiniMicBar(),
                              )
                            : KeyedSubtree(
                                key: const ValueKey('full_mic'),
                                child: _buildFullMicSection(),
                              ),
                      ),
                      SizedBox(height: isKeyboardOpen ? 12 : 20),
                      _buildEditorCard(isKeyboardOpen: isKeyboardOpen),
                      if (!isKeyboardOpen && _ctrl.historyList.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _buildHistorySection(),
                      ],
                      SizedBox(height: isKeyboardOpen ? 16 : 32),
                    ],
                  ),
                ),
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
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
    final color = _ctrl.isConnected ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    final label = _ctrl.isConnected ? 'ONLINE' : 'OFFLINE';

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

  // ─── Mic Button Section ──────────────────────────────────

  Widget _buildFullMicSection() {
    return Column(
      children: [
        Text(
          _ctrl.statusText.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 11,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        _buildMicButton(),
        const SizedBox(height: 12),
        Text(
          _ctrl.isListening ? '正在录音中... 点击停止' : '点击麦克风说话',
          style: TextStyle(
            color: _ctrl.isListening
                ? const Color(0xFF22D3EE)
                : Colors.white.withValues(alpha: 0.6),
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 10),
        _buildLocaleSelector(),
      ],
    );
  }

  Widget _buildMiniMicBar() {
    final isListening = _ctrl.isListening;
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
          color: isListening
              ? const Color(0xFF22D3EE).withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.08),
        ),
        boxShadow: [
          if (isListening)
            BoxShadow(
              color: const Color(0xFF22D3EE).withValues(alpha: 0.15),
              blurRadius: 10,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              if (isListening) {
                _ctrl.stopListening();
              } else {
                _ctrl.startListening();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF22D3EE).withValues(alpha: isListening ? 0.25 : 0.08),
              ),
              child: Icon(
                isListening ? Icons.mic : Icons.mic_none,
                size: 16,
                color: const Color(0xFF22D3EE),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isListening ? '正在录音中...' : _ctrl.statusText.toUpperCase(),
              style: TextStyle(
                color: isListening
                    ? const Color(0xFF22D3EE)
                    : Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _buildLocaleSelector(),
        ],
      ),
    );
  }

  Widget _buildLocaleSelector() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        LocaleSelectionSheet.show(context, _ctrl);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF22D3EE).withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.translate_rounded,
              size: 13,
              color: Color(0xFF22D3EE),
            ),
            const SizedBox(width: 6),
            Text(
              _ctrl.currentLocaleDisplayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 15,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMicButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        if (_ctrl.isListening) {
          _ctrl.stopListening();
        } else {
          _ctrl.startListening();
        }
      },
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          final isListening = _ctrl.isListening;
          return Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF22D3EE).withValues(alpha: isListening ? 0.15 : 0.05),
              border: Border.all(
                color: const Color(0xFF22D3EE).withValues(
                  alpha: isListening ? 0.5 + (_animController.value * 0.5) : 0.25,
                ),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF22D3EE).withValues(
                    alpha: isListening ? 0.35 : 0.08,
                  ),
                  blurRadius: isListening ? 20 + (_animController.value * 20) : 10,
                  spreadRadius: isListening ? 4 : 1,
                ),
              ],
            ),
            child: Icon(
              isListening ? Icons.mic : Icons.mic_none,
              size: 40,
              color: const Color(0xFF22D3EE),
            ),
          );
        },
      ),
    );
  }

  // ─── Text Editor & Send Card ─────────────────────────────

  Widget _buildEditorCard({required bool isKeyboardOpen}) {
    final hasText = _textController.text.trim().isNotEmpty;
    final canSend = _ctrl.isConnected && hasText;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasText
              ? const Color(0xFF22D3EE).withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.08),
        ),
        boxShadow: [
          if (hasText)
            BoxShadow(
              color: const Color(0xFF22D3EE).withValues(alpha: 0.05),
              blurRadius: 16,
              spreadRadius: 2,
            ),
        ],
      ),
      padding: EdgeInsets.all(isKeyboardOpen ? 14 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.edit_note_rounded,
                    size: 16,
                    color: Color(0xFF22D3EE),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '待发送文字',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                              '清空',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (isKeyboardOpen) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        FocusScope.of(context).unfocus();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22D3EE).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFF22D3EE).withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.keyboard_hide_rounded,
                              size: 12,
                              color: Color(0xFF22D3EE),
                            ),
                            SizedBox(width: 4),
                            Text(
                              '收起',
                              style: TextStyle(
                                color: Color(0xFF22D3EE),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          SizedBox(height: isKeyboardOpen ? 8 : 12),

          // Text Field
          TextField(
            controller: _textController,
            focusNode: _focusNode,
            maxLines: isKeyboardOpen ? 4 : 5,
            minLines: isKeyboardOpen ? 2 : 3,
            style: const TextStyle(
              fontSize: 16,
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
              hintText: '点击上方麦克风开始录音，或在此处直接输入/修改文字...',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.25),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
          SizedBox(height: isKeyboardOpen ? 10 : 16),
          const Divider(color: Color(0x1AFFFFFF), height: 1),
          SizedBox(height: isKeyboardOpen ? 8 : 12),

          // Bottom Send Toolbar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Character count & status hint
              Row(
                children: [
                  Text(
                    '${_textController.text.length} 字符',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!_ctrl.isConnected)
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 3,
                          backgroundColor: Colors.amber.withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Mac 未连接',
                          style: TextStyle(
                            color: Colors.amber.withValues(alpha: 0.8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                ],
              ),

              // Right: Auto-Enter toggle & Send Button
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAutoEnterToggle(),
                  const SizedBox(width: 8),
                  _buildSendButton(canSend),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAutoEnterToggle() {
    final enabled = _ctrl.autoPressEnter;
    return Tooltip(
      message: enabled ? '发送时自动触发 Mac 回车' : '发送时不触发回车',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          _ctrl.toggleAutoPressEnter();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: enabled
                ? const Color(0xFF22D3EE).withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: enabled
                  ? const Color(0xFF22D3EE).withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.keyboard_return_rounded,
                size: 14,
                color: enabled ? const Color(0xFF22D3EE) : Colors.white.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 4),
              Text(
                '回车',
                style: TextStyle(
                  color: enabled ? const Color(0xFF22D3EE) : Colors.white.withValues(alpha: 0.4),
                  fontSize: 12,
                  fontWeight: enabled ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSendButton(bool canSend) {
    return GestureDetector(
      onTap: canSend
          ? () {
              HapticFeedback.mediumImpact();
              final willPressEnter = _ctrl.autoPressEnter;
              final success = _ctrl.sendCurrentDraft();
              if (success) {
                _textController.clear();
                FocusScope.of(context).unfocus();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      willPressEnter ? '✅ 已发送到 Mac (已触发回车)' : '✅ 已发送到 Mac',
                    ),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          : () {
              if (!_ctrl.isConnected) {
                HapticFeedback.selectionClick();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('⚠️ 请先连接局域网内的 Mac 主机'),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: canSend
              ? const LinearGradient(
                  colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
                )
              : null,
          color: canSend ? null : Colors.white.withValues(alpha: 0.08),
          boxShadow: [
            if (canSend)
              BoxShadow(
                color: const Color(0xFF06B6D4).withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.send_rounded,
              size: 15,
              color: canSend ? Colors.white : Colors.white.withValues(alpha: 0.25),
            ),
            const SizedBox(width: 6),
            Text(
              '发送到 Mac',
              style: TextStyle(
                color: canSend ? Colors.white : Colors.white.withValues(alpha: 0.25),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── History Section ─────────────────────────────────────

  Widget _buildHistorySection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '发送历史 (点击可重新填入)',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _ctrl.clearHistory();
                },
                child: Text(
                  '清空记录',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _ctrl.historyList.length > 5 ? 5 : _ctrl.historyList.length,
            separatorBuilder: (context, index) =>
                const Divider(color: Color(0x0DFFFFFF), height: 12),
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
                        Icons.history_rounded,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          itemText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.north_west_rounded,
                        size: 12,
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
