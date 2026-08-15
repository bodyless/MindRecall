import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/features/memo/editor/plain_text/markdown_editor_helper.dart';

void main() {
  group('MarkdownEditorHelper', () {
    test('wrapSelection wraps highlighted text with bold markers', () {
      final controller = TextEditingController(text: 'hello world');
      controller.selection = const TextSelection(baseOffset: 6, extentOffset: 11);

      MarkdownEditorHelper.wrapSelection(
        controller,
        left: '**',
        right: '**',
      );

      expect(controller.text, 'hello **world**');
      expect(controller.selection.start, 8);
      expect(controller.selection.end, 13);
    });

    test('applyHeading converts selected line to H1', () {
      final controller = TextEditingController(text: '第一行\n第二行');
      controller.selection = const TextSelection(baseOffset: 2, extentOffset: 2);

      MarkdownEditorHelper.applyHeading(controller, 1);

      expect(controller.text, '# 第一行\n第二行');
    });

    test('applyHeading replaces existing heading level', () {
      final controller = TextEditingController(text: '## 标题');
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 5);

      MarkdownEditorHelper.applyHeading(controller, 1);

      expect(controller.text, '# 标题');
    });

    test('selectedLineRange covers full lines in selection', () {
      const text = 'aaa\nbbb\nccc';
      const selection = TextSelection(baseOffset: 5, extentOffset: 7);

      final range = MarkdownEditorHelper.selectedLineRange(text, selection);

      expect(range.start, 4);
      expect(range.end, 7);
    });

    test('applyLinePrefix keeps collapsed caret without selecting whole line', () {
      final controller = TextEditingController(text: 'hello');
      controller.selection = const TextSelection.collapsed(offset: 3);

      MarkdownEditorHelper.applyLinePrefix(
        controller,
        prefix: '- ',
        replaceExisting: RegExp(r'^[-*+]\s*'),
      );

      expect(controller.text, '- hello');
      expect(controller.selection.isCollapsed, isTrue);
      expect(controller.selection.baseOffset, 5);
    });

    test('applyTaskList converts the line to an unchecked task', () {
      final controller = TextEditingController(text: 'hello');
      controller.selection = const TextSelection.collapsed(offset: 3);

      MarkdownEditorHelper.applyTaskList(controller);

      expect(controller.text, '- [ ] hello');
    });

    test('applyTaskList strips existing task or bullet prefix', () {
      final controller = TextEditingController(text: '- [x] done');
      controller.selection = const TextSelection.collapsed(offset: 4);

      MarkdownEditorHelper.applyTaskList(controller);

      expect(controller.text, '- [ ] done');
    });

    test('applyLinePrefix bullet removes existing task marker', () {
      final controller = TextEditingController(text: '- [ ] hello');
      controller.selection = const TextSelection.collapsed(offset: 6);

      MarkdownEditorHelper.applyLinePrefix(
        controller,
        prefix: '- ',
        replaceExisting: RegExp(r'^(?:[-*+]\s+\[[ xX]\]\s*|[-*+]\s*)'),
      );

      expect(controller.text, '- hello');
    });
  });
}
