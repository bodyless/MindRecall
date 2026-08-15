import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/features/memo/editor/live/live_markdown_editor.dart';
import 'package:mind_recall/l10n/app_localizations.dart';
import 'package:mind_recall/theme/app_theme.dart';

void main() {
  testWidgets('空正文显示灰色提示，点空白区聚焦输入', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final controller = TextEditingController(text: '');
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

    expect(find.text('点击此处输入文本'), findsOneWidget);
    expect(focus.hasFocus, isFalse);

    await tester.tap(find.byKey(LiveMarkdownEditor.emptyBodyFillKey));
    await tester.pump();
    expect(focus.hasFocus, isTrue);
  });

  testWidgets('已有正文时不显示空文档提示', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final controller = TextEditingController(text: 'hello');
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

    expect(find.text('点击此处输入文本'), findsNothing);
    expect(find.byKey(LiveMarkdownEditor.emptyBodyFillKey), findsNothing);
  });
}
