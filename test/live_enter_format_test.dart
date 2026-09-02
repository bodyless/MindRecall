import 'package:flutter/services.dart';
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

  group('isBlockStartImeClear', () {
    test('块首折叠光标且新值为空才拦截', () {
      const oldValue = TextEditingValue(
        text: '标题',
        selection: TextSelection.collapsed(offset: 0),
      );
      const cleared = TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
      expect(isBlockStartImeClear(oldValue, cleared), isTrue);
    });

    test('从末尾删至空或块首删一字不拦截', () {
      const fromEnd = TextEditingValue(
        text: '标',
        selection: TextSelection.collapsed(offset: 1),
      );
      const emptied = TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
      expect(isBlockStartImeClear(fromEnd, emptied), isFalse);

      const atStart = TextEditingValue(
        text: '标题',
        selection: TextSelection.collapsed(offset: 0),
      );
      const deleteFirst = TextEditingValue(
        text: '题',
        selection: TextSelection.collapsed(offset: 0),
      );
      expect(isBlockStartImeClear(atStart, deleteFirst), isFalse);
    });
  });
}
