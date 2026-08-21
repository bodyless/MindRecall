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

    test('asTaskItem 生成未勾选任务项', () {
      const block = ParagraphBlock(id: 'p1', text: '买牛奶');
      final task = block.asTaskItem() as BulletBlock;
      expect(task.checked, isFalse);
      expect(task.text, '买牛奶');
      expect(task.toMarkdown(), '- [ ] 买牛奶');
    });
  });

  group('GFM task list', () {
    test('parses unchecked, checked, and [X] as task bullets', () {
      const text = '- [ ] buy\n- [x] done\n- [X] also';
      final blocks = parseMarkdownBlocks(text);
      expect(blocks, hasLength(3));
      expect((blocks[0] as BulletBlock).checked, isFalse);
      expect((blocks[0] as BulletBlock).text, 'buy');
      expect((blocks[1] as BulletBlock).checked, isTrue);
      expect((blocks[1] as BulletBlock).text, 'done');
      expect((blocks[2] as BulletBlock).checked, isTrue);
      expect((blocks[2] as BulletBlock).text, 'also');
    });

    test('plain bullet stays checked == null', () {
      final blocks = parseMarkdownBlocks('- item');
      expect(blocks, hasLength(1));
      expect(blocks.first, isA<BulletBlock>());
      expect((blocks.first as BulletBlock).checked, isNull);
      expect((blocks.first as BulletBlock).text, 'item');
      expect(blocks.first.toMarkdown(), '- item');
    });

    test('ordered 1. [ ] is not a task', () {
      final blocks = parseMarkdownBlocks('1. [ ] not task');
      expect(blocks.first, isA<OrderedBlock>());
      expect((blocks.first as OrderedBlock).text, '[ ] not task');
    });

    test('round-trips task markdown', () {
      const text = '- [ ] a\n- [x] b';
      final blocks = parseMarkdownBlocks(text);
      expect(serializeMdBlocks(blocks), text);
    });

    test('copyWithPlainText 保留 checked', () {
      const task = BulletBlock(id: 't', text: 'old', checked: true);
      final updated = task.copyWithPlainText('new');
      expect(updated.checked, isTrue);
      expect(updated.text, 'new');
    });
  });

  group('thematic break', () {
    test('parses --- *** ___ and indented --- as ThematicBreakBlock', () {
      expect(parseMarkdownBlocks('---').single, isA<ThematicBreakBlock>());
      expect(parseMarkdownBlocks('***').single, isA<ThematicBreakBlock>());
      expect(parseMarkdownBlocks('___').single, isA<ThematicBreakBlock>());
      expect(parseMarkdownBlocks('   ---').single, isA<ThematicBreakBlock>());
    });

    test('*** round-trips to ---', () {
      final blocks = parseMarkdownBlocks('***');
      expect(serializeMdBlocks(blocks), '---');
    });

    test('- - - stays a bullet', () {
      final blocks = parseMarkdownBlocks('- - -');
      expect(blocks.single, isA<BulletBlock>());
      expect((blocks.single as BulletBlock).text, '- -');
    });

    test('Foo\\n--- is paragraph plus break, not setext H2', () {
      final blocks = parseMarkdownBlocks('Foo\n---');
      expect(blocks, hasLength(2));
      expect(blocks[0], isA<ParagraphBlock>());
      expect((blocks[0] as ParagraphBlock).text, 'Foo');
      expect(blocks[1], isA<ThematicBreakBlock>());
    });

    test('hello\\n---\\nworld splits into three blocks', () {
      final blocks = parseMarkdownBlocks('hello\n---\nworld');
      expect(blocks, hasLength(3));
      expect((blocks[0] as ParagraphBlock).text, 'hello');
      expect(blocks[1], isA<ThematicBreakBlock>());
      expect((blocks[2] as ParagraphBlock).text, 'world');
    });

    test('applyBlockTrigger converts typed ---', () {
      const block = ParagraphBlock(id: 'b1', text: '');
      final triggered = applyBlockTrigger(block, '---');
      expect(triggered, isA<ThematicBreakBlock>());
      expect(triggered!.id, 'b1');
    });

    test('supportsPlainEditing is false only for atomic blocks', () {
      expect(const ParagraphBlock(id: 'p', text: '').supportsPlainEditing, isTrue);
      expect(
        const HeadingBlock(id: 'h', level: 1, text: 't').supportsPlainEditing,
        isTrue,
      );
      expect(const CodeBlock(id: 'c', code: 'x').supportsPlainEditing, isTrue);
      expect(
        const ImageBlock(id: 'i', alt: '', src: './a.png').supportsPlainEditing,
        isFalse,
      );
      expect(const ThematicBreakBlock(id: 'hr').supportsPlainEditing, isFalse);
    });
  });
}
