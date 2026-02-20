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

  bool get isConnected => _isConnected;
  String get statusText => _statusText;

  // ─── Speech-to-Text ──────────────────────────────────────
  final SpeechToText _speechToText = SpeechToText();
  String? _selectedLocaleId;
  String _lastWords = '';
  String _lastSentWords = '';
  final List<String> _historyList = [];
  Timer? _debounceTimer;

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
    bool available = await _speechToText.initialize();
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
    try {
      _statusText = 'Scanning for Mac...';
      notifyListeners();

      final discovery = await nsd.startDiscovery('_vocal._tcp');
      discovery.addListener(() {
        if (discovery.services.isEmpty) {
          _statusText = 'No Mac found yet...';
          notifyListeners();
          return;
        }

        for (final service in discovery.services) {
          debugPrint(
            'Discovered: ${service.name} (${service.host}:${service.port})',
          );
          if (service.host != null && service.port != null && !_isConnected) {
            _connectToMac(service.host!, service.port!);
            nsd.stopDiscovery(discovery);
            break;
          } else {
            _statusText = 'Found ${service.name}, resolving...';
            notifyListeners();
          }
        }
      });
    } catch (e) {
      _statusText = 'Discovery error: $e';
      notifyListeners();
    }
  }

  // ─── WebSocket Connection ────────────────────────────────

  void _connectToMac(String host, int port) {
    try {
      final wsUrl = 'ws://$host:$port';
      debugPrint('Attempting connection to $wsUrl');
      _statusText = 'Connecting to Mac...';
      notifyListeners();

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

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
    _lastWords = '';
    _lastSentWords = '';
    notifyListeners();

    await _speechToText.listen(
      onResult: _onSpeechResult,
      localeId: _selectedLocaleId,
    );
    notifyListeners();
  }

  Future<void> stopListening() async {
    await _speechToText.stop();
    notifyListeners();
  }

  // ─── Speech Result Handling (Debounce) ─────────────────────

  void _onSpeechResult(SpeechRecognitionResult result) {
    final newWords = result.recognizedWords;
    _lastWords = newWords;
    notifyListeners();

    // Final result: save to history, flush immediately, done.
    if (result.finalResult) {
      _debounceTimer?.cancel();
      if (newWords.trim().isNotEmpty) {
        _sendToMac(newWords);
        if (!_historyList.contains(newWords)) {
          _historyList.insert(0, newWords);
        }
        notifyListeners();
      }
      debugPrint('Final sent: "$newWords"');
      return;
    }

    // Partial result: debounce 300ms — wait for speech to pause.
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _sendToMac(newWords);
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
