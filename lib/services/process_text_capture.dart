/// 将系统选区文本规范为可写入笔记的正文；空选区返回 null。
String? normalizeCapturedProcessText(String? raw) {
  if (raw == null) {
    return null;
  }
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

/// 当前活动笔记无标题且无正文时，应填入该篇而非再新建。
bool shouldReuseEmptyActiveMemo({
  required String title,
  required String content,
}) {
  return title.trim().isEmpty && content.trim().isEmpty;
}
