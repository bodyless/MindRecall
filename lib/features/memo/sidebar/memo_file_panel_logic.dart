/// 侧栏 / 抽屉文件面板的纯逻辑（便于单测，无 Flutter 依赖）。

/// 窄屏抽屉边缘拖动手势起始区占屏宽比例（左半屏即可呼出）。
const double kDrawerEdgeDragWidthFraction = 0.5;

/// 是否展示搜索结果列表。
///
/// query 已空时即使 [isSearchActive] 仍为 true（防抖未跑完），也必须回退到文件列表，
/// 否则会短暂或持续显示「无匹配结果」，看起来像文件列表被清空。
bool memoFilePanelShowsSearchResults({
  required bool isSearchActive,
  required String query,
}) {
  return isSearchActive && query.trim().isNotEmpty;
}

/// 窄屏抽屉边缘拖动手势起始区宽度。
///
/// [screenWidth] 的 [fraction]（默认半屏）；再加左侧安全区，避免刘海裁掉起始点。
double drawerEdgeDragWidthFor({
  required double screenWidth,
  required double leftSafePadding,
  double fraction = kDrawerEdgeDragWidthFraction,
}) {
  return screenWidth * fraction + leftSafePadding;
}

/// 窄屏是否允许边缘拖动手势打开抽屉。
///
/// 宽屏不启用。窄屏只认系统 IME [insetBottomLogical]：键盘可见时禁用，
/// 避免侧滑与键盘下落叠动画。不把「有焦点 / 有光标」当作禁止条件——
/// Android 常在收起键盘后仍保留 TextField 焦点与 caret。
bool drawerOpenDragGestureEnabled({
  required bool isWide,
  required double insetBottomLogical,
}) {
  if (isWide) {
    return false;
  }
  return insetBottomLogical <= 0.5;
}

/// 打开抽屉前是否需要先等 IME 收起。
bool drawerShouldWaitForIme({
  required bool editorFocused,
  required double insetBottomLogical,
}) {
  return editorFocused || insetBottomLogical > 0.5;
}

/// 宽屏侧栏展开揭示状态：先播宽度动画，结束后再挂载面板，避免窄宽溢出。
final class SidebarRevealState {
  SidebarRevealState({
    this.expanded = true,
    this.contentVisible = true,
  });

  bool expanded;
  bool contentVisible;

  bool get shouldBuildPanel => expanded && contentVisible;

  void collapse() {
    expanded = false;
    contentVisible = false;
  }

  void beginExpand() {
    expanded = true;
    contentVisible = false;
  }

  /// 宽度动画 [onEnd] 时调用；若已收起则忽略。
  void onExpandAnimationEnded() {
    if (expanded) {
      contentVisible = true;
    }
  }
}
