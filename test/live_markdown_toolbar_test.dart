import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/features/memo/editor/widgets/markdown_toolbar.dart';
import 'package:mind_recall/l10n/app_localizations.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }

  LiveMarkdownToolbar toolbar({
    required FocusNode focusNode,
    VoidCallback? onPrepareToolbarAction,
    VoidCallback? onParagraph,
    VoidCallback? onBold,
  }) {
    return LiveMarkdownToolbar(
      focusNode: focusNode,
      onPrepareToolbarAction: onPrepareToolbarAction,
      onHeading: (_) {},
      onBulletList: () {},
      onOrderedList: () {},
      onTaskList: () {},
      onQuote: () {},
      onInsertThematicBreak: () {},
      onParagraph: onParagraph ?? () {},
      onBold: onBold ?? () {},
    );
  }

  testWidgets('正文按钮在 H3 之后、粗体之前', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);

    await tester.pumpWidget(wrap(toolbar(focusNode: focus)));
    await tester.pumpAndSettle();

    final h3 = tester.getTopLeft(find.text('H3'));
    final paragraph = tester.getTopLeft(find.byIcon(Icons.notes));
    final bold = tester.getTopLeft(find.byIcon(Icons.format_bold));
    expect(h3.dx < paragraph.dx, isTrue);
    expect(paragraph.dx < bold.dx, isTrue);
  });

  testWidgets('点正文走 onPrepareToolbarAction 与 onParagraph', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    var prepared = 0;
    var paragraph = 0;

    await tester.pumpWidget(
      wrap(
        toolbar(
          focusNode: focus,
          onPrepareToolbarAction: () => prepared++,
          onParagraph: () => paragraph++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.notes));
    await tester.pump();

    expect(prepared, greaterThan(0));
    expect(paragraph, 1);
  });
}
