/// 跨模块共享的布局与 UI 时序常量。
library;

/// 宽屏布局断点（≥ 此宽度显示固定侧栏）。
const double kWideLayoutBreakpoint = 720;

/// 无标题时，用正文首行作列表预览的最大字符数。
const int kMemoTitlePreviewMaxLength = 40;

/// 窄屏底部 Markdown 工具栏叠在键盘上方时的估算高度（含外边距）。
/// 用于编辑/实时模式 scrollPadding 与 ListView 底部留白，避免光标被挡住。
const double kMarkdownImeToolbarHeight = 60;

/// 光标/活动块与工具栏之间的额外间隙。
const double kImeCaretGap = 24;

/// 编辑区正文底部基础留白（不含安全区 / IME）。
///
/// 实时 ListView `padding.bottom` 与编辑 TextField `contentPadding.bottom` 基数须一致，
/// 否则底端「空档 / 遮盖」高度两模式不一致。
const double kEditorBodyBottomPadding = 24;

/// 编辑/实时模式为避开 IME（及可选底部工具栏）所需的底部滚动留白。
///
/// 窄屏打开键盘时须在**同一次** settle 提交中计入工具栏高度，
/// 避免先按键盘高度刷位置、工具栏再弹出时二次刷新。
double imeBottomScrollPadding({
  required double keyboardInset,
  required bool focused,
  bool includeToolbar = true,
}) {
  if (!focused) {
    return 0;
  }
  return keyboardInset +
      (includeToolbar ? kMarkdownImeToolbarHeight : 0) +
      kImeCaretGap;
}

/// 实时 ListView 尾部 IME spacer 高度（不含 ListView 基础 padding / 安全区）。
///
/// 与 [imeBottomScrollPadding] 同值；用尾部项承载，避免改 padding 触发整表 rebuild。
double liveListImeSpacerHeight({
  required double keyboardInset,
  required bool focused,
  bool includeToolbar = true,
}) {
  return imeBottomScrollPadding(
    keyboardInset: keyboardInset,
    focused: focused,
    includeToolbar: includeToolbar,
  );
}

/// 若光标/块底边落在 IME 遮挡区内，返回还需上滚的像素；否则 0。
double scrollDeltaToClearIme({
  required double caretOrBlockGlobalBottom,
  required double viewportGlobalBottom,
  required double obscuredBottom,
}) {
  if (obscuredBottom <= 0) {
    return 0;
  }
  final usableBottom = viewportGlobalBottom - obscuredBottom;
  if (caretOrBlockGlobalBottom <= usableBottom) {
    return 0;
  }
  return caretOrBlockGlobalBottom - usableBottom;
}

/// 编辑模式 [TextField] `contentPadding.bottom`（仅基础底距 + 安全区）。
///
/// IME / 工具栏遮挡改由视口下方 [editImeBottomSpacerHeight] spacer 承托，
/// **不要**再把大块 [imeObscured] 塞进 contentPadding，否则会变成挡住末行的底遮罩。
/// [basePadding] 与实时 ListView [kEditorBodyBottomPadding] 对齐。
double editFieldContentBottomPadding({
  required double bottomSafe,
  double basePadding = kEditorBodyBottomPadding,
}) {
  return basePadding + bottomSafe;
}

/// 编辑模式底部 IME spacer 高度（与实时尾部 spacer 同公式）。
///
/// 仅在键盘已展开（[keyboardInset] > 0）时非零；收起时为 0，避免无键盘时底遮罩挡末行。
double editImeBottomSpacerHeight({
  required double keyboardInset,
  required bool focused,
  bool includeToolbar = true,
}) {
  if (!focused || keyboardInset <= 0) {
    return 0;
  }
  return imeBottomScrollPadding(
    keyboardInset: keyboardInset,
    focused: true,
    includeToolbar: includeToolbar,
  );
}

/// 键盘 metrics 收稳后是否需要提交 inset（与已提交值有可见差异）。
bool shouldCommitImeInset({
  required double pendingLogical,
  required double committedLogical,
  double epsilon = 0.5,
}) {
  return (pendingLogical - committedLogical).abs() > epsilon;
}

/// 键盘开始收起时是否应立刻隐藏 IME 工具栏 / 清空正文留白（不等 settle）。
bool shouldHideImeToolbarImmediately({
  required double pendingLogical,
  required double committedLogical,
  double epsilon = 0.5,
}) {
  return committedLogical > epsilon &&
      pendingLogical < committedLogical - epsilon;
}

/// 与 [shouldHideImeToolbarImmediately] 相同：收起瞬间提交正文 inset。
bool shouldCommitImeDismissImmediately({
  required double pendingLogical,
  required double committedLogical,
  double epsilon = 0.5,
}) {
  return shouldHideImeToolbarImmediately(
    pendingLogical: pendingLogical,
    committedLogical: committedLogical,
    epsilon: epsilon,
  );
}

/// pending 相对已武装值变化达到此值才重置 settle。
///
/// 动画前段大步进仍会推迟提交；末段小步进/同值尾抖不拖长等待。
/// settle 回调须读取**最新** pending，而非武装时的旧值。
const double kImeSettleRestartMinDelta = 8;

/// 是否应取消并重启 IME settle 计时器。
bool shouldRestartImeSettleTimer({
  required double pendingLogical,
  required double armedPendingLogical,
  double minDeltaLogical = kImeSettleRestartMinDelta,
}) {
  return (pendingLogical - armedPendingLogical).abs() >= minDeltaLogical;
}

/// 已废弃于 UI 路径：动画中步进提交会造成「一截一截」跳动。
@Deprecated('IME UI 使用 settle-only，勿再步进提交')
bool shouldCommitImeInsetStepped({
  required double pendingLogical,
  required double committedLogical,
  double minStepLogical = 40,
}) {
  return (pendingLogical - committedLogical).abs() >= minStepLogical;
}

/// 自上次「显著」pending 变化后，再等此时长一次性提交**正文**留白 / 滚入。
const Duration kImeInsetSettleDelay = Duration(milliseconds: 48);

/// 打开键盘、工具栏尚未显示时：pending 完全静止后再等此时长，一次性显栏。
///
/// 比正文 settle 更严，避免动画末段小步进让工具栏分多帧爬升。
const Duration kImeToolbarOpenSettleDelay = Duration(milliseconds: 120);

/// 打开未显栏时，pending 变化达到此值即重武装工具栏显栏计时（近似「仍在动」）。
const double kImeToolbarOpenSettleRestartDelta = 1.0;

/// 打开抽屉前等待 IME 的上限（失焦后 inset 会自己落，不宜拖太久）。
const Duration kDrawerImeWaitTimeout = Duration(milliseconds: 180);

/// 打开过程中是否应重武装工具栏「静止后显栏」计时。
bool shouldRestartImeToolbarOpenSettle({
  required double pendingLogical,
  required double armedPendingLogical,
  double minDeltaLogical = kImeToolbarOpenSettleRestartDelta,
}) {
  return (pendingLogical - armedPendingLogical).abs() >= minDeltaLogical;
}

/// settle/显栏回调：是否应从隐藏态一次性写出工具栏 inset。
///
/// 已显示则不再改高度（同一次打开只弹一次）；收起清零后再开可再显。
bool shouldRevealImeToolbarOnce({
  required double pendingLogical,
  required double toolbarLogical,
  double epsilon = 0.5,
}) {
  return toolbarLogical <= epsilon && pendingLogical > epsilon;
}
