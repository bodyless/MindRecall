/// 块级 chrome 的纯数值/字符串常量（无 Flutter 依赖）。
///
/// Widget 层见 [MdBlockChrome]；粘贴规范化等纯逻辑可直接引用本类，
/// 避免 `block_ops` 依赖 `material.dart`。
abstract final class MdBlockChromeMetrics {
  /// 无序列表可见前缀（与 Markdown `- ` 对应的 WYSIWYG 字形）。
  static const bulletPrefix = '•  ';

  /// 引用正文相对装饰线的左缩进。
  static const quoteIndent = 12.0;

  /// 代码块内边距（渲染 Container / chromeless 补齐）。
  static const codePadding = 12.0;

  /// 空块占位字符：透明空格，保留段落几何供光标测量。
  static const emptyBodyPlaceholder = ' ';

  /// 有序列表前缀，如 `1. `。
  static String orderedPrefix(String marker) => '$marker ';
}
