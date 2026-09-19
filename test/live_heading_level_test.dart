import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/core/markdown/renderer/md_block_renderer.dart';
import 'package:mind_recall/core/markdown/renderer/md_block_styles.dart';
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
            height: 400,
            child: LiveMarkdownEditor(
              key: editorKey,
              controller: controller,
              focusNode: focus,
              scrollController: scroll,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder slotHeadingText(String text) {
    return find.descendant(
      of: find.byType(MdBlockRenderer),
      matching: find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == text,
      ),
    );
  }

  /// 列表槽 [MdBlockRenderer] 上标题纯文本的样式（Overlay TextField 不含 Text）。
  TextStyle? slotHeadingStyle(WidgetTester tester, String text) {
    return tester.widget<Text>(slotHeadingText(text)).style;
  }

  /// `_stabilizeInputFocus` 会挂 800ms 过渡标志，收尾须泵掉以免 pending Timer。
  Future<void> drainStabilizeTimers(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 850));
  }

  testWidgets('H1 切 H2 后一帧列表即用 H2 字号', (tester) async {
    final editorKey = GlobalKey<LiveMarkdownEditorState>();
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final controller = TextEditingController(text: '# 标题');
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

    final theme = Theme.of(tester.element(find.byType(LiveMarkdownEditor)));
    final h1Size = MdBlockStyles.headingStyle(theme, 1)?.fontSize;
    final h2Size = MdBlockStyles.headingStyle(theme, 2)?.fontSize;
    expect(h1Size, isNotNull);
    expect(h2Size, isNotNull);
    expect(h1Size, isNot(h2Size));
    expect(slotHeadingStyle(tester, '标题')?.fontSize, h1Size);

    editorKey.currentState!.applyHeading(2);
    await tester.pump();

    expect(slotHeadingStyle(tester, '标题')?.fontSize, h2Size);
    expect(controller.text.trim(), '## 标题');
    await drainStabilizeTimers(tester);
  });

  testWidgets('H1 切正文后一帧变为正文字号', (tester) async {
    final editorKey = GlobalKey<LiveMarkdownEditorState>();
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final controller = TextEditingController(text: '# 标题');
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

    editorKey.currentState!.applyParagraph();
    await tester.pump();

    expect(controller.text.trim(), '标题');
    expect(find.byType(MdBlockRenderer), findsOneWidget);
    expect(slotHeadingText('标题'), findsNothing);
    await drainStabilizeTimers(tester);
  });

  testWidgets('同级再点 H2 保持焦点且字号不变', (tester) async {
    final editorKey = GlobalKey<LiveMarkdownEditorState>();
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final controller = TextEditingController(text: '## 标题');
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
    expect(focus.hasFocus, isTrue);

    final theme = Theme.of(tester.element(find.byType(LiveMarkdownEditor)));
    final h2Size = MdBlockStyles.headingStyle(theme, 2)?.fontSize;
    editorKey.currentState!.applyHeading(2);
    await tester.pump();

    expect(focus.hasFocus, isTrue);
    expect(slotHeadingStyle(tester, '标题')?.fontSize, h2Size);
    expect(controller.text.trim(), '## 标题');
    await drainStabilizeTimers(tester);
  });
}
