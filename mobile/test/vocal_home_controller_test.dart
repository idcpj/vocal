import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:vocal/i18n/app_strings.dart';
import 'package:vocal/page/vocal_home_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VocalHomeController Manual Send & Draft Tests', () {
    test('initial draft should be empty and connection flags false', () {
      final ctrl = VocalHomeController(autoInit: false);
      expect(ctrl.textDraft, isEmpty);
      expect(ctrl.historyList, isEmpty);
      expect(ctrl.isConnecting, isFalse);
      expect(ctrl.isConnected, isFalse);
      ctrl.dispose();
    });

    test('updateText and clearText should update textDraft', () {
      final ctrl = VocalHomeController(autoInit: false);
      ctrl.updateText('你好 Mac');
      expect(ctrl.textDraft, '你好 Mac');

      ctrl.clearText();
      expect(ctrl.textDraft, isEmpty);
      ctrl.dispose();
    });

    test('setText should update textDraft (history reuse)', () {
      final ctrl = VocalHomeController(autoInit: false);
      ctrl.setText('历史文字');
      expect(ctrl.textDraft, '历史文字');
      ctrl.dispose();
    });

    test('history list should store multiple items, support LRU reorder, cap at 50, and clear', () {
      final ctrl = VocalHomeController(autoInit: false);
      expect(ctrl.historyList, isEmpty);

      // Add 5 distinct items
      for (int i = 1; i <= 5; i++) {
        ctrl.addHistoryItemForTesting('指令 $i');
      }
      expect(ctrl.historyList.length, 5);
      expect(ctrl.historyList.first, '指令 5');
      expect(ctrl.historyList.last, '指令 1');

      // LRU re-order when re-adding '指令 2'
      ctrl.addHistoryItemForTesting('指令 2');
      expect(ctrl.historyList.length, 5);
      expect(ctrl.historyList.first, '指令 2');

      // Add items up to and exceeding limit (55 items)
      for (int i = 6; i <= 60; i++) {
        ctrl.addHistoryItemForTesting('指令 $i');
      }
      expect(ctrl.historyList.length, VocalHomeController.maxHistoryLength);
      expect(ctrl.historyList.length, 50);
      expect(ctrl.historyList.first, '指令 60');

      // Clear history
      ctrl.clearHistory();
      expect(ctrl.historyList, isEmpty);
      ctrl.dispose();
    });

    test('autoPressEnter toggle and setter should update state', () {
      final ctrl = VocalHomeController(autoInit: false);
      expect(ctrl.autoPressEnter, isFalse);

      ctrl.toggleAutoPressEnter();
      expect(ctrl.autoPressEnter, isTrue);

      ctrl.toggleAutoPressEnter();
      expect(ctrl.autoPressEnter, isFalse);

      ctrl.setAutoPressEnter(true);
      expect(ctrl.autoPressEnter, isTrue);
      ctrl.dispose();
    });

    test('sendCurrentDraft without connection or empty text should return false', () {
      final ctrl = VocalHomeController(autoInit: false);
      // Empty text
      expect(ctrl.sendCurrentDraft(), isFalse);

      // With text but not connected
      ctrl.updateText('测试未连接发送');
      expect(ctrl.sendCurrentDraft(), isFalse);
      // Draft should remain intact if not sent
      expect(ctrl.textDraft, '测试未连接发送');
      ctrl.dispose();
    });

    test('speech results should not duplicate words upon finalization and post-stop callbacks', () {
      final ctrl = VocalHomeController(autoInit: false);
      ctrl.setSessionBaseTextForTesting('');

      // 1. First partial result
      const words = '好的按你说的处理';
      final partialResult = SpeechRecognitionResult([
        SpeechRecognitionWords(words, null, 1.0),
      ], false);
      ctrl.handleSpeechResultForTesting(partialResult);
      expect(ctrl.textDraft, '好的按你说的处理');

      // 2. Final result from engine
      final finalResult = SpeechRecognitionResult([
        SpeechRecognitionWords(words, null, 1.0),
      ], true);
      ctrl.handleSpeechResultForTesting(finalResult);
      expect(ctrl.textDraft, '好的按你说的处理');

      // 3. Spurious post-stop event from iOS engine with same text
      ctrl.handleSpeechResultForTesting(finalResult);
      expect(ctrl.textDraft, '好的按你说的处理'); // MUST NOT be duplicated!

      ctrl.dispose();
    });
  });

  group('VocalHomeController Multi-language Tests', () {
    test('setAvailableLocalesForTesting and setLocale should update current locale', () {
      final ctrl = VocalHomeController(autoInit: false);
      final mockLocales = [
        LocaleName('zh_CN', 'Chinese (China)'),
        LocaleName('en_US', 'English (United States)'),
        LocaleName('ja_JP', 'Japanese (Japan)'),
      ];

      ctrl.setAvailableLocalesForTesting(mockLocales, defaultLocaleId: 'zh_CN');
      expect(ctrl.availableLocales.length, 3);
      expect(ctrl.selectedLocaleId, 'zh_CN');
      expect(ctrl.currentLocaleDisplayName, 'Chinese (China)');

      // Switch to English
      ctrl.setLocale('en_US');
      expect(ctrl.selectedLocaleId, 'en_US');
      expect(ctrl.currentLocaleDisplayName, 'English (United States)');

      // Switch to Japanese
      ctrl.setLocale('ja_JP');
      expect(ctrl.selectedLocaleId, 'ja_JP');
      expect(ctrl.currentLocaleDisplayName, 'Japanese (Japan)');

      ctrl.dispose();
    });

    test('empty locales should fallback to default Chinese and English', () {
      final ctrl = VocalHomeController(autoInit: false);
      ctrl.setAvailableLocalesForTesting([], defaultLocaleId: null);

      // Even if raw list is empty, default display name gracefully handles it
      expect(ctrl.currentLocaleDisplayName, '中文 (普通话)');
      ctrl.dispose();
    });
  });

  group('Android STT Error Recovery & Continuous Dictation Tests', () {
    test('benign timeouts (error_speech_timeout & error_no_match) should preserve draft and listening intent', () {
      final ctrl = VocalHomeController(autoInit: false);
      ctrl.setSessionBaseTextForTesting('基准文字');
      ctrl.setCurrentSessionWordsForTesting('正在说的话');
      ctrl.updateText('基准文字正在说的话');
      ctrl.setWantsListeningForTesting(true);

      // Simulate Android pause error: error_speech_timeout
      final timeoutErr = SpeechRecognitionError('error_speech_timeout', false);
      ctrl.handleSpeechErrorForTesting(timeoutErr);

      // Listening intent MUST remain true!
      expect(ctrl.isListening, isTrue);
      // Draft MUST NOT be cleared!
      expect(ctrl.textDraft, '基准文字正在说的话');
      // No scary error message presented to user
      expect(ctrl.speechErrorMessage, isNull);

      // Simulate Android no match error: error_no_match
      final noMatchErr = SpeechRecognitionError('error_no_match', false);
      ctrl.handleSpeechErrorForTesting(noMatchErr);

      expect(ctrl.isListening, isTrue);
      expect(ctrl.textDraft, '基准文字正在说的话');
      expect(ctrl.speechErrorMessage, isNull);

      ctrl.dispose();
    });

    test('network errors (error_network) should show friendly message and preserve draft', () {
      final ctrl = VocalHomeController(autoInit: false);
      ctrl.setSessionBaseTextForTesting('网络断开前的内容');
      ctrl.setWantsListeningForTesting(true);

      final netErr = SpeechRecognitionError('error_network', false);
      ctrl.handleSpeechErrorForTesting(netErr);

      expect(ctrl.speechErrorMessage, contains('网络异常'));
      expect(ctrl.textDraft, '网络断开前的内容');
      expect(ctrl.isListening, isFalse);

      ctrl.clearSpeechError();
      expect(ctrl.speechErrorMessage, isNull);

      ctrl.dispose();
    });

    test('audio contention (error_audio_error) should show mic occupied message and preserve draft', () {
      final ctrl = VocalHomeController(autoInit: false);
      ctrl.setSessionBaseTextForTesting('录音被占用前的内容');
      ctrl.setWantsListeningForTesting(true);

      final audioErr = SpeechRecognitionError('error_audio_error', false);
      ctrl.handleSpeechErrorForTesting(audioErr);

      expect(ctrl.speechErrorMessage, contains('麦克风被其他应用占用'));
      expect(ctrl.textDraft, '录音被占用前的内容');
      expect(ctrl.isListening, isFalse);

      ctrl.dispose();
    });

    test('speech unavailable state gracefully blocks listening and provides clear prompt', () async {
      final ctrl = VocalHomeController(autoInit: false);
      ctrl.setSpeechAvailableForTesting(false, errorMessage: '未检测到系统语音识别服务');
      expect(ctrl.isSpeechAvailable, isFalse);
      expect(ctrl.speechErrorMessage, '未检测到系统语音识别服务');

      // Draft typing is unaffected
      ctrl.updateText('手写文字不受影响');
      expect(ctrl.textDraft, '手写文字不受影响');

      ctrl.dispose();
    });
  });

  group('VocalHomeController App Lifecycle Tests', () {
    test('backgrounding app (paused/inactive/hidden) must stop listening to release mic and keep draft', () {
      final ctrl = VocalHomeController(autoInit: false);
      ctrl.setSessionBaseTextForTesting('录制中切换到微信');
      ctrl.setWantsListeningForTesting(true);
      expect(ctrl.isListening, isTrue);

      // App backgrounded
      ctrl.handleAppLifecycleState(AppLifecycleState.paused);

      // Microphone MUST be safely released
      expect(ctrl.isListening, isFalse);
      // Draft MUST be completely preserved
      expect(ctrl.textDraft, '录制中切换到微信');

      ctrl.dispose();
    });

    test('resuming app (resumed) should auto-trigger service discovery when disconnected', () {
      final ctrl = VocalHomeController(autoInit: false, enableAutoReconnect: true);
      expect(ctrl.isConnected, isFalse);
      expect(ctrl.connectionState, VocalConnectionState.disconnected);

      // App resumed back from background
      ctrl.handleAppLifecycleState(AppLifecycleState.resumed);

      // Should automatically transition to searching
      expect(ctrl.connectionState, VocalConnectionState.searching);

      ctrl.dispose();
    });
  });

  group('VocalHomeController History Management Tests', () {
    test('setHistoryForTesting should populate historyList and notify listeners', () {
      final ctrl = VocalHomeController(autoInit: false);
      var notified = false;
      ctrl.addListener(() => notified = true);

      ctrl.setHistoryForTesting(['记录 1', '记录 2', '记录 3']);
      expect(notified, isTrue);
      expect(ctrl.historyList, equals(['记录 1', '记录 2', '记录 3']));
      ctrl.dispose();
    });

    test('sendCurrentDraft should accumulate multiple history items in LIFO order', () {
      final ctrl = VocalHomeController(autoInit: false);
      ctrl.setConnectedForTesting(true);

      // 1. Send first message
      ctrl.updateText('First Message');
      expect(ctrl.sendCurrentDraft(), isTrue);
      expect(ctrl.historyList, equals(['First Message']));

      // 2. Send second message
      ctrl.updateText('Second Message');
      expect(ctrl.sendCurrentDraft(), isTrue);
      expect(ctrl.historyList, equals(['Second Message', 'First Message']));

      // 3. Send third message
      ctrl.updateText('Third Message');
      expect(ctrl.sendCurrentDraft(), isTrue);
      expect(ctrl.historyList, equals(['Third Message', 'Second Message', 'First Message']));

      ctrl.dispose();
    });

    test('sending existing text should move it to top (LRU deduplication)', () {
      final ctrl = VocalHomeController(autoInit: false);
      ctrl.setConnectedForTesting(true);
      ctrl.setHistoryForTesting(['Item A', 'Item B', 'Item C']);

      // Send Item C again -> it should be moved to top
      ctrl.updateText('Item C');
      expect(ctrl.sendCurrentDraft(), isTrue);

      expect(ctrl.historyList.length, 3);
      expect(ctrl.historyList, equals(['Item C', 'Item A', 'Item B']));

      // Send Item A again -> moved to top
      ctrl.updateText('Item A');
      expect(ctrl.sendCurrentDraft(), isTrue);

      expect(ctrl.historyList.length, 3);
      expect(ctrl.historyList, equals(['Item A', 'Item C', 'Item B']));

      ctrl.dispose();
    });

    test('history list should enforce maximum capacity of 50 items and drop oldest', () {
      final ctrl = VocalHomeController(autoInit: false);
      ctrl.setConnectedForTesting(true);

      // Populate with 50 items: "Item 0" .. "Item 49"
      final initialHistory = List.generate(50, (i) => 'Item $i');
      ctrl.setHistoryForTesting(initialHistory);
      expect(ctrl.historyList.length, 50);
      expect(ctrl.historyList.first, 'Item 0');
      expect(ctrl.historyList.last, 'Item 49');

      // Send a new unique item
      ctrl.updateText('Brand New 51st Item');
      expect(ctrl.sendCurrentDraft(), isTrue);

      // Max capacity 50 should be strictly preserved
      expect(ctrl.historyList.length, 50);
      expect(ctrl.historyList.first, 'Brand New 51st Item');
      expect(ctrl.historyList[1], 'Item 0');
      // Oldest item ("Item 49") was dropped
      expect(ctrl.historyList.contains('Item 49'), isFalse);
      expect(ctrl.historyList.last, 'Item 48');

      ctrl.dispose();
    });

    test('clearHistory should empty the historyList and notify listeners', () {
      final ctrl = VocalHomeController(autoInit: false);
      ctrl.setHistoryForTesting(['记录 A', '记录 B']);
      expect(ctrl.historyList.length, 2);

      var notified = false;
      ctrl.addListener(() => notified = true);
      ctrl.clearHistory();

      expect(notified, isTrue);
      expect(ctrl.historyList, isEmpty);
      ctrl.dispose();
    });

    test('OCCUPIED error message transitions state to occupied, sets occupied status text, and inhibits auto-reconnect storm', () async {
      AppStrings.setLocale('zh');
      final ctrl = VocalHomeController(autoInit: false, enableAutoReconnect: true);
      expect(ctrl.connectionState, VocalConnectionState.disconnected);

      ctrl.handleIncomingMessageForTesting(
        '{"type": "error", "code": "OCCUPIED", "message": "Host is occupied by another device"}',
      );

      expect(ctrl.connectionState, VocalConnectionState.occupied);
      expect(ctrl.isOccupied, isTrue);
      expect(ctrl.isConnected, isFalse);
      expect(ctrl.statusText, AppStrings.current.occupied);
      expect(ctrl.statusText, '已被占用');

      // Resuming app should not trigger discovery when occupied
      ctrl.handleAppLifecycleState(AppLifecycleState.resumed);
      expect(ctrl.connectionState, VocalConnectionState.occupied);
      expect(ctrl.isOccupied, isTrue);

      // Explicit discoverServices call should be safely blocked to avoid infinite retry storms
      await ctrl.discoverServices();
      expect(ctrl.connectionState, VocalConnectionState.occupied);
      expect(ctrl.isOccupied, isTrue);

      // Test English locale representation
      AppStrings.setLocale('en');
      expect(AppStrings.current.occupied, 'Occupied');
      expect(AppStrings.current.deviceOccupied, 'Device is occupied by another client');

      // Manual retry restores non-occupied state
      await ctrl.retryConnection();
      expect(ctrl.isOccupied, isFalse);
      expect(ctrl.connectionState, isNot(VocalConnectionState.occupied));

      // Reset locale back to zh
      AppStrings.setLocale('zh');
      expect(AppStrings.current.occupied, '已被占用');
      expect(AppStrings.current.deviceOccupied, '设备已被其他设备占用');

      ctrl.dispose();
    });
  });

  group('VocalHomeController PIN Authentication & Pairing Tests', () {
    test('initial auth state should be unauthenticated with no required pin', () {
      final ctrl = VocalHomeController(autoInit: false);
      expect(ctrl.isPinRequired, isFalse);
      expect(ctrl.pinErrorMessage, isNull);
      expect(ctrl.authToken, isNull);
      expect(ctrl.pinRemainingAttempts, 3);
      ctrl.dispose();
    });

    test('auth_require_pin message should trigger isPinRequired flag', () {
      final ctrl = VocalHomeController(autoInit: false);
      expect(ctrl.isPinRequired, isFalse);

      var notified = false;
      ctrl.addListener(() => notified = true);

      ctrl.handleIncomingMessageForTesting('{"type": "auth_require_pin"}');

      expect(notified, isTrue);
      expect(ctrl.isPinRequired, isTrue);
      expect(ctrl.pinErrorMessage, isNull);
      ctrl.dispose();
    });

    test('auth_failed message should expose error reason and remaining attempts', () {
      final ctrl = VocalHomeController(autoInit: false);
      ctrl.handleIncomingMessageForTesting('{"type": "auth_require_pin"}');
      expect(ctrl.isPinRequired, isTrue);

      ctrl.handleIncomingMessageForTesting('{"type": "auth_failed", "reason": "PIN 码不正确", "remainingAttempts": 2}');
      expect(ctrl.isPinRequired, isTrue);
      expect(ctrl.pinErrorMessage, 'PIN 码不正确');
      expect(ctrl.pinRemainingAttempts, 2);
      ctrl.dispose();
    });

    test('auth_success message should clear pin requirement and store auth token', () {
      final ctrl = VocalHomeController(autoInit: false);
      ctrl.handleIncomingMessageForTesting('{"type": "auth_require_pin"}');
      expect(ctrl.isPinRequired, isTrue);

      ctrl.handleIncomingMessageForTesting('{"type": "auth_success", "token": "token_abc12345"}');
      expect(ctrl.isPinRequired, isFalse);
      expect(ctrl.pinErrorMessage, isNull);
      expect(ctrl.authToken, 'token_abc12345');
      ctrl.dispose();
    });

    test('cancelPinVerification should reset auth flags and trigger disconnect', () {
      final ctrl = VocalHomeController(autoInit: false);
      ctrl.handleIncomingMessageForTesting('{"type": "auth_require_pin"}');
      expect(ctrl.isPinRequired, isTrue);

      ctrl.cancelPinVerification();
      expect(ctrl.isPinRequired, isFalse);
      expect(ctrl.pinErrorMessage, isNull);
      expect(ctrl.isConnected, isFalse);
      ctrl.dispose();
    });
  });
}
