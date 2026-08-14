import 'package:flutter/material.dart';

import '../ast/md_block.dart';
import '../md_block_chrome_metrics.dart';
import 'md_block_styles.dart';

/// 块级「外壳」几何：渲染层与 chromeless Overlay **必须共用**，避免前缀宽度/缩进漂移。
///
/// 常量数值见 [MdBlockChromeMetrics]；本类提供 Widget / EdgeInsets 助手。
abstract final class MdBlockChrome {
  static const bulletPrefix = MdBlockChromeMetrics.bulletPrefix;
  static const quoteIndent = MdBlockChromeMetrics.quoteIndent;
  static const codePadding = MdBlockChromeMetrics.codePadding;
  static const emptyBodyPlaceholder = MdBlockChromeMetrics.emptyBodyPlaceholder;

  /// 有序列表前缀，如 `1. `。
  static String orderedPrefix(String marker) =>
      MdBlockChromeMetrics.orderedPrefix(marker);

  /// 块在横向 Row 中占用的前缀文案；无前缀返回空串。
  static String prefixLabel(MdBlock block) {
    return switch (block) {
      BulletBlock() => bulletPrefix,
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
  static Widget buildPrefix(
    MdBlock block,
    TextStyle? style, {
    required bool visible,
  }) {
    final label = prefixLabel(block);
    if (label.isNotEmpty) {
      final text = Text(label, style: style);
      if (visible) {
        return text;
      }
      return Opacity(opacity: 0, child: text);
    }
    final spacer = leadingSpacerWidth(block);
    if (spacer > 0) {
      return SizedBox(width: spacer);
    }
    return const SizedBox.shrink();
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
