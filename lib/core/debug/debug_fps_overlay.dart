import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// 帧耗时超过该预算视为卡顿（约 < 50 FPS）。
const Duration kDebugFpsJankFrameBudget = Duration(milliseconds: 20);

/// 平滑 FPS 下限：不低于此值且无慢帧时显示绿色。
const double kDebugFpsSmoothMin = 50;

/// 由最近若干帧的 totalSpan 计算展示用 FPS 与是否卡顿。
({double fps, bool janky}) summarizeDebugFps(List<Duration> recentTotals) {
  if (recentTotals.isEmpty) {
    return (fps: 60, janky: false);
  }
  var micros = 0;
  var windowJank = false;
  for (final span in recentTotals) {
    micros += span.inMicroseconds;
    if (span > kDebugFpsJankFrameBudget) {
      windowJank = true;
    }
  }
  final avgMicros = micros / recentTotals.length;
  final fps = avgMicros <= 0 ? 0.0 : 1e6 / avgMicros;
  return (fps: fps, janky: windowJank || fps < kDebugFpsSmoothMin);
}

/// Debug 专用右上角 FPS 徽标。
///
/// 仅应在 [kDebugMode] 且用户开启「启用调试」时挂载；内部用
/// [SchedulerBinding.addTimingsCallback] 采样，开销很小。
class DebugFpsOverlay extends StatefulWidget {
  const DebugFpsOverlay({super.key});

  @override
  State<DebugFpsOverlay> createState() => _DebugFpsOverlayState();
}

class _DebugFpsOverlayState extends State<DebugFpsOverlay> {
  static const _sampleWindow = 30;
  /// 徽标 UI 刷新下限，避免每帧 setState 干扰键盘动画期 profiling。
  static const _uiMinInterval = Duration(milliseconds: 250);

  final List<Duration> _recentTotals = <Duration>[];
  double _fps = 60;
  bool _janky = false;
  bool _listening = false;
  DateTime? _lastUiAt;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      SchedulerBinding.instance.addTimingsCallback(_onTimings);
      _listening = true;
    }
  }

  @override
  void dispose() {
    if (_listening) {
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    }
    super.dispose();
  }

  void _onTimings(List<FrameTiming> timings) {
    if (!mounted || timings.isEmpty) {
      return;
    }
    for (final timing in timings) {
      _recentTotals.add(timing.totalSpan);
    }
    while (_recentTotals.length > _sampleWindow) {
      _recentTotals.removeAt(0);
    }
    final now = DateTime.now();
    final lastAt = _lastUiAt;
    if (lastAt != null && now.difference(lastAt) < _uiMinInterval) {
      return;
    }
    final summary = summarizeDebugFps(_recentTotals);
    if (_fps == summary.fps && _janky == summary.janky) {
      _lastUiAt = now;
      return;
    }
    _lastUiAt = now;
    setState(() {
      _fps = summary.fps;
      _janky = summary.janky;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }
    final color = _janky ? Colors.redAccent : Colors.greenAccent;
    final top = MediaQuery.paddingOf(context).top + 4;
    return Positioned(
      top: top,
      right: 8,
      child: IgnorePointer(
        child: Material(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              '${_fps.toStringAsFixed(0)} FPS',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
