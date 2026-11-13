import 'dart:async';
import 'dart:convert';
import 'dart:ui' show AppLifecycleState;

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:nsd/nsd.dart' as nsd;
import 'package:vocal/i18n/app_strings.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

/// Connection states of the Vocal mobile client state machine.
enum VocalConnectionState {
  disconnected,
  searching,
  connecting,
  connected,
  reconnecting,
  occupied,
}

/// Controls all business logic for the Vocal app:
/// mDNS discovery, WebSocket connection, heartbeat, STT, delta-sync, history.
class VocalHomeController extends ChangeNotifier {
  // ─── Connection ──────────────────────────────────────────
  WebSocketChannel? _channel;
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isOccupied = false;
  String? _lastConnectedWsUrl;
  VocalConnectionState _connectionState = VocalConnectionState.disconnected;
  String _statusText = 'Searching for Mac...';
  DateTime? _lastHeartbeat;

  // ─── PIN & Device Authentication ──────────────────────────
  String _deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
  String? _authToken;
  bool _isPinRequired = false;
  String? _pinErrorMessage;
  int _pinRemainingAttempts = 3;

  bool get isPinRequired => _isPinRequired;
  String? get pinErrorMessage => _pinErrorMessage;
  int get pinRemainingAttempts => _pinRemainingAttempts;
  String? get authToken => _authToken;
  String get deviceId => _deviceId;

  final Duration heartbeatTimeout;
  final Duration heartbeatCheckInterval;
  final bool enableAutoReconnect;

  // ─── Device Discovery ────────────────────────────────────
  final List<nsd.Service> _discoveredServices = [];
  nsd.Discovery? _activeDiscovery;

  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  bool get isOccupied => _isOccupied || _connectionState == VocalConnectionState.occupied;
  VocalConnectionState get connectionState => _connectionState;
  String get statusText => _statusText;
  List<nsd.Service> get discoveredServices =>
      List.unmodifiable(_discoveredServices);

  // ─── Speech-to-Text & Locales ────────────────────────────
  final SpeechToText _speechToText = SpeechToText();
  bool _isSpeechAvailable = false;
  String? _speechErrorMessage;
  List<LocaleName> _availableLocales = [];
  String? _selectedLocaleId;
  String _lastWords = '';
  String _lastSentWords = '';

  bool get isSpeechAvailable => _isSpeechAvailable;
  String? get speechErrorMessage => _speechErrorMessage;

  /// Clear any active speech error message
  void clearSpeechError() {
    _speechErrorMessage = null;
    notifyListeners();
  }

  List<LocaleName> get availableLocales => List.unmodifiable(_availableLocales);
  String? get selectedLocaleId => _selectedLocaleId;

  /// User-friendly label for current recognition locale
  String get currentLocaleDisplayName {
    if (_selectedLocaleId == null || _availableLocales.isEmpty) {
      return '中文 (普通话)';
    }
    final match = _availableLocales.where((l) => l.localeId == _selectedLocaleId);
    if (match.isNotEmpty) {
      return match.first.name;
    }
    return _selectedLocaleId!;
  }

  /// Switch STT recognition locale dynamically in real-time
  void setLocale(String localeId) {
    if (_selectedLocaleId == localeId) return;
    if (_speechToText.isListening) {
      stopListening();
    }
    _selectedLocaleId = localeId;
    debugPrint('Switched recognition locale to: $localeId');
    notifyListeners();
  }

  @visibleForTesting
  void setAvailableLocalesForTesting(List<LocaleName> locales, {String? defaultLocaleId}) {
    _availableLocales = locales;
    if (defaultLocaleId != null) {
      _selectedLocaleId = defaultLocaleId;
    } else if (locales.isNotEmpty) {
      _selectedLocaleId = locales.first.localeId;
    }
    notifyListeners();
  }

  /// The current text in the draft/input box on mobile.
  String _textDraft = '';

  /// Base text accumulated before the current listening session started.
  String _sessionBaseText = '';

  /// Current session recognized words.
  String _currentSessionWords = '';

  /// Guard to prevent engine stop/final callbacks from duplicating text.
  bool _isSessionFinalized = false;

  /// Maximum number of items preserved in send history.
  static const int maxHistoryLength = 50;

  final List<String> _historyList = [];
  bool _wantsListening = false; // User wants continuous listening (manual stop only)
  bool _isStartingSession = false; // Guard against parallel restarts

  bool get isListening => _wantsListening || _speechToText.isListening;
  String get lastWords => _lastWords;
  String get lastSentWords => _lastSentWords;
  String get textDraft => _textDraft;
  List<String> get historyList => List.unmodifiable(_historyList);

  /// Whether to automatically simulate Enter/Return on Mac after sending text.
  bool _autoPressEnter = false;
  bool get autoPressEnter => _autoPressEnter;

  /// Toggle the auto press Enter setting.
  void toggleAutoPressEnter() {
    _autoPressEnter = !_autoPressEnter;
    debugPrint('Toggled autoPressEnter to: $_autoPressEnter');
    notifyListeners();
  }

  /// Explicitly set the auto press Enter setting.
  void setAutoPressEnter(bool value) {
    if (_autoPressEnter != value) {
      _autoPressEnter = value;
      notifyListeners();
    }
  }

  /// Update the current draft text (e.g. when typing or editing in TextField).
  void updateText(String text) {
    _textDraft = text;
    _sessionBaseText = text;
    _currentSessionWords = '';
    notifyListeners();
  }

  /// Explicitly set the text (e.g. from history click).
  void setText(String text) {
    _textDraft = text;
    _sessionBaseText = text;
    _currentSessionWords = '';
    notifyListeners();
  }

  /// Clear the current draft text and reset speech base.
  void clearText() {
    _textDraft = '';
    _sessionBaseText = '';
    _currentSessionWords = '';
    _lastWords = '';
    notifyListeners();
  }

  /// Clear history list.
  void clearHistory() {
    _historyList.clear();
    notifyListeners();
  }

  /// Add history item directly for testing or simulation.
  @visibleForTesting
  void addHistoryItemForTesting(String item) {
    _historyList.remove(item);
    _historyList.insert(0, item);
    if (_historyList.length > maxHistoryLength) {
      _historyList.removeRange(maxHistoryLength, _historyList.length);
    }
    notifyListeners();
  }

  /// Set the entire history list (for testing or restoration).
  @visibleForTesting
  void setHistoryForTesting(List<String> history) {
    _historyList.clear();
    _historyList.addAll(history);
    if (_historyList.length > maxHistoryLength) {
      _historyList.removeRange(maxHistoryLength, _historyList.length);
    }
    notifyListeners();
  }

  bool _isMockConnectedForTesting = false;

  /// Directly set connection status for testing without requiring real WebSocket handshake.
  @visibleForTesting
  void setConnectedForTesting(bool connected, {WebSocketChannel? channel}) {
    _isConnected = connected;
    _isMockConnectedForTesting = connected;
    _connectionState = connected ? VocalConnectionState.connected : VocalConnectionState.disconnected;
    if (channel != null) {
      _channel = channel;
    }
    notifyListeners();
  }

  bool _isDisposed = false;

  // ─── Lifecycle ───────────────────────────────────────────

  VocalHomeController({
    bool autoInit = true,
    this.heartbeatTimeout = const Duration(seconds: 15),
    this.heartbeatCheckInterval = const Duration(seconds: 5),
    this.enableAutoReconnect = true,
  }) {
    if (autoInit) {
      _initSpeech();
      discoverServices();
    }
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _isConnecting = false;
    stopDiscovery();
    _channel?.sink.close(status.normalClosure);
    _channel = null;
    super.dispose();
  }

  // ─── Speech Init & Callbacks ─────────────────────────────

  Future<bool> _initSpeech() async {
    try {
      final available = await _speechToText.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
      );
      _isSpeechAvailable = available;
      if (!available) {
        _speechErrorMessage = '未检测到系统语音识别服务';
        debugPrint('STT init: Speech recognition not available on this device');
      } else {
        _speechErrorMessage = null;
        var locales = await _speechToText.locales();
        if (locales.isEmpty) {
          locales = [
            LocaleName('zh_CN', '中文 (中国)'),
            LocaleName('en_US', 'English (United States)'),
          ];
        }
        _availableLocales = locales;
        _selectDefaultLocale(locales);
      }
      notifyListeners();
      return available;
    } catch (e) {
      _isSpeechAvailable = false;
      _speechErrorMessage = '语音服务初始化异常: $e';
      debugPrint('STT init error: $e');
      notifyListeners();
      return false;
    }
  }

  void _selectDefaultLocale(List<LocaleName> locales) {
    if (locales.isEmpty) return;
    LocaleName? preferred;
    for (var locale in locales) {
      final id = locale.localeId.toLowerCase().replaceAll('-', '_');
      if (id.contains('zh_cn') || id.contains('zh_hans')) {
        preferred = locale;
        break;
      }
    }
    if (preferred == null) {
      for (var locale in locales) {
        if (locale.localeId.toLowerCase().startsWith('zh')) {
          preferred = locale;
          break;
        }
      }
    }
    preferred ??= locales.first;

    _selectedLocaleId = preferred.localeId;
    debugPrint('STT Locale initialized to: ${preferred.name} (${preferred.localeId})');
  }

  void _onSpeechStatus(String status) {
    debugPrint('STT Status: $status');
    // Safety net & Android continuous dictation: if engine stops while user still wants listening
    if (status == 'done' && _wantsListening) {
      if (_currentSessionWords.trim().isNotEmpty) {
        _sessionBaseText = _textDraft;
        _currentSessionWords = '';
      }
      Future.delayed(const Duration(milliseconds: 150), () {
        if (_wantsListening &&
            !_speechToText.isListening &&
            !_isStartingSession) {
          debugPrint('Android STT: Smooth session auto-restart...');
          _beginListenSession();
        }
      });
    }
    notifyListeners();
  }

  void _onSpeechError(SpeechRecognitionError error) {
    final msg = error.errorMsg;
    debugPrint('STT Error: $msg (permanent: ${error.permanent})');

    // 1. Android typical silence & pause timeouts (Benign, smooth restart)
    if (msg == 'error_speech_timeout' || msg == 'error_no_match') {
      debugPrint('STT benign timeout/no-match, keeping session alive...');
      if (_currentSessionWords.trim().isNotEmpty) {
        _sessionBaseText = _textDraft;
        _currentSessionWords = '';
      }
      if (_wantsListening) {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (_wantsListening &&
              !_speechToText.isListening &&
              !_isStartingSession) {
            debugPrint('STT: Resuming after timeout/no-match...');
            _beginListenSession();
          }
        });
      }
      return;
    }

    // 2. Network error (Google Speech cloud unreachable / needs offline package)
    if (msg == 'error_network' || msg == 'error_network_timeout') {
      _speechErrorMessage = '语音识别网络异常，请检查网络或配置离线语言包';
      _finalizeLocalSpeech();
      notifyListeners();
      return;
    }

    // 3. Audio hardware occupied
    if (msg == 'error_audio_error') {
      _speechErrorMessage = '麦克风被其他应用占用';
      _finalizeLocalSpeech();
      notifyListeners();
      return;
    }

    // 4. Engine busy / client error
    if (msg == 'error_busy' || msg == 'error_client') {
      if (_wantsListening) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (_wantsListening &&
              !_speechToText.isListening &&
              !_isStartingSession) {
            _beginListenSession();
          }
        });
        return;
      }
    }

    // Other permanent / fatal errors
    _speechErrorMessage = '语音识别异常: $msg';
    _finalizeLocalSpeech();
    notifyListeners();
  }

  // ─── mDNS Discovery ─────────────────────────────────────

  Future<void> discoverServices() async {
    // Guard: skip if already connected, connecting, occupied, or discovery in progress
    if (_isConnected || _isConnecting || _isOccupied || _connectionState == VocalConnectionState.occupied) return;
    if (_activeDiscovery != null) return;

    try {
      _discoveredServices.clear();
      _connectionState = _connectionState == VocalConnectionState.disconnected
          ? VocalConnectionState.searching
          : VocalConnectionState.reconnecting;
      _statusText = 'Scanning for Mac...';
      notifyListeners();

      final discovery = await nsd.startDiscovery('_vocal._tcp');
      _activeDiscovery = discovery;
      discovery.addListener(() {
        if (_isDisposed || _activeDiscovery == null) return;
        for (final service in discovery.services) {
          // Skip duplicates (by name)
          if (_discoveredServices.any((s) => s.name == service.name)) continue;
          if (service.host != null && service.port != null) {
            _discoveredServices.add(service);
            debugPrint(
              'Discovered: ${service.name} (${service.host}:${service.port})',
            );
          }
        }
        if (_discoveredServices.isEmpty) {
          _statusText = 'No Mac found yet...';
        } else if (_discoveredServices.length == 1 && !_isConnected && !_isConnecting) {
          // Auto-connect when only one device found
          connectToService(_discoveredServices.first);
          return;
        } else {
          _statusText = 'Found ${_discoveredServices.length} device(s)';
        }
        notifyListeners();
      });
    } catch (e) {
      stopDiscovery();
      _statusText = 'Discovery error: $e';
      _connectionState = VocalConnectionState.disconnected;
      notifyListeners();
    }
  }

  /// Connect to a user-selected service from the discovered list.
  void connectToService(nsd.Service service) {
    if (_isConnecting || _isConnected) return;
    stopDiscovery();
    _isConnecting = true;
    _connectionState = VocalConnectionState.connecting;
    _statusText = 'Connecting to Mac...';
    notifyListeners();
    _connectToMac(service.host!, service.port!);
  }

  /// Stop active mDNS discovery.
  void stopDiscovery() {
    final d = _activeDiscovery;
    _activeDiscovery = null;
    if (d != null) {
      try {
        nsd.stopDiscovery(d);
      } catch (e) {
        debugPrint('stopDiscovery error (ignored): $e');
      }
    }
  }

  // ─── WebSocket Connection ────────────────────────────────

  /// Connect directly to a specific host and port without mDNS.
  Future<void> connectDirect(String host, int port) async {
    await connectToUrl('ws://$host:$port');
  }

  /// Connect directly to a WebSocket URL.
  Future<void> connectToUrl(String wsUrl) async {
    // Release active discovery and its MulticastLock when connecting
    stopDiscovery();

    // If currently connected and actively communicating, avoid reconnecting/closing
    if (_isConnected && _channel != null) {
      debugPrint('Already connected to Mac, skipping duplicate connectToUrl');
      return;
    }

    // If handshake is already in progress with an active channel, ignore concurrent calls
    if (_isConnecting && _channel != null) {
      debugPrint('Connection handshake already in progress, ignoring concurrent connectToUrl');
      return;
    }

    // If channel exists but not connected (e.g. stale/half-open channel), close cleanly first
    if (_channel != null) {
      try {
        await _channel!.sink.close(status.normalClosure);
      } catch (_) {}
      _channel = null;
    }

    _lastConnectedWsUrl = wsUrl;
    _isOccupied = false;
    _isConnecting = true;
    try {
      debugPrint('Attempting connection to $wsUrl');
      _connectionState = VocalConnectionState.connecting;
      _statusText = 'Connecting to Mac...';
      notifyListeners();

      final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _channel = channel;

      await channel.ready;

      _isConnected = true;
      _connectionState = VocalConnectionState.connected;
      _statusText = 'Connected to Mac';
      _lastHeartbeat = DateTime.now();
      notifyListeners();

      channel.stream.listen(
        (message) {
          _handleIncomingMessage(message.toString());
        },
        onDone: () {
          debugPrint('Connection closed.');
          _handleConnectionClosed();
        },
        onError: (e) {
          debugPrint('Connection error: $e');
          _handleConnectionClosed(error: e);
        },
      );

      _startHeartbeatCheck();
    } catch (e) {
      debugPrint('Connection failed: $e');
      _isConnected = false;
      if (!_isOccupied && _connectionState != VocalConnectionState.occupied) {
        _connectionState = VocalConnectionState.disconnected;
        _statusText = 'Connection failed';
      }
      _channel = null;
      notifyListeners();
      rethrow;
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  Future<void> _connectToMac(String host, int port) async {
    try {
      await connectDirect(host, port);
    } catch (e) {
      debugPrint('Failed to connect to Mac at $host:$port: $e');
      // Status text and connectionState have already been updated by connectToUrl
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  void _handleIncomingMessage(String msgStr) {
    if (msgStr.contains('"type":"ping"') || msgStr.contains('"type": "ping"')) {
      _channel?.sink.add('{"type": "pong"}');
      _lastHeartbeat = DateTime.now();
      debugPrint('Received ping, sent pong.');
      return;
    }

    try {
      final decoded = jsonDecode(msgStr);
      if (decoded is Map<String, dynamic>) {
        final type = decoded['type'];
        if (type == 'error' && decoded['code'] == 'OCCUPIED') {
          debugPrint('Host is OCCUPIED: ${decoded['message']}');
          _isOccupied = true;
          _isConnected = false;
          _isConnecting = false;
          _isPinRequired = false;
          _connectionState = VocalConnectionState.occupied;
          _statusText = AppStrings.current.occupied;
          notifyListeners();
          return;
        } else if (type == 'auth_require_pin') {
          _isPinRequired = true;
          _pinErrorMessage = null;
          debugPrint('Host requires PIN pairing.');
          notifyListeners();
        } else if (type == 'auth_success') {
          _isPinRequired = false;
          _pinErrorMessage = null;
          if (decoded.containsKey('token') && decoded['token'] is String) {
            _authToken = decoded['token'] as String;
            debugPrint('Received auth token: $_authToken');
          }
          notifyListeners();
        } else if (type == 'auth_failed') {
          _pinErrorMessage = decoded['reason'] as String? ?? 'PIN 码错误';
          _pinRemainingAttempts = decoded['remainingAttempts'] as int? ?? 0;
          debugPrint('Auth failed: $_pinErrorMessage (remaining: $_pinRemainingAttempts)');
          notifyListeners();
        }
      }
    } catch (_) {}

    // String fallback for OCCUPIED
    if (msgStr.contains('"code":"OCCUPIED"') || msgStr.contains('"code": "OCCUPIED"')) {
      debugPrint('Host is OCCUPIED (fallback)');
      _isOccupied = true;
      _isConnected = false;
      _isConnecting = false;
      _isPinRequired = false;
      _connectionState = VocalConnectionState.occupied;
      _statusText = AppStrings.current.occupied;
      notifyListeners();
    }
  }

  /// Submit 4-digit PIN for device pairing.
  void verifyPin(String pin) {
    if (_channel != null && _isConnected) {
      final payload = jsonEncode({
        'type': 'auth_verify_pin',
        'pin': pin.trim(),
      });
      _channel!.sink.add(payload);
      debugPrint('Sent PIN verification: $pin');
    }
  }

  /// Dismiss PIN pairing dialog and disconnect.
  void cancelPinVerification() {
    _isPinRequired = false;
    _pinErrorMessage = null;
    disconnect();
  }

  void setAuthTokenForTesting(String? token) {
    _authToken = token;
  }

  void setDeviceIdForTesting(String id) {
    _deviceId = id;
  }

  void handleIncomingMessageForTesting(String message) {
    _handleIncomingMessage(message);
  }

  void _handleConnectionClosed({Object? error}) {
    if (_isDisposed) return;
    final wasOccupied = _isOccupied ||
        _connectionState == VocalConnectionState.occupied ||
        _channel?.closeCode == 4001;
    _channel = null;
    _isConnected = false;
    _isConnecting = false;
    _isPinRequired = false;
    _pinErrorMessage = null;
    _lastSentWords = '';

    if (wasOccupied) {
      _isOccupied = true;
      _connectionState = VocalConnectionState.occupied;
      _statusText = AppStrings.current.occupied;
      debugPrint('Connection closed in occupied state; auto-reconnect suppressed.');
      notifyListeners();
      return;
    }

    _connectionState = VocalConnectionState.disconnected;
    if (enableAutoReconnect) {
      _statusText = 'Disconnected. Searching...';
      notifyListeners();
      discoverServices();
    } else {
      _statusText = 'Disconnected';
      notifyListeners();
    }
  }

  void _handleDisconnect() {
    if (_isConnected) {
      try {
        _channel?.sink.close(status.normalClosure);
      } catch (_) {}
      _channel = null;
      _isConnected = false;
      _isConnecting = false;
      _lastSentWords = '';
      if (_isOccupied || _connectionState == VocalConnectionState.occupied) {
        _connectionState = VocalConnectionState.occupied;
        _statusText = 'Mac 已被占用 (已暂停重连)';
        notifyListeners();
        return;
      }
      _connectionState = VocalConnectionState.disconnected;
      if (enableAutoReconnect) {
        _statusText = 'Connection Lost';
        notifyListeners();
        discoverServices();
      } else {
        _statusText = 'Connection Lost';
        notifyListeners();
      }
    }
  }

  /// Manually disconnect the current WebSocket connection without triggering auto-reconnect.
  Future<void> disconnect() async {
    _isOccupied = false;
    stopDiscovery();
    _isConnected = false;
    _isConnecting = false;
    _isPinRequired = false;
    _pinErrorMessage = null;
    _connectionState = VocalConnectionState.disconnected;
    _statusText = 'Disconnected';
    _lastSentWords = '';
    if (_channel != null) {
      try {
        await _channel!.sink.close(status.normalClosure);
      } catch (_) {}
      _channel = null;
    }
    notifyListeners();
  }

  /// Explicitly retry connection after being occupied or disconnected.
  /// Resets occupied state and restarts discovery or reconnects to last host.
  Future<void> retryConnection() async {
    debugPrint('User manually triggered retryConnection');
    _isOccupied = false;
    stopDiscovery();
    if (_channel != null) {
      try {
        await _channel!.sink.close(status.normalClosure);
      } catch (_) {}
      _channel = null;
    }
    _isConnected = false;
    _isConnecting = false;
    _isPinRequired = false;
    _pinErrorMessage = null;
    _connectionState = VocalConnectionState.disconnected;
    _statusText = 'Reconnecting...';
    notifyListeners();

    if (_lastConnectedWsUrl != null && _lastConnectedWsUrl!.isNotEmpty) {
      try {
        await connectToUrl(_lastConnectedWsUrl!);
      } catch (e) {
        debugPrint('Retry direct connection failed: $e');
        if (!_isOccupied && enableAutoReconnect) {
          discoverServices();
        }
      }
    } else {
      discoverServices();
    }
  }

  // ─── Heartbeat ───────────────────────────────────────────

  void _startHeartbeatCheck() {
    Future.doWhile(() async {
      await Future.delayed(heartbeatCheckInterval);
      if (!_isConnected || _isDisposed) return false;

      final now = DateTime.now();
      if (_lastHeartbeat != null &&
          now.difference(_lastHeartbeat!) > heartbeatTimeout) {
        debugPrint('Heartbeat timeout.');
        _handleDisconnect();
        return false;
      }
      return true;
    });
  }

  // ─── Listening (STT) ────────────────────────────────────

  Future<bool> startListening() async {
    // If engine was not available, try initializing once more
    if (!_isSpeechAvailable) {
      final initialized = await _initSpeech();
      if (!initialized) {
        _speechErrorMessage = '未检测到系统语音识别服务，可直接打字输入';
        notifyListeners();
        return false;
      }
    }

    _speechErrorMessage = null;
    _sessionBaseText = _textDraft;
    _currentSessionWords = '';
    _isSessionFinalized = false;
    _wantsListening = true;
    notifyListeners();
    await _beginListenSession();
    return true;
  }

  /// Manually stop listening (manual stop only, no automatic cutoff)
  Future<void> stopListening() async {
    _wantsListening = false;
    _finalizeLocalSpeech();
  }

  // ─── App Lifecycle ───────────────────────────────────────

  /// Handle Flutter App lifecycle changes (e.g. backgrounding / foregrounding).
  /// Protects microphone when going background, auto-recovers connection on resume.
  void handleAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) return;
    debugPrint('VocalHomeController: lifecycle state changed to $state');

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // Protect microphone in background, preserve draft intact
        if (_wantsListening || _speechToText.isListening) {
          debugPrint('App backgrounded: safely stopping speech to release microphone...');
          stopListening();
        }
        break;

      case AppLifecycleState.resumed:
        // Foreground resume: self-check connection liveness
        debugPrint('App resumed: checking WebSocket connection...');
        if (!_isConnected && !_isConnecting && enableAutoReconnect && !_isOccupied && _connectionState != VocalConnectionState.occupied) {
          debugPrint('App resumed and disconnected: restarting discovery...');
          discoverServices();
        }
        break;

      case AppLifecycleState.detached:
        break;
    }
  }

  /// Internal: start a single STT listen session.
  Future<void> _beginListenSession() async {
    if (_isStartingSession) return;
    _isStartingSession = true;

    try {
      // Defensive delay for iOS 26 to ensure AVAudioSession is ready and stable
      await Future.delayed(const Duration(milliseconds: 300));

      if (!_wantsListening) return; // Checked again after delay

      await _speechToText.listen(
        onResult: _onSpeechResult,
        localeId: _selectedLocaleId,
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          cancelOnError: false,
        ),
        listenFor: const Duration(hours: 1), // Long duration: manual stop only
        pauseFor: const Duration(seconds: 30), // Prevent aggressive auto-pause
      );
    } finally {
      _isStartingSession = false;
      notifyListeners();
    }
  }

  // ─── Speech Result Handling (Continuous Manual Stop) ────────

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (_isSessionFinalized) {
      debugPrint('Ignoring post-finalization speech result: "${result.recognizedWords}"');
      return;
    }

    final newWords = result.recognizedWords;
    _currentSessionWords = newWords;
    _lastWords = newWords;

    // Combine base text (before this session) with current session words
    _textDraft = _combineBaseAndSpoken(_sessionBaseText, newWords);
    notifyListeners();

    // When a single sentence completes (engine finalizes a phrase):
    // Commit to base text so subsequent phrases accumulate, but DO NOT stop listening!
    if (result.finalResult && _wantsListening) {
      _sessionBaseText = _textDraft;
      _currentSessionWords = '';
    }
  }

  /// Smart helper to cleanly combine base text with newly spoken text
  String _combineBaseAndSpoken(String base, String spoken) {
    final trimmedSpoken = spoken.trim();
    if (trimmedSpoken.isEmpty) return base;
    final trimmedBase = base.trimRight();
    if (trimmedBase.isEmpty) return trimmedSpoken;

    final lastChar = trimmedBase.substring(trimmedBase.length - 1);
    final firstChar = trimmedSpoken.substring(0, 1);
    final isBaseCjk = RegExp(r'[\u4e00-\u9fa5]').hasMatch(lastChar);
    final isSpokenCjk = RegExp(r'[\u4e00-\u9fa5]').hasMatch(firstChar);

    if (isBaseCjk && isSpokenCjk) {
      return '$trimmedBase$trimmedSpoken';
    } else {
      return '$trimmedBase $trimmedSpoken';
    }
  }

  /// Finalize current spoken sentence into the draft when user manually stops listening.
  void _finalizeLocalSpeech() {
    if (_isSessionFinalized) return;
    _isSessionFinalized = true;

    _textDraft = _combineBaseAndSpoken(_sessionBaseText, _currentSessionWords);
    _sessionBaseText = _textDraft;
    _currentSessionWords = '';
    _lastWords = '';
    _wantsListening = false;
    _speechToText.stop();
    notifyListeners();
  }

  @visibleForTesting
  void handleSpeechResultForTesting(SpeechRecognitionResult result) {
    _onSpeechResult(result);
  }

  @visibleForTesting
  void setSessionBaseTextForTesting(String text) {
    _sessionBaseText = text;
    _textDraft = text;
    _isSessionFinalized = false;
  }

  @visibleForTesting
  void setSpeechAvailableForTesting(bool available, {String? errorMessage}) {
    _isSpeechAvailable = available;
    _speechErrorMessage = errorMessage;
    notifyListeners();
  }

  @visibleForTesting
  void handleSpeechErrorForTesting(SpeechRecognitionError error) {
    _onSpeechError(error);
  }

  @visibleForTesting
  void handleSpeechStatusForTesting(String status) {
    _onSpeechStatus(status);
  }

  @visibleForTesting
  void setWantsListeningForTesting(bool value) {
    _wantsListening = value;
  }

  @visibleForTesting
  void setCurrentSessionWordsForTesting(String words) {
    _currentSessionWords = words;
  }

  @visibleForTesting
  void setOccupiedForTesting({bool occupied = true}) {
    _isOccupied = occupied;
    _connectionState = occupied ? VocalConnectionState.occupied : VocalConnectionState.disconnected;
    if (occupied) {
      _isConnected = false;
      _isConnecting = false;
      _statusText = AppStrings.current.occupied;
    }
    notifyListeners();
  }

  // ─── Manual Send to Mac ──────────────────────────────────

  /// Manually send the current draft text to the connected Mac host.
  /// If [directText] is provided, it takes precedence over [_textDraft].
  /// Returns true if successfully sent, false if empty or not connected.
  bool sendCurrentDraft([String? directText]) {
    final rawText = directText ?? _textDraft;
    final textToSend = rawText.trim();
    if (textToSend.isEmpty) {
      return false;
    }

    if (!_isConnected || (_channel == null && !_isMockConnectedForTesting)) {
      debugPrint('Cannot send: Mac is not connected.');
      return false;
    }

    // Stop active listening if speech is in progress
    if (_speechToText.isListening) {
      stopListening();
    }

    final payload = jsonEncode({
      'type': 'text',
      'text': textToSend,
      'pressEnter': _autoPressEnter,
    });
    _channel?.sink.add(payload);
    debugPrint('Manually sent to Mac: "$textToSend" (pressEnter: $_autoPressEnter)');

    _lastSentWords = textToSend;
    // Move existing item to top (LRU) or insert fresh item, respecting maxHistoryLength
    _historyList.remove(textToSend);
    _historyList.insert(0, textToSend);
    if (_historyList.length > maxHistoryLength) {
      _historyList.removeRange(maxHistoryLength, _historyList.length);
    }

    // Clear draft after successful transmission
    _textDraft = '';
    _sessionBaseText = '';
    _lastWords = '';
    notifyListeners();
    return true;
  }
}
