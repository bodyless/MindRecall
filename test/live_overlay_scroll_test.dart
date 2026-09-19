import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/features/memo/editor/live/live_markdown_editor.dart';
import 'package:mind_recall/l10n/app_localizations.dart';
import 'package:mind_recall/theme/app_theme.dart';

void main() {
  Future<void> pumpLiveEditor({
    required WidgetTester tester,
    required FocusNode focus,
    required TextEditingController controller,
    required ScrollController scroll,
    ValueNotifier<double>? keyboardInset,
    double height = 400,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: height,
            child: LiveMarkdownEditor(
              controller: controller,
              focusNode: focus,
              scrollController: scroll,
              keyboardBottomInset: keyboardInset,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    '聚焦且模拟 IME 时，在 Overlay 上垂直拖会滚列表且保持焦点',
    (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      final body = List.generate(
        80,
        (i) => 'Line $i of a long paragraph that fills the viewport.',
      ).join(' ');
      final controller = TextEditingController(text: body);
      addTearDown(controller.dispose);
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      final keyboardInset = ValueNotifier<double>(180);
      addTearDown(keyboardInset.dispose);

      await pumpLiveEditor(
        tester: tester,
        focus: focus,
        controller: controller,
        scroll: scroll,
        keyboardInset: keyboardInset,
        height: 240,
      );

      focus.requestFocus();
      await tester.pump();
      await tester.pump();
      expect(focus.hasFocus, isTrue);
      expect(scroll.hasClients, isTrue);
      expect(scroll.position.maxScrollExtent, greaterThan(0));

      final offsetBefore = scroll.offset;
      await tester.drag(
        find.byKey(LiveMarkdownEditor.overlayListScrollKey),
        const Offset(0, -160),
      );
      await tester.pumpAndSettle();

      expect(scroll.offset, greaterThan(offsetBefore));
      expect(focus.hasFocus, isTrue);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    '聚焦 Overlay 单击一次即按落点设光标',
    (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      const body = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
      final controller = TextEditingController(text: body);
      addTearDown(controller.dispose);
      final scroll = ScrollController();
      addTearDown(scroll.dispose);

      await pumpLiveEditor(
        tester: tester,
        focus: focus,
        controller: controller,
        scroll: scroll,
      );

      focus.requestFocus();
      await tester.pump();
      await tester.pump();
      expect(focus.hasFocus, isTrue);

      final field = find.byType(TextField);
      expect(field, findsOneWidget);
      final editing = tester.widget<TextField>(field).controller!;
      final end = editing.text.length;

      final topLeft = tester.getTopLeft(field);
      await tester.tapAt(topLeft + const Offset(10, 8));
      await tester.pump();
      await tester.pump();

      expect(focus.hasFocus, isTrue);
      expect(editing.selection.isValid, isTrue);
      expect(editing.selection.isCollapsed, isTrue);
      expect(editing.selection.baseOffset, lessThan(end));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
