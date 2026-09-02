import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/core/markdown/markdown.dart';

void main() {
  group('expandMultilineParagraphsForLive', () {
    test('splits a multi-line paragraph into one block per line', () {
      final ids = MdBlockIdGenerator();
      final blocks = expandMultilineParagraphsForLive([
        ParagraphBlock(id: 'p1', text: 'line1\nline2\nline3'),
      ], ids);

      expect(blocks.length, 3);
      expect(blocks[0], isA<ParagraphBlock>());
      expect((blocks[0] as ParagraphBlock).text, 'line1');
      expect((blocks[1] as ParagraphBlock).text, 'line2');
      expect((blocks[2] as ParagraphBlock).text, 'line3');
      expect((blocks[0] as ParagraphBlock).continuesWithNext, isTrue);
      expect((blocks[1] as ParagraphBlock).continuesWithNext, isTrue);
      expect((blocks[2] as ParagraphBlock).continuesWithNext, isFalse);
      expect(blocks[0].id, 'p1');
    });

    test('preserves headings and code blocks', () {
      final ids = MdBlockIdGenerator();
      final blocks = expandMultilineParagraphsForLive([
        HeadingBlock(id: 'h1', level: 2, text: 'Title'),
        CodeBlock(id: 'c1', code: 'a\nb'),
      ], ids);

      expect(blocks.length, 2);
      expect(blocks[0], isA<HeadingBlock>());
      expect(blocks[1], isA<CodeBlock>());
    });
  });

  group('splitMultilineParagraphAtPlainOffset', () {
    test('selects the line under the cursor for block transforms', () {
      final ids = MdBlockIdGenerator();
      const block = ParagraphBlock(id: 'p1', text: 'one\ntwo\nthree');
      final split = splitMultilineParagraphAtPlainOffset(
        block: block,
        plainOffset: 'one\n'.length + 1,
        idGenerator: ids,
      );

      expect(split.blocks.length, 3);
      expect(split.activeLineIndex, 1);
      expect(split.blocks[1].text, 'two');
    });
  });

  group('parseMarkdownBlocks + expand for live', () {
    test('consecutive bullet lines parse as separate blocks', () {
      const markdown = '# 过函谷关\n- 是的就不行\n- 继续继续家';
      final blocks = parseMarkdownBlocks(markdown);
      expect(blocks.length, 3);
      expect(blocks[0], isA<HeadingBlock>());
      expect(blocks[1], isA<BulletBlock>());
      expect((blocks[1] as BulletBlock).text, '是的就不行');
      expect(blocks[2], isA<BulletBlock>());
      expect((blocks[2] as BulletBlock).text, '继续继续家');
    });

    test('five plain lines become five editable blocks', () {
      const markdown = 'line1\nline2\nline3\nline4\nline5';
      final ids = MdBlockIdGenerator();
      final blocks = expandMultilineParagraphsForLive(
        parseMarkdownBlocks(markdown),
        ids,
      );

      expect(blocks.length, 5);
      expect((blocks[1] as ParagraphBlock).text, 'line2');
    });
  });

  group('live_line_markdown', () {
    test('applyBulletLineMarkdown prepends bullet prefix', () {
      expect(applyBulletLineMarkdown('hello'), '- hello');
      expect(applyBulletLineMarkdown('# Title'), '- Title');
      expect(applyBulletLineMarkdown('- old'), '- old');
      expect(applyBulletLineMarkdown('- [ ] task'), '- task');
    });

    test('applyTaskLineMarkdown prepends unchecked task prefix', () {
      expect(applyTaskLineMarkdown('hello'), '- [ ] hello');
      expect(applyTaskLineMarkdown('# Title'), '- [ ] Title');
      expect(applyTaskLineMarkdown('- old'), '- [ ] old');
      expect(applyTaskLineMarkdown('- [x] done'), '- [ ] done');
    });

    test('stripBlockLinePrefix 去掉勾选标记', () {
      expect(stripBlockLinePrefix('- [ ] buy'), 'buy');
      expect(stripBlockLinePrefix('- [x] done'), 'done');
      expect(stripBlockLinePrefix('* [X] also'), 'also');
    });

    test('applyBlockTrigger converts [ ] on a plain bullet into a task', () {
      const block = BulletBlock(id: 'b1', text: '');
      final triggered = applyBlockTrigger(block, '[ ] typed');
      expect(triggered, isA<BulletBlock>());
      expect((triggered as BulletBlock).checked, isFalse);
      expect((triggered as BulletBlock).text, 'typed');
      expect(triggered!.id, 'b1');
    });

    test('reparseBlockFromLineMarkdown parses bullet and preserves id', () {
      const template = ParagraphBlock(id: 'keep', text: 'hello');
      final block = reparseBlockFromLineMarkdown(
        template,
        lineMarkdown: '- item',
      );
      expect(block.id, 'keep');
      expect(block, isA<BulletBlock>());
      expect((block as BulletBlock).text, 'item');
    });

    test('applyBlockTrigger uses parser for typed bullet syntax', () {
      const block = ParagraphBlock(id: 'p1', text: '');
      final triggered = applyBlockTrigger(block, '- typed');
      expect(triggered, isA<BulletBlock>());
      expect((triggered as BulletBlock).text, 'typed');
      expect(triggered.id, 'p1');
    });

    test('heading enter sibling should be paragraph markdown transform', () {
      const heading = HeadingBlock(id: 'h1', level: 2, text: 'Title');
      expect(lineMarkdownForBlock(heading, 'next'), '## next');
      final reparsed = reparseBlockFromLineMarkdown(
        heading,
        lineMarkdown: applyParagraphLineMarkdown('## next'),
      );
      expect(reparsed, isA<ParagraphBlock>());
      expect((reparsed as ParagraphBlock).text, 'next');
    });

    test('lineMarkdownForBlock builds sibling line for list enter', () {
      const bullet = BulletBlock(id: 'b1', text: 'a');
      expect(lineMarkdownForBlock(bullet, 'next'), '- next');
      const task = BulletBlock(id: 't1', text: 'a', checked: true);
      expect(lineMarkdownForBlock(task, 'next'), '- [x] next');
    });

    test('chromelessContentPadding indents quote blocks', () {
      final theme = ThemeData();
      const quote = QuoteBlock(id: 'q1', text: '');
      final padding = MdBlockStyles.chromelessContentPadding(quote, theme);
      expect(padding.left, 12);
    });
  });

  group('ordered list renumbering', () {
    test('renumbers after removing a middle item', () {
      final blocks = <MdBlock>[
        OrderedBlock(id: '1', marker: '1.', text: 'a'),
        OrderedBlock(id: '2', marker: '2.', text: 'b'),
        OrderedBlock(id: '3', marker: '3.', text: 'c'),
        OrderedBlock(id: '4', marker: '4.', text: 'd'),
        OrderedBlock(id: '5', marker: '5.', text: 'e'),
      ];
      blocks.removeAt(2);
      renumberOrderedBlocksAfterRemoval(blocks, 2);

      expect(blocks.length, 4);
      expect((blocks[0] as OrderedBlock).marker, '1.');
      expect((blocks[1] as OrderedBlock).marker, '2.');
      expect((blocks[2] as OrderedBlock).marker, '3.');
      expect((blocks[2] as OrderedBlock).text, 'd');
      expect((blocks[3] as OrderedBlock).marker, '4.');
      expect((blocks[3] as OrderedBlock).text, 'e');
    });

    test('renumbers ordered run after a heading', () {
      final blocks = <MdBlock>[
        HeadingBlock(id: 'h', level: 1, text: 'Title'),
        OrderedBlock(id: '1', marker: '1.', text: 'a'),
        OrderedBlock(id: '2', marker: '2.', text: 'b'),
        OrderedBlock(id: '3', marker: '3.', text: 'c'),
      ];
      blocks.removeAt(2);
      renumberOrderedBlocksAfterRemoval(blocks, 2);

      expect((blocks[2] as OrderedBlock).marker, '2.');
      expect((blocks[2] as OrderedBlock).text, 'c');
    });

    test('首项改为正文后后续有序从 1. 起重计', () {
      final blocks = <MdBlock>[
        OrderedBlock(id: '1', marker: '1.', text: 'a'),
        OrderedBlock(id: '2', marker: '2.', text: 'b'),
      ];
      blocks[0] = ParagraphBlock(id: '1', text: 'a');
      renumberOrderedBlocksAround(blocks, 0);

      expect(blocks[0], isA<ParagraphBlock>());
      expect((blocks[1] as OrderedBlock).marker, '1.');
      expect((blocks[1] as OrderedBlock).text, 'b');
    });

    test('首项改为无序后后续有序从 1. 起重计', () {
      final blocks = <MdBlock>[
        OrderedBlock(id: '1', marker: '1.', text: 'a'),
        OrderedBlock(id: '2', marker: '2.', text: 'b'),
      ];
      blocks[0] = BulletBlock(id: '1', text: 'a');
      renumberOrderedBlocksAround(blocks, 0);

      expect(blocks[0], isA<BulletBlock>());
      expect((blocks[1] as OrderedBlock).marker, '1.');
    });

    test('中间项换型后拆成两段各自从 1. 起', () {
      final blocks = <MdBlock>[
        OrderedBlock(id: '1', marker: '1.', text: 'a'),
        OrderedBlock(id: '2', marker: '2.', text: 'b'),
        OrderedBlock(id: '3', marker: '3.', text: 'c'),
      ];
      blocks[1] = ParagraphBlock(id: '2', text: 'b');
      renumberOrderedBlocksAround(blocks, 1);

      expect((blocks[0] as OrderedBlock).marker, '1.');
      expect(blocks[1], isA<ParagraphBlock>());
      expect((blocks[2] as OrderedBlock).marker, '1.');
      expect((blocks[2] as OrderedBlock).text, 'c');
    });

    test('夹在两段有序之间的正文改为有序则整段重排', () {
      final blocks = <MdBlock>[
        OrderedBlock(id: '1', marker: '1.', text: 'a'),
        ParagraphBlock(id: 'p', text: 'b'),
        OrderedBlock(id: '3', marker: '1.', text: 'c'),
      ];
      blocks[1] = OrderedBlock(id: 'p', marker: '1.', text: 'b');
      renumberOrderedBlocksAround(blocks, 1);

      expect((blocks[0] as OrderedBlock).marker, '1.');
      expect((blocks[1] as OrderedBlock).marker, '2.');
      expect((blocks[2] as OrderedBlock).marker, '3.');
    });
  });

  group('MdBlockStyles spacing', () {
    test('bottomSpacingFor removes gap between flowed paragraph lines', () {
      const flowed = ParagraphBlock(
        id: 'a',
        text: 'line1',
        continuesWithNext: true,
      );
      const last = ParagraphBlock(id: 'b', text: 'line2');
      const heading = HeadingBlock(id: 'h', level: 2, text: 'Title');

      expect(MdBlockStyles.bottomSpacingFor(flowed, next: last), 0);
      expect(MdBlockStyles.bottomSpacingFor(last), MdBlockStyles.blockGap);
      expect(MdBlockStyles.bottomSpacingFor(heading), MdBlockStyles.blockGap);
    });

    test('stale continuesWithNext before a list uses blockGap not 0', () {
      const para = ParagraphBlock(
        id: 'a',
        text: 'body',
        continuesWithNext: true,
      );
      const bullet = BulletBlock(id: 'b', text: 'item');
      const ordered = OrderedBlock(id: 'o', marker: '1.', text: 'item');
      const task = BulletBlock(id: 't', text: 'item', checked: false);

      expect(
        MdBlockStyles.bottomSpacingFor(para, next: bullet),
        MdBlockStyles.blockGap,
      );
      expect(
        MdBlockStyles.slotPaddingFor(bullet, previous: para),
        MdBlockStyles.slotPadding,
      );
      expect(
        MdBlockStyles.bottomSpacingFor(para, next: ordered),
        MdBlockStyles.blockGap,
      );
      expect(
        MdBlockStyles.bottomSpacingFor(para, next: task),
        MdBlockStyles.blockGap,
      );
    });

    test('consecutive list items use tighter listItemGap', () {
      const bullet = BulletBlock(id: 'a', text: 'one');
      const nextBullet = BulletBlock(id: 'b', text: 'two');
      const ordered = OrderedBlock(id: 'o', marker: '1.', text: 'one');
      const nextOrdered = OrderedBlock(id: 'p', marker: '2.', text: 'two');
      const task = BulletBlock(id: 't', text: 'one', checked: false);
      const nextTask = BulletBlock(id: 'u', text: 'two', checked: true);
      const para = ParagraphBlock(id: 'p', text: 'body');

      expect(
        MdBlockStyles.bottomSpacingFor(bullet, next: nextBullet),
        MdBlockStyles.listItemGap,
      );
      expect(
        MdBlockStyles.bottomSpacingFor(ordered, next: nextOrdered),
        MdBlockStyles.listItemGap,
      );
      expect(
        MdBlockStyles.bottomSpacingFor(task, next: nextTask),
        MdBlockStyles.listItemGap,
      );
      expect(
        MdBlockStyles.bottomSpacingFor(bullet, next: ordered),
        MdBlockStyles.listItemGap,
      );
      expect(
        MdBlockStyles.bottomSpacingFor(bullet, next: para),
        MdBlockStyles.blockGap,
      );
      expect(MdBlockStyles.listItemGap < MdBlockStyles.blockGap, isTrue);
    });

    test('slotPadding has no vertical inset so live matches preview', () {
      expect(MdBlockStyles.slotPadding.top, 0);
      expect(MdBlockStyles.slotPadding.bottom, 0);
      expect(MdBlockStyles.editorBodyTopPadding, 8);
      expect(MdBlockStyles.editorBodyHorizontalPadding, 16);
    });

    test('slotPaddingFor removes vertical padding for flowed lines', () {
      const first = ParagraphBlock(
        id: 'a',
        text: 'line1',
        continuesWithNext: true,
      );
      const second = ParagraphBlock(id: 'b', text: 'line2');
      const standalone = ParagraphBlock(id: 'c', text: 'solo');

      expect(
        MdBlockStyles.slotPaddingFor(first, next: second),
        const EdgeInsets.symmetric(horizontal: 2),
      );
      expect(
        MdBlockStyles.slotPaddingFor(second, previous: first),
        const EdgeInsets.symmetric(horizontal: 2),
      );
      expect(
        MdBlockStyles.slotPaddingFor(standalone),
        MdBlockStyles.slotPadding,
      );
    });
  });
}
