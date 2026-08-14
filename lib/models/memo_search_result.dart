enum MemoJumpField { title, content }

class MemoJumpTarget {
  const MemoJumpTarget({
    required this.field,
    required this.offset,
    required this.length,
    required this.lineNumber,
  });

  final MemoJumpField field;
  final int offset;
  final int length;
  final int lineNumber;
}

class MemoSearchMatch {
  const MemoSearchMatch({
    required this.lineNumber,
    required this.lineText,
    required this.snippet,
  });

  final int lineNumber;
  final String lineText;
  final String snippet;
}

class MemoSearchResult {
  const MemoSearchResult({
    required this.memoId,
    required this.title,
    required this.snippet,
    required this.jumpTarget,
    required this.matchCount,
    required this.updatedAt,
  });

  final String memoId;
  final String title;
  final String snippet;
  final MemoJumpTarget jumpTarget;
  final int matchCount;
  final DateTime updatedAt;
}
