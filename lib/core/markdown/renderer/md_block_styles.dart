import 'package:flutter/material.dart';

import '../ast/md_block.dart';
abstract final class MdBlockStyles {
  /// 不同块级单元之间的垂直间距（与 [MdBlocksPreview] 一致）。
  static const blockGap = 8.0;

  static const slotPadding = EdgeInsets.symmetric(vertical: 2, horizontal: 2);

  /// 块槽位内边距；同一段落内换行（[ParagraphBlock.continuesWithNext]）不加垂直 padding。
  static EdgeInsets slotPaddingFor(MdBlock block, {MdBlock? previous}) {
    final flowsFromPrevious =
        previous is ParagraphBlock && previous.continuesWithNext;
    final flowsToNext =
        block is ParagraphBlock && block.continuesWithNext;
    if (flowsFromPrevious || flowsToNext) {
      return const EdgeInsets.symmetric(horizontal: 2);
    }
    return slotPadding;
  }

  /// 当前块底部的外边距：段落内换行（[ParagraphBlock.continuesWithNext]）为 0。
  static double bottomSpacingFor(MdBlock block) {
    if (block is ParagraphBlock && block.continuesWithNext) {
      return 0;
    }
    return blockGap;
  }

  static StrutStyle strutFor(TextStyle? style) {
    final resolved = style ?? const TextStyle();
    return StrutStyle.fromTextStyle(
      resolved,
      forceStrutHeight: true,
    );
  }

  /// H3 相对正文的字号倍率；Material 默认 titleMedium 与 bodyLarge 同为 16，
  /// 仅靠加粗无法与正文粗体区分。
  static const _h3SizeScale = 1.2;

  static TextStyle? headingStyle(ThemeData theme, int level) {
    final bodySize = theme.textTheme.bodyLarge?.fontSize ?? 16;
    return switch (level) {
      1 => theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
      2 => theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      3 => theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: bodySize * _h3SizeScale,
        ),
      _ => theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
    };
  }

  static BoxDecoration quoteDecoration(ThemeData theme) {
    return BoxDecoration(
      border: Border(
        left: BorderSide(color: theme.colorScheme.primary, width: 3),
      ),
    );
  }

  static BoxDecoration codeBlockDecoration(ThemeData theme) {
    return BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
    );
  }

  static TextStyle? quoteTextStyle(ThemeData theme) {
    return theme.textTheme.bodyLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
  }

  /// 实时 Overlay 输入层左侧缩进，与 [MdBlockRenderer] 正文起始对齐。
  static EdgeInsets chromelessContentPadding(MdBlock block, ThemeData theme) {
    return switch (block) {
      QuoteBlock() => const EdgeInsets.only(left: 12),
      _ => EdgeInsets.zero,
    };
  }
}
