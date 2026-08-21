import 'package:flutter/material.dart';

/// Markdown 正文编辑辅助：基于 [TextEditingController] 选区插入语法。
class MarkdownEditorHelper {
  static void wrapSelection(
    TextEditingController controller, {
    required String left,
    required String right,
  }) {
    final text = controller.text;
    final selection = controller.selection;
    if (!selection.isValid) {
      return;
    }

    if (selection.isCollapsed) {
      final position = selection.start;
      final newText =
          text.substring(0, position) + left + right + text.substring(position);
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: position + left.length),
      );
      return;
    }

    final selected = text.substring(selection.start, selection.end);
    final newText = text.substring(0, selection.start) +
        left +
        selected +
        right +
        text.substring(selection.end);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: selection.start + left.length,
        extentOffset: selection.end + left.length,
      ),
    );
  }

  static void applyHeading(TextEditingController controller, int level) {
    final safeLevel = level.clamp(1, 6);
    _transformSelectedLines(
      controller,
      (line) {
        final stripped = line.replaceFirst(RegExp(r'^#{1,6}\s*'), '');
        return '${'#' * safeLevel} $stripped';
      },
    );
  }

  static void applyLinePrefix(
    TextEditingController controller, {
    required String prefix,
    RegExp? replaceExisting,
  }) {
    _transformSelectedLines(
      controller,
      (line) {
        final stripped =
            replaceExisting == null ? line : line.replaceFirst(replaceExisting, '');
        if (stripped.startsWith(prefix)) {
          return stripped;
        }
        return '$prefix$stripped';
      },
    );
  }

  /// 当前行转为未勾选 GFM 任务项；去掉旧块前缀（含 `- [ ]` / `- [x]`）。
  static void applyTaskList(TextEditingController controller) {
    _transformSelectedLines(
      controller,
      (line) {
        final stripped = line.replaceFirst(_existingBlockPrefix, '');
        return stripped.isEmpty ? '- [ ]' : '- [ ] $stripped';
      },
    );
  }

  /// 标题 / 引用 / 有序 / 无序 / 勾选 行首前缀。
  static final _existingBlockPrefix = RegExp(
    r'^(?:#{1,6}\s+|>\s*|\d+\.\s+|[-*+]\s+\[([ xX])\]\s*|[-*+]\s+)',
  );

  static void applyOrderedList(TextEditingController controller) {
    var index = 1;
    _transformSelectedLines(
      controller,
      (line) {
        final stripped = line.replaceFirst(RegExp(r'^\d+\.\s*'), '');
        final item = '$index. $stripped';
        index++;
        return item;
      },
    );
  }

  static void insertAtCursor(TextEditingController controller, String text) {
    final value = controller.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    final newText =
        value.text.substring(0, start) + text + value.text.substring(end);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + text.length),
    );
  }

  static const _thematicBreakSnippet = '\n---\n';

  /// 在光标处插入 Markdown 分割线。
  static void insertThematicBreak(TextEditingController controller) {
    insertAtCursor(controller, _thematicBreakSnippet);
  }

  /// 插入或包裹 Markdown 链接 `[text](url)`。
  static void applyLink(
    TextEditingController controller, {
    required String url,
    String? displayText,
  }) {
    final selection = controller.selection;
    if (!selection.isValid) {
      return;
    }
    final selected = selection.isCollapsed
        ? ''
        : controller.text.substring(selection.start, selection.end);
    final label = (displayText != null && displayText.trim().isNotEmpty)
        ? displayText.trim()
        : (selected.isNotEmpty ? selected : url);
    final markdown = '[$label]($url)';
    if (selection.isCollapsed) {
      insertAtCursor(controller, markdown);
      return;
    }
    final text = controller.text;
    final newText = text.substring(0, selection.start) +
        markdown +
        text.substring(selection.end);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + markdown.length,
      ),
    );
  }

  static void _transformSelectedLines(
    TextEditingController controller,
    String Function(String line) transform,
  ) {
    final text = controller.text;
    final selection = controller.selection;
    if (!selection.isValid) {
      return;
    }

    final range = selectedLineRange(text, selection);
    final block = text.substring(range.start, range.end);
    final lines = block.split('\n');
    final transformed = lines.map(transform).join('\n');
    final collapsed = selection.isCollapsed;

    final newText =
        text.substring(0, range.start) + transformed + text.substring(range.end);
    if (collapsed) {
      final delta = transformed.length - block.length;
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: (selection.start + delta).clamp(0, newText.length),
        ),
      );
      return;
    }

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: range.start,
        extentOffset: range.start + transformed.length,
      ),
    );
  }

  @visibleForTesting
  static ({int start, int end}) selectedLineRange(
    String text,
    TextSelection selection,
  ) {
    final anchorStart = selection.start < selection.end
        ? selection.start
        : selection.end;
    final anchorEnd =
        selection.start < selection.end ? selection.end : selection.start;

    var lineStart = 0;
    if (anchorStart > 0) {
      final previousBreak = text.lastIndexOf('\n', anchorStart - 1);
      lineStart = previousBreak == -1 ? 0 : previousBreak + 1;
    }

    var lineEnd = text.length;
    if (anchorEnd < text.length) {
      final nextBreak = text.indexOf('\n', anchorEnd);
      lineEnd = nextBreak == -1 ? text.length : nextBreak;
    }

    return (start: lineStart, end: lineEnd);
  }
}
