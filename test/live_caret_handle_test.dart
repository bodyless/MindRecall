import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/core/markdown/markdown.dart';
import 'package:mind_recall/features/memo/editor/live/live_markdown_editor.dart';
import 'package:mind_recall/l10n/app_localizations.dart';
import 'package:mind_recall/theme/app_theme.dart';

void main() {
  testWidgets('chromeless 关掉系统折叠手柄，改由渲染层自绘水滴', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) {
            final collapsed = chromelessTextSelectionControls.buildHandle(
              context,
              TextSelectionHandleType.collapsed,
              16,
            );
            final expanded = chromelessTextSelectionControls.buildHandle(
              context,
              TextSelectionHandleType.right,
              16,
            );
            return Column(
              children: [
                KeyedSubtree(
                  key: const ValueKey<String>('collapsed-handle'),
                  child: collapsed,
                ),
                KeyedSubtree(
                  key: const ValueKey<String>('expanded-handle'),
                  child: expanded,
                ),
              ],
            );
          },
        ),
      ),
    );

    final collapsedBox = tester.widget<SizedBox>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('collapsed-handle')),
        matching: find.byType(SizedBox),
      ),
    );
    expect(collapsedBox.width, 0);
    expect(collapsedBox.height, 0);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('expanded-handle')),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
  });

  testWidgets('同一列表块软换行后会检查上浮', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final controller = TextEditingController(text: '- short');
    addTearDown(controller.dispose);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    final keyboardInset = ValueNotifier<double>(180);
    addTearDown(keyboardInset.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 320,
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

    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isTrue);

    final offsetBefore = scroll.offset;
    await tester.enterText(find.byType(TextField), '${'word ' * 48}end');
    await tester.pump();
    await tester.pump();

    expect(scroll.offset, greaterThan(offsetBefore));
  });

  testWidgets('聚焦列表块时渲染层水滴仍在光标下方', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final controller = TextEditingController(text: '- short');
    addTearDown(controller.dispose);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);

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
              controller: controller,
              focusNode: focus,
              scrollController: scroll,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(focus.hasFocus, isTrue);

    expect(
      find.byKey(LiveMarkdownEditor.collapsedCaretHandleKey),
      findsOneWidget,
    );
  });

  testWidgets('打字后隐藏水滴，再点选显示', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final controller = TextEditingController(text: '- short');
    addTearDown(controller.dispose);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);

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
              controller: controller,
              focusNode: focus,
              scrollController: scroll,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(
      find.byKey(LiveMarkdownEditor.collapsedCaretHandleKey),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), 'short typed');
    await tester.pump();
    await tester.pump();
    expect(
      find.byKey(LiveMarkdownEditor.collapsedCaretHandleKey),
      findsNothing,
    );

    // 与首次 tap 隔开，避免被识别成双击选词（折叠水滴只在 collapsed 时绘制）。
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(
      find.byKey(LiveMarkdownEditor.collapsedCaretHandleKey),
      findsOneWidget,
    );
  });

  test('编辑模式折叠锚点相对系统左缘右移半个光标宽', () {
    final material = MaterialTextSelectionControls();
    final aligned = AlignedCollapsedHandleControls();
    const lineHeight = 16.0;
    expect(
      aligned.getHandleAnchor(TextSelectionHandleType.collapsed, lineHeight),
      alignedCollapsedHandleAnchor(
        material.getHandleAnchor(TextSelectionHandleType.collapsed, lineHeight),
      ),
    );
  });
}
