import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/core/markdown/markdown.dart';
import 'package:mind_recall/theme/app_theme.dart';

void main() {
  group('removeBlockAt', () {
    test('removes image block and activates neighbor', () {
      final ids = MdBlockIdGenerator();
      final image = ImageBlock(
        id: ids.next(),
        alt: 'pic',
        src: './a.png',
      );
      final para = ParagraphBlock(id: ids.next(), text: 'hello');
      final result = removeBlockAt(
        [image, para],
        index: 0,
        idGenerator: ids,
      );
      expect(result.blocks, hasLength(1));
      expect(result.blocks.single, isA<ParagraphBlock>());
      expect(result.activeIndex, 0);
      expect(serializeMdBlocks(result.blocks), 'hello');
    });

    test('inserts empty paragraph when deleting the only block', () {
      final ids = MdBlockIdGenerator();
      final image = ImageBlock(
        id: ids.next(),
        alt: '',
        src: './solo.png',
      );
      final result = removeBlockAt(
        [image],
        index: 0,
        idGenerator: ids,
      );
      expect(result.blocks, hasLength(1));
      expect(result.blocks.single, isA<ParagraphBlock>());
      expect((result.blocks.single as ParagraphBlock).text, isEmpty);
    });
  });

  group('MdBlockRenderer empty chrome', () {
    testWidgets('does not show ellipsis placeholder for empty paragraph',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: MdBlockRenderer(
              block: ParagraphBlock(id: 'p1', text: ''),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('…'), findsNothing);
      expect(find.textContaining('…'), findsNothing);
    });

    testWidgets('keeps bullet marker without ellipsis for empty list item',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: MdBlockRenderer(
              block: BulletBlock(id: 'b1', text: ''),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('•'), findsOneWidget);
      expect(find.text('…'), findsNothing);
    });
  });
}
