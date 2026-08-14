import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/core/markdown/markdown.dart';
import 'package:mind_recall/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MdBlocksPreview selection', () {
    testWidgets('selection mirror uses bullet glyph matching renderer',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: MdBlocksPreview(
              markdown: '- alpha\n- beta',
            ),
          ),
        ),
      );
      await tester.pump();

      // 渲染层与选区镜像都应是 •，而非数据层 `-`
      expect(find.textContaining('•'), findsWidgets);
      expect(find.textContaining('- alpha'), findsNothing);
    });

    testWidgets('heading selection mirror has no hash prefix', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: MdBlocksPreview(markdown: '## Title'),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('## Title'), findsNothing);
      expect(find.text('Title'), findsWidgets);
    });
  });
}
