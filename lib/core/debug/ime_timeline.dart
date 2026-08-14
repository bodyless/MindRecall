import 'package:mind_recall/core/debug/debug_timeline.dart';

/// IME 链路 Timeline 作用域（DevTools 搜 `Ime.`）。
abstract final class ImeTimelineScope {
  static const live = 'Live';
  static const edit = 'Edit';
  static const toolbar = 'Toolbar';
}

/// 组装 IME Timeline 参数（纯函数，便于单测）。
Map<String, String> imeTimelineArgs({
  required double pendingLogical,
  required double committedLogical,
  int? burstMs,
  int? settleResetCount,
  bool? willCommit,
  bool? focused,
  String? reason,
}) {
  return <String, String>{
    'pending': pendingLogical.toStringAsFixed(1),
    'committed': committedLogical.toStringAsFixed(1),
    if (burstMs != null) 'burstMs': '$burstMs',
    if (settleResetCount != null) 'settleResetCount': '$settleResetCount',
    if (willCommit != null) 'willCommit': '$willCommit',
    if (focused != null) 'focused': '$focused',
    if (reason != null) 'reason': reason,
  };
}

/// metrics 回调：每次 viewInsets 变化打一点。
///
/// [settleResetCount] > 0 表示本次又取消了未到期的 settle（尾抖延长的主嫌疑）。
void imeTimelineMetrics(
  String scope, {
  required double pendingLogical,
  required double committedLogical,
  required int burstMs,
  required int settleResetCount,
  bool? focused,
}) {
  debugTimelineInstant(
    'Ime.$scope.metrics',
    arguments: imeTimelineArgs(
      pendingLogical: pendingLogical,
      committedLogical: committedLogical,
      burstMs: burstMs,
      settleResetCount: settleResetCount,
      focused: focused,
    ),
  );
}

/// settle 定时器真正触发（准备提交留白 / 滚入 / 显示工具栏）。
void imeTimelineSettle(
  String scope, {
  required double pendingLogical,
  required double committedLogical,
  required int burstMs,
  required int settleResetCount,
  required bool willCommit,
}) {
  debugTimelineInstant(
    'Ime.$scope.settle',
    arguments: imeTimelineArgs(
      pendingLogical: pendingLogical,
      committedLogical: committedLogical,
      burstMs: burstMs,
      settleResetCount: settleResetCount,
      willCommit: willCommit,
    ),
  );
}

/// 已提交的 inset 发生变化。
void imeTimelineCommit(
  String scope, {
  required double pendingLogical,
  required double committedLogical,
  String? reason,
}) {
  debugTimelineInstant(
    'Ime.$scope.commit',
    arguments: imeTimelineArgs(
      pendingLogical: pendingLogical,
      committedLogical: committedLogical,
      reason: reason,
    ),
  );
}

/// 调度或执行滚入。
void imeTimelineScroll(String scope, {String? reason}) {
  debugTimelineInstant(
    'Ime.$scope.scroll',
    arguments: {
      if (reason != null) 'reason': reason,
    },
  );
}
