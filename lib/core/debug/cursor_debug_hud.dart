import 'package:flutter/foundation.dart';
import 'package:mind_recall/core/markdown/ast/md_block.dart';

/// 块类型的调试短标签。
String mdBlockDebugTypeLabel(MdBlock block) {
  return switch (block) {
    HeadingBlock(:final level) => 'H$level',
    ParagraphBlock() => 'P',
    BulletBlock(:final checked) => switch (checked) {
        null => 'ul',
        false => 'task',
        true => 'task:x',
      },
    OrderedBlock(:final marker) => 'ol:$marker',
    QuoteBlock() => 'quote',
    CodeBlock(:final language) =>
      (language == null || language.isEmpty) ? 'code' : 'code:$language',
    ImageBlock() => 'img',
    ThematicBreakBlock() => 'hr',
  };
}

/// 块 id 截断，便于 HUD 一行显示。
String mdBlockDebugIdShort(String id, {int maxChars = 8}) {
  if (id.length <= maxChars) {
    return id;
  }
  return id.substring(id.length - maxChars);
}

/// 屏上光标调试 HUD 的一帧快照（仅 debug 有意义）。
@immutable
class CursorDebugSnapshot {
  const CursorDebugSnapshot({
    this.mode = '',
    this.focused = false,
    this.selectionBase = 0,
    this.selectionExtent = 0,
    this.collapsed = true,
    this.blockType = '',
    this.blockIndex,
    this.blockCount,
    this.blockId = '',
    this.contextBefore = '',
    this.contextAfter = '',
    this.composingStart,
    this.composingEnd,
    this.docLine,
    this.docColumn,
    this.overlayHitTestActive = false,
    this.overlayInView = false,
    this.imeSessionFocused = false,
    this.editorFocused = false,
    this.languageFocused = false,
    this.sameBlockTapDiscarded = false,
  });

  static const empty = CursorDebugSnapshot();

  /// `Live` / `Edit` / `Preview`。
  final String mode;
  final bool focused;
  final int selectionBase;
  final int selectionExtent;
  final bool collapsed;

  /// 块类型标签（如 `H2`、`P`、`ul`）；编辑模式可为行上下文简述。
  final String blockType;
  final int? blockIndex;
  final int? blockCount;
  final String blockId;
  final String contextBefore;
  final String contextAfter;
  final int? composingStart;
  final int? composingEnd;
  final int? docLine;
  final int? docColumn;

  /// Overlay 是否吃点击（正文或语言框会话仍在）。
  final bool overlayHitTestActive;

  /// 活动块 Overlay 是否视为在视口内。
  final bool overlayInView;
  final bool imeSessionFocused;
  final bool editorFocused;
  final bool languageFocused;

  /// 同块 InkWell 激活时丢掉了落点。
  final bool sameBlockTapDiscarded;

  @override
  bool operator ==(Object other) {
    return other is CursorDebugSnapshot &&
        other.mode == mode &&
        other.focused == focused &&
        other.selectionBase == selectionBase &&
        other.selectionExtent == selectionExtent &&
        other.collapsed == collapsed &&
        other.blockType == blockType &&
        other.blockIndex == blockIndex &&
        other.blockCount == blockCount &&
        other.blockId == blockId &&
        other.contextBefore == contextBefore &&
        other.contextAfter == contextAfter &&
        other.composingStart == composingStart &&
        other.composingEnd == composingEnd &&
        other.docLine == docLine &&
        other.docColumn == docColumn &&
        other.overlayHitTestActive == overlayHitTestActive &&
        other.overlayInView == overlayInView &&
        other.imeSessionFocused == imeSessionFocused &&
        other.editorFocused == editorFocused &&
        other.languageFocused == languageFocused &&
        other.sameBlockTapDiscarded == sameBlockTapDiscarded;
  }

  @override
  int get hashCode => Object.hashAll([
        mode,
        focused,
        selectionBase,
        selectionExtent,
        collapsed,
        blockType,
        blockIndex,
        blockCount,
        blockId,
        contextBefore,
        contextAfter,
        composingStart,
        composingEnd,
        docLine,
        docColumn,
        overlayHitTestActive,
        overlayInView,
        imeSessionFocused,
        editorFocused,
        languageFocused,
        sameBlockTapDiscarded,
      ]);
}

/// 全局光标 HUD 状态；仅 [kDebugMode] 下由编辑器 publish。
final ValueNotifier<CursorDebugSnapshot> cursorDebugHud =
    ValueNotifier<CursorDebugSnapshot>(CursorDebugSnapshot.empty);

/// 光标上下文截取半径（字符数）。
const int kCursorDebugContextRadius = 12;

/// 发布光标 HUD。非 debug 零开销。
void publishCursorDebugHud(CursorDebugSnapshot snapshot) {
  if (!kDebugMode) {
    return;
  }
  if (snapshot == cursorDebugHud.value) {
    return;
  }
  cursorDebugHud.value = snapshot;
}

void clearCursorDebugHud() {
  publishCursorDebugHud(CursorDebugSnapshot.empty);
}

/// 从文本与光标偏移截取前后文（换行显示为 ↵）。
({String before, String after}) cursorDebugContextAround({
  required String text,
  required int caretOffset,
  int radius = kCursorDebugContextRadius,
}) {
  final caret = caretOffset.clamp(0, text.length);
  final start = (caret - radius).clamp(0, text.length);
  final end = (caret + radius).clamp(0, text.length);
  return (
    before: _escapeCursorDebugSnippet(text.substring(start, caret)),
    after: _escapeCursorDebugSnippet(text.substring(caret, end)),
  );
}

/// 文档偏移 → 1-based 行号与 0-based 列号。
({int line, int column}) cursorDebugLineColumn(String text, int offset) {
  final caret = offset.clamp(0, text.length);
  var line = 1;
  var lineStart = 0;
  for (var i = 0; i < caret; i++) {
    if (text.codeUnitAt(i) == 0x0A) {
      line++;
      lineStart = i + 1;
    }
  }
  return (line: line, column: caret - lineStart);
}

/// 格式化为屏上多行（纯函数，便于单测）。
List<String> formatCursorDebugHudLines(CursorDebugSnapshot snapshot) {
  if (snapshot.mode.isEmpty) {
    return const ['Cursor —'];
  }
  final focusTag = snapshot.focused ? 'F' : 'U';
  final sel = snapshot.collapsed
      ? '${snapshot.selectionBase}'
      : '${snapshot.selectionBase}..${snapshot.selectionExtent}';
  final lines = <String>[
    'Cursor ${snapshot.mode} $focusTag',
    'sel $sel${snapshot.collapsed ? '' : ' len=${(snapshot.selectionExtent - snapshot.selectionBase).abs()}'}',
  ];
  if (snapshot.blockIndex != null && snapshot.blockCount != null) {
    final id = snapshot.blockId.isEmpty ? '' : ' id=${snapshot.blockId}';
    final type = snapshot.blockType.isEmpty ? '?' : snapshot.blockType;
    lines.add(
      'blk ${snapshot.blockIndex! + 1}/${snapshot.blockCount} $type$id',
    );
  } else if (snapshot.blockType.isNotEmpty) {
    lines.add(snapshot.blockType);
  }
  if (snapshot.docLine != null && snapshot.docColumn != null) {
    lines.add('pos L${snapshot.docLine}:C${snapshot.docColumn}');
  }
  if (snapshot.mode == 'Live') {
    lines.add(
      'ov hit=${snapshot.overlayHitTestActive ? '1' : '0'} '
      'view=${snapshot.overlayInView ? '1' : '0'} '
      'imeF=${snapshot.imeSessionFocused ? '1' : '0'} '
      'edF=${snapshot.editorFocused ? '1' : '0'} '
      'langF=${snapshot.languageFocused ? '1' : '0'} '
      'sameTap=${snapshot.sameBlockTapDiscarded ? '1' : '0'}',
    );
  }
  lines.add('ctx «${snapshot.contextBefore}|${snapshot.contextAfter}»');
  if (snapshot.composingStart != null &&
      snapshot.composingEnd != null &&
      snapshot.composingStart != snapshot.composingEnd) {
    lines.add('ime ${snapshot.composingStart}..${snapshot.composingEnd}');
  }
  return lines;
}

String _escapeCursorDebugSnippet(String raw) {
  return raw
      .replaceAll('\r\n', '↵')
      .replaceAll('\n', '↵')
      .replaceAll('\r', '↵');
}
