/// 块级 chrome 的纯数值/字符串常量（无 Flutter 依赖）。
///
/// Widget 层见 [MdBlockChrome]；粘贴规范化等纯逻辑可直接引用本类，
/// 避免 `block_ops` 依赖 `material.dart`。
abstract final class MdBlockChromeMetrics {
  /// 无序列表可见前缀（与 Markdown `- ` 对应的 WYSIWYG 字形）。
  static const bulletPrefix = '•  ';

  /// 勾选列表复制用标记（预览选区镜像）；可见前缀为 Material 图标，见 [taskIconSize]。
  static const taskUncheckedPrefix = '☐  ';

  /// 勾选列表已勾选的复制用标记。
  static const taskCheckedPrefix = '☑  ';

  /// 勾选前缀图标边长（与正文 `•` 视觉量级接近，避免系统 ☐/☑ 字形）。
  static const taskIconSize = 18.0;

  /// 勾选图标与正文之间的空隙。
  static const taskPrefixTrailingGap = 6.0;

  /// 勾选前缀槽总宽（renderer / Overlay / 选区镜像必须一致）。
  static const taskPrefixWidth = taskIconSize + taskPrefixTrailingGap;

  /// 无序 / 有序 / 勾选列表共用的前缀槽宽，避免 `1.` 比 `•` / 勾选更靠左。
  static const listPrefixSlotWidth = taskPrefixWidth;

  /// 标题「无标题」与空正文 hint 共用的 [ColorScheme.onSurfaceVariant] 透明度。
  static const hintColorAlpha = 0.55;

  /// 相对行框垂直居中的额外 Y 偏移；0 表示不额外平移。
  static const taskIconOpticalYOffset = 0.0;

  /// 引用正文相对装饰线的左缩进。
  static const quoteIndent = 12.0;

  /// 代码块内边距（渲染 Container / chromeless 补齐）。
  static const codePadding = 12.0;

  /// 空块占位字符：透明空格，保留段落几何供光标测量。
  static const emptyBodyPlaceholder = ' ';

  /// 有序列表前缀，如 `1. `。
  static String orderedPrefix(String marker) => '$marker ';
}
