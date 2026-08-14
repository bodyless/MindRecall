/// 行内 Markdown AST（粗体、斜体、代码、纯文本）。
sealed class MdInline {
  const MdInline();

  String get plainText;

  String toMarkdown();
}

final class TextInline extends MdInline {
  const TextInline(this.text);

  final String text;

  @override
  String get plainText => text;

  @override
  String toMarkdown() => text;
}

final class BoldInline extends MdInline {
  const BoldInline(this.children);

  final List<MdInline> children;

  @override
  String get plainText => children.map((child) => child.plainText).join();

  @override
  String toMarkdown() => '**${children.map((c) => c.toMarkdown()).join()}**';
}

final class ItalicInline extends MdInline {
  const ItalicInline(this.children);

  final List<MdInline> children;

  @override
  String get plainText => children.map((child) => child.plainText).join();

  @override
  String toMarkdown() => '*${children.map((c) => c.toMarkdown()).join()}*';
}

final class CodeInline extends MdInline {
  const CodeInline(this.text);

  final String text;

  @override
  String get plainText => text;

  @override
  String toMarkdown() => '`$text`';
}

final class LinkInline extends MdInline {
  const LinkInline({
    required this.label,
    required this.href,
  });

  final String label;
  final String href;

  @override
  String get plainText => label;

  @override
  String toMarkdown() => '[$label]($href)';
}

/// 链接可见文字：优先使用 markdown 标签；仅当标签仍是原始 href / 文件名时，
/// 才用 [resolvedTitle]（如本地 `./日期.md` → 文档标题）。
String linkDisplayLabel({
  required String label,
  required String href,
  String? resolvedTitle,
}) {
  final trimmedLabel = label.trim();
  if (resolvedTitle == null || resolvedTitle.isEmpty) {
    return trimmedLabel.isEmpty ? href : label;
  }
  if (trimmedLabel.isEmpty) {
    return resolvedTitle;
  }
  final trimmedHref = href.trim();
  if (trimmedLabel == trimmedHref) {
    return resolvedTitle;
  }
  final baseName = trimmedHref.replaceAll('\\', '/').split('/').last;
  if (baseName.isNotEmpty &&
      (trimmedLabel == baseName || trimmedLabel == './$baseName')) {
    return resolvedTitle;
  }
  return label;
}

enum InlineStyle { bold, italic, code }

/// 将行内 Markdown 解析为 [MdInline] 节点列表。
List<MdInline> parseInlineMarkdown(String input) {
  if (input.isEmpty) {
    return const [];
  }

  final nodes = <MdInline>[];
  // 链接须优先；三星/三下划线须在 ** / * 之前匹配。
  final pattern = RegExp(
    r'(\[[^\]]+\]\([^)]+\)|\*\*\*.+?\*\*\*|___.+?___|\*\*.+?\*\*|__.+?__|\*.+?\*|_.+?_|`.+?`)',
  );
  var start = 0;

  for (final match in pattern.allMatches(input)) {
    if (match.start > start) {
      nodes.add(TextInline(input.substring(start, match.start)));
    }
    final token = match.group(0)!;
    if (token.startsWith('[')) {
      final link = RegExp(r'^\[([^\]]+)\]\(([^)]+)\)$').firstMatch(token)!;
      nodes.add(LinkInline(label: link.group(1)!, href: link.group(2)!));
    } else if (_isWrapped(token, '***') || _isWrapped(token, '___')) {
      final markerLen = 3;
      final inner = token.substring(markerLen, token.length - markerLen);
      nodes.add(BoldInline([ItalicInline(parseInlineMarkdown(inner))]));
    } else if (_isWrapped(token, '**') || _isWrapped(token, '__')) {
      final markerLen = 2;
      final inner = token.substring(markerLen, token.length - markerLen);
      nodes.add(BoldInline(parseInlineMarkdown(inner)));
    } else if (token.startsWith('`') &&
        token.endsWith('`') &&
        token.length >= 2) {
      nodes.add(CodeInline(token.substring(1, token.length - 1)));
    } else if (token.length >= 2) {
      final inner = token.substring(1, token.length - 1);
      nodes.add(ItalicInline(parseInlineMarkdown(inner)));
    } else {
      nodes.add(TextInline(token));
    }
    start = match.end;
  }

  if (start < input.length) {
    nodes.add(TextInline(input.substring(start)));
  }
  return nodes;
}

/// 是否为完整成对标记包裹（避免 `***` 被 `*.+?*` 匹配后误走三星分支导致 RangeError）。
bool _isWrapped(String token, String marker) {
  final n = marker.length;
  return token.length >= n * 2 + 1 &&
      token.startsWith(marker) &&
      token.endsWith(marker);
}

String serializeInlineMarkdown(List<MdInline> nodes) {
  return nodes.map((node) => node.toMarkdown()).join();
}

String plainTextFromInlines(List<MdInline> nodes) {
  return nodes.map((node) => node.plainText).join();
}

/// 按 plain 文本偏移拆分行内 markdown。
({String before, String after}) splitInlineMarkdown(
  String markdown,
  int plainOffset,
) {
  final nodes = parseInlineMarkdown(markdown);
  final totalPlain = plainTextFromInlines(nodes).length;
  final offset = plainOffset.clamp(0, totalPlain);
  final (beforeNodes, afterNodes) = splitInlineNodesAt(nodes, offset);
  return (
    before: serializeInlineMarkdown(beforeNodes),
    after: serializeInlineMarkdown(afterNodes),
  );
}

(List<MdInline> before, List<MdInline> after) splitInlineNodesAt(
  List<MdInline> nodes,
  int plainOffset,
) {
  final before = <MdInline>[];
  final after = <MdInline>[];
  var remaining = plainOffset;
  var splitDone = false;

  for (final node in nodes) {
    if (splitDone) {
      after.add(node);
      continue;
    }

    final length = node.plainText.length;
    if (remaining >= length) {
      before.add(node);
      remaining -= length;
      continue;
    }

    if (remaining <= 0) {
      after.add(node);
      splitDone = true;
      continue;
    }

    final (left, right) = splitMdInlineNode(node, remaining);
    if (left != null) {
      before.add(left);
    }
    if (right != null) {
      after.add(right);
    }
    splitDone = true;
  }

  return (before, after);
}

(MdInline? left, MdInline? right) splitMdInlineNode(MdInline node, int offset) {
  final length = node.plainText.length;
  if (offset <= 0) {
    return (null, node);
  }
  if (offset >= length) {
    return (node, null);
  }

  switch (node) {
    case TextInline(:final text):
      return (
        TextInline(text.substring(0, offset)),
        TextInline(text.substring(offset)),
      );
    case BoldInline(:final children):
      final (before, after) = splitInlineNodesAt(children, offset);
      return (
        before.isEmpty ? null : BoldInline(before),
        after.isEmpty ? null : BoldInline(after),
      );
    case ItalicInline(:final children):
      final (before, after) = splitInlineNodesAt(children, offset);
      return (
        before.isEmpty ? null : ItalicInline(before),
        after.isEmpty ? null : ItalicInline(after),
      );
    case CodeInline(:final text):
      return (
        CodeInline(text.substring(0, offset)),
        CodeInline(text.substring(offset)),
      );
    case LinkInline(:final label, :final href):
      return (
        LinkInline(label: label.substring(0, offset), href: href),
        LinkInline(label: label.substring(offset), href: href),
      );
  }
}

/// 将 plain 文本编辑应用到行内 markdown，保留已有样式。
String applyPlainTextChange({
  required String markdown,
  required String previousPlain,
  required String newPlain,
}) {
  if (previousPlain == newPlain) {
    return markdown;
  }

  final nodes = parseInlineMarkdown(markdown);
  if (plainTextFromInlines(nodes) != previousPlain) {
    return newPlain;
  }

  var prefix = 0;
  while (prefix < previousPlain.length &&
      prefix < newPlain.length &&
      previousPlain.codeUnitAt(prefix) == newPlain.codeUnitAt(prefix)) {
    prefix++;
  }

  var oldEnd = previousPlain.length;
  var newEnd = newPlain.length;
  while (oldEnd > prefix &&
      newEnd > prefix &&
      previousPlain.codeUnitAt(oldEnd - 1) == newPlain.codeUnitAt(newEnd - 1)) {
    oldEnd--;
    newEnd--;
  }

  final replacement = newPlain.substring(prefix, newEnd);
  final updated = replacePlainTextInNodes(
    nodes,
    prefix,
    oldEnd,
    replacement,
  );
  return serializeInlineMarkdown(updated);
}

List<MdInline> replacePlainTextInNodes(
  List<MdInline> nodes,
  int start,
  int end,
  String replacement,
) {
  final (before, rest) = splitInlineNodesAt(nodes, start);
  final (_, after) = splitInlineNodesAt(rest, end - start);
  final styles = stylesAtPlainOffset(nodes, start);
  final middle = replacement.isEmpty
      ? <MdInline>[]
      : [_wrapStyledText(replacement, styles)];
  return [...before, ...middle, ...after];
}

Set<InlineStyle> stylesAtPlainOffset(List<MdInline> nodes, int offset) {
  final segments = _flattenSegments(nodes);
  if (segments.isEmpty) {
    return {};
  }

  final total = plainTextFromInlines(nodes);
  if (offset >= total.length) {
    return {};
  }

  var pos = 0;
  for (final segment in segments) {
    final end = pos + segment.text.length;
    if (offset < end) {
      return segment.styles;
    }
    pos = end;
  }

  return {};
}

/// 合并两段行内 markdown（如 Backspace 合并块时）。
String mergeInlineMarkdown(String leftMarkdown, String rightMarkdown) {
  if (leftMarkdown.isEmpty) {
    return rightMarkdown;
  }
  if (rightMarkdown.isEmpty) {
    return leftMarkdown;
  }
  return serializeInlineMarkdown([
    ...parseInlineMarkdown(leftMarkdown),
    ...parseInlineMarkdown(rightMarkdown),
  ]);
}

/// 在 plain 文本选区上应用或切换行内样式（B/I/代码）。
List<MdInline> applyInlineStyle(
  List<MdInline> nodes,
  int selectionStart,
  int selectionEnd,
  InlineStyle style,
) {
  final plainLength = plainTextFromInlines(nodes).length;
  var start = selectionStart.clamp(0, plainLength);
  var end = selectionEnd.clamp(0, plainLength);
  if (start > end) {
    final temp = start;
    start = end;
    end = temp;
  }

  final segments = _flattenSegments(nodes);
  if (segments.isEmpty && start == end) {
    return [_wrapStyledText('', {style})];
  }

  final updated = <_StyledSegment>[];
  var offset = 0;
  for (final segment in segments) {
    final segmentStart = offset;
    final segmentEnd = offset + segment.text.length;
    offset = segmentEnd;

    if (segmentEnd <= start || segmentStart >= end) {
      updated.add(segment);
      continue;
    }

    final rawLocalStart = start - segmentStart;
    final rawLocalEnd = end - segmentStart;
    if (rawLocalEnd <= 0 || rawLocalStart >= segment.text.length) {
      updated.add(segment);
      continue;
    }

    final localStart = rawLocalStart.clamp(0, segment.text.length);
    final localEnd = rawLocalEnd.clamp(0, segment.text.length);
    if (localEnd < localStart) {
      updated.add(segment);
      continue;
    }
    final text = segment.text;

    if (localStart > 0) {
      updated.add(
        _StyledSegment(
          _safeSubstring(text, 0, localStart),
          segment.styles,
          linkHref: segment.linkHref,
        ),
      );
    }

    final selected = _safeSubstring(text, localStart, localEnd);
    if (selected.isNotEmpty || (start == end && localStart == localEnd)) {
      final targetStyles = Set<InlineStyle>.from(segment.styles);
      if (style == InlineStyle.code) {
        targetStyles
          ..remove(InlineStyle.bold)
          ..remove(InlineStyle.italic);
      }
      if (targetStyles.contains(style)) {
        targetStyles.remove(style);
      } else {
        targetStyles.add(style);
      }
      updated.add(
        _StyledSegment(selected, targetStyles, linkHref: segment.linkHref),
      );
    }

    if (localEnd < text.length) {
      updated.add(
        _StyledSegment(
          _safeSubstring(text, localEnd, text.length),
          segment.styles,
          linkHref: segment.linkHref,
        ),
      );
    }
  }

  final result = _unflattenSegments(_mergeAdjacentSegments(updated));
  return result.isEmpty && nodes.isNotEmpty ? nodes : result;
}

String _safeSubstring(String text, int start, int end) {
  if (text.isEmpty) {
    return '';
  }
  final safeStart = start.clamp(0, text.length);
  final safeEnd = end.clamp(safeStart, text.length);
  return text.substring(safeStart, safeEnd);
}

class _StyledSegment {
  const _StyledSegment(this.text, this.styles, {this.linkHref});

  final String text;
  final Set<InlineStyle> styles;
  final String? linkHref;
}

List<_StyledSegment> _flattenSegments(List<MdInline> nodes) {
  final result = <_StyledSegment>[];
  void walk(List<MdInline> inlineNodes, Set<InlineStyle> styles) {
    for (final node in inlineNodes) {
      switch (node) {
        case TextInline(:final text):
          if (text.isNotEmpty) {
            result.add(_StyledSegment(text, Set.unmodifiable(styles)));
          }
        case BoldInline(:final children):
          walk(children, {...styles, InlineStyle.bold});
        case ItalicInline(:final children):
          walk(children, {...styles, InlineStyle.italic});
        case CodeInline(:final text):
          if (text.isNotEmpty) {
            result.add(
              _StyledSegment(text, const {InlineStyle.code}),
            );
          }
        case LinkInline(:final label, :final href):
          if (label.isNotEmpty) {
            result.add(
              _StyledSegment(
                label,
                Set.unmodifiable(styles),
                linkHref: href,
              ),
            );
          }
      }
    }
  }

  walk(nodes, {});
  return result;
}

List<_StyledSegment> _mergeAdjacentSegments(List<_StyledSegment> segments) {
  if (segments.isEmpty) {
    return segments;
  }
  final merged = <_StyledSegment>[segments.first];
  for (var i = 1; i < segments.length; i++) {
    final previous = merged.last;
    final current = segments[i];
    if (previous.linkHref == current.linkHref &&
        previous.styles.length == current.styles.length &&
        previous.styles.containsAll(current.styles)) {
      merged[merged.length - 1] = _StyledSegment(
        '${previous.text}${current.text}',
        previous.styles,
        linkHref: previous.linkHref,
      );
    } else {
      merged.add(current);
    }
  }
  return merged;
}

List<MdInline> _unflattenSegments(List<_StyledSegment> segments) {
  final nodes = <MdInline>[];
  for (final segment in segments) {
    if (segment.text.isEmpty) {
      continue;
    }
    final href = segment.linkHref;
    if (href != null) {
      nodes.add(LinkInline(label: segment.text, href: href));
      continue;
    }
    nodes.add(_wrapStyledText(segment.text, segment.styles));
  }
  return nodes;
}

MdInline _wrapStyledText(String text, Set<InlineStyle> styles) {
  if (styles.contains(InlineStyle.code)) {
    return CodeInline(text);
  }
  MdInline node = TextInline(text);
  if (styles.contains(InlineStyle.italic)) {
    node = ItalicInline([node]);
  }
  if (styles.contains(InlineStyle.bold)) {
    node = BoldInline([node]);
  }
  return node;
}
