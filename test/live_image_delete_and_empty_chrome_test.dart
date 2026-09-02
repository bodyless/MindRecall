import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/core/markdown/markdown.dart';
import 'package:mind_recall/theme/app_theme.dart';

void main() {
  group('removeBlockAt', () {
    test('removes image block and activates neighbor', () {
      final ids = MdBlockIdGenerator();
      final image = ImageBlock(id: ids.next(), alt: 'pic', src: './a.png');
      final para = ParagraphBlock(id: ids.next(), text: 'hello');
      final result = removeBlockAt([image, para], index: 0, idGenerator: ids);
      expect(result.blocks, hasLength(1));
      expect(result.blocks.single, isA<ParagraphBlock>());
      expect(result.activeIndex, 0);
      expect(serializeMdBlocks(result.blocks), 'hello');
    });

    test('inserts empty paragraph when deleting the only block', () {
      final ids = MdBlockIdGenerator();
      final image = ImageBlock(id: ids.next(), alt: '', src: './solo.png');
      final result = removeBlockAt([image], index: 0, idGenerator: ids);
      expect(result.blocks, hasLength(1));
      expect(result.blocks.single, isA<ParagraphBlock>());
      expect((result.blocks.single as ParagraphBlock).text, isEmpty);
    });
  });

  group('MdBlockRenderer empty chrome', () {
    testWidgets('does not show ellipsis placeholder for empty paragraph', (
      tester,
    ) async {
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

    testWidgets('keeps bullet marker without ellipsis for empty list item', (
      tester,
    ) async {
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

    testWidgets('空段落可叠灰色 hint 且仍无省略号占位', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: MdBlockRenderer(
              block: ParagraphBlock(id: 'p1', text: ''),
              emptyBodyHint: '点击此处输入文本',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('点击此处输入文本'), findsOneWidget);
      expect(find.text('…'), findsNothing);
    });
  });

  group('MdBlockRenderer network image', () {
    testWidgets('https 图带 errorBuilder，握手失败回退为 alt', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: MdBlockRenderer(
              block: ImageBlock(
                id: 'img',
                alt: 'cover',
                src: 'https://example.invalid/x.png',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<NetworkImage>());
      expect(image.errorBuilder, isNotNull);
      final fallback = image.errorBuilder!(
        tester.element(find.byType(Image)),
        HandshakeException('Connection terminated during handshake'),
        StackTrace.empty,
      );
      expect(fallback, isA<Text>());
      expect((fallback as Text).data, 'cover');
    });

    testWidgets('无 alt 时网络图失败回退为 src', (tester) async {
      const src = 'https://example.invalid/x.png';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MdBlockRenderer(
              block: ImageBlock(id: 'img', alt: '', src: src),
            ),
          ),
        ),
      );
      await tester.pump();

      final image = tester.widget<Image>(find.byType(Image));
      final fallback = image.errorBuilder!(
        tester.element(find.byType(Image)),
        HandshakeException('Connection terminated during handshake'),
        StackTrace.empty,
      );
      expect((fallback as Text).data, src);
    });
  });
}
