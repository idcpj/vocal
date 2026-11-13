import 'package:flutter/foundation.dart';

/// Lightweight i18n support for Vocal App (English & Simplified Chinese).
/// Automatically detects system locale, supports instant reactive switching.
class AppStrings {
  final String languageCode;

  const AppStrings({this.languageCode = 'zh'});

  bool get isChinese => languageCode.startsWith('zh');

  /// Global reactive notifier for current locale
  static final ValueNotifier<AppStrings> notifier =
      ValueNotifier<AppStrings>(_detectSystemLocale());

  /// Current active instance
  static AppStrings get current => notifier.value;

  static AppStrings _detectSystemLocale() {
    final code = PlatformDispatcher.instance.locale.languageCode.toLowerCase();
    return AppStrings(languageCode: code);
  }

  /// Explicitly set the UI language ('zh' or 'en')
  static void setLocale(String code) {
    notifier.value = AppStrings(languageCode: code.toLowerCase());
  }

  // ─── Header ───────────────────────────────────────────────
  String get appName => 'VOCAL';
  String get manualMode => 'MANUAL';
  String get online => 'ONLINE';
  String get offline => 'OFFLINE';
  String get macNotConnected => isChinese ? 'Mac 未连接' : 'Mac Disconnected';
  String deviceCount(int count) => isChinese ? '$count 台设备' : '$count devices';

  // ─── History ──────────────────────────────────────────────
  String get historyTitle => isChinese ? '发送历史 (点击快捷填入)' : 'History (Tap to reuse)';
  String get clearHistory => isChinese ? '清空记录' : 'Clear';
  String get emptyHistoryTitle => isChinese ? '暂无历史消息' : 'No history yet';
  String get emptyHistorySub => isChinese ? '发送成功后的文字将自动留存于此' : 'Sent messages will be saved here';

  // ─── Draft Editor ─────────────────────────────────────────
  String get listeningStatus => isChinese ? '正在语音识别录入...' : 'Listening & transcribing...';
  String get draftTitle => isChinese ? '待发送文字' : 'Draft Text';
  String get clearDraft => isChinese ? '清空' : 'Clear';
  String get editorHint => isChinese
      ? '点击下方语音按钮说话，或在此处直接编辑文字...'
      : 'Tap voice button below to speak, or edit here...';
  String charCount(int count) => isChinese ? '$count 字符' : '$count chars';
  String get autoEnterOn => isChinese ? '回车: 开' : 'Enter: ON';
  String get autoEnterOff => isChinese ? '回车: 关' : 'Enter: OFF';

  // ─── Bottom Actions ───────────────────────────────────────
  String get tapToSpeak => isChinese ? '轻触开始语音' : 'Tap to Speak';
  String get recordingStop => isChinese ? '录音中 · 点击停止' : 'Recording · Tap to Stop';
  String get dismissKeyboard => isChinese ? '收起键盘' : 'Dismiss Keyboard';
  String get send => isChinese ? '发送' : 'Send';

  // ─── Toast Feedback & Speech Status ───────────────────────
  String get sentWithEnter => isChinese ? '已发送 (已自动触发回车)' : 'Sent (Return simulated)';
  String get sent => isChinese ? '已发送' : 'Sent';
  String get connectFirst => isChinese ? '请先连接局域网内的 Mac 主机' : 'Please connect to a Mac host first';
  String get speechUnavailable =>
      isChinese ? '未检测到系统语音服务，可直接打字输入' : 'Speech service unavailable, please type';
  String get speechNetworkError =>
      isChinese ? '语音识别网络异常，请检查网络或离线语言包' : 'Speech network error, check network or offline pack';
  String get micOccupied => isChinese ? '麦克风被其他应用占用' : 'Microphone is occupied by another app';

  // ─── Device Selection Page ────────────────────────────────
  String get selectDevice => isChinese ? '选择设备' : 'Select Device';
  String get back => isChinese ? '返回' : 'Back';
  String get discoveredDevices => isChinese ? '发现以下设备' : 'Discovered Devices';
  String get chooseMac => isChinese ? '选择要连接的 Mac' : 'Choose a Mac to connect';
  String get searchingDevices => isChinese ? '正在搜索设备...' : 'Searching for devices...';
  String get scanning => isChinese ? '正在扫描...' : 'Scanning...';
  String get cancel => isChinese ? '取消' : 'Cancel';
  String get unknownDevice => isChinese ? '未知设备' : 'Unknown Device';
  String get manualConnect => isChinese ? '手动输入 IP 连接' : 'Manual IP Connect';
  String get enterMacIp => isChinese ? '输入 Mac 局域网 IP' : 'Enter Mac IP';
  String get enterMacIpHint => isChinese ? '例如 192.168.1.100' : 'e.g. 192.168.1.100';
  String get port => isChinese ? '端口' : 'Port';
  String get connect => isChinese ? '连接' : 'Connect';

  // ─── Locale Selection Sheet ───────────────────────────────
  String get selectSpeechLanguage => isChinese ? '选择识别语言' : 'Speech Recognition Language';
  String supportedLanguagesCount(int count) =>
      isChinese ? '支持 $count 种系统识别语言' : 'Supports $count system languages';
  String get searchLanguageHint => isChinese
      ? '搜索语言或代码 (如 中文, en, ja)...'
      : 'Search language or code (e.g. English, zh)...';
}
