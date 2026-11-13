import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vocal/page/vocal_home_controller.dart';

/// Lightweight Mock WebSocket Host Server running in-memory on loopback.
class MockVocalHost {
  final bool autoAuth;
  final bool singleDeviceExclusive;
  MockVocalHost({this.autoAuth = true, this.singleDeviceExclusive = false});

  HttpServer? _server;
  WebSocket? _currentSocket;
  final StreamController<String> _messageStreamController =
      StreamController<String>.broadcast();
  final List<String> receivedMessages = [];
  final List<Completer<String>> _waiters = [];

  int get port => _server?.port ?? 0;
  bool get hasActiveClient => _currentSocket != null;
  Stream<String> get messageStream => _messageStreamController.stream;

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen((HttpRequest request) async {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        final socket = await WebSocketTransformer.upgrade(request);
        if (singleDeviceExclusive && _currentSocket != null) {
          // Reject secondary connection in accordance with protocol
          socket.add('{"type": "error", "code": "OCCUPIED", "message": "Host is occupied by another device"}');
          Future.delayed(const Duration(milliseconds: 50), () async {
            try {
              await socket.close(4001, 'Host Occupied');
            } catch (_) {}
          });
          return;
        }
        _currentSocket = socket;
        socket.listen(
          (dynamic data) {
            final msg = data.toString();
            receivedMessages.add(msg);
            _messageStreamController.add(msg);
            if (autoAuth && msg.contains('"type":"auth_request"')) {
              try {
                socket.add('{"type": "auth_success", "mode": "open"}');
              } catch (_) {}
              return;
            }
            if (_waiters.isNotEmpty) {
              final waiter = _waiters.removeAt(0);
              if (!waiter.isCompleted) {
                waiter.complete(msg);
              }
            }
          },
          onDone: () {
            if (_currentSocket == socket) {
              _currentSocket = null;
            }
          },
          onError: (_) {
            if (_currentSocket == socket) {
              _currentSocket = null;
            }
          },
        );
      } else {
        request.response.statusCode = HttpStatus.forbidden;
        await request.response.close();
      }
    });
  }

  /// Send message to the connected mobile client
  void send(String message) {
    if (_currentSocket == null) {
      throw StateError('No active WebSocket client connected');
    }
    _currentSocket!.add(message);
  }

  /// Wait for the next incoming message from client
  Future<String> waitForNextMessage({Duration timeout = const Duration(seconds: 2)}) async {
    final completer = Completer<String>();
    _waiters.add(completer);
    return await completer.future.timeout(
      timeout,
      onTimeout: () {
        _waiters.remove(completer);
        throw TimeoutException('Timed out waiting for message after $timeout');
      },
    );
  }

  /// Abruptly disconnect the current connected client
  Future<void> disconnectClient({int? closeCode, String? closeReason}) async {
    if (_currentSocket != null) {
      final s = _currentSocket!;
      _currentSocket = null;
      await s.close(closeCode, closeReason);
    }
  }

  /// Stop server and clean up resources
  Future<void> stop() async {
    await disconnectClient();
    await _server?.close(force: true);
    _server = null;
    for (final waiter in _waiters) {
      if (!waiter.isCompleted) {
        waiter.completeError(StateError('Mock server stopped'));
      }
    }
    _waiters.clear();
    await _messageStreamController.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Layer 1: Mobile Mock Host Integration Tests', () {
    test('1. Handshake & state transition from disconnected to connected with reentrancy guard', () async {
      final host = MockVocalHost();
      await host.start();

      final ctrl = VocalHomeController(
        autoInit: false,
        enableAutoReconnect: false,
      );

      // Verify initial state
      expect(ctrl.connectionState, VocalConnectionState.disconnected);
      expect(ctrl.isConnected, isFalse);
      expect(ctrl.isConnecting, isFalse);

      // Connect directly to mock host
      final connFuture = ctrl.connectDirect('127.0.0.1', host.port);
      expect(ctrl.isConnecting, isTrue);

      // Concurrent connection attempt while in-flight handshake is pending
      final dupFuture = ctrl.connectDirect('127.0.0.1', host.port);
      await Future.wait([connFuture, dupFuture]);

      // Verify connected state
      expect(ctrl.connectionState, VocalConnectionState.connected);
      expect(ctrl.isConnected, isTrue);
      expect(ctrl.isConnecting, isFalse);
      expect(ctrl.statusText, 'Connected to Mac');
      expect(host.hasActiveClient, isTrue);

      // Re-entrant connectToUrl while already connected should safely no-op without disconnecting
      await ctrl.connectToUrl('ws://127.0.0.1:${host.port}');
      expect(ctrl.isConnected, isTrue);
      expect(ctrl.isConnecting, isFalse);
      expect(host.hasActiveClient, isTrue);

      await ctrl.disconnect();
      expect(ctrl.connectionState, VocalConnectionState.disconnected);
      expect(ctrl.isConnected, isFalse);
      expect(ctrl.isConnecting, isFalse);

      await host.stop();
      ctrl.dispose();
    });

    test('2. Heartbeat Ping-Pong response within 200ms', () async {
      final host = MockVocalHost();
      await host.start();

      final ctrl = VocalHomeController(
        autoInit: false,
        enableAutoReconnect: false,
      );

      await ctrl.connectDirect('127.0.0.1', host.port);
      expect(ctrl.isConnected, isTrue);

      // Prepare waiter for Pong response
      final pongFuture = host.waitForNextMessage(
        timeout: const Duration(milliseconds: 200),
      );

      final stopwatch = Stopwatch()..start();
      // Host sends ping to client
      host.send('{"type": "ping"}');

      final pongMessage = await pongFuture;
      stopwatch.stop();

      // Assert reply content and latency under 200ms
      expect(pongMessage, '{"type": "pong"}');
      expect(stopwatch.elapsedMilliseconds, lessThan(200));
      expect(ctrl.connectionState, VocalConnectionState.connected);

      await host.stop();
      ctrl.dispose();
    });

    test('3. Manual draft transmission and autoPressEnter control', () async {
      final host = MockVocalHost();
      await host.start();

      final ctrl = VocalHomeController(
        autoInit: false,
        enableAutoReconnect: false,
      );

      await ctrl.connectDirect('127.0.0.1', host.port);
      expect(ctrl.isConnected, isTrue);

      // Case A: With enter enabled (pressEnter: true)
      ctrl.setAutoPressEnter(true);
      ctrl.updateText('Hello Vocal with Enter');
      expect(ctrl.textDraft, 'Hello Vocal with Enter');

      final messageFutureA = host.waitForNextMessage();
      final sentA = ctrl.sendCurrentDraft();
      expect(sentA, isTrue);

      final rawPayloadA = await messageFutureA;
      final payloadA = jsonDecode(rawPayloadA) as Map<String, dynamic>;
      expect(payloadA['type'], 'text');
      expect(payloadA['text'], 'Hello Vocal with Enter');
      expect(payloadA['pressEnter'], isTrue);

      // Assert mobile draft cleared & added to history
      expect(ctrl.textDraft, isEmpty);
      expect(ctrl.historyList.first, 'Hello Vocal with Enter');

      // Case B: With enter disabled (pressEnter: false)
      ctrl.setAutoPressEnter(false);
      ctrl.updateText('Second draft without enter');

      final messageFutureB = host.waitForNextMessage();
      final sentB = ctrl.sendCurrentDraft();
      expect(sentB, isTrue);

      final rawPayloadB = await messageFutureB;
      final payloadB = jsonDecode(rawPayloadB) as Map<String, dynamic>;
      expect(payloadB['type'], 'text');
      expect(payloadB['text'], 'Second draft without enter');
      expect(payloadB['pressEnter'], isFalse);

      expect(ctrl.textDraft, isEmpty);
      expect(ctrl.historyList.first, 'Second draft without enter');
      expect(ctrl.historyList.length, 2);

      await host.stop();
      ctrl.dispose();
    });

    test('4. Unexpected disconnect preserves local draft without loss', () async {
      final host = MockVocalHost();
      await host.start();

      final ctrl = VocalHomeController(
        autoInit: false,
        enableAutoReconnect: false,
      );

      await ctrl.connectDirect('127.0.0.1', host.port);
      expect(ctrl.isConnected, isTrue);

      // User types or speaks an important draft
      const criticalDraft = '重要语音草稿：绝不能因网络断开丢失！';
      ctrl.updateText(criticalDraft);
      expect(ctrl.textDraft, criticalDraft);

      // Host abruptly cuts the connection
      await host.disconnectClient();

      // Wait a moment for client stream onDone to fire
      await Future.delayed(const Duration(milliseconds: 100));

      // Assert client state transitioned to disconnected
      expect(ctrl.isConnected, isFalse);
      expect(ctrl.connectionState, VocalConnectionState.disconnected);

      // CRITICAL RULE ASSERTION: Local draft MUST remain intact!
      expect(ctrl.textDraft, criticalDraft);

      // Attempting to send in disconnected state fails safely and does NOT wipe draft
      final sendResult = ctrl.sendCurrentDraft();
      expect(sendResult, isFalse);
      expect(ctrl.textDraft, criticalDraft);

      await host.stop();
      ctrl.dispose();
    });

    test('5. Server restart and client reconnection recovers draft transmission', () async {
      final host = MockVocalHost();
      await host.start();

      final ctrl = VocalHomeController(
        autoInit: false,
        enableAutoReconnect: false,
      );

      await ctrl.connectDirect('127.0.0.1', host.port);
      expect(ctrl.isConnected, isTrue);

      const persistentDraft = '断线重连测试草稿';
      ctrl.updateText(persistentDraft);

      // Host terminates
      await host.stop();
      await Future.delayed(const Duration(milliseconds: 100));
      expect(ctrl.isConnected, isFalse);
      expect(ctrl.textDraft, persistentDraft);

      // Restart a new host instance (simulating Mac host relaunch)
      final newHost = MockVocalHost();
      await newHost.start();

      // Reconnect to new host
      await ctrl.connectDirect('127.0.0.1', newHost.port);
      expect(ctrl.isConnected, isTrue);
      expect(ctrl.connectionState, VocalConnectionState.connected);
      expect(ctrl.textDraft, persistentDraft);

      // Send retained draft to new host
      final msgFuture = newHost.waitForNextMessage();
      final sent = ctrl.sendCurrentDraft();
      expect(sent, isTrue);

      final rawPayload = await msgFuture;
      final payload = jsonDecode(rawPayload) as Map<String, dynamic>;
      expect(payload['type'], 'text');
      expect(payload['text'], persistentDraft);

      expect(ctrl.textDraft, isEmpty);
      expect(ctrl.historyList.first, persistentDraft);

      await newHost.stop();
      ctrl.dispose();
    });

    test('6. Heartbeat timeout detection safely marks disconnected and keeps draft', () async {
      final host = MockVocalHost();
      await host.start();

      // Set aggressive heartbeat timeout for fast test execution
      final ctrl = VocalHomeController(
        autoInit: false,
        enableAutoReconnect: false,
        heartbeatTimeout: const Duration(milliseconds: 250),
        heartbeatCheckInterval: const Duration(milliseconds: 100),
      );

      await ctrl.connectDirect('127.0.0.1', host.port);
      expect(ctrl.isConnected, isTrue);

      ctrl.updateText('草稿在假死断线后依然完好');

      // Host intentionally remains silent (no ping sent)
      // Wait for heartbeat check loop to detect timeout (> 250ms)
      await Future.delayed(const Duration(milliseconds: 450));

      expect(ctrl.isConnected, isFalse);
      expect(ctrl.connectionState, VocalConnectionState.disconnected);
      expect(ctrl.statusText, 'Connection Lost');
      expect(ctrl.textDraft, '草稿在假死断线后依然完好');

      await host.stop();
      ctrl.dispose();
    });

    test('7. Multi-device anti-preemption: Client B receives OCCUPIED, halts auto-reconnect, while Client A remains undisturbed', () async {
      final host = MockVocalHost(singleDeviceExclusive: true);
      await host.start();

      // Client A connects first
      final ctrlA = VocalHomeController(
        autoInit: false,
        enableAutoReconnect: true,
      );
      await ctrlA.connectDirect('127.0.0.1', host.port);
      expect(ctrlA.isConnected, isTrue);
      expect(ctrlA.connectionState, VocalConnectionState.connected);
      expect(host.hasActiveClient, isTrue);

      // Client B connects to the same Mock Host
      final ctrlB = VocalHomeController(
        autoInit: false,
        enableAutoReconnect: true, // Auto-reconnect enabled to verify anti-storm circuit breaker!
      );
      await ctrlB.connectDirect('127.0.0.1', host.port);

      // Wait briefly for OCCUPIED frame reception and subsequent socket close
      await Future.delayed(const Duration(milliseconds: 150));

      // 1) Assert Client B enters occupied state
      expect(ctrlB.connectionState, VocalConnectionState.occupied);
      expect(ctrlB.isOccupied, isTrue);
      expect(ctrlB.isConnected, isFalse);

      // 2) Assert Client B halts auto-reconnection and does not storm the host
      // Wait for an additional period to verify no auto-reconnect occurred
      await Future.delayed(const Duration(milliseconds: 200));
      expect(ctrlB.connectionState, VocalConnectionState.occupied);
      expect(ctrlB.isOccupied, isTrue);

      // 3) Assert Client A remains completely undisturbed and actively connected
      expect(ctrlA.isConnected, isTrue);
      expect(ctrlA.connectionState, VocalConnectionState.connected);

      // Client A can still send messages normally
      ctrlA.updateText('Message from Client A while Client B was rejected');
      final msgFutureA = host.waitForNextMessage();
      final sentA = ctrlA.sendCurrentDraft();
      expect(sentA, isTrue);

      final rawPayloadA = await msgFutureA;
      final payloadA = jsonDecode(rawPayloadA) as Map<String, dynamic>;
      expect(payloadA['text'], 'Message from Client A while Client B was rejected');

      // Client A still responds to Ping
      final pongFuture = host.waitForNextMessage();
      host.send('{"type": "ping"}');
      final pongMsg = await pongFuture;
      expect(pongMsg, '{"type": "pong"}');

      // 4) Test Client B manual retryConnection:
      // While Client A is still connected, retry should be rejected again and stay occupied
      await ctrlB.retryConnection();
      await Future.delayed(const Duration(milliseconds: 150));
      expect(ctrlB.connectionState, VocalConnectionState.occupied);

      // When Client A disconnects, Client B can successfully reconnect via retryConnection()
      await ctrlA.disconnect();
      expect(ctrlA.isConnected, isFalse);
      await Future.delayed(const Duration(milliseconds: 150));
      expect(host.hasActiveClient, isFalse);

      await ctrlB.retryConnection();
      await Future.delayed(const Duration(milliseconds: 150));
      expect(ctrlB.isConnected, isTrue);
      expect(ctrlB.connectionState, VocalConnectionState.connected);
      expect(ctrlB.isOccupied, isFalse);

      await host.stop();
      ctrlA.dispose();
      ctrlB.dispose();
    });
  });
}
