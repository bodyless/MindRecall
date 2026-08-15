import 'package:flutter/widgets.dart';

/// 将 [didChangeMetrics] 从 State 中拆出，避免 State 直接 mix-in。
class ImeMetricsObserver with WidgetsBindingObserver {
  ImeMetricsObserver(this.onMetricsChanged);

  final VoidCallback onMetricsChanged;

  @override
  void didChangeMetrics() => onMetricsChanged();
}
