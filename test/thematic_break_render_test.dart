import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/core/markdown/markdown.dart';
import 'package:mind_recall/theme/app_theme.dart';

void main() {
  group('ThematicBreakBlock renderer', () {
    testWidgets('renders Divider and not empty-body hint', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: MdBlockRenderer(
              block: ThematicBreakBlock(id: 'hr'),
              emptyBodyHint: '点击此处输入文本',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Divider), findsOneWidget);
      expect(find.text('点击此处输入文本'), findsNothing);
      expect(find.text('…'), findsNothing);
      expect(find.text('---'), findsNothing);
    });
  });
}
