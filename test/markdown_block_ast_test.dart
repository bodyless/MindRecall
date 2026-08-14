import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/core/markdown/markdown.dart';

void main() {
  group('parseMarkdownBlocks', () {
    test('parses heading and paragraph', () {
      const text = '# Title\n\nHello **world**';
      final blocks = parseMarkdownBlocks(text);

      expect(blocks.length, 2);
      expect(blocks[0], isA<HeadingBlock>());
      expect((blocks[0] as HeadingBlock).text, 'Title');
      expect(blocks[1], isA<ParagraphBlock>());
      expect((blocks[1] as ParagraphBlock).text, 'Hello **world**');
    });

    test('round-trips block content (blank lines between blocks are normalized)', () {
      const text = '# Title\n\nBody line';
      final blocks = parseMarkdownBlocks(text);
      expect(serializeMdBlocks(blocks), '# Title\nBody line');

      final reparsed = parseMarkdownBlocks(serializeMdBlocks(blocks));
      expect(reparsed.length, blocks.length);
      expect(reparsed[0], isA<HeadingBlock>());
      expect((reparsed[0] as HeadingBlock).text, 'Title');
      expect((reparsed[1] as ParagraphBlock).text, 'Body line');
    });
  });

  group('MdBlock transforms', () {
    test('asHeading only changes node type and level', () {
      const block = ParagraphBlock(id: 'b1', text: 'Hello');
      final heading = block.asHeading(2) as HeadingBlock;

      expect(heading.level, 2);
      expect(heading.text, 'Hello');
      expect(heading.toMarkdown(), '## Hello');
    });

    test('applyBlockTrigger converts typed prefix', () {
      const block = ParagraphBlock(id: 'b1', text: '');
      final triggered = applyBlockTrigger(block, '# TEST');

      expect(triggered, isA<HeadingBlock>());
      expect((triggered as HeadingBlock).text, 'TEST');
    });
  });
}
