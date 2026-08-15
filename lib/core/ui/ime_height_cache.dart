import 'dart:ui' show FlutterView;

import 'package:flutter/foundation.dart';
import 'package:mind_recall/app_layout_constants.dart';

/// JSON 根键：`{ "heights": { "360x800": 348.1 } }`。
const String kImeHeightCacheJsonHeightsKey = 'heights';

/// 按视口逻辑尺寸分桶缓存 IME 高度，避免横竖屏混用。
///
/// 内存为源；落盘由 [onChanged]（见 `ImeHeightCacheStore`）负责。
class ImeHeightCache {
  ImeHeightCache({this.onChanged});

  final Map<String, double> _heights = {};

  /// 高度集合变化时回调（hydrate 不触发）。
  VoidCallback? onChanged;

  Map<String, double> get snapshot => Map<String, double>.unmodifiable(_heights);

  double? lookup(String key) {
    final value = _heights[key];
    if (value == null || value <= 0.5) {
      return null;
    }
    return value;
  }

  void store(String key, double logicalHeight) {
    if (logicalHeight <= 0.5) {
      if (_heights.remove(key) != null) {
        onChanged?.call();
      }
      return;
    }
    final previous = _heights[key];
    if (previous != null && (previous - logicalHeight).abs() <= 0.5) {
      return;
    }
    _heights[key] = logicalHeight;
    onChanged?.call();
  }

  /// 启动时灌入磁盘记录；不触发 [onChanged]，避免刚读完又写盘。
  void hydrate(Map<String, double> heights) {
    _heights
      ..clear()
      ..addAll({
        for (final entry in heights.entries)
          if (entry.value > 0.5) entry.key: entry.value,
      });
  }

  void clear() {
    if (_heights.isEmpty) {
      return;
    }
    _heights.clear();
    onChanged?.call();
  }
}

/// Live / Edit 共用；启动时由 [ImeHeightCacheStore] 灌入并挂落盘。
final ImeHeightCache defaultImeHeightCache = ImeHeightCache();

Map<String, double> decodeImeHeightCacheJson(Object? json) {
  if (json is! Map) {
    return {};
  }
  final raw = json[kImeHeightCacheJsonHeightsKey];
  if (raw is! Map) {
    return {};
  }
  final out = <String, double>{};
  for (final entry in raw.entries) {
    final key = entry.key.toString();
    final value = entry.value;
    if (key.isEmpty || value is! num) {
      continue;
    }
    final logical = value.toDouble();
    if (logical <= 0.5) {
      continue;
    }
    out[key] = logical;
  }
  return out;
}

Map<String, dynamic> encodeImeHeightCacheJson(Map<String, double> heights) {
  final cleaned = <String, double>{
    for (final entry in heights.entries)
      if (entry.value > 0.5) entry.key: entry.value,
  };
  return {kImeHeightCacheJsonHeightsKey: cleaned};
}

/// 与正文 nudge 同拍：隐藏则显栏；已显示仅在目标高度变化时跟随（raise / correct）。
bool shouldSyncImeToolbarInset({
  required double targetLogical,
  required double toolbarLogical,
  double epsilon = 0.5,
}) {
  if (targetLogical <= epsilon) {
    return false;
  }
  return (toolbarLogical - targetLogical).abs() > epsilon;
}

String imeHeightCacheKey({
  required double viewWidthLogical,
  required double viewHeightLogical,
}) {
  return '${viewWidthLogical.round()}x${viewHeightLogical.round()}';
}

String imeHeightCacheKeyForView(FlutterView view) {
  final size = view.physicalSize / view.devicePixelRatio;
  return imeHeightCacheKey(
    viewWidthLogical: size.width,
    viewHeightLogical: size.height,
  );
}

/// settle 后如何滚动：立即 / 120ms 防抖 / 不滚。
enum ImeSettleNudgeMode { none, immediate, debounce }

/// 一次 IME settle 回调的纯决策（便于单测，不碰 Timer）。
class ImeSettleDecision {
  const ImeSettleDecision({
    this.commitLogical,
    this.reason,
    this.nudge = ImeSettleNudgeMode.none,
    this.markCacheApplied = false,
    this.storeCacheLogical,
  });

  static const none = ImeSettleDecision();

  /// 非 null 时写入 committed spacer。
  final double? commitLogical;
  final String? reason;
  final ImeSettleNudgeMode nudge;

  /// 本次打开已套用缓存，后续低于缓存的 settle 不再把 spacer 往回收。
  final bool markCacheApplied;

  /// 写入缓存的键盘 inset；null 表示本次不改缓存。
  final double? storeCacheLogical;

  bool get shouldCommit => commitLogical != null;
}

/// 根据 pending / 缓存决定本次 settle 提交什么、是否 nudge。
ImeSettleDecision resolveImeSettleDecision({
  required double pendingLogical,
  required double committedLogical,
  required double? cachedLogical,
  required bool appliedCacheThisOpen,
  double epsilon = 0.5,
}) {
  if (pendingLogical <= epsilon) {
    return ImeSettleDecision.none;
  }

  final cached = cachedLogical;
  if (cached != null && cached > epsilon && !appliedCacheThisOpen) {
    final target = pendingLogical > cached ? pendingLogical : cached;
    return ImeSettleDecision(
      commitLogical: target,
      reason: 'applyCache',
      nudge: ImeSettleNudgeMode.immediate,
      markCacheApplied: true,
      storeCacheLogical: target,
    );
  }

  if (appliedCacheThisOpen) {
    if (pendingLogical > committedLogical + epsilon) {
      return ImeSettleDecision(
        commitLogical: pendingLogical,
        reason: 'raiseCache',
        nudge: ImeSettleNudgeMode.immediate,
        storeCacheLogical: pendingLogical,
      );
    }
    return ImeSettleDecision.none;
  }

  if (!shouldCommitImeInset(
        pendingLogical: pendingLogical,
        committedLogical: committedLogical,
        epsilon: epsilon,
      )) {
    return ImeSettleDecision.none;
  }
  return ImeSettleDecision(
    commitLogical: pendingLogical,
    reason: 'settle',
    nudge: ImeSettleNudgeMode.debounce,
  );
}

/// 已套用缓存但真实 inset 长时间明显更矮时，才允许把 spacer 降下来。
bool shouldArmImeCacheDownCorrect({
  required bool appliedCacheThisOpen,
  required double pendingLogical,
  required double committedLogical,
  double minDeltaLogical = kImeSettleRestartMinDelta,
}) {
  return appliedCacheThisOpen &&
      pendingLogical > 0.5 &&
      committedLogical - pendingLogical >= minDeltaLogical;
}
