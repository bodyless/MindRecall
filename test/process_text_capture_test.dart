import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/services/process_text_capture.dart';

void main() {
  group('normalizeCapturedProcessText', () {
    test('null 返回 null', () {
      expect(normalizeCapturedProcessText(null), isNull);
    });

    test('空白返回 null', () {
      expect(normalizeCapturedProcessText(''), isNull);
      expect(normalizeCapturedProcessText('   \n\t  '), isNull);
    });

    test('去掉首尾空白', () {
      expect(normalizeCapturedProcessText('  hello\n'), 'hello');
    });
  });

  group('shouldReuseEmptyActiveMemo', () {
    test('标题与正文都空则复用', () {
      expect(
        shouldReuseEmptyActiveMemo(title: '', content: ''),
        isTrue,
      );
      expect(
        shouldReuseEmptyActiveMemo(title: '  ', content: '\n'),
        isTrue,
      );
    });

    test('有标题或正文则不复用', () {
      expect(
        shouldReuseEmptyActiveMemo(title: 'T', content: ''),
        isFalse,
      );
      expect(
        shouldReuseEmptyActiveMemo(title: '', content: 'body'),
        isFalse,
      );
    });
  });
}
