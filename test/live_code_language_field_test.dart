import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/features/memo/editor/live/live_markdown_editor.dart';
import 'package:mind_recall/l10n/app_localizations.dart';
import 'package:mind_recall/theme/app_theme.dart';

void main() {
  Future<void> pumpLiveEditor({
    required WidgetTester tester,
    required GlobalKey<LiveMarkdownEditorState> editorKey,
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
              key: editorKey,
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

  testWidgets('聚焦后点语言标识 python 能把光标放进语言框', (tester) async {
    final editorKey = GlobalKey<LiveMarkdownEditorState>();
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final controller = TextEditingController(text: '```python\nprint(1)\n```');
    addTearDown(controller.dispose);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);

    await pumpLiveEditor(
      tester: tester,
      editorKey: editorKey,
      focus: focus,
      controller: controller,
      scroll: scroll,
    );

    focus.requestFocus();
    await tester.pump();
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    expect(find.byKey(LiveMarkdownEditor.codeLanguageFieldKey), findsOneWidget);
    expect(find.text('python'), findsOneWidget);

    await tester.tap(find.text('python'));
    await tester.pump();
    await tester.pump();

    expect(editorKey.currentState!.isCodeLanguageFieldFocused, isTrue);
  });

  testWidgets('点语言文字后列表不会跳到文档顶部', (tester) async {
    final editorKey = GlobalKey<LiveMarkdownEditorState>();
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final controller = TextEditingController(text: '```python\nprint(1)\n```');
    addTearDown(controller.dispose);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    final keyboardInset = ValueNotifier<double>(180);
    addTearDown(keyboardInset.dispose);

    await pumpLiveEditor(
      tester: tester,
      editorKey: editorKey,
      focus: focus,
      controller: controller,
      scroll: scroll,
      keyboardInset: keyboardInset,
      height: 280,
    );

    focus.requestFocus();
    await tester.pump();
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    expect(find.byKey(LiveMarkdownEditor.codeLanguageFieldKey), findsOneWidget);
    expect(scroll.hasClients, isTrue);
    expect(scroll.position.maxScrollExtent, greaterThan(0));

    // 只挪几个像素，保证语言框仍在视口内，同时 offset > 0 才能发现跳顶。
    final target = scroll.position.maxScrollExtent < 8
        ? scroll.position.maxScrollExtent
        : 8.0;
    scroll.jumpTo(target);
    await tester.pump();
    expect(scroll.offset, greaterThan(0));
    final offsetBefore = scroll.offset;

    await tester.tap(find.text('python'));
    await tester.pump();
    await tester.pump();

    expect(editorKey.currentState!.isCodeLanguageFieldFocused, isTrue);
    expect(scroll.offset, greaterThan(0));
    expect((scroll.offset - offsetBefore).abs(), lessThan(80));
  });
}
