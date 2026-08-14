import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Debug 专用 Timeline 埋点。
///
/// [kDebugMode] 为 false（profile / release）时直接执行 [body]，无 Timeline 开销。
void debugTimelineSync(
  String name,
  void Function() body, {
  Map<String, String>? arguments,
}) {
  if (!kDebugMode) {
    body();
    return;
  }
  developer.Timeline.timeSync(name, body, arguments: arguments);
}

/// Debug 专用异步 Timeline；非 debug 时零开销直通。
Future<T> debugTimelineAsync<T>(
  String name,
  Future<T> Function() body, {
  Map<String, String>? arguments,
}) async {
  if (!kDebugMode) {
    return body();
  }
  developer.Timeline.startSync(name, arguments: arguments);
  try {
    return await body();
  } finally {
    developer.Timeline.finishSync();
  }
}

/// Debug 瞬时事件（无耗时区间）。
void debugTimelineInstant(
  String name, {
  Map<String, String>? arguments,
}) {
  if (!kDebugMode) {
    return;
  }
  developer.Timeline.instantSync(name, arguments: arguments);
}
