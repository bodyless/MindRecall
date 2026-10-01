import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/core/markdown/markdown.dart';

void main() {
  late MdBlockIdGenerator ids;

  setUp(() {
    ids = MdBlockIdGenerator();
  });

  group('prepareLiveBlocksFromMarkdown', () {
    test('空文档得到单段落并激活', () {
      final prepared = prepareLiveBlocksFromMarkdown('', idGenerator: ids);
      expect(prepared.blocks, hasLength(1));
      expect(prepared.blocks.first, isA<ParagraphBlock>());
      expect(prepared.activeBlockId, prepared.blocks.first.id);
    });

    test('isEmptyDocumentBody 仅单空段落', () {
      expect(isEmptyDocumentBody([ParagraphBlock(id: 'p', text: '')]), isTrue);
      expect(
        isEmptyDocumentBody([ParagraphBlock(id: 'p', text: '  ')]),
        isTrue,
      );
      expect(
        isEmptyDocumentBody([ParagraphBlock(id: 'p', text: 'hi')]),
        isFalse,
      );
      expect(
        isEmptyDocumentBody([
          ParagraphBlock(id: 'p', text: ''),
          ParagraphBlock(id: 'q', text: ''),
        ]),
        isFalse,
      );
      expect(isEmptyDocumentBody([BulletBlock(id: 'b', text: '')]), isFalse);
    });

    test('rendererParagraphMatchesCaretPlain 识别 stale 正文', () {
      expect(
        rendererParagraphMatchesCaretPlain(
          controllerPlain: 'ab',
          paragraphPlain: 'a',
          hasInlineFormatting: false,
        ),
        isFalse,
      );
      expect(
        rendererParagraphMatchesCaretPlain(
          controllerPlain: 'ab',
          paragraphPlain: 'ab',
          hasInlineFormatting: false,
        ),
        isTrue,
      );
      expect(
        rendererParagraphMatchesCaretPlain(
          controllerPlain: '',
          paragraphPlain: ' ',
          hasInlineFormatting: false,
        ),
        isTrue,
      );
      expect(
        rendererParagraphMatchesCaretPlain(
          controllerPlain: 'ab',
          paragraphPlain: 'a',
          hasInlineFormatting: true,
        ),
        isTrue,
      );
    });

    test('preferLastBlock 激活末块', () {
      final prepared = prepareLiveBlocksFromMarkdown(
        'a\n\nb',
        idGenerator: ids,
        preferLastBlock: true,
      );
      expect(prepared.blocks.length, greaterThanOrEqualTo(2));
      expect(prepared.activeBlockId, prepared.blocks.last.id);
    });

    test('保留 preferredActiveId', () {
      final first = prepareLiveBlocksFromMarkdown(
        '## H\n\nbody',
        idGenerator: ids,
      );
      final keepId = first.blocks.first.id;
      final second = prepareLiveBlocksFromMarkdown(
        '## H\n\nbody',
        idGenerator: ids,
        preferredActiveId: keepId,
      );
      // 重解析后 id 会变；preferred 若不在列表则回退首块。
      expect(second.activeBlockId, second.blocks.first.id);
    });

    test('多行段落展开为多块', () {
      final prepared = prepareLiveBlocksFromMarkdown(
        'line1\nline2',
        idGenerator: ids,
      );
      expect(prepared.blocks.length, greaterThanOrEqualTo(2));
      expect(prepared.blocks.every((b) => b is ParagraphBlock), isTrue);
    });
  });

  group('splitMultilineBlockAt', () {
    test('在 plain 光标处拆成两段并标记 continuesWithNext', () {
      final blocks = [ParagraphBlock(id: 'p1', text: 'hello world')];
      final result = splitMultilineBlockAt(
        blocks: blocks,
        index: 0,
        resolvedMarkdownBeforeEdit: 'hello world',
        plainCursor: 5,
        idGenerator: ids,
      );
      expect(result.blocks, hasLength(2));
      final first = result.blocks[0] as ParagraphBlock;
      expect(first.text, 'hello');
      expect(first.continuesWithNext, isTrue);
      expect((result.blocks[1] as ParagraphBlock).text, ' world');
      expect(result.newActiveId, result.blocks[1].id);
    });

    test('含行内格式时按 plain 光标拆分 markdown', () {
      final blocks = [ParagraphBlock(id: 'p1', text: '**ab**cd')];
      // plain = "abcd"；光标在 2 → 拆成 **ab** | cd
      final result = splitMultilineBlockAt(
        blocks: blocks,
        index: 0,
        resolvedMarkdownBeforeEdit: '**ab**cd',
        plainCursor: 2,
        idGenerator: ids,
      );
      expect((result.blocks[0] as ParagraphBlock).text, '**ab**');
      expect((result.blocks[1] as ParagraphBlock).text, 'cd');
    });

    test('中间插入继承原块 continuesWithNext', () {
      final blocks = [
        const ParagraphBlock(id: 'a', text: '行1', continuesWithNext: true),
        const ParagraphBlock(id: 'b', text: '行2', continuesWithNext: true),
        const ParagraphBlock(id: 'c', text: '行3'),
      ];
      final result = splitMultilineBlockAt(
        blocks: blocks,
        index: 0,
        resolvedMarkdownBeforeEdit: '行1',
        plainCursor: 2,
        idGenerator: ids,
      );
      expect(result.blocks, hasLength(4));
      expect((result.blocks[0] as ParagraphBlock).continuesWithNext, isTrue);
      expect((result.blocks[1] as ParagraphBlock).text, isEmpty);
      expect((result.blocks[1] as ParagraphBlock).continuesWithNext, isTrue);
      expect((result.blocks[2] as ParagraphBlock).text, '行2');
    });
  });

  group('insertBlockBelowSingleLine', () {
    test('标题 Enter 后半段变为段落', () {
      final blocks = [HeadingBlock(id: 'h1', level: 1, text: 'TitleMore')];
      final result = insertBlockBelowSingleLine(
        blocks: blocks,
        index: 0,
        beforePlain: 'Title',
        afterPlain: 'More',
        idGenerator: ids,
      );
      expect(result.blocks, hasLength(2));
      expect(result.blocks[0], isA<HeadingBlock>());
      expect((result.blocks[0] as HeadingBlock).text, 'Title');
      expect(result.blocks[1], isA<ParagraphBlock>());
      expect((result.blocks[1] as ParagraphBlock).text, 'More');
      expect(result.newActiveId, result.blocks[1].id);
    });

    test('无序列表 Enter 保留类型并拆分', () {
      final blocks = [BulletBlock(id: 'b1', text: 'one two')];
      final result = insertBlockBelowSingleLine(
        blocks: blocks,
        index: 0,
        beforePlain: 'one',
        afterPlain: 'two',
        idGenerator: ids,
      );
      expect(result.blocks[0], isA<BulletBlock>());
      expect((result.blocks[0] as BulletBlock).text, 'one');
      expect(result.blocks[1], isA<BulletBlock>());
      expect((result.blocks[1] as BulletBlock).text, 'two');
    });

    test('勾选列表 Enter 新块未勾选且当前块 checked 不变', () {
      final blocks = [
        const BulletBlock(id: 't1', text: 'one two', checked: true),
      ];
      final result = insertBlockBelowSingleLine(
        blocks: blocks,
        index: 0,
        beforePlain: 'one',
        afterPlain: 'two',
        idGenerator: ids,
      );
      expect((result.blocks[0] as BulletBlock).checked, isTrue);
      expect((result.blocks[0] as BulletBlock).text, 'one');
      expect((result.blocks[1] as BulletBlock).checked, isFalse);
      expect((result.blocks[1] as BulletBlock).text, 'two');
      expect(result.blocks[1].toMarkdown(), '- [ ] two');
    });

    test('有序列表 Enter 后重编号', () {
      final blocks = [
        OrderedBlock(id: 'o1', marker: '1.', text: 'a b'),
        OrderedBlock(id: 'o2', marker: '2.', text: 'c'),
      ];
      final result = insertBlockBelowSingleLine(
        blocks: blocks,
        index: 0,
        beforePlain: 'a',
        afterPlain: 'b',
        idGenerator: ids,
      );
      expect(result.blocks, hasLength(3));
      expect((result.blocks[0] as OrderedBlock).marker, '1.');
      expect((result.blocks[1] as OrderedBlock).marker, '2.');
      expect((result.blocks[2] as OrderedBlock).marker, '3.');
    });
  });

  group('commitPlainToBlock / resolvedInlineMarkdownForEdit', () {
    test('无变更时返回同一实例', () {
      final block = ParagraphBlock(id: 'p', text: 'hi');
      expect(identical(commitPlainToBlock(block, 'hi'), block), isTrue);
    });

    test('写回 plain 更新 markdown', () {
      final block = ParagraphBlock(id: 'p', text: 'hi');
      final updated = commitPlainToBlock(block, 'hello');
      expect(inlineMarkdownForBlock(updated), 'hello');
    });

    test('resolvedInlineMarkdownForEdit 保持未改动的行内语法', () {
      final block = ParagraphBlock(id: 'p', text: '**hi**');
      expect(resolvedInlineMarkdownForEdit(block, 'hi'), '**hi**');
    });

    test('代码块提交保留多行', () {
      const block = CodeBlock(id: 'c', code: 'a');
      final updated = commitPlainToBlock(block, 'a\nb\nc');
      expect(updated, isA<CodeBlock>());
      expect((updated as CodeBlock).code, 'a\nb\nc');
    });

    test('标题提交只留第一行', () {
      const block = HeadingBlock(id: 'h', level: 1, text: 'old');
      final updated = commitPlainToBlock(block, 'a\nb');
      expect(updated, isA<HeadingBlock>());
      expect((updated as HeadingBlock).text, 'a');
    });
  });

  group('liveShowsTrailingAfterCodeFill', () {
    test('最后一块代码为 true；段落与空文档为 false', () {
      expect(
        liveShowsTrailingAfterCodeFill([
          const CodeBlock(id: 'c', code: 'print(1)'),
        ]),
        isTrue,
      );
      expect(
        liveShowsTrailingAfterCodeFill([
          const ParagraphBlock(id: 'p', text: 'hello'),
        ]),
        isFalse,
      );
      expect(
        liveShowsTrailingAfterCodeFill([
          const ParagraphBlock(id: 'p', text: ''),
        ]),
        isFalse,
      );
    });
  });

  group('paragraphFlowAfterHeadingToBody', () {
    List<MdBlock> headingToBody(List<MdBlock> blocks, int index) {
      final before = blocks[index];
      final reparsed = reparseBlockFromLineMarkdown(
        before,
        lineMarkdown: applyParagraphLineMarkdown(before.toMarkdown()),
      );
      final next = List<MdBlock>.of(blocks);
      next[index] = reparsed;
      paragraphFlowAfterHeadingToBody(
        blocks: next,
        index: index,
        before: before,
      );
      syncParagraphFlowFlags(next);
      return next;
    }

    test('标题改为正文且下一块是段落时收成段内行距', () {
      final blocks = headingToBody(
        const [
          HeadingBlock(id: 'h', level: 1, text: 'Title'),
          ParagraphBlock(id: 'p', text: 'body'),
        ],
        0,
      );

      expect((blocks[0] as ParagraphBlock).continuesWithNext, isTrue);
      expect(MdBlockStyles.bottomSpacingFor(blocks[0], next: blocks[1]), 0);
    });

    test('标题上下都是正文时两处间距都收成段内行距', () {
      final blocks = headingToBody(
        const [
          ParagraphBlock(id: 'a', text: '上文'),
          HeadingBlock(id: 'h', level: 1, text: '标题1'),
          ParagraphBlock(id: 'b', text: '下文'),
        ],
        1,
      );

      expect((blocks[0] as ParagraphBlock).continuesWithNext, isTrue);
      expect((blocks[1] as ParagraphBlock).continuesWithNext, isTrue);
      expect(MdBlockStyles.bottomSpacingFor(blocks[0], next: blocks[1]), 0);
      expect(MdBlockStyles.bottomSpacingFor(blocks[1], next: blocks[2]), 0);
    });

    test('标题改为正文但下一块不是段落时仍用块间距', () {
      final blocks = headingToBody(
        const [
          HeadingBlock(id: 'h', level: 2, text: 'Title'),
          BulletBlock(id: 'b', text: 'item'),
        ],
        0,
      );

      expect((blocks[0] as ParagraphBlock).continuesWithNext, isFalse);
      expect(
        MdBlockStyles.bottomSpacingFor(blocks[0], next: blocks[1]),
        MdBlockStyles.blockGap,
      );
    });

    test('上一块是列表时不给列表打 flow', () {
      final blocks = headingToBody(
        const [
          BulletBlock(id: 'b', text: 'item'),
          HeadingBlock(id: 'h', level: 1, text: 'Title'),
          ParagraphBlock(id: 'p', text: 'body'),
        ],
        1,
      );

      expect(blocks[0], isA<BulletBlock>());
      expect(
        MdBlockStyles.bottomSpacingFor(blocks[0], next: blocks[1]),
        MdBlockStyles.blockGap,
      );
      expect(MdBlockStyles.bottomSpacingFor(blocks[1], next: blocks[2]), 0);
    });

    test('列表改为正文不打段内 flow', () {
      final blocks = headingToBody(
        const [
          BulletBlock(id: 'b', text: 'item'),
          ParagraphBlock(id: 'p', text: 'body'),
        ],
        0,
      );

      expect((blocks[0] as ParagraphBlock).continuesWithNext, isFalse);
      expect(
        MdBlockStyles.bottomSpacingFor(blocks[0], next: blocks[1]),
        MdBlockStyles.blockGap,
      );
    });
  });

  group('copyWithContinuesWithNext', () {
    test('仅段落携带 flow 标记', () {
      final para = ParagraphBlock(id: 'p', text: 'a');
      final next = copyWithContinuesWithNext(para, continuesWithNext: true);
      expect((next as ParagraphBlock).continuesWithNext, isTrue);

      final bullet = BulletBlock(id: 'b', text: 'x');
      expect(
        identical(
          copyWithContinuesWithNext(bullet, continuesWithNext: true),
          bullet,
        ),
        isTrue,
      );
    });
  });

  group('syncParagraphFlowFlags', () {
    test('正文后改成列表时清掉前一块 continuesWithNext', () {
      final blocks = <MdBlock>[
        const ParagraphBlock(id: 'a', text: 'body', continuesWithNext: true),
        BulletBlock(id: 'b', text: 'item'),
      ];
      syncParagraphFlowFlags(blocks);
      expect((blocks[0] as ParagraphBlock).continuesWithNext, isFalse);
    });

    test('下一块仍是段落时保留 continuesWithNext', () {
      final blocks = <MdBlock>[
        const ParagraphBlock(id: 'a', text: 'line1', continuesWithNext: true),
        const ParagraphBlock(id: 'b', text: 'line2'),
      ];
      syncParagraphFlowFlags(blocks);
      expect((blocks[0] as ParagraphBlock).continuesWithNext, isTrue);
    });

    test('插入分割线后清掉被隔开的段落 flow', () {
      final replaced = insertThematicBreakAt(
        blocks: const [
          ParagraphBlock(id: 'a', text: 'above', continuesWithNext: true),
          ParagraphBlock(id: 'b', text: ''),
        ],
        index: 1,
        idGenerator: ids,
      );
      expect(replaced.blocks[0], isA<ParagraphBlock>());
      expect((replaced.blocks[0] as ParagraphBlock).continuesWithNext, isFalse);
      expect(replaced.blocks[1], isA<ThematicBreakBlock>());

      final inserted = insertThematicBreakAt(
        blocks: const [
          ParagraphBlock(id: 'a', text: 'above', continuesWithNext: true),
          ParagraphBlock(id: 'b', text: 'below'),
        ],
        index: 0,
        idGenerator: ids,
      );
      expect((inserted.blocks[0] as ParagraphBlock).continuesWithNext, isFalse);
      expect(inserted.blocks[1], isA<ThematicBreakBlock>());
    });
  });

  group('thematic break session ops', () {
    test('ensureEditableBlockAfterAtomic 在原子块下插入空段落', () {
      final hr = ThematicBreakBlock(id: ids.next());
      final result = ensureEditableBlockAfterAtomic(
        blocks: [hr],
        atomicIndex: 0,
        idGenerator: ids,
      );
      expect(result.blocks, hasLength(2));
      expect(result.blocks[0], isA<ThematicBreakBlock>());
      expect(result.blocks[1], isA<ParagraphBlock>());
      expect((result.blocks[1] as ParagraphBlock).text, isEmpty);
      expect(result.newActiveId, result.blocks[1].id);
    });

    test('insertThematicBreakAt 替换空段落并聚焦线后空段', () {
      final empty = ParagraphBlock(id: ids.next(), text: '');
      final result = insertThematicBreakAt(
        blocks: [empty],
        index: 0,
        idGenerator: ids,
      );
      expect(result.blocks, hasLength(2));
      expect(result.blocks[0], isA<ThematicBreakBlock>());
      expect(result.blocks[0].id, empty.id);
      expect(result.blocks[1], isA<ParagraphBlock>());
      expect(result.newActiveId, result.blocks[1].id);
    });

    test('insertThematicBreakAt 有正文则插在后方', () {
      final para = ParagraphBlock(id: ids.next(), text: 'hello');
      final result = insertThematicBreakAt(
        blocks: [para],
        index: 0,
        idGenerator: ids,
      );
      expect(result.blocks, hasLength(3));
      expect(result.blocks[0], isA<ParagraphBlock>());
      expect((result.blocks[0] as ParagraphBlock).text, 'hello');
      expect(result.blocks[1], isA<ThematicBreakBlock>());
      expect(result.blocks[2], isA<ParagraphBlock>());
      expect(result.newActiveId, result.blocks[2].id);
    });
  });

  group('mergeCurrentBlockIntoPrevious', () {
    test('空段落下的标题并入正文并删除当前块', () {
      final empty = ParagraphBlock(id: ids.next(), text: '');
      final heading = HeadingBlock(id: ids.next(), level: 1, text: '标题');
      final result = mergeCurrentBlockIntoPrevious(
        blocks: [empty, heading],
        currentIndex: 1,
        currentPlain: '标题',
      );
      expect(result.handled, isTrue);
      expect(result.blocks, hasLength(1));
      expect(result.blocks.single, isA<ParagraphBlock>());
      expect((result.blocks.single as ParagraphBlock).text, '标题');
      expect(result.activeId, empty.id);
      expect(result.caretOffset, 0);
    });

    test('空标题接下一段落时保持标题格式', () {
      final heading = HeadingBlock(id: ids.next(), level: 2, text: '');
      final para = ParagraphBlock(id: ids.next(), text: '正文');
      final result = mergeCurrentBlockIntoPrevious(
        blocks: [heading, para],
        currentIndex: 1,
        currentPlain: '正文',
      );
      expect(result.handled, isTrue);
      expect(result.blocks, hasLength(1));
      expect(result.blocks.single, isA<HeadingBlock>());
      expect((result.blocks.single as HeadingBlock).text, '正文');
      expect((result.blocks.single as HeadingBlock).level, 2);
    });

    test('上一块为原子块时删除无效', () {
      final hr = ThematicBreakBlock(id: ids.next());
      final heading = HeadingBlock(id: ids.next(), level: 1, text: '标题');
      final result = mergeCurrentBlockIntoPrevious(
        blocks: [hr, heading],
        currentIndex: 1,
        currentPlain: '标题',
      );
      expect(result.handled, isFalse);
      expect(result.blocks, hasLength(2));
      expect(result.blocks[1], isA<HeadingBlock>());
      expect((result.blocks[1] as HeadingBlock).text, '标题');
    });

    test('当前块文本接到上一文本块末尾', () {
      final prev = ParagraphBlock(id: ids.next(), text: 'hello');
      final current = HeadingBlock(id: ids.next(), level: 1, text: 'World');
      final result = mergeCurrentBlockIntoPrevious(
        blocks: [prev, current],
        currentIndex: 1,
        currentPlain: 'World',
      );
      expect(result.handled, isTrue);
      expect(result.blocks, hasLength(1));
      expect((result.blocks.single as ParagraphBlock).text, 'helloWorld');
      expect(result.caretOffset, 'hello'.length);
    });

    test('文档首块不合并', () {
      final heading = HeadingBlock(id: ids.next(), level: 1, text: '标题');
      final result = mergeCurrentBlockIntoPrevious(
        blocks: [heading],
        currentIndex: 0,
        currentPlain: '标题',
      );
      expect(result.handled, isFalse);
      expect(result.blocks, hasLength(1));
    });

    test('有序列表中间项合并后重编号', () {
      final first = OrderedBlock(id: ids.next(), marker: '1.', text: 'a');
      final second = OrderedBlock(id: ids.next(), marker: '2.', text: 'b');
      final third = OrderedBlock(id: ids.next(), marker: '3.', text: 'c');
      final result = mergeCurrentBlockIntoPrevious(
        blocks: [first, second, third],
        currentIndex: 1,
        currentPlain: 'b',
      );
      expect(result.handled, isTrue);
      expect(result.blocks, hasLength(2));
      expect((result.blocks[0] as OrderedBlock).text, 'ab');
      expect((result.blocks[0] as OrderedBlock).marker, '1.');
      expect((result.blocks[1] as OrderedBlock).marker, '2.');
      expect((result.blocks[1] as OrderedBlock).text, 'c');
    });
  });
}
