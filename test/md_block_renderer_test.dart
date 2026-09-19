import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/core/markdown/markdown.dart';
import 'package:mind_recall/theme/app_theme.dart';

void main() {
  testWidgets('标题含删除线标记时只渲染纯文本，无 lineThrough', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: MdBlockRenderer(
            block: HeadingBlock(
              id: 'h',
              level: 2,
              text: '~~测试asdasdasdasd~~',
            ),
          ),
        ),
      ),
    );

    expect(find.text('测试asdasdasdasd'), findsOneWidget);
    expect(find.textContaining('~~'), findsNothing);

    final text = tester.widget<Text>(find.text('测试asdasdasdasd'));
    expect(text.style?.decoration, isNot(TextDecoration.lineThrough));

    final richTexts = tester.widgetList<RichText>(find.byType(RichText));
    for (final rich in richTexts) {
      final root = rich.text;
      if (root is! TextSpan) {
        continue;
      }
      expect(
        _spanHasLineThrough(root),
        isFalse,
        reason: '标题不得带删除线装饰',
      );
    }
  });
}

bool _spanHasLineThrough(TextSpan span) {
  if (span.style?.decoration == TextDecoration.lineThrough) {
    return true;
  }
  final children = span.children;
  if (children == null) {
    return false;
  }
  for (final child in children) {
    if (child is TextSpan && _spanHasLineThrough(child)) {
      return true;
    }
  }
  return false;
}
