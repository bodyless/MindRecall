import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/core/markdown/markdown.dart';

void main() {
  group('MdBlockChromeMetrics', () {
    test('bulletPrefix 与有序前缀格式稳定', () {
      expect(MdBlockChromeMetrics.bulletPrefix, '•  ');
      expect(MdBlockChromeMetrics.taskUncheckedPrefix, '☐  ');
      expect(MdBlockChromeMetrics.taskCheckedPrefix, '☑  ');
      expect(
        MdBlockChromeMetrics.taskPrefixWidth,
        MdBlockChromeMetrics.taskIconSize +
            MdBlockChromeMetrics.taskPrefixTrailingGap,
      );
      expect(MdBlockChromeMetrics.orderedPrefix('1.'), '1. ');
      expect(
        MdBlockChromeMetrics.listPrefixSlotWidth,
        MdBlockChromeMetrics.taskPrefixWidth,
      );
      expect(MdBlockChromeMetrics.hintColorAlpha, 0.55);
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
          const BulletBlock(id: 't', text: 'x', checked: false),
        ),
        MdBlockChrome.taskUncheckedPrefix,
      );
      expect(
        MdBlockChrome.prefixLabel(
          const BulletBlock(id: 't', text: 'x', checked: true),
        ),
        MdBlockChrome.taskCheckedPrefix,
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

    test('prefixLineHeight 跟随字号与 height', () {
      expect(
        MdBlockChrome.prefixLineHeight(
          const TextStyle(fontSize: 16, height: 1.5),
        ),
        24,
      );
    });

    testWidgets('勾选前缀使用 Material check_box 图标而非系统 ☐/☑', (tester) async {
      const unchecked = BulletBlock(id: 't', text: 'a', checked: false);
      const checked = BulletBlock(id: 't', text: 'b', checked: true);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final style = Theme.of(context).textTheme.bodyLarge;
              final accent = Theme.of(context).colorScheme.primary;
              return Column(
                children: [
                  MdBlockChrome.buildPrefix(
                    unchecked,
                    style,
                    visible: true,
                    accentColor: accent,
                  ),
                  MdBlockChrome.buildPrefix(
                    checked,
                    style,
                    visible: true,
                    accentColor: accent,
                  ),
                ],
              );
            },
          ),
        ),
      );
      expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);
      expect(find.byIcon(Icons.check_box), findsOneWidget);
    });

    testWidgets('勾选图标垂直中心贴近同行正文', (tester) async {
      const style = TextStyle(
        fontSize: 16,
        height: 1.5,
        color: Colors.black,
      );
      const task = BulletBlock(id: 't', text: '买牛奶', checked: false);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MdBlockChrome.buildPrefix(
                  task,
                  style,
                  visible: true,
                ),
                Text(
                  '买牛奶',
                  style: style,
                  strutStyle: MdBlockStyles.strutFor(style),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      final iconY = tester.getCenter(find.byIcon(Icons.check_box_outline_blank)).dy;
      final textY = tester.getCenter(find.text('买牛奶')).dy;
      expect(
        (iconY - textY).abs(),
        lessThan(4),
        reason: 'iconY=$iconY textY=$textY',
      );
    });

    testWidgets('有序/无序/勾选前缀槽等宽', (tester) async {
      const style = TextStyle(fontSize: 16, height: 1.5, color: Colors.black);
      await tester.pumpWidget(
        MaterialApp(
          home: Row(
            children: [
              MdBlockChrome.buildPrefix(
                OrderedBlock(id: 'o', marker: '1.', text: 'a'),
                style,
                visible: true,
              ),
              MdBlockChrome.buildPrefix(
                BulletBlock(id: 'b', text: 'a'),
                style,
                visible: true,
              ),
              MdBlockChrome.buildPrefix(
                const BulletBlock(id: 't', text: 'a', checked: false),
                style,
                visible: true,
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SizedBox &&
              widget.width == MdBlockChrome.listPrefixSlotWidth,
        ),
        findsNWidgets(3),
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

  group('toggleBulletTaskChecked', () {
    test('翻转勾选态，非任务块原样返回', () {
      const task = BulletBlock(id: 't', text: 'a', checked: false);
      final flipped = toggleBulletTaskChecked(task) as BulletBlock;
      expect(flipped.checked, isTrue);
      expect(flipped.text, 'a');
      expect(flipped.id, 't');

      const bullet = BulletBlock(id: 'b', text: 'a');
      expect(identical(toggleBulletTaskChecked(bullet), bullet), isTrue);
    });
  });
}
