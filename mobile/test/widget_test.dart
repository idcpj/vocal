import 'package:flutter_test/flutter_test.dart';
import 'package:vocal/i18n/app_strings.dart';
import 'package:vocal/main.dart';

void main() {
  testWidgets('Vocal App UI Smoke Test with Multi-language selector (Chinese & English i18n)', (WidgetTester tester) async {
    // 1. Verify Chinese UI (Default)
    AppStrings.setLocale('zh');
    await tester.pumpWidget(const VocalApp());

    expect(find.text('VOCAL'), findsOneWidget);
    expect(find.text('MANUAL'), findsOneWidget);
    expect(find.text('发送'), findsOneWidget);
    expect(find.textContaining('回车'), findsOneWidget);
    expect(find.text('轻触开始语音'), findsOneWidget);
    expect(find.text('暂无历史消息'), findsOneWidget);
    expect(find.text('中文 (普通话)'), findsOneWidget);

    // 2. Switch to English UI and verify reactive localization
    AppStrings.setLocale('en');
    await tester.pump();

    expect(find.text('VOCAL'), findsOneWidget);
    expect(find.text('MANUAL'), findsOneWidget);
    expect(find.text('Send'), findsOneWidget);
    expect(find.textContaining('Enter'), findsOneWidget);
    expect(find.text('Tap to Speak'), findsOneWidget);
    expect(find.text('No history yet'), findsOneWidget);

    // Restore to zh
    AppStrings.setLocale('zh');
  });
}
