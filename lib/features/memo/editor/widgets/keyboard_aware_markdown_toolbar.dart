import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mind_recall/app_layout_constants.dart';

/// 窄屏底部工具栏：跟随键盘 inset 贴齐 IME 顶边。
///
/// 展开：与正文 nudge 同拍写入 inset（有缓存则 applyCache 当拍）；
/// 已显示后仅 raiseCache / correctCacheDown 可改高度。
/// 收起：与正文 dismissImmediate 同拍清零。
class KeyboardAwareMarkdownToolbar extends StatelessWidget {
  const KeyboardAwareMarkdownToolbar({
    super.key,
    required this.sessionActive,
    required this.keyboardInset,
    required this.child,
  });

  /// 输入会话是否激活（聚焦 / 实时过渡宽限等）。
  final bool sessionActive;

  /// 与正文 settle 同拍的工具栏贴齐高度（逻辑像素）。
  final ValueListenable<double> keyboardInset;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: keyboardInset,
      builder: (context, inset, _) {
        if (!sessionActive || inset <= 0) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: EdgeInsets.only(
            bottom: imeToolbarBottomPadding(keyboardInset: inset),
          ),
          child: Material(
            elevation: 4,
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(kImeToolbarTopRadius),
            ),
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
        );
      },
    );
  }
}
