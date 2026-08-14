/// 解析器与块触发共用的块级 Markdown 行正则。
///
/// 集中定义，避免 [parseMarkdownBlocks] 与 [applyBlockTrigger] 正则漂移。
abstract final class MdSyntaxPatterns {
  static final headingLine = RegExp(r'^(#{1,6})\s+(.*)$');
  static final imageLine = RegExp(r'^!\[(.*)\]\((.+)\)$');
  static final bulletLine = RegExp(r'^[-*+]\s+');
  static final bulletTrigger = RegExp(r'^[-*+]\s+(.*)$');
  static final orderedLine = RegExp(r'^(\d+\.)\s+(.*)$');
  static final quotePrefix = RegExp(r'^>\s?');
}
