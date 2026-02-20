import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:nsd/nsd.dart' as nsd;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VocalApp());
}

class VocalApp extends StatelessWidget {
  const VocalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vocal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0F1C),
      ),
      home: const VocalHomeScreen(),
    );
  }
}

class VocalHomeScreen extends StatefulWidget {
  const VocalHomeScreen({super.key});

  @override
  State<VocalHomeScreen> createState() => _VocalHomeScreenState();
}

class _VocalHomeScreenState extends State<VocalHomeScreen>
    with SingleTickerProviderStateMixin {
  final SpeechToText _speechToText = SpeechToText();
  String _lastWords = '';
  WebSocketChannel? _channel;
  bool _isConnected = false;
  String _statusText = 'Searching for Mac...';
  late AnimationController _animController;
  DateTime? _lastHeartbeat;
  String? _selectedLocaleId;
  String _lastSentWords = '';

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _discoverServices();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  void _initSpeech() async {
    bool available = await _speechToText.initialize();
    if (available) {
      final locales = await _speechToText.locales();
      // Try to find Chinese (Mandarin)
      for (var locale in locales) {
        if (locale.localeId.startsWith('zh')) {
          _selectedLocaleId = locale.localeId;
          print('Selected Chinese locale: ${locale.name}');
          break;
        }
      }
    }
    if (mounted) setState(() {});
  }

  void _discoverServices() async {
    try {
      setState(() => _statusText = 'Scanning for Mac...');
      final discovery = await nsd.startDiscovery('_vocal._tcp');
      discovery.addListener(() {
        if (discovery.services.isEmpty) {
          if (mounted) setState(() => _statusText = 'No Mac found yet...');
          return;
        }

        for (final service in discovery.services) {
          print(
            'Discovered: ${service.name} (${service.host}:${service.port})',
          );
          if (service.host != null && service.port != null && !_isConnected) {
            _connectToMac(service.host!, service.port!);
            nsd.stopDiscovery(discovery);
            break;
          } else {
            if (mounted) {
              setState(
                () => _statusText = 'Found ${service.name}, resolving...',
              );
            }
          }
        }
      });
    } catch (e) {
      if (mounted) setState(() => _statusText = 'Discovery error: $e');
    }
  }

  void _connectToMac(String host, int port) {
    try {
      final wsUrl = 'ws://$host:$port';
      print('Attempting connection to $wsUrl');
      if (mounted) setState(() => _statusText = 'Connecting to Mac...');
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _channel!.stream.listen(
        (message) {
          _lastHeartbeat = DateTime.now();
          if (message.toString().contains('"type":"ping"') ||
              message.toString().contains('"type": "ping"')) {
            _channel!.sink.add('{"type": "pong"}');
            print('Received ping, sent pong.');
          }
        },
        onDone: () {
          _handleDisconnect();
        },
        onError: (e) {
          _handleDisconnect();
        },
      );

      setState(() {
        _isConnected = true;
        _statusText = 'Connected to Mac';
      });

      _startHeartbeatCheck();
    } catch (e) {
      if (mounted) setState(() => _statusText = 'Connection failed');
    }
  }

  void _handleDisconnect() {
    if (mounted && _isConnected) {
      setState(() {
        _isConnected = false;
        _statusText = 'Connection Lost';
      });
      _discoverServices(); // Restart discovery
    }
  }

  void _startHeartbeatCheck() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 10));
      if (!_isConnected) return false;

      final now = DateTime.now();
      if (_lastHeartbeat != null &&
          now.difference(_lastHeartbeat!).inSeconds > 15) {
        print('Heartbeat timeout.');
        _handleDisconnect();
        return false;
      }
      return true;
    });
  }

  void _startListening() async {
    _lastSentWords = ''; // Reset for new session
    await _speechToText.listen(
      onResult: _onSpeechResult,
      localeId: _selectedLocaleId,
    );
    if (mounted) setState(() {});
  }

  void _stopListening() async {
    await _speechToText.stop();
    if (mounted) setState(() {});
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    final newWords = result.recognizedWords;
    setState(() {
      _lastWords = newWords;
    });

    if (_isConnected && _channel != null) {
      String delta = '';
      if (newWords.startsWith(_lastSentWords)) {
        delta = newWords.substring(_lastSentWords.length);
      } else {
        // Recognition might have diverged or restarted (e.g. system correction)
        // In this case, we send a space and the whole thing to be safe,
        // or just the whole thing if we assume the previous text was already "finalized" enough.
        // For now, let's just send the whole new content if it doesn't match prefix.
        delta = newWords;
      }

      if (delta.isNotEmpty) {
        _channel!.sink.add(delta);
        _lastSentWords = newWords;
      }
    }
  }

  @override
  void dispose() {
    _channel?.sink.close(status.goingAway);
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header (header) - Height 60
            Container(
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _isConnected
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 3,
                          backgroundColor: _isConnected
                              ? Colors.green
                              : Colors.red,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isConnected ? 'ONLINE' : 'OFFLINE',
                          style: TextStyle(
                            color: _isConnected ? Colors.green : Colors.red,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Main Area (main) - Centered Mic
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _statusText.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 12,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 48),
                    GestureDetector(
                      onTapDown: (_) => _startListening(),
                      onTapUp: (_) => _stopListening(),
                      onTapCancel: () => _stopListening(),
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
                                color: const Color(0xFF22D3EE).withOpacity(
                                  0.3 + (_animController.value * 0.4),
                                ),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF22D3EE).withOpacity(
                                    _speechToText.isListening ? 0.2 : 0.05,
                                  ),
                                  blurRadius: 20 + (_animController.value * 20),
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Icon(
                              _speechToText.isListening
                                  ? Icons.mic
                                  : Icons.mic_none,
                              size: 48,
                              color: const Color(0xFF22D3EE),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      _speechToText.isListening
                          ? 'LISTENING...'
                          : 'PUSH TO TALK',
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
            ),

            // Transcription Block (transcription_bg)
            Container(
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
                      Icon(
                        Icons.notes,
                        size: 14,
                        color: Colors.white.withOpacity(0.3),
                      ),
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
                  Text(
                    _lastWords.isEmpty
                        ? 'Transcription will appear here...'
                        : _lastWords,
                    style: TextStyle(
                      color: _lastWords.isEmpty
                          ? Colors.white.withOpacity(0.2)
                          : Colors.white.withOpacity(0.9),
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
