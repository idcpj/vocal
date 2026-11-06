import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:vocal/page/vocal_home_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VocalHomeController Manual Send & Draft Tests', () {
    test('initial draft should be empty', () {
      final ctrl = VocalHomeController(autoInit: false);
      expect(ctrl.textDraft, isEmpty);
      expect(ctrl.historyList, isEmpty);
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
  });
}
