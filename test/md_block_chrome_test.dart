import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/core/markdown/markdown.dart';

void main() {
  group('MdBlockChromeMetrics', () {
    test('bulletPrefix 与有序前缀格式稳定', () {
      expect(MdBlockChromeMetrics.bulletPrefix, '•  ');
      expect(MdBlockChromeMetrics.orderedPrefix('1.'), '1. ');
      expect(MdBlockChromeMetrics.quoteIndent, 12.0);
      expect(MdBlockChromeMetrics.codePadding, 12.0);
    });
  });

  group('MdBlockChrome', () {
    test('prefixLabel 覆盖列表类型', () {
      expect(
        MdBlockChrome.prefixLabel(
          BulletBlock(id: 'b', text: 'x'),
        ),
        MdBlockChrome.bulletPrefix,
      );
      expect(
        MdBlockChrome.prefixLabel(
          OrderedBlock(id: 'o', marker: '2.', text: 'y'),
        ),
        '2. ',
      );
      expect(
        MdBlockChrome.prefixLabel(
          ParagraphBlock(id: 'p', text: 'z'),
        ),
        '',
      );
    });

    test('leadingSpacerWidth / chromelessBodyPadding 与渲染常量对齐', () {
      expect(
        MdBlockChrome.leadingSpacerWidth(QuoteBlock(id: 'q', text: '')),
        MdBlockChrome.quoteIndent,
      );
      expect(
        MdBlockChrome.leadingSpacerWidth(CodeBlock(id: 'c', code: '')),
        MdBlockChrome.quoteIndent,
      );
      expect(
        MdBlockChrome.leadingSpacerWidth(ParagraphBlock(id: 'p', text: '')),
        0,
      );

      final codePad = MdBlockChrome.chromelessBodyPadding(
        CodeBlock(id: 'c', code: 'x'),
      );
      expect(codePad.left, 0);
      expect(codePad.top, MdBlockChrome.codePadding);
      expect(codePad.right, MdBlockChrome.codePadding);
      expect(codePad.bottom, MdBlockChrome.codePadding);

      expect(
        MdBlockChrome.chromelessBodyPadding(ParagraphBlock(id: 'p', text: '')),
        EdgeInsets.zero,
      );
    });

    test('quote / code EdgeInsets 助手', () {
      expect(
        MdBlockChrome.quoteBodyPadding(),
        const EdgeInsets.only(left: MdBlockChrome.quoteIndent),
      );
      expect(
        MdBlockChrome.codeBlockPadding(),
        const EdgeInsets.all(MdBlockChrome.codePadding),
      );
    });
  });

  group('粘贴规范化与 chrome 前缀同源', () {
    test('normalizePastedMarkdown 识别 MdBlockChromeMetrics.bulletPrefix', () {
      final raw = '${MdBlockChromeMetrics.bulletPrefix}一项';
      expect(normalizePastedMarkdown(raw), '- 一项');
    });
  });
}
