import 'package:flutter/rendering.dart';

import 'ast/md_inline.dart';
import 'md_block_chrome_metrics.dart';

/// 将渲染层 display offset 映射回 plain offset（链接标题等可能不等长）。
int displayOffsetToPlainOffset({
  required int displayOffset,
  required String plainText,
  required String displayText,
  required String? displayMarkdown,
  String? Function(String href)? resolveLinkLabel,
}) {
  if (plainText.isEmpty) {
    return 0;
  }
  if (displayOffset <= 0) {
    return 0;
  }
  if (plainText == displayText || displayMarkdown == null) {
    return displayOffset.clamp(0, plainText.length);
  }

  final nodes = parseInlineMarkdown(displayMarkdown);
  var displayRemaining = displayOffset;
  var plain = 0;
  for (final node in nodes) {
    final plainLen = node.plainText.length;
    final shown = switch (node) {
      LinkInline(:final label, :final href) => linkDisplayLabel(
          label: label,
          href: href,
          resolvedTitle: resolveLinkLabel?.call(href),
        ),
      _ => node.plainText,
    };
    if (displayRemaining <= shown.length) {
      if (shown.length == plainLen) {
        return (plain + displayRemaining).clamp(0, plainText.length);
      }
      if (displayRemaining <= 0) {
        return plain.clamp(0, plainText.length);
      }
      if (displayRemaining >= shown.length) {
        return (plain + plainLen).clamp(0, plainText.length);
      }
      final ratio = displayRemaining / shown.length;
      return (plain + (ratio * plainLen).round().clamp(0, plainLen))
          .clamp(0, plainText.length);
    }
    displayRemaining -= shown.length;
    plain += plainLen;
  }
  return plain.clamp(0, plainText.length);
}

/// 在块槽位内按全局坐标命中正文 [RenderParagraph]，得到 plain caret offset。
///
/// 找不到段落或坐标无效时返回 null（调用方回退到块末）。
int? plainOffsetAtGlobalTap({
  required RenderObject? slotRoot,
  required Offset globalPosition,
  required String plainText,
  required RenderParagraph? Function(RenderObject? root, {required String plainText})
      findBodyParagraph,
  String? displayMarkdown,
  String? Function(String href)? resolveLinkLabel,
}) {
  if (plainText.isEmpty) {
    return 0;
  }
  if (slotRoot == null) {
    return null;
  }
  final paragraph = findBodyParagraph(slotRoot, plainText: plainText);
  if (paragraph == null) {
    return null;
  }
  final local = paragraph.globalToLocal(globalPosition);
  final size = paragraph.size;
  final clamped = Offset(
    local.dx.clamp(0.0, size.width),
    local.dy.clamp(0.0, size.height),
  );
  final displayOffset = paragraph.getPositionForOffset(clamped).offset;
  final displayText = paragraph.text.toPlainText();
  return displayOffsetToPlainOffset(
    displayOffset: displayOffset,
    plainText: plainText,
    displayText: displayText,
    displayMarkdown: displayMarkdown,
    resolveLinkLabel: resolveLinkLabel,
  );
}

/// 列表 chrome 前缀段落（`•  ` / `1. ` / 勾选字符），不能当正文测光标。
bool isListChromePrefixPlain(String text) {
  if (text == MdBlockChromeMetrics.bulletPrefix ||
      text == MdBlockChromeMetrics.taskUncheckedPrefix ||
      text == MdBlockChromeMetrics.taskCheckedPrefix) {
    return true;
  }
  // 有序前缀整段即 `12. ` 这种；正文即使以数字开头也不会整段都是前缀。
  return RegExp(r'^\d+\.\s$').hasMatch(text);
}

/// 将 plain caret 映射为渲染层 display offset（链接标题等可能不等长）。
int plainOffsetToDisplayOffset({
  required int plainOffset,
  required String plainText,
  required String displayText,
  required String? displayMarkdown,
  String? Function(String href)? resolveLinkLabel,
}) {
  if (plainOffset >= plainText.length) {
    return displayText.length;
  }
  if (plainText == displayText || displayMarkdown == null) {
    return plainOffset.clamp(0, displayText.length);
  }

  final nodes = parseInlineMarkdown(displayMarkdown);
  var plainRemaining = plainOffset;
  var display = 0;
  for (final node in nodes) {
    final plainLen = node.plainText.length;
    final shown = switch (node) {
      LinkInline(:final label, :final href) => linkDisplayLabel(
          label: label,
          href: href,
          resolvedTitle: resolveLinkLabel?.call(href),
        ),
      _ => node.plainText,
    };
    if (plainRemaining <= plainLen) {
      if (shown.length == plainLen) {
        return display + plainRemaining;
      }
      if (plainRemaining <= 0) {
        return display;
      }
      if (plainRemaining >= plainLen) {
        return display + shown.length;
      }
      final ratio = plainRemaining / plainLen;
      return display + (ratio * shown.length).round().clamp(0, shown.length);
    }
    plainRemaining -= plainLen;
    display += shown.length;
  }
  return display.clamp(0, displayText.length);
}

/// 渲染层测光标用的 [TextPosition]。
///
/// 文末必须 [TextAffinity.upstream]，否则刚好在软换行边界时 caret 会被送到
/// 下一行行首，而系统选区手柄仍停在上一行行尾，看起来偏右。
TextPosition caretTextPositionForDisplay({
  required int displayOffset,
  required int displayLength,
  TextAffinity affinity = TextAffinity.downstream,
}) {
  final offset = displayOffset.clamp(0, displayLength);
  if (offset >= displayLength && displayLength > 0) {
    return TextPosition(offset: offset, affinity: TextAffinity.upstream);
  }
  return TextPosition(offset: offset, affinity: affinity);
}

/// 在块槽位内找到正文 [RenderParagraph]（跳过列表 `•` / `1.` 前缀）。
RenderParagraph? findLiveBodyParagraph(
  RenderObject? root, {
  required String plainText,
}) {
  if (root == null) {
    return null;
  }
  final paragraphs = <RenderParagraph>[];
  void visit(RenderObject node) {
    if (node is RenderParagraph) {
      paragraphs.add(node);
    }
    node.visitChildren(visit);
  }

  visit(root);
  if (paragraphs.isEmpty) {
    return null;
  }

  bool isPrefix(RenderParagraph paragraph) =>
      isListChromePrefixPlain(paragraph.text.toPlainText());

  // 空块占位是透明空格「 」；勿误用列表「• 」前缀段落。
  if (plainText.isEmpty) {
    for (final paragraph in paragraphs) {
      if (isPrefix(paragraph)) {
        continue;
      }
      final text = paragraph.text.toPlainText();
      if (text == ' ' || text == '\u200B' || text.isEmpty) {
        return paragraph;
      }
    }
    for (final paragraph in paragraphs) {
      if (isPrefix(paragraph)) {
        continue;
      }
      return paragraph;
    }
    return paragraphs.last;
  }

  for (final paragraph in paragraphs) {
    if (isPrefix(paragraph)) {
      continue;
    }
    final text = paragraph.text.toPlainText();
    if (text == plainText) {
      return paragraph;
    }
  }

  // 列表块另有前缀段落，取最宽的正文段落。
  final body = paragraphs.where((paragraph) => !isPrefix(paragraph)).toList();
  final ranked = body.isEmpty ? paragraphs : body;
  ranked.sort((a, b) => b.size.width.compareTo(a.size.width));
  return ranked.first;
}

/// Material 折叠水滴边长（与 Flutter `_kHandleSize` 一致）。
const double kLiveCollapsedCaretHandleSize = 22.0;

/// 光标条宽度。折叠水滴对准其中线，避免贴左缘看起来比光标提前 1–2px。
const double kTextCaretWidth = 2.0;

/// Material 折叠手柄锚点：相对手柄左上，对准光标底边中点。
const Offset kLiveCollapsedCaretHandleAnchor = Offset(
  kLiveCollapsedCaretHandleSize / 2,
  -4,
);

/// 折叠水滴左上角（overlay 坐标）：对准光标底边中线。
Offset liveCollapsedCaretHandleTopLeft({
  required Offset caretTopLeft,
  required double caretWidth,
  required double caretHeight,
}) {
  final caretBottomCenter = Offset(
    caretTopLeft.dx + caretWidth / 2,
    caretTopLeft.dy + caretHeight,
  );
  return caretBottomCenter - kLiveCollapsedCaretHandleAnchor;
}

/// 把 Material 折叠锚点从光标左缘改到光标中线（右移 [kTextCaretWidth]/2）。
Offset alignedCollapsedHandleAnchor(Offset materialCollapsedAnchor) {
  return Offset(
    materialCollapsedAnchor.dx - kTextCaretWidth / 2,
    materialCollapsedAnchor.dy,
  );
}

/// 对齐编辑模式：点选显示折叠水滴，打字（文本变了）后隐藏。
bool liveCollapsedHandleVisibleAfterEdit({
  required bool visible,
  required bool textChanged,
  required bool revealFromUserTap,
}) {
  if (revealFromUserTap) {
    return true;
  }
  if (textChanged) {
    return false;
  }
  return visible;
}
