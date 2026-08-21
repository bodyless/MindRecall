import 'dart:io';

import 'package:flutter/services.dart';

/// Android 选区「记录到笔记」：接收 Native trampoline 转发的文本。
///
/// `PROCESS_TEXT` 入口是 `ProcessTextActivity`（立刻 finish + NEW_TASK），
/// 禁止把 Flutter `MainActivity` 直接挂到系统选区菜单。
class AndroidProcessText {
  static const _channelName = 'com.wishtech.mind_recall/process_text';

  /// 非 Android 不建立 EventChannel 订阅。
  static Stream<String> events() {
    if (!Platform.isAndroid) {
      return const Stream<String>.empty();
    }
    return const EventChannel(_channelName)
        .receiveBroadcastStream()
        .map((event) => '$event');
  }
}
