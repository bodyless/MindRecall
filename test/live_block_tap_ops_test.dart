import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/core/markdown/markdown.dart';
import 'package:mind_recall/theme/app_theme.dart';

void main() {
  group('displayOffsetToPlainOffset', () {
    test('plain equals display → identity', () {
      expect(
        displayOffsetToPlainOffset(
          displayOffset: 3,
          plainText: 'hello',
          displayText: 'hello',
          displayMarkdown: null,
        ),
        3,
      );
    });

    test('clamps to plain length', () {
      expect(
        displayOffsetToPlainOffset(
          displayOffset: 99,
          plainText: 'ab',
          displayText: 'ab',
          displayMarkdown: null,
        ),
        2,
      );
    });

    test('empty plain → 0', () {
      expect(
        displayOffsetToPlainOffset(
          displayOffset: 1,
          plainText: '',
          displayText: ' ',
          displayMarkdown: null,
        ),
        0,
      );
    });

    test('bold markdown same visible length', () {
      expect(
        displayOffsetToPlainOffset(
          displayOffset: 4,
          plainText: 'bold',
          displayText: 'bold',
          displayMarkdown: '**bold**',
        ),
        4,
      );
    });

    test('link resolved title longer than plain', () {
      // 标签等于 href 时展示 resolvedTitle，display 与 plain 不等长。
      expect(
        displayOffsetToPlainOffset(
          displayOffset: 5,
          plainText: 'http://x',
          displayText: 'Title',
          displayMarkdown: '[http://x](http://x)',
          resolveLinkLabel: (_) => 'Title',
        ),
        8, // ratio 5/5 → full plain length
      );
    });
  });

  group('plainOffsetToDisplayOffset', () {
    test('plain equals display → identity', () {
      expect(
        plainOffsetToDisplayOffset(
          plainOffset: 3,
          plainText: 'hello',
          displayText: 'hello',
          displayMarkdown: null,
        ),
        3,
      );
    });

    test('at or past end → display length', () {
      expect(
        plainOffsetToDisplayOffset(
          plainOffset: 99,
          plainText: 'ab',
          displayText: 'ab',
          displayMarkdown: null,
        ),
        2,
      );
    });
  });

  group('isListChromePrefixPlain', () {
    test('matches bullet / task / ordered chrome', () {
      expect(isListChromePrefixPlain(MdBlockChromeMetrics.bulletPrefix), isTrue);
      expect(
        isListChromePrefixPlain(MdBlockChromeMetrics.taskUncheckedPrefix),
        isTrue,
      );
      expect(
        isListChromePrefixPlain(MdBlockChromeMetrics.taskCheckedPrefix),
        isTrue,
      );
      expect(isListChromePrefixPlain('1. '), isTrue);
      expect(isListChromePrefixPlain('10. '), isTrue);
    });

    test('does not match list body', () {
      expect(isListChromePrefixPlain('hello'), isFalse);
      expect(isListChromePrefixPlain('1. not just prefix'), isFalse);
      expect(isListChromePrefixPlain('•item'), isFalse);
    });
  });

  group('caretTextPositionForDisplay', () {
    test('文末使用 upstream，避免换行边界把光标送到下一行行首', () {
      final position = caretTextPositionForDisplay(
        displayOffset: 12,
        displayLength: 12,
      );
      expect(position.offset, 12);
      expect(position.affinity, TextAffinity.upstream);
    });

    test('文中保持调用方 affinity', () {
      final position = caretTextPositionForDisplay(
        displayOffset: 3,
        displayLength: 12,
        affinity: TextAffinity.downstream,
      );
      expect(position.offset, 3);
      expect(position.affinity, TextAffinity.downstream);
    });

    test('空文本 offset 0', () {
      final position = caretTextPositionForDisplay(
        displayOffset: 0,
        displayLength: 0,
      );
      expect(position.offset, 0);
      expect(position.affinity, TextAffinity.downstream);
    });
  });

  group('liveCollapsedCaretHandleTopLeft', () {
    test('锚在光标底边中点', () {
      final topLeft = liveCollapsedCaretHandleTopLeft(
        caretTopLeft: const Offset(10, 20),
        caretWidth: kTextCaretWidth,
        caretHeight: 16,
      );
      // 底边中点 (11, 36) − 锚点 (11, -4) → (0, 40)
      expect(topLeft, const Offset(0, 40));
    });
  });

  group('alignedCollapsedHandleAnchor', () {
    test('锚点 x 减少半个光标宽，手柄右移对准中线', () {
      expect(
        alignedCollapsedHandleAnchor(const Offset(11, -4)),
        const Offset(10, -4),
      );
    });
  });

  group('liveCollapsedHandleVisibleAfterEdit', () {
    test('打字后隐藏', () {
      expect(
        liveCollapsedHandleVisibleAfterEdit(
          visible: true,
          textChanged: true,
          revealFromUserTap: false,
        ),
        isFalse,
      );
    });

    test('点选后显示', () {
      expect(
        liveCollapsedHandleVisibleAfterEdit(
          visible: false,
          textChanged: false,
          revealFromUserTap: true,
        ),
        isTrue,
      );
    });

    test('仅选区变化保持原可见性', () {
      expect(
        liveCollapsedHandleVisibleAfterEdit(
          visible: true,
          textChanged: false,
          revealFromUserTap: false,
        ),
        isTrue,
      );
    });
  });

  testWidgets('findLiveBodyParagraph 跳过列表前缀段落', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: KeyedSubtree(
            key: key,
            child: const MdBlockRenderer(
              block: BulletBlock(
                id: 'b',
                text: 'body text that is not a prefix',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final paragraph = findLiveBodyParagraph(
      key.currentContext!.findRenderObject(),
      plainText: 'body text that is not a prefix',
    );
    expect(paragraph, isNotNull);
    expect(
      paragraph!.text.toPlainText(),
      'body text that is not a prefix',
    );
  });
}
