import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/core/markdown/live_block_tap_ops.dart';

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
}
