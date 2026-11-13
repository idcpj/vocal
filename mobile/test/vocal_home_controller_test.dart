import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
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
}
