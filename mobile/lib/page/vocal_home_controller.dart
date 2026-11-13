import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:nsd/nsd.dart' as nsd;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

/// Connection states of the Vocal mobile client state machine.
enum VocalConnectionState {
  disconnected,
  searching,
  connecting,
  connected,
  reconnecting,
}

/// Controls all business logic for the Vocal app:
/// mDNS discovery, WebSocket connection, heartbeat, STT, delta-sync, history.
class VocalHomeController extends ChangeNotifier {
  // ─── Connection ──────────────────────────────────────────
  WebSocketChannel? _channel;
  bool _isConnected = false;
  bool _isConnecting = false;
  VocalConnectionState _connectionState = VocalConnectionState.disconnected;
  String _statusText = 'Searching for Mac...';
  DateTime? _lastHeartbeat;

  final Duration heartbeatTimeout;
  final Duration heartbeatCheckInterval;
  final bool enableAutoReconnect;

  // ─── Device Discovery ────────────────────────────────────
  final List<nsd.Service> _discoveredServices = [];
  nsd.Discovery? _activeDiscovery;

  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  VocalConnectionState get connectionState => _connectionState;
  String get statusText => _statusText;
  List<nsd.Service> get discoveredServices =>
      List.unmodifiable(_discoveredServices);

  // ─── Speech-to-Text & Locales ────────────────────────────
  final SpeechToText _speechToText = SpeechToText();
  List<LocaleName> _availableLocales = [];
  String? _selectedLocaleId;
  String _lastWords = '';
  String _lastSentWords = '';

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

  // ─── Speech Init ─────────────────────────────────────────

  Future<void> _initSpeech() async {
    bool available = await _speechToText.initialize(
      onStatus: (status) {
        debugPrint('STT Status: $status');
        // Safety net: if engine stops unexpectedly while user still wants listening
        if (status == 'done' && _wantsListening) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (_wantsListening &&
                !_speechToText.isListening &&
                !_isStartingSession) {
              debugPrint('Engine stopped, restarting cleanly...');
              _beginListenSession();
            }
          });
        }
      },
      onError: (error) {
        debugPrint('STT Error: $error');
      },
    );
    if (available) {
      final locales = await _speechToText.locales();
      _availableLocales = locales;

      // Smart default: prioritize Mandarin Chinese (zh_CN), fallback to any zh, or first locale
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
      if (preferred == null && locales.isNotEmpty) {
        preferred = locales.first;
      }

      if (preferred != null) {
        _selectedLocaleId = preferred.localeId;
        debugPrint('STT Locale initialized to: ${preferred.name} (${preferred.localeId})');
      }
    }
    notifyListeners();
  }

  // ─── mDNS Discovery ─────────────────────────────────────

  Future<void> discoverServices() async {
    // Guard: skip if already connected, connecting, or discovery in progress
    if (_isConnected || _isConnecting) return;
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
          final msgStr = message.toString();
          if (msgStr.contains('"type":"ping"') ||
              msgStr.contains('"type": "ping"')) {
            channel.sink.add('{"type": "pong"}');
            _lastHeartbeat = DateTime.now();
            debugPrint('Received ping, sent pong.');
          }
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
      _connectionState = VocalConnectionState.disconnected;
      _statusText = 'Connection failed';
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

  void _handleConnectionClosed({Object? error}) {
    if (_isDisposed) return;
    _channel = null;
    _isConnected = false;
    _isConnecting = false;
    _connectionState = VocalConnectionState.disconnected;
    _lastSentWords = '';
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
      _connectionState = VocalConnectionState.disconnected;
      _lastSentWords = '';
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
    _isConnected = false;
    _isConnecting = false;
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

  Future<void> startListening() async {
    _sessionBaseText = _textDraft;
    _currentSessionWords = '';
    _isSessionFinalized = false;
    _wantsListening = true;
    notifyListeners();
    await _beginListenSession();
  }

  /// Manually stop listening (manual stop only, no automatic cutoff)
  Future<void> stopListening() async {
    _wantsListening = false;
    _finalizeLocalSpeech();
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
        listenMode: ListenMode.dictation,
        listenFor: const Duration(hours: 1), // Long duration: manual stop only
        pauseFor: const Duration(seconds: 30), // Prevent aggressive auto-pause
        cancelOnError: false,
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

    if (!_isConnected || _channel == null) {
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
    _channel!.sink.add(payload);
    debugPrint('Manually sent to Mac: "$textToSend" (pressEnter: $_autoPressEnter)');

    _lastSentWords = textToSend;
    if (!_historyList.contains(textToSend)) {
      _historyList.insert(0, textToSend);
    }

    // Clear draft after successful transmission
    _textDraft = '';
    _sessionBaseText = '';
    _lastWords = '';
    notifyListeners();
    return true;
  }
}
