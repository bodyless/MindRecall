import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/core/markdown/markdown.dart';

void main() {
  late MdBlockIdGenerator ids;

  setUp(() {
    ids = MdBlockIdGenerator();
  });

  group('prepareLiveBlocksFromMarkdown', () {
    test('空文档得到单段落并激活', () {
      final prepared = prepareLiveBlocksFromMarkdown(
        '',
        idGenerator: ids,
      );
      expect(prepared.blocks, hasLength(1));
      expect(prepared.blocks.first, isA<ParagraphBlock>());
      expect(prepared.activeBlockId, prepared.blocks.first.id);
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
      final blocks = [
        ParagraphBlock(id: 'p1', text: 'hello world'),
      ];
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
      final blocks = [
        ParagraphBlock(id: 'p1', text: '**ab**cd'),
      ];
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
  });

  group('insertBlockBelowSingleLine', () {
    test('标题 Enter 后半段变为段落', () {
      final blocks = [
        HeadingBlock(id: 'h1', level: 1, text: 'TitleMore'),
      ];
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
      final blocks = [
        BulletBlock(id: 'b1', text: 'one two'),
      ];
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
      expect(
        resolvedInlineMarkdownForEdit(block, 'hi'),
        '**hi**',
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
}
