import 'package:flutter/material.dart';

import '../ast/md_block.dart';
import '../md_block_chrome_metrics.dart';
import 'md_block_styles.dart';

/// 块级「外壳」几何：渲染层与 chromeless Overlay **必须共用**，避免前缀宽度/缩进漂移。
///
/// 常量数值见 [MdBlockChromeMetrics]；本类提供 Widget / EdgeInsets 助手。
abstract final class MdBlockChrome {
  static const bulletPrefix = MdBlockChromeMetrics.bulletPrefix;
  static const taskUncheckedPrefix = MdBlockChromeMetrics.taskUncheckedPrefix;
  static const taskCheckedPrefix = MdBlockChromeMetrics.taskCheckedPrefix;
  static const taskIconSize = MdBlockChromeMetrics.taskIconSize;
  static const taskPrefixTrailingGap = MdBlockChromeMetrics.taskPrefixTrailingGap;
  static const taskPrefixWidth = MdBlockChromeMetrics.taskPrefixWidth;
  static const listPrefixSlotWidth = MdBlockChromeMetrics.listPrefixSlotWidth;
  static const hintColorAlpha = MdBlockChromeMetrics.hintColorAlpha;
  static const taskIconOpticalYOffset = MdBlockChromeMetrics.taskIconOpticalYOffset;
  static const quoteIndent = MdBlockChromeMetrics.quoteIndent;
  static const codePadding = MdBlockChromeMetrics.codePadding;
  static const emptyBodyPlaceholder = MdBlockChromeMetrics.emptyBodyPlaceholder;

  /// 有序列表前缀，如 `1. `。
  static String orderedPrefix(String marker) =>
      MdBlockChromeMetrics.orderedPrefix(marker);

  /// 块在横向 Row 中占用的前缀文案；无前缀返回空串。
  static String prefixLabel(MdBlock block) {
    return switch (block) {
      BulletBlock(:final checked) => switch (checked) {
          null => bulletPrefix,
          false => taskUncheckedPrefix,
          true => taskCheckedPrefix,
        },
      OrderedBlock(:final marker) => orderedPrefix(marker),
      _ => '',
    };
  }

  /// chromeless 左侧占位宽度（引用/代码用固定 inset，列表用文字前缀）。
  static double leadingSpacerWidth(MdBlock block) {
    return switch (block) {
      QuoteBlock() || CodeBlock() => quoteIndent,
      _ => 0,
    };
  }

  /// chromeless 中 TextField 外包 padding（代码块补上/右/下，左已由 spacer 承担）。
  static EdgeInsets chromelessBodyPadding(MdBlock block) {
    return switch (block) {
      CodeBlock() => const EdgeInsets.fromLTRB(
          0,
          codePadding,
          codePadding,
          codePadding,
        ),
      _ => EdgeInsets.zero,
    };
  }

  /// 渲染层代码块整体 padding。
  static EdgeInsets codeBlockPadding() => const EdgeInsets.all(codePadding);

  /// 引用正文 padding（仅左）。
  static EdgeInsets quoteBodyPadding() =>
      const EdgeInsets.only(left: quoteIndent);

  /// 构建列表/引用等前缀 Widget；[visible] 为 false 时用于 chromeless 等宽占位。
  ///
  /// [onTaskToggle] 仅勾选块使用；预览不传。`visible: false` 时仍可点且等宽。
  /// [accentColor] 已勾选图标色（一般为 `colorScheme.primary`），与工具栏/侧栏勾选一致。
  static Widget buildPrefix(
    MdBlock block,
    TextStyle? style, {
    required bool visible,
    VoidCallback? onTaskToggle,
    Color? accentColor,
  }) {
    if (block is BulletBlock && block.checked != null) {
      Widget prefix = _taskCheckboxPrefix(
        checked: block.checked!,
        style: style,
        visible: visible,
        accentColor: accentColor,
      );
      if (onTaskToggle != null) {
        prefix = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTaskToggle,
          child: prefix,
        );
      }
      return prefix;
    }
    final label = prefixLabel(block);
    if (label.isNotEmpty) {
      Widget prefix = Text(
        label,
        style: style,
        maxLines: 1,
        softWrap: false,
      );
      if (!visible) {
        prefix = Opacity(opacity: 0, child: prefix);
      }
      // 有序右对齐、无序左对齐，槽宽与勾选一致，正文起点对齐。
      final endAlign = block is OrderedBlock;
      return SizedBox(
        width: listPrefixSlotWidth,
        child: Align(
          alignment:
              endAlign ? Alignment.centerRight : Alignment.centerLeft,
          child: prefix,
        ),
      );
    }
    final spacer = leadingSpacerWidth(block);
    if (spacer > 0) {
      return SizedBox(width: spacer);
    }
    return const SizedBox.shrink();
  }

  /// Material 勾选图标 + 等宽槽；高度与正文 strut 对齐，避免 WidgetSpan 把图标顶出下行。
  static Widget _taskCheckboxPrefix({
    required bool checked,
    required TextStyle? style,
    required bool visible,
    Color? accentColor,
  }) {
    final resolved = style ?? const TextStyle();
    final foreground = resolved.color ?? const Color(0xFF000000);
    final iconColor = visible
        ? (checked ? (accentColor ?? foreground) : foreground)
        : Colors.transparent;
    final lineHeight = prefixLineHeight(resolved);
    final iconSize =
        taskIconSize > lineHeight ? lineHeight : taskIconSize;
    return SizedBox(
      width: taskPrefixWidth,
      height: lineHeight,
      child: Stack(
        alignment: Alignment.centerLeft,
        clipBehavior: Clip.hardEdge,
        children: [
          Transform.translate(
            offset: const Offset(0, taskIconOpticalYOffset),
            child: Icon(
              checked ? Icons.check_box : Icons.check_box_outline_blank,
              size: iconSize,
              color: iconColor,
            ),
          ),
          // 预览选区复制仍需 ☐/☑ 字符；不影响行高。
          IgnorePointer(
            child: Text(
              checked ? taskCheckedPrefix : taskUncheckedPrefix,
              style: const TextStyle(
                color: Colors.transparent,
                fontSize: 0.01,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 与 [MdBlockStyles.strutFor] 一致的行高，供勾选前缀槽对齐正文。
  static double prefixLineHeight(TextStyle? style) {
    final resolved = style ?? const TextStyle();
    final fontSize = resolved.fontSize ?? 14.0;
    final height = resolved.height;
    if (height != null) {
      return fontSize * height;
    }
    return fontSize;
  }

  /// 标题「无标题」与空正文提示共用的灰色 hint 样式。
  static TextStyle? hintStyle(TextStyle? base, ColorScheme scheme) {
    return base?.copyWith(
      fontWeight: FontWeight.normal,
      color: scheme.onSurfaceVariant.withValues(alpha: hintColorAlpha),
    );
  }

  /// 空块正文占位（透明空格 + strut）。
  static Widget emptyBodyPlaceholderText(TextStyle? style) {
    final resolved = style ?? const TextStyle();
    return Text(
      emptyBodyPlaceholder,
      style: resolved.copyWith(color: Colors.transparent),
      strutStyle: MdBlockStyles.strutFor(resolved),
    );
  }
}
