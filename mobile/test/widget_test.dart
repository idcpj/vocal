import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocal/i18n/app_strings.dart';
import 'package:vocal/main.dart';
import 'package:vocal/page/vocal_home_controller.dart';
import 'package:vocal/page/vocal_home_screen.dart';

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

  testWidgets('History section renders multiple items scrollable with RawScrollbar', (WidgetTester tester) async {
    final ctrl = VocalHomeController(autoInit: false, enableAutoReconnect: false);
    final testHistory = List.generate(10, (i) => '历史记录测试长文本项目第 $i 条');
    ctrl.setHistoryForTesting(testHistory);

    await tester.pumpWidget(
      MaterialApp(
        home: VocalHomeScreen(controller: ctrl),
      ),
    );
    await tester.pump();

    // Verify history count badge is displayed
    expect(find.text('10'), findsOneWidget);

    // Verify RawScrollbar is present
    expect(find.byType(RawScrollbar), findsOneWidget);

    // Verify initial visible history items
    expect(find.text('历史记录测试长文本项目第 0 条'), findsOneWidget);

    // Scroll the history list downwards
    final listViewFinder = find.byType(ListView);
    expect(listViewFinder, findsOneWidget);
    await tester.drag(listViewFinder, const Offset(0, -300));
    await tester.pump();

    // Verify scrolled items can be found
    expect(find.text('历史记录测试长文本项目第 9 条'), findsOneWidget);

    ctrl.dispose();
  });

  testWidgets('Tapping history item fills text draft into editor and positions cursor at end', (WidgetTester tester) async {
    final ctrl = VocalHomeController(autoInit: false, enableAutoReconnect: false);
    ctrl.setHistoryForTesting(['这是一条待回填的历史语句']);

    await tester.pumpWidget(
      MaterialApp(
        home: VocalHomeScreen(controller: ctrl),
      ),
    );
    await tester.pump();

    // Initially editor is empty
    expect(ctrl.textDraft, isEmpty);
    expect(find.text('这是一条待回填的历史语句'), findsOneWidget);

    // Tap history item
    await tester.tap(find.text('这是一条待回填的历史语句'));
    await tester.pump();

    // Draft in controller and TextField is updated
    expect(ctrl.textDraft, '这是一条待回填的历史语句');
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller?.text, '这是一条待回填的历史语句');

    ctrl.dispose();
  });

  testWidgets('Clicking send while focused clears text draft but keeps focus active for continuous typing', (WidgetTester tester) async {
    final ctrl = VocalHomeController(autoInit: false, enableAutoReconnect: false);
    ctrl.setConnectedForTesting(true);

    await tester.pumpWidget(
      MaterialApp(
        home: VocalHomeScreen(controller: ctrl),
      ),
    );
    await tester.pump();

    // Tap TextField to focus it
    await tester.tap(find.byType(TextField));
    await tester.pump();

    // Check focus
    final editableText = tester.firstState<EditableTextState>(find.byType(EditableText));
    expect(editableText.widget.focusNode.hasFocus, isTrue);

    // Enter text
    await tester.enterText(find.byType(TextField), '第一句连续打字内容');
    await tester.pump();
    expect(ctrl.textDraft, '第一句连续打字内容');

    // Tap Send button
    await tester.tap(find.text('发送'));
    await tester.pump();

    // Draft is sent and cleared
    expect(ctrl.textDraft, isEmpty);
    expect(ctrl.historyList.first, '第一句连续打字内容');

    // Focus MUST still be retained on the TextField!
    expect(editableText.widget.focusNode.hasFocus, isTrue);

    // Enter second sentence seamlessly without tapping TextField again
    await tester.enterText(find.byType(TextField), '第二句继续打字内容');
    await tester.pump();
    expect(ctrl.textDraft, '第二句继续打字内容');

    await tester.tap(find.text('发送'));
    await tester.pump();

    expect(ctrl.textDraft, isEmpty);
    expect(ctrl.historyList, equals(['第二句继续打字内容', '第一句连续打字内容']));
    expect(editableText.widget.focusNode.hasFocus, isTrue);

    ctrl.dispose();
  });

  testWidgets('Tapping dismiss keyboard button unfocuses TextField', (WidgetTester tester) async {
    final ctrl = VocalHomeController(autoInit: false, enableAutoReconnect: false);
    ctrl.setConnectedForTesting(true);

    // Set a non-zero bottom view inset to simulate keyboard appearance
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(viewInsets: EdgeInsets.only(bottom: 300)),
        child: MaterialApp(
          home: VocalHomeScreen(controller: ctrl),
        ),
      ),
    );
    await tester.pump();

    // Focus TextField
    await tester.tap(find.byType(TextField));
    await tester.pump();

    final editableText = tester.firstState<EditableTextState>(find.byType(EditableText));
    expect(editableText.widget.focusNode.hasFocus, isTrue);

    // When keyboard is open (viewInsets.bottom > 0), dismiss keyboard button is shown
    expect(find.text('收起键盘'), findsOneWidget);

    // Tap dismiss keyboard button
    await tester.tap(find.text('收起键盘'));
    await tester.pump();

    // Focus should now be removed
    expect(editableText.widget.focusNode.hasFocus, isFalse);

    ctrl.dispose();
  });

  testWidgets('Occupied banner displays amber badge and retry connection button when state is occupied', (WidgetTester tester) async {
    final ctrl = VocalHomeController(autoInit: false, enableAutoReconnect: false);
    ctrl.setOccupiedForTesting(occupied: true);

    await tester.pumpWidget(
      MaterialApp(
        home: VocalHomeScreen(controller: ctrl),
      ),
    );
    await tester.pump();

    // Verify occupied badge in header
    expect(find.text('已被占用'), findsOneWidget);

    // Verify banner content matches vocal.pen design
    expect(find.text('当前 Mac 已被其他设备占用'), findsOneWidget);
    expect(find.text('防止双端冲突，已进入保护态'), findsOneWidget);
    expect(find.text('重试连接'), findsOneWidget);

    // Tap retry connection button
    await tester.tap(find.text('重试连接'));
    await tester.pump();

    // Occupied state reset and resumes searching
    expect(ctrl.isOccupied, isFalse);
    expect(ctrl.connectionState, VocalConnectionState.searching);

    ctrl.dispose();
  });

  testWidgets('PIN pairing overlay displays 4-digit input, subtitle, and action buttons when auth_require_pin arrives', (WidgetTester tester) async {
    final ctrl = VocalHomeController(autoInit: false, enableAutoReconnect: false);

    await tester.pumpWidget(
      MaterialApp(
        home: VocalHomeScreen(controller: ctrl),
      ),
    );
    await tester.pump();

    // Initially PIN overlay is hidden
    expect(find.text('设备安全配对'), findsNothing);

    // Host triggers auth_require_pin
    ctrl.handleIncomingMessageForTesting('{"type": "auth_require_pin"}');
    await tester.pump();

    // PIN overlay is visible
    expect(find.text('设备安全配对'), findsOneWidget);
    expect(find.text('请输入 Mac 菜单栏显示的 4 位 PIN 码'), findsOneWidget);
    expect(find.text('确认配对'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);

    // Tap cancel button
    await tester.tap(find.text('取消'));
    await tester.pump();

    // Overlay is dismissed
    expect(find.text('设备安全配对'), findsNothing);
    expect(ctrl.isPinRequired, isFalse);

    ctrl.dispose();
  });
}
