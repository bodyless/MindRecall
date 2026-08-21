import 'package:flutter/material.dart';

import '../ast/md_block.dart';
abstract final class MdBlockStyles {
  /// 不同块级单元之间的垂直间距（与 [MdBlocksPreview] 一致）。
  static const blockGap = 8.0;

  static const slotPadding = EdgeInsets.symmetric(vertical: 2, horizontal: 2);

  /// 图片块在槽位内的上下留白（[MdBlockRenderer] 与 × 按钮定位共用）。
  static const imageContentVerticalPadding = 8.0;

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

  /// 分割线 [Divider] 的线宽。
  static const thematicBreakThickness = 1.0;

  /// 分割线槽位高度（含上下留白，供点击与选区镜像对齐）。
  static const thematicBreakHeight = 16.0;

  /// 原子块 × 相对图/槽右缘的内缩。
  static const atomicDeleteButtonInset = 4.0;

  static const atomicDeleteIconSize = 18.0;

  static const atomicDeleteTapPadding = 6.0;

  /// × 圆形按钮边长（图标 + 点击内边距）。
  static const atomicDeleteButtonExtent =
      atomicDeleteIconSize + atomicDeleteTapPadding * 2;

  /// 叉相对圆心的光学偏移。正值向右 / 向下，负值向左 / 向上。
  static const atomicDeleteIconOpticalOffset = Offset(0, 2);

  /// 分割线的 × 与线垂直居中；图片贴在图内右上，避免顶出画面。
  static bool atomicDeleteAlignCenterVertically(MdBlock block) =>
      block is ThematicBreakBlock;

  /// 非居中时 × 的 `Positioned.top`（已含槽位 padding 与图片留白）。
  static double atomicDeleteButtonTop(MdBlock block) {
    if (block is ImageBlock) {
      return slotPadding.top +
          imageContentVerticalPadding +
          atomicDeleteButtonInset;
    }
    return atomicDeleteButtonInset;
  }

  static double atomicDeleteButtonRight() =>
      slotPadding.right + atomicDeleteButtonInset;

  /// 将删除按钮放进原子块 [Stack]；分割线垂直居中，图片右上内缩。
  static Widget positionAtomicDeleteButton({
    required MdBlock block,
    required Widget button,
  }) {
    final right = atomicDeleteButtonRight();
    if (atomicDeleteAlignCenterVertically(block)) {
      return Positioned(
        top: 0,
        bottom: 0,
        right: right,
        child: Center(child: button),
      );
    }
    return Positioned(
      top: atomicDeleteButtonTop(block),
      right: right,
      child: button,
    );
  }

  /// 原子块删除钮：正方形圆底，X 用 strut 锁行高以免字形偏出圆心。
  ///
  /// 禁止用裸 [Icon] 外包 [Padding]：图标字体 descent 会把 × 画偏，圆居中而叉不居中。
  static Widget buildAtomicDeleteButton({VoidCallback? onPressed}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: SizedBox.square(
        dimension: atomicDeleteButtonExtent,
        child: Material(
          color: Colors.black54,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: Center(
            child: Transform.translate(
              offset: atomicDeleteIconOpticalOffset,
              child: Text(
                String.fromCharCode(Icons.close.codePoint),
                textAlign: TextAlign.center,
                strutStyle: const StrutStyle(
                  fontSize: atomicDeleteIconSize,
                  height: 1,
                  forceStrutHeight: true,
                  leadingDistribution: TextLeadingDistribution.even,
                ),
                style: TextStyle(
                  fontFamily: Icons.close.fontFamily,
                  package: Icons.close.fontPackage,
                  fontSize: atomicDeleteIconSize,
                  height: 1,
                  color: Colors.white,
                  leadingDistribution: TextLeadingDistribution.even,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

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
