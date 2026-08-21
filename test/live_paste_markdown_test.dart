import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/core/markdown/markdown.dart';

void main() {
  group('normalizePastedMarkdown', () {
    test('converts bullet glyphs to markdown dashes', () {
      expect(
        normalizePastedMarkdown('•  one\n•  two'),
        '- one\n- two',
      );
    });
  });

  group('pasteMarkdownIntoBlocks', () {
    test('pastes multiline list into empty paragraph', () {
      final ids = MdBlockIdGenerator();
      final empty = ParagraphBlock(id: ids.next(), text: '');
      final result = pasteMarkdownIntoBlocks(
        blocks: [empty],
        activeIndex: 0,
        activeBlock: empty,
        beforePlain: '',
        afterPlain: '',
        pastedMarkdown: '- a\n- b',
        idGenerator: ids,
      );
      expect(result.blocks, hasLength(2));
      expect(result.blocks[0], isA<BulletBlock>());
      expect((result.blocks[0] as BulletBlock).text, 'a');
      expect(result.blocks[1], isA<BulletBlock>());
      expect(serializeMdBlocks(result.blocks), '- a\n- b');
    });

    test('pastes preview bullet glyphs into live blocks', () {
      final ids = MdBlockIdGenerator();
      final empty = ParagraphBlock(id: ids.next(), text: '');
      final result = pasteMarkdownIntoBlocks(
        blocks: [empty],
        activeIndex: 0,
        activeBlock: empty,
        beforePlain: '',
        afterPlain: '',
        pastedMarkdown: '•  alpha\n•  beta',
        idGenerator: ids,
      );
      expect(serializeMdBlocks(result.blocks), '- alpha\n- beta');
    });

    test('keeps prefix text and appends pasted blocks', () {
      final ids = MdBlockIdGenerator();
      final para = ParagraphBlock(id: ids.next(), text: 'hi');
      final result = pasteMarkdownIntoBlocks(
        blocks: [para],
        activeIndex: 0,
        activeBlock: para,
        beforePlain: 'hi',
        afterPlain: '',
        pastedMarkdown: '- x',
        idGenerator: ids,
      );
      expect(result.blocks.first, isA<ParagraphBlock>());
      expect((result.blocks.first as ParagraphBlock).text, 'hi');
      expect(result.blocks[1], isA<BulletBlock>());
    });

    test('pastes GFM task lines as checked bullets', () {
      final ids = MdBlockIdGenerator();
      final empty = ParagraphBlock(id: ids.next(), text: '');
      final result = pasteMarkdownIntoBlocks(
        blocks: [empty],
        activeIndex: 0,
        activeBlock: empty,
        beforePlain: '',
        afterPlain: '',
        pastedMarkdown: '- [ ] a\n- [x] b',
        idGenerator: ids,
      );
      expect(result.blocks, hasLength(2));
      expect((result.blocks[0] as BulletBlock).checked, isFalse);
      expect((result.blocks[0] as BulletBlock).text, 'a');
      expect((result.blocks[1] as BulletBlock).checked, isTrue);
      expect((result.blocks[1] as BulletBlock).text, 'b');
      expect(serializeMdBlocks(result.blocks), '- [ ] a\n- [x] b');
    });

    test('pastes thematic break as its own block', () {
      final ids = MdBlockIdGenerator();
      final empty = ParagraphBlock(id: ids.next(), text: '');
      final result = pasteMarkdownIntoBlocks(
        blocks: [empty],
        activeIndex: 0,
        activeBlock: empty,
        beforePlain: '',
        afterPlain: '',
        pastedMarkdown: 'a\n---\nb',
        idGenerator: ids,
      );
      expect(result.blocks, hasLength(3));
      expect(result.blocks[1], isA<ThematicBreakBlock>());
      expect(serializeMdBlocks(result.blocks), 'a\n---\nb');
    });
  });

  group('visualSelectionToMarkdown', () {
    test('maps bullet glyphs to dashes', () {
      expect(
        visualSelectionToMarkdown('•  a\n•  b'),
        '- a\n- b',
      );
    });

    test('maps task glyphs to GFM checkboxes', () {
      expect(
        visualSelectionToMarkdown(
          '${MdBlockChrome.taskUncheckedPrefix}a\n${MdBlockChrome.taskCheckedPrefix}b',
        ),
        '- [ ] a\n- [x] b',
      );
    });
  });
}
