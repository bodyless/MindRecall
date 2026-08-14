import 'package:flutter/foundation.dart';

/// 屏上 IME 调试 HUD 的一帧快照（仅 debug 有意义）。
@immutable
class ImeDebugSnapshot {
  const ImeDebugSnapshot({
    this.scope = '',
    this.pendingLogical = 0,
    this.committedLogical = 0,
    this.toolbarLogical = 0,
    this.burstMs = 0,
    this.settleResetCount = 0,
    this.settleActive = false,
    this.focused = false,
    this.lastCommitReason = '',
  });

  static const empty = ImeDebugSnapshot();

  /// `Live` / `Edit`（与 [ImeTimelineScope] 一致）。
  final String scope;
  final double pendingLogical;
  final double committedLogical;
  final double toolbarLogical;
  final int burstMs;
  final int settleResetCount;
  final bool settleActive;
  final bool focused;
  final String lastCommitReason;

  @override
  bool operator ==(Object other) {
    return other is ImeDebugSnapshot &&
        other.scope == scope &&
        other.pendingLogical == pendingLogical &&
        other.committedLogical == committedLogical &&
        other.toolbarLogical == toolbarLogical &&
        other.burstMs == burstMs &&
        other.settleResetCount == settleResetCount &&
        other.settleActive == settleActive &&
        other.focused == focused &&
        other.lastCommitReason == lastCommitReason;
  }

  @override
  int get hashCode => Object.hash(
        scope,
        pendingLogical,
        committedLogical,
        toolbarLogical,
        burstMs,
        settleResetCount,
        settleActive,
        focused,
        lastCommitReason,
      );
}

/// 全局 IME HUD 状态；仅 [kDebugMode] 下由编辑器 publish。
final ValueNotifier<ImeDebugSnapshot> imeDebugHud =
    ValueNotifier<ImeDebugSnapshot>(ImeDebugSnapshot.empty);

/// 发布 HUD 快照。非 debug 零开销；[lastCommitReason] 为 null 时保留上次 reason。
void publishImeDebugHud({
  required String scope,
  required double pendingLogical,
  required double committedLogical,
  required double toolbarLogical,
  required int burstMs,
  required int settleResetCount,
  required bool settleActive,
  required bool focused,
  String? lastCommitReason,
}) {
  if (!kDebugMode) {
    return;
  }
  final prev = imeDebugHud.value;
  final next = ImeDebugSnapshot(
    scope: scope,
    pendingLogical: pendingLogical,
    committedLogical: committedLogical,
    toolbarLogical: toolbarLogical,
    burstMs: burstMs,
    settleResetCount: settleResetCount,
    settleActive: settleActive,
    focused: focused,
    lastCommitReason: lastCommitReason ?? prev.lastCommitReason,
  );
  if (next == prev) {
    return;
  }
  imeDebugHud.value = next;
}

/// 格式化为屏上多行（纯函数，便于单测）。
List<String> formatImeDebugHudLines(ImeDebugSnapshot snapshot) {
  if (snapshot.scope.isEmpty) {
    return const ['IME —'];
  }
  final settleTag = snapshot.settleActive ? ' settle' : '';
  final focusTag = snapshot.focused ? 'F' : 'U';
  final lines = <String>[
    'IME ${snapshot.scope} $focusTag',
    'p=${_hudPx(snapshot.pendingLogical)} '
        'c=${_hudPx(snapshot.committedLogical)} '
        't=${_hudPx(snapshot.toolbarLogical)}',
    'burst=${snapshot.burstMs} rst=${snapshot.settleResetCount}$settleTag',
  ];
  if (snapshot.lastCommitReason.isNotEmpty) {
    lines.add('commit=${snapshot.lastCommitReason}');
  }
  return lines;
}

String _hudPx(double logical) => logical.toStringAsFixed(0);
