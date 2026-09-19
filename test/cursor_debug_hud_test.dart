import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/core/debug/cursor_debug_hud.dart';
import 'package:mind_recall/core/markdown/ast/md_block.dart';

void main() {
  tearDown(() {
    cursorDebugHud.value = CursorDebugSnapshot.empty;
  });

  group('cursorDebugContextAround', () {
    test('splits before and after caret and escapes newlines', () {
      final ctx = cursorDebugContextAround(
        text: 'hello\nworld',
        caretOffset: 6,
        radius: 20,
      );
      expect(ctx.before, 'hello↵');
      expect(ctx.after, 'world');
    });
  });

  group('cursorDebugLineColumn', () {
    test('computes 1-based line and 0-based column', () {
      expect(cursorDebugLineColumn('a\nbc', 0), (line: 1, column: 0));
      expect(cursorDebugLineColumn('a\nbc', 2), (line: 2, column: 0));
      expect(cursorDebugLineColumn('a\nbc', 3), (line: 2, column: 1));
    });
  });

  group('formatCursorDebugHudLines', () {
    test('empty snapshot shows placeholder', () {
      expect(formatCursorDebugHudLines(CursorDebugSnapshot.empty), ['Cursor —']);
    });

    test('formats live block selection and context', () {
      final lines = formatCursorDebugHudLines(
        const CursorDebugSnapshot(
          mode: 'Live',
          focused: true,
          selectionBase: 2,
          selectionExtent: 5,
          collapsed: false,
          blockType: 'H2',
          blockIndex: 1,
          blockCount: 4,
          blockId: 'md-b2',
          contextBefore: 'ab',
          contextAfter: 'cde',
        ),
      );
      expect(lines.first, 'Cursor Live F');
      expect(lines, contains('sel 2..5 len=3'));
      expect(lines, contains('blk 2/4 H2 id=md-b2'));
      expect(
        lines,
        contains('ov hit=0 view=0 imeF=0 edF=0 langF=0 sameTap=0'),
      );
      expect(lines, contains('ctx «ab|cde»'));
    });

    test('formats live overlay hit fields', () {
      final lines = formatCursorDebugHudLines(
        const CursorDebugSnapshot(
          mode: 'Live',
          focused: true,
          overlayHitTestActive: true,
          overlayInView: true,
          imeSessionFocused: true,
          editorFocused: true,
          languageFocused: false,
          sameBlockTapDiscarded: true,
        ),
      );
      expect(
        lines,
        contains('ov hit=1 view=1 imeF=1 edF=1 langF=0 sameTap=1'),
      );
    });
  });

  group('mdBlockDebugTypeLabel', () {
    test('labels common block types', () {
      expect(
        mdBlockDebugTypeLabel(const HeadingBlock(id: '1', level: 2, text: 't')),
        'H2',
      );
      expect(
        mdBlockDebugTypeLabel(const ParagraphBlock(id: '1', text: 't')),
        'P',
      );
      expect(
        mdBlockDebugTypeLabel(const BulletBlock(id: '1', text: 't')),
        'ul',
      );
      expect(
        mdBlockDebugTypeLabel(
          const BulletBlock(id: '1', text: 't', checked: false),
        ),
        'task',
      );
      expect(
        mdBlockDebugTypeLabel(
          const BulletBlock(id: '1', text: 't', checked: true),
        ),
        'task:x',
      );
      expect(
        mdBlockDebugTypeLabel(const ThematicBreakBlock(id: '1')),
        'hr',
      );
    });
  });

  test('publishCursorDebugHud updates notifier', () {
    publishCursorDebugHud(
      const CursorDebugSnapshot(mode: 'Edit', focused: true, selectionBase: 3),
    );
    expect(cursorDebugHud.value.mode, 'Edit');
    expect(cursorDebugHud.value.selectionBase, 3);
  });
}
