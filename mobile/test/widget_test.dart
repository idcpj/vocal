import 'package:flutter_test/flutter_test.dart';
import 'package:vocal/main.dart';

void main() {
  testWidgets('Vocal App UI Smoke Test with Multi-language selector', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const VocalApp());

    // Verify header elements exist
    expect(find.text('VOCAL'), findsOneWidget);
    expect(find.text('MANUAL'), findsOneWidget);
    expect(find.text('发送'), findsOneWidget);
    expect(find.textContaining('回车'), findsOneWidget);
    expect(find.text('轻触开始语音'), findsOneWidget);

    // Verify language selector is rendered
    expect(find.text('中文 (普通话)'), findsOneWidget);
  });
}
