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

    test('applyHeading strips strikethrough markers on the line', () {
      final controller = TextEditingController(text: '~~测试asdasdasdasd~~');
      controller.selection = const TextSelection.collapsed(offset: 4);

      MarkdownEditorHelper.applyHeading(controller, 2);

      expect(controller.text, '## 测试asdasdasdasd');
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

    test('insertThematicBreak inserts snippet at caret', () {
      final controller = TextEditingController(text: 'ab');
      controller.selection = const TextSelection.collapsed(offset: 1);

      MarkdownEditorHelper.insertThematicBreak(controller);

      expect(controller.text, 'a\n---\nb');
    });

    test('wrapSelection wraps highlighted text with strikethrough markers', () {
      final controller = TextEditingController(text: 'hello world');
      controller.selection = const TextSelection(
        baseOffset: 6,
        extentOffset: 11,
      );

      MarkdownEditorHelper.wrapSelection(
        controller,
        left: '~~',
        right: '~~',
      );

      expect(controller.text, 'hello ~~world~~');
      expect(controller.selection.start, 8);
      expect(controller.selection.end, 13);
    });

    test('insertCodeBlockFence wraps selection as fence body', () {
      final controller = TextEditingController(text: 'hello world');
      controller.selection = const TextSelection(
        baseOffset: 6,
        extentOffset: 11,
      );

      MarkdownEditorHelper.insertCodeBlockFence(controller);

      expect(controller.text, 'hello ```\nworld\n```');
      expect(controller.selection.baseOffset, 'hello ```\nworld'.length);
    });

    test('insertCodeBlockFence splits abc|def into empty fence', () {
      final controller = TextEditingController(text: 'abcdef');
      controller.selection = const TextSelection.collapsed(offset: 3);

      MarkdownEditorHelper.insertCodeBlockFence(controller);

      expect(controller.text, 'abc\n```\n\n```\ndef');
      expect(controller.selection.baseOffset, 'abc\n```\n'.length);
    });

    test('insertCodeBlockFence at eof adds trailing blank line', () {
      final controller = TextEditingController(text: 'abc');
      controller.selection = const TextSelection.collapsed(offset: 3);

      MarkdownEditorHelper.insertCodeBlockFence(controller);

      expect(controller.text, 'abc\n```\n\n```\n\n');
    });

    test('insertCodeBlockFence on empty document has no leading newline', () {
      final controller = TextEditingController(text: '');
      controller.selection = const TextSelection.collapsed(offset: 0);

      MarkdownEditorHelper.insertCodeBlockFence(controller);

      expect(controller.text, '```\n\n```\n\n');
      expect(controller.selection.baseOffset, '```\n'.length);
    });
  });
}
