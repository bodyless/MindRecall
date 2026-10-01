/// 解析器与块触发共用的块级 Markdown 行正则。
///
/// 集中定义，避免 [parseMarkdownBlocks] 与 [applyBlockTrigger] 正则漂移。
abstract final class MdSyntaxPatterns {
  static final headingLine = RegExp(r'^(#{1,6})\s+(.*)$');
  static final imageLine = RegExp(r'^!\[(.*)\]\((.+)\)$');

  /// 单独成行图片：`![alt](destination)` 或双引号标题 `![alt](destination "title")`。
  static final standaloneImageLine = RegExp(r'^!\[(.*)\]\((.+)\)\s*$');

  /// 括号内「路径 + 空格 + 双引号标题」。不认单引号标题。
  static final imageDestinationWithTitle = RegExp(r'^(.+?)\s+"([^"]*)"$');
  static final bulletLine = RegExp(r'^[-*+]\s+');
  static final bulletTrigger = RegExp(r'^[-*+]\s+(.*)$');
  /// GFM 勾选行：`- [ ] text` / `- [x] text`（须先于 [bulletLine] 匹配）。
  static final taskLine = RegExp(r'^[-*+]\s+\[([ xX])\](?:\s+(.*))?$');
  /// 已是无序列表时，行首再输入 `[ ]` / `[x]` 转为勾选块。
  static final taskBodyMarker = RegExp(r'^\[([ xX])\](?:\s+(.*))?$');
  static final orderedLine = RegExp(r'^(\d+\.)\s+(.*)$');
  static final quotePrefix = RegExp(r'^>\s?');
  /// 分割线：行首最多 3 空格 + 连续 ≥3 个同字符 `-` / `*` / `_`；不认 `- - -`。
  static final thematicBreakLine = RegExp(r'^ {0,3}(-{3,}|\*{3,}|_{3,})\s*$');

  static bool taskMarkerIsChecked(String marker) =>
      marker.toLowerCase() == 'x';
}

/// 单独成行的图片。非该形式返回 null（含段落中的行内图片）。
({String alt, String destination, String? title})? parseStandaloneImageLine(
  String line,
) {
  final match = MdSyntaxPatterns.standaloneImageLine.firstMatch(line.trim());
  if (match == null) {
    return null;
  }
  final alt = match.group(1) ?? '';
  final inside = match.group(2) ?? '';
  final titled = MdSyntaxPatterns.imageDestinationWithTitle.firstMatch(inside);
  if (titled == null) {
    return (alt: alt, destination: inside, title: null);
  }
  final destination = titled.group(1) ?? '';
  if (destination.isEmpty) {
    return null;
  }
  final rawTitle = titled.group(2) ?? '';
  return (
    alt: alt,
    destination: destination,
    title: rawTitle.isEmpty ? null : rawTitle,
  );
}

/// 写回单独成行图片。空标题不带引号。
String formatStandaloneImageLine({
  required String alt,
  required String destination,
  String? title,
}) {
  if (title == null || title.isEmpty) {
    return '![$alt]($destination)';
  }
  return '![$alt]($destination "$title")';
}
