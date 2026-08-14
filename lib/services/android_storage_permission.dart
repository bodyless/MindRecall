import 'dart:io';

import 'package:flutter/services.dart';

/// Android 存储权限（避免引入 permission_handler 的 Windows NuGet 依赖）。
class AndroidStoragePermission {
  static const _channel = MethodChannel('com.wishtech.mind_recall/storage');

  static Future<void> requestIfNeeded() async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('requestStorage');
    } catch (_) {
      // 权限请求失败时不阻塞后续文件访问尝试。
    }
  }
}
