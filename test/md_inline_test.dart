import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/core/markdown/ast/md_inline.dart';
import 'package:mind_recall/core/markdown/renderer/md_inline_renderer.dart';

void main() {
  group('parseInlineMarkdown', () {
    test('parses markdown links', () {
      final nodes = parseInlineMarkdown('见 [文档](./note.md) 与 [站点](https://a.com)');
      expect(nodes.length, 4);
      expect(nodes[0], isA<TextInline>());
      expect(nodes[1], isA<LinkInline>());
      expect((nodes[1] as LinkInline).label, '文档');
      expect((nodes[1] as LinkInline).href, './note.md');
      expect(nodes[3], isA<LinkInline>());
      expect((nodes[3] as LinkInline).href, 'https://a.com');
    });

    test('parseInlineMarkdown does not crash on asterisk-only token ***', () {
      // `*.+?*` 可匹配 `***`；若误走三星分支会 RangeError(end): Only valid value is 3: 0
      expect(() => parseInlineMarkdown('***'), returnsNormally);
      expect(() => parseInlineMarkdown('前 *** 后'), returnsNormally);
      final nodes = parseInlineMarkdown('***');
      expect(nodes, isNotEmpty);
    });

    test('linkDisplayLabel prefers custom label over resolved title', () {
      expect(
        linkDisplayLabel(
          label: '测试1',
          href: '文档1',
          resolvedTitle: '测试',
        ),
        '测试1',
      );
      expect(
        linkDisplayLabel(
          label: '测试',
          href: '文档1',
          resolvedTitle: '测试',
        ),
        '测试',
      );
    });

    test('linkDisplayLabel resolves when label is raw path or href', () {
      expect(
        linkDisplayLabel(
          label: './170000.md',
          href: './170000.md',
          resolvedTitle: '旅行计划',
        ),
        '旅行计划',
      );
      expect(
        linkDisplayLabel(
          label: '170000.md',
          href: './170000.md',
          resolvedTitle: '旅行计划',
        ),
        '旅行计划',
      );
      expect(
        linkDisplayLabel(
          label: '文档1',
          href: '文档1',
          resolvedTitle: '文档1',
        ),
        '文档1',
      );
    });

    test('parses bold and plain text', () {
      final nodes = parseInlineMarkdown('Hello **world**');
      expect(nodes.length, 2);
      expect(nodes[0], isA<TextInline>());
      expect((nodes[0] as TextInline).text, 'Hello ');
      expect(nodes[1], isA<BoldInline>());
      expect((nodes[1] as BoldInline).plainText, 'world');
    });

    test('round-trips through serialize', () {
      const input = 'Hello **bold** and *italic*';
      final nodes = parseInlineMarkdown(input);
      expect(serializeInlineMarkdown(nodes), input);
    });

    test('parses bold italic with triple asterisks', () {
      final nodes = parseInlineMarkdown('Hello ***world***');
      expect(nodes.length, 2);
      expect(nodes[1], isA<BoldInline>());
      final bold = nodes[1] as BoldInline;
      expect(bold.plainText, 'world');
      expect(bold.children.single, isA<ItalicInline>());
      expect(serializeInlineMarkdown(nodes), 'Hello ***world***');
    });

    test('parses bold italic with triple underscores', () {
      const input = '___both___';
      final nodes = parseInlineMarkdown(input);
      expect(nodes.single, isA<BoldInline>());
      expect(nodes.single.plainText, 'both');
      // 序列化统一用星号表示。
      expect(serializeInlineMarkdown(nodes), '***both***');
    });
  });

  group('applyInlineStyle', () {
    test('wraps selected range in bold', () {
      const input = 'Hello world';
      final nodes = parseInlineMarkdown(input);
      final updated = applyInlineStyle(nodes, 6, 11, InlineStyle.bold);
      expect(serializeInlineMarkdown(updated), 'Hello **world**');
    });

    test('toggles bold off when already bold', () {
      const input = 'Hello **world**';
      final nodes = parseInlineMarkdown(input);
      final updated = applyInlineStyle(nodes, 6, 11, InlineStyle.bold);
      expect(serializeInlineMarkdown(updated), 'Hello world');
    });

    test('applies code style to selection', () {
      const input = 'Use print here';
      final nodes = parseInlineMarkdown(input);
      final updated = applyInlineStyle(nodes, 4, 9, InlineStyle.code);
      expect(serializeInlineMarkdown(updated), 'Use `print` here');
    });

    test('applies bold and italic to selection', () {
      const input = 'Hello world';
      var nodes = parseInlineMarkdown(input);
      nodes = applyInlineStyle(nodes, 6, 11, InlineStyle.bold);
      nodes = applyInlineStyle(nodes, 6, 11, InlineStyle.italic);
      expect(serializeInlineMarkdown(nodes), 'Hello ***world***');
    });

    test('handles selection beyond plain text length safely', () {
      const input = 'ab';
      final nodes = parseInlineMarkdown(input);
      final updated = applyInlineStyle(nodes, 2, 3, InlineStyle.bold);
      expect(serializeInlineMarkdown(updated), 'ab');
    });

    test('returns original nodes when style apply would wipe content', () {
      const input = 'abc';
      final nodes = parseInlineMarkdown(input);
      final updated = applyInlineStyle(nodes, 3, 3, InlineStyle.bold);
      expect(serializeInlineMarkdown(updated), input);
    });
  });

  group('splitInlineMarkdown', () {
    test('splits before and after bold segment', () {
      const input = 'hello **world**';
      final split = splitInlineMarkdown(input, 6);
      expect(split.before, 'hello ');
      expect(split.after, '**world**');
    });

    test('splits inside bold segment', () {
      const input = 'hello **world**';
      final split = splitInlineMarkdown(input, 8);
      expect(split.before, 'hello **wo**');
      expect(split.after, '**rld**');
    });
  });

  group('applyPlainTextChange', () {
    test('appends plain text after bold markdown', () {
      const markdown = 'hello **world**';
      final updated = applyPlainTextChange(
        markdown: markdown,
        previousPlain: 'hello world',
        newPlain: 'hello world!',
      );
      expect(updated, 'hello **world**!');
    });

    test('preserves bold when inserting in plain prefix', () {
      const markdown = '**bold** text';
      final updated = applyPlainTextChange(
        markdown: markdown,
        previousPlain: 'bold text',
        newPlain: 'bold more text',
      );
      expect(updated, '**bold** more text');
    });
  });

  group('mergeInlineMarkdown', () {
    test('concatenates formatted segments', () {
      expect(
        mergeInlineMarkdown('hello **world**', 'next'),
        'hello **world**next',
      );
    });
  });

  group('MdInlineText', () {
    TextSpan? findSpanWithStyle(TextSpan span, bool Function(TextStyle? s) match) {
      if (match(span.style)) return span;
      for (final child in span.children ?? const <InlineSpan>[]) {
        if (child is TextSpan) {
          final found = findSpanWithStyle(child, match);
          if (found != null) return found;
        }
      }
      return null;
    }

    testWidgets('renders bold text with bold font weight', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MdInlineText(markdown: 'Hello **world**'),
          ),
        ),
      );

      final richText = tester.widget<RichText>(find.byType(RichText));
      final root = richText.text as TextSpan;
      final boldSpan = findSpanWithStyle(
        root,
        (style) =>
            style?.fontWeight == FontWeight.bold ||
            style?.fontWeight == FontWeight.w700 ||
            style?.fontWeight == FontWeight.w800 ||
            style?.fontWeight == FontWeight.w900,
      );

      expect(boldSpan, isNotNull);
      expect(boldSpan!.text ?? boldSpan.toPlainText(), contains('world'));
    });

    testWidgets('renders italic text with italic font style', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MdInlineText(markdown: 'Hello *world*'),
          ),
        ),
      );

      final richText = tester.widget<RichText>(find.byType(RichText));
      final root = richText.text as TextSpan;
      final italicSpan = findSpanWithStyle(
        root,
        (style) => style?.fontStyle == FontStyle.italic,
      );

      expect(italicSpan, isNotNull);
    });

    testWidgets('renders bold italic text with both styles', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MdInlineText(markdown: 'Hello ***world***'),
          ),
        ),
      );

      final richText = tester.widget<RichText>(find.byType(RichText));
      final root = richText.text as TextSpan;
      final styledSpan = findSpanWithStyle(
        root,
        (style) =>
            (style?.fontWeight == FontWeight.bold ||
                style?.fontWeight == FontWeight.w700 ||
                style?.fontWeight == FontWeight.w800 ||
                style?.fontWeight == FontWeight.w900) &&
            style?.fontStyle == FontStyle.italic,
      );

      expect(styledSpan, isNotNull);
      expect(styledSpan!.text ?? styledSpan.toPlainText(), contains('world'));
    });
  });
}
