import 'package:flutter/rendering.dart';

import 'ast/md_inline.dart';

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
