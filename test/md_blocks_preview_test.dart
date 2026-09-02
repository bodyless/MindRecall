import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/core/markdown/markdown.dart';
import 'package:mind_recall/theme/app_theme.dart';

void main() {
  TextSpan? findSpanWithStyle(
    TextSpan span,
    bool Function(TextStyle? style) match,
  ) {
    if (match(span.style)) {
      return span;
    }
    for (final child in span.children ?? const <InlineSpan>[]) {
      if (child is TextSpan) {
        final found = findSpanWithStyle(child, match);
        if (found != null) {
          return found;
        }
      }
    }
    return null;
  }

  bool treeHasBold(TextSpan root) {
    return findSpanWithStyle(
          root,
          (style) =>
              style?.fontWeight == FontWeight.bold ||
              style?.fontWeight == FontWeight.w700 ||
              style?.fontWeight == FontWeight.w800 ||
              style?.fontWeight == FontWeight.w900,
        ) !=
        null;
  }

  group('MdBlocksPreview', () {
    testWidgets('renders bold in paragraph preview', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: MdBlocksPreview(markdown: 'Hello **world**'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final richTexts = tester.widgetList<RichText>(find.byType(RichText));
      expect(richTexts, isNotEmpty);
      expect(
        richTexts.any((richText) => treeHasBold(richText.text as TextSpan)),
        isTrue,
      );
    });

    testWidgets('default padding matches live body insets', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MdBlocksPreview(markdown: 'hi', selectable: false),
          ),
        ),
      );

      final preview = tester.widget<MdBlocksPreview>(
        find.byType(MdBlocksPreview),
      );
      expect(preview.padding.top, MdBlockStyles.editorBodyTopPadding);
      expect(preview.padding.left, MdBlockStyles.editorBodyHorizontalPadding);
      expect(preview.padding.right, MdBlockStyles.editorBodyHorizontalPadding);
    });

    testWidgets('renders bold in Chinese paragraph preview', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: MdBlocksPreview(markdown: '这是**粗体**测试')),
        ),
      );
      await tester.pumpAndSettle();

      final richTexts = tester.widgetList<RichText>(find.byType(RichText));
      expect(
        richTexts.any((richText) => treeHasBold(richText.text as TextSpan)),
        isTrue,
      );
    });
  });
}
