import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'android_storage_permission.dart';

/// 统一管理应用数据目录：`Download/MindRecall`（各平台 Downloads 目录下）。
class AppStorageService {
  static const folderName = 'MindRecall';

  Directory? _cachedDir;
  bool _permissionRequested = false;

  Future<Directory> storageDirectory() async {
    if (_cachedDir != null) {
      return _cachedDir!;
    }

    await _ensureAndroidStoragePermission();

    final downloads = await getDownloadsDirectory();
    final base = downloads != null
        ? Directory(p.join(downloads.path, folderName))
        : Directory(
            p.join(
              (await getApplicationDocumentsDirectory()).path,
              folderName,
            ),
          );

    if (!await base.exists()) {
      await base.create(recursive: true);
    }

    _cachedDir = base;
    return base;
  }

  Future<void> _ensureAndroidStoragePermission() async {
    if (!Platform.isAndroid || _permissionRequested) {
      return;
    }
    _permissionRequested = true;
    await AndroidStoragePermission.requestIfNeeded();
  }
}

final appStorageService = AppStorageService();
