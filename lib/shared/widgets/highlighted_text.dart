import 'package:flutter/material.dart';

class HighlightedText extends StatelessWidget {
  const HighlightedText({
    super.key,
    required this.text,
    required this.keywords,
    required this.caseSensitive,
    this.style,
    this.highlightStyle,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final List<String> keywords;
  final bool caseSensitive;
  final TextStyle? style;
  final TextStyle? highlightStyle;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = style ?? theme.textTheme.bodyMedium;
    final activeHighlightStyle = highlightStyle ??
        baseStyle?.copyWith(
          backgroundColor: theme.colorScheme.tertiaryContainer,
          color: theme.colorScheme.onTertiaryContainer,
          fontWeight: FontWeight.w600,
        );

    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: _buildSpans(
          text: text,
          keywords: keywords,
          caseSensitive: caseSensitive,
          highlightStyle: activeHighlightStyle,
          baseStyle: baseStyle,
        ),
      ),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.ellipsis,
    );
  }

  static List<String> splitKeywords(String query) {
    return query
        .trim()
        .split(RegExp(r'\s+'))
        .where((keyword) => keyword.isNotEmpty)
        .toList();
  }

  static List<InlineSpan> _buildSpans({
    required String text,
    required List<String> keywords,
    required bool caseSensitive,
    required TextStyle? highlightStyle,
    required TextStyle? baseStyle,
  }) {
    if (text.isEmpty || keywords.isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    final ranges = _findHighlightRanges(
      text: text,
      keywords: keywords,
      caseSensitive: caseSensitive,
    );
    if (ranges.isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final range in ranges) {
      if (range.start > cursor) {
        spans.add(TextSpan(
          text: text.substring(cursor, range.start),
          style: baseStyle,
        ));
      }
      spans.add(TextSpan(
        text: text.substring(range.start, range.end),
        style: highlightStyle,
      ));
      cursor = range.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(
        text: text.substring(cursor),
        style: baseStyle,
      ));
    }

    return spans;
  }

  static List<({int start, int end})> _findHighlightRanges({
    required String text,
    required List<String> keywords,
    required bool caseSensitive,
  }) {
    final ranges = <({int start, int end})>[];

    for (final keyword in keywords) {
      if (keyword.isEmpty) {
        continue;
      }

      final source = caseSensitive ? text : text.toLowerCase();
      final target = caseSensitive ? keyword : keyword.toLowerCase();
      var start = 0;
      while (start <= source.length - target.length) {
        final index = source.indexOf(target, start);
        if (index < 0) {
          break;
        }
        ranges.add((start: index, end: index + keyword.length));
        start = index + 1;
      }
    }

    if (ranges.isEmpty) {
      return ranges;
    }

    ranges.sort((a, b) => a.start.compareTo(b.start));
    final merged = <({int start, int end})>[ranges.first];
    for (var i = 1; i < ranges.length; i++) {
      final current = ranges[i];
      final last = merged.last;
      if (current.start <= last.end) {
        merged[merged.length - 1] = (
          start: last.start,
          end: current.end > last.end ? current.end : last.end,
        );
      } else {
        merged.add(current);
      }
    }
    return merged;
  }
}
