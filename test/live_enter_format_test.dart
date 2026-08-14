import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/core/markdown/editor/md_block_editor_field.dart';

void main() {
  group('isMultilinePasteInsertion', () {
    test('single Enter is not paste', () {
      expect(isMultilinePasteInsertion('\n'), isFalse);
      expect(isMultilinePasteInsertion('\r\n'), isFalse);
      expect(isMultilinePasteInsertion('\r'), isFalse);
    });

    test('multiline or text-with-newline is paste', () {
      expect(isMultilinePasteInsertion('a\nb'), isTrue);
      expect(isMultilinePasteInsertion('\n\n'), isTrue);
      expect(isMultilinePasteInsertion('hello\n'), isTrue);
    });

    test('null or no newline is not paste', () {
      expect(isMultilinePasteInsertion(null), isFalse);
      expect(isMultilinePasteInsertion('hello'), isFalse);
      expect(isMultilinePasteInsertion(''), isFalse);
    });
  });
}
