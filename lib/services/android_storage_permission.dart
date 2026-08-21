import 'dart:io';

import 'package:flutter/services.dart';

/// Android 存储权限（避免引入 permission_handler 的 Windows NuGet 依赖）。
class AndroidStoragePermission {
  static const _channel = MethodChannel('com.wishtech.mind_recall/storage');

  /// 是否已有可读公共 Downloads 的权限（API 30+ 为所有文件访问 + 照片）。
  static Future<bool> hasAccess() async {
    if (!Platform.isAndroid) {
      return true;
    }
    try {
      return await _channel.invokeMethod<bool>('hasStorageAccess') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 若缺失则弹出系统授权页并等待返回。非 Android 视为已授权。
  static Future<bool> requestIfNeeded() async {
    if (!Platform.isAndroid) {
      return true;
    }
    try {
      return await _channel.invokeMethod<bool>('requestStorage') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Android 用 Java `File.listFiles` 递归复制；非 Android 或通道失败返回 null。
  static Future<int?> copyDirectoryTree({
    required String sourcePath,
    required String destPath,
    required String skipName,
  }) async {
    if (!Platform.isAndroid) {
      return null;
    }
    try {
      return await _channel.invokeMethod<int>('copyDirectoryTree', {
        'source': sourcePath,
        'destination': destPath,
        'skipName': skipName,
      });
    } catch (_) {
      return null;
    }
  }
}
