import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:nsd/nsd.dart' as nsd;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

/// Controls all business logic for the Vocal app:
/// mDNS discovery, WebSocket connection, heartbeat, STT, delta-sync, history.
class VocalHomeController extends ChangeNotifier {
  // ─── Connection ──────────────────────────────────────────
  WebSocketChannel? _channel;
  bool _isConnected = false;
  String _statusText = 'Searching for Mac...';
  DateTime? _lastHeartbeat;

  // ─── Device Discovery ────────────────────────────────────
  final List<nsd.Service> _discoveredServices = [];
  nsd.Discovery? _activeDiscovery;

  bool get isConnected => _isConnected;
  String get statusText => _statusText;
  List<nsd.Service> get discoveredServices =>
      List.unmodifiable(_discoveredServices);

  // ─── Speech-to-Text ──────────────────────────────────────
  final SpeechToText _speechToText = SpeechToText();
  String? _selectedLocaleId;
  String _lastWords = '';
  String _lastSentWords = '';

  /// The last recognized sentence that was finalized and sent to Mac.
  /// Used for deduplication within a single logic flow.
  String _lastFinalizedText = '';

  /// Guard to prevent parallel finalizations (debounce vs finalResult).
  bool _isFinalizing = false;

  final List<String> _historyList = [];
  Timer? _debounceTimer;
  bool _wantsListening = false; // Toggle state: user wants continuous listening
  bool _isStartingSession = false; // Guard against parallel restarts

  bool get isListening => _speechToText.isListening;
  String get lastWords => _lastWords;
  String get lastSentWords => _lastSentWords;
  List<String> get historyList => List.unmodifiable(_historyList);

  // ─── Lifecycle ───────────────────────────────────────────

  VocalHomeController() {
    _initSpeech();
    discoverServices();
  }

  @override
  void dispose() {
    _channel?.sink.close(status.goingAway);
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
      for (var locale in locales) {
        if (locale.localeId.startsWith('zh')) {
          _selectedLocaleId = locale.localeId;
          debugPrint('Selected Chinese locale: ${locale.name}');
          break;
        }
      }
    }
    notifyListeners();
  }

  // ─── mDNS Discovery ─────────────────────────────────────

  Future<void> discoverServices() async {
    // Guard: skip if already connected or discovery in progress
    if (_isConnected) return;
    if (_activeDiscovery != null) return;

    try {
      _discoveredServices.clear();
      _statusText = 'Scanning for Mac...';
      notifyListeners();

      final discovery = await nsd.startDiscovery('_vocal._tcp');
      _activeDiscovery = discovery;
      discovery.addListener(() {
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
        } else if (_discoveredServices.length == 1 && !_isConnected) {
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
      notifyListeners();
    }
  }

  /// Connect to a user-selected service from the discovered list.
  void connectToService(nsd.Service service) {
    // Defer stop so it doesn't fire inside the discovery listener callback
    Future.microtask(() => stopDiscovery());
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

  Future<void> _connectToMac(String host, int port) async {
    try {
      final wsUrl = 'ws://$host:$port';
      debugPrint('Attempting connection to $wsUrl');
      _statusText = 'Connecting to Mac...';
      notifyListeners();

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      await _channel!.ready;

      _channel!.stream.listen(
        (message) {
          if (message.toString().contains('"type":"ping"') ||
              message.toString().contains('"type": "ping"')) {
            _channel!.sink.add('{"type": "pong"}');
            _lastHeartbeat = DateTime.now();
            debugPrint('Received ping, sent pong.');
          }
        },
        onDone: () {
          debugPrint('Connection closed.');
          _isConnected = false;
          _statusText = 'Disconnected. Searching...';
          _lastSentWords = '';
          notifyListeners();
          discoverServices();
        },
        onError: (e) {
          debugPrint('Connection error: $e');
          _isConnected = false;
          _lastSentWords = '';
          notifyListeners();
        },
      );

      _isConnected = true;
      _statusText = 'Connected to Mac';
      notifyListeners();

      _startHeartbeatCheck();
    } catch (e) {
      _statusText = 'Connection failed';
      notifyListeners();
    }
  }

  void _handleDisconnect() {
    if (_isConnected) {
      _isConnected = false;
      _statusText = 'Connection Lost';
      notifyListeners();
      discoverServices();
    }
  }

  // ─── Heartbeat ───────────────────────────────────────────

  void _startHeartbeatCheck() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 10));
      if (!_isConnected) return false;

      final now = DateTime.now();
      if (_lastHeartbeat != null &&
          now.difference(_lastHeartbeat!).inSeconds > 15) {
        debugPrint('Heartbeat timeout.');
        _handleDisconnect();
        return false;
      }
      return true;
    });
  }

  // ─── Listening (STT) ────────────────────────────────────

  Future<void> startListening() async {
    _wantsListening = true;

    notifyListeners();
    await _beginListenSession();
  }

  Future<void> stopListening() async {
    _wantsListening = false;
    _debounceTimer?.cancel();
    await _speechToText.stop();
    _lastWords = '';
    _lastSentWords = '';
    notifyListeners();
  }

  /// Internal: start a single STT listen session.
  /// Uses dictation mode so the engine stays open and fires finalResult
  /// for each completed sentence without stopping.
  Future<void> _beginListenSession() async {
    if (_isStartingSession) return;
    _isStartingSession = true;

    // Clear session-level deduplication state
    _lastFinalizedText = '';

    try {
      // Defensive delay for iOS 26 to ensure AVAudioSession is ready and stable
      await Future.delayed(const Duration(milliseconds: 400));

      if (!_wantsListening) return; // Checked again after delay

      await _speechToText.listen(
        onResult: _onSpeechResult,
        localeId: _selectedLocaleId,
        listenMode: ListenMode.dictation,
        listenFor: const Duration(seconds: 60),
        cancelOnError: true,
      );
    } finally {
      _isStartingSession = false;
      notifyListeners();
    }
  }

  // ─── Speech Result Handling (Debounce) ─────────────────────

  void _onSpeechResult(SpeechRecognitionResult result) async {
    final newWords = result.recognizedWords;
    final trimmed = newWords.trim();

    // Ignore updates that match what we already finalized
    if (trimmed == _lastFinalizedText && _lastFinalizedText.isNotEmpty) {
      return;
    }

    _lastWords = newWords;
    notifyListeners();

    // Reset debounce timer on every result
    _debounceTimer?.cancel();
    if (trimmed.isNotEmpty) {
      _debounceTimer = Timer(const Duration(milliseconds: 900), () {
        debugPrint('Silence detected, auto-finalizing: "$newWords"');
        _finalizeSentence(newWords);
      });
    }

    // Official final result: handle immediately
    if (result.finalResult) {
      _debounceTimer?.cancel();
      _finalizeSentence(newWords);
    }
  }

  /// Finalize the current sentence: send to Mac, add to history, and restart listener.
  void _finalizeSentence(String words) {
    final trimmed = words.trim();
    if (trimmed.isEmpty) return;

    // Guard against parallel finalization (silence debounce vs official finalResult)
    // or immediate duplicate strings.
    if (_isFinalizing ||
        (trimmed == _lastFinalizedText && _lastFinalizedText.isNotEmpty)) {
      debugPrint('Ignoring duplicate/parallel finalization: "$trimmed"');
      return;
    }

    _isFinalizing = true;
    _lastFinalizedText = trimmed;

    // Send to Mac and update history
    _sendToMac(trimmed);
    if (!_historyList.contains(trimmed)) {
      _historyList.insert(0, trimmed);
    }

    // Clear local transient state
    _lastWords = '';
    _lastSentWords = '';

    // Stop the engine. The onStatus listener will detect 'done' and restart
    // because _wantsListening is still true.
    _speechToText.stop();
    notifyListeners();

    // Reset the guard after a small "cooling" period to ensure the engine
    // has actually stopped or transitioned state.
    Future.delayed(const Duration(milliseconds: 300), () {
      _isFinalizing = false;
    });
  }

  /// Send full recognized text to Mac. Mac handles delta calculation.
  void _sendToMac(String fullText) {
    if (_isConnected && _channel != null && fullText.isNotEmpty) {
      _channel!.sink.add(fullText);
      _lastSentWords = fullText;
      notifyListeners();
      debugPrint('Sent: "$fullText"');
    }
  }
}
