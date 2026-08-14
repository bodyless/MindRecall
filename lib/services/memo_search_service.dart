import 'package:flutter/foundation.dart';

import '../models/memo.dart';
import '../models/memo_search_result.dart';

class MemoSearchService {
  List<MemoSearchResult> searchMemos({
    required List<Memo> memos,
    required String query,
    required bool caseSensitive,
    String untitledLabel = 'Untitled',
  }) {
    final keywords = splitKeywords(query);
    if (keywords.isEmpty) {
      return [];
    }

    final results = <MemoSearchResult>[];
    for (final memo in memos) {
      final result = _searchMemo(
        memo,
        keywords,
        caseSensitive,
        untitledLabel: untitledLabel,
      );
      if (result != null) {
        results.add(result);
      }
    }

    results.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return results;
  }

  @visibleForTesting
  List<String> splitKeywords(String query) {
    return query
        .trim()
        .split(RegExp(r'\s+'))
        .where((keyword) => keyword.isNotEmpty)
        .toList();
  }

  MemoSearchResult? _searchMemo(
    Memo memo,
    List<String> keywords,
    bool caseSensitive, {
    required String untitledLabel,
  }) {
    if (!_containsAllKeywords(
      memo.title,
      memo.content,
      keywords,
      caseSensitive,
    )) {
      return null;
    }

    final jumpTarget = findFirstJumpTarget(
      title: memo.title,
      content: memo.content,
      keywords: keywords,
      caseSensitive: caseSensitive,
    );
    if (jumpTarget == null) {
      return null;
    }

    final snippet = buildSnippet(
      title: memo.title,
      content: memo.content,
      keywords: keywords,
      caseSensitive: caseSensitive,
    );
    final matchCount = countMatches(
      title: memo.title,
      content: memo.content,
      keywords: keywords,
      caseSensitive: caseSensitive,
    );

    return MemoSearchResult(
      memoId: memo.id,
      title: memo.displayTitle(untitledLabel),
      snippet: snippet,
      jumpTarget: jumpTarget,
      matchCount: matchCount,
      updatedAt: memo.updatedAt,
    );
  }

  @visibleForTesting
  bool containsAllKeywords({
    required String title,
    required String content,
    required List<String> keywords,
    required bool caseSensitive,
  }) {
    return _containsAllKeywords(title, content, keywords, caseSensitive);
  }

  bool _containsAllKeywords(
    String title,
    String content,
    List<String> keywords,
    bool caseSensitive,
  ) {
    for (final keyword in keywords) {
      if (!_containsKeyword(title, keyword, caseSensitive) &&
          !_containsKeyword(content, keyword, caseSensitive)) {
        return false;
      }
    }
    return true;
  }

  bool _containsKeyword(String text, String keyword, bool caseSensitive) {
    if (caseSensitive) {
      return text.contains(keyword);
    }
    return text.toLowerCase().contains(keyword.toLowerCase());
  }

  @visibleForTesting
  MemoJumpTarget? findFirstJumpTarget({
    required String title,
    required String content,
    required List<String> keywords,
    required bool caseSensitive,
  }) {
    final titleMatch = _earliestMatchInText(title, keywords, caseSensitive);
    if (titleMatch != null) {
      return MemoJumpTarget(
        field: MemoJumpField.title,
        offset: titleMatch.offset,
        length: titleMatch.length,
        lineNumber: 1,
      );
    }

    final contentMatch = _earliestMatchInText(content, keywords, caseSensitive);
    if (contentMatch != null) {
      return MemoJumpTarget(
        field: MemoJumpField.content,
        offset: contentMatch.offset,
        length: contentMatch.length,
        lineNumber: _lineNumberAtOffset(content, contentMatch.offset),
      );
    }

    return null;
  }

  ({int offset, int length})? _earliestMatchInText(
    String text,
    List<String> keywords,
    bool caseSensitive,
  ) {
    ({int offset, int length})? earliest;
    for (final keyword in keywords) {
      final match = _findFirstInText(text, keyword, caseSensitive);
      if (match != null && (earliest == null || match.offset < earliest.offset)) {
        earliest = match;
      }
    }
    return earliest;
  }

  ({int offset, int length})? _findFirstInText(
    String text,
    String keyword,
    bool caseSensitive,
  ) {
    if (text.isEmpty) {
      return null;
    }

    final source = caseSensitive ? text : text.toLowerCase();
    final target = caseSensitive ? keyword : keyword.toLowerCase();
    final index = source.indexOf(target);
    if (index < 0) {
      return null;
    }
    return (offset: index, length: keyword.length);
  }

  @visibleForTesting
  String buildSnippet({
    required String title,
    required String content,
    required List<String> keywords,
    required bool caseSensitive,
  }) {
    final contentLines = content.split('\n');
    for (var i = 0; i < contentLines.length; i++) {
      if (_lineMatchesKeywords(contentLines[i], keywords, caseSensitive)) {
        return _truncateSnippet('${i + 1}: ${contentLines[i]}');
      }
    }

    if (_lineMatchesKeywords(title, keywords, caseSensitive)) {
      return _truncateSnippet('标题: $title');
    }

    if (contentLines.isNotEmpty && contentLines.first.trim().isNotEmpty) {
      return _truncateSnippet(contentLines.first);
    }
    if (title.trim().isNotEmpty) {
      return _truncateSnippet(title);
    }
    return '（空文件）';
  }

  bool _lineMatchesKeywords(
    String line,
    List<String> keywords,
    bool caseSensitive,
  ) {
    for (final keyword in keywords) {
      if (_containsKeyword(line, keyword, caseSensitive)) {
        return true;
      }
    }
    return false;
  }

  String _truncateSnippet(String text, {int maxLength = 56}) {
    final normalized = text.trim();
    if (normalized.length <= maxLength) {
      return normalized;
    }
    return '${normalized.substring(0, maxLength)}…';
  }

  @visibleForTesting
  int countMatches({
    required String title,
    required String content,
    required List<String> keywords,
    required bool caseSensitive,
  }) {
    var count = 0;
    for (final keyword in keywords) {
      count += _countOccurrences(title, keyword, caseSensitive);
      count += _countOccurrences(content, keyword, caseSensitive);
    }
    return count;
  }

  int _countOccurrences(String text, String keyword, bool caseSensitive) {
    if (text.isEmpty || keyword.isEmpty) {
      return 0;
    }

    final source = caseSensitive ? text : text.toLowerCase();
    final target = caseSensitive ? keyword : keyword.toLowerCase();
    var count = 0;
    var start = 0;
    while (true) {
      final index = source.indexOf(target, start);
      if (index < 0) {
        break;
      }
      count++;
      start = index + target.length;
    }
    return count;
  }

  int _lineNumberAtOffset(String content, int offset) {
    if (content.isEmpty) {
      return 1;
    }
    final safeOffset = offset.clamp(0, content.length);
    return content.substring(0, safeOffset).split('\n').length;
  }
}
