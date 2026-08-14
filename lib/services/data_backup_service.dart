import 'dart:io';

import 'package:path/path.dart' as p;

import 'app_storage_service.dart';
import 'memo_trash_service.dart';
import 'user_preferences_service.dart';

/// 导出 / 导入结果。
final class DataBackupResult {
  const DataBackupResult({
    required this.targetPath,
    required this.memoFileCount,
    required this.includedPreferences,
  });

  final String targetPath;
  final int memoFileCount;
  final bool includedPreferences;
}

/// 将 `MindRecall/` 文档目录与 `user_preferences.json` 成套备份 / 恢复。
class DataBackupService {
  DataBackupService({
    required this.prefsService,
    AppStorageService? appStorage,
  }) : _appStorage = appStorage ?? appStorageService;

  final UserPreferencesService prefsService;
  final AppStorageService _appStorage;

  static const backupFolderPrefix = 'MindRecall_Backup_';
  static const memosFolderName = AppStorageService.folderName;

  /// 导出到 [destinationParent] 下的时间戳子目录：
  /// `{parent}/MindRecall_Backup_yyyyMMdd_HHmmss/{MindRecall,user_preferences.json}`
  Future<DataBackupResult> exportToDirectory(String destinationParent) async {
    final parent = Directory(destinationParent);
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }

    final stamp = _timestampFolderName();
    final backupRoot = Directory(p.join(parent.path, stamp));
    if (await backupRoot.exists()) {
      await backupRoot.delete(recursive: true);
    }
    await backupRoot.create(recursive: true);

    final sourceMemos = await _appStorage.storageDirectory();
    final destMemos = Directory(p.join(backupRoot.path, memosFolderName));
    final memoCount = await _copyDirectory(sourceMemos, destMemos);

    final prefsSource = await prefsService.preferencesFile();
    var includedPrefs = false;
    if (await prefsSource.exists()) {
      final prefsDest = p.join(
        backupRoot.path,
        UserPreferencesService.fileName,
      );
      await prefsSource.copy(prefsDest);
      includedPrefs = true;
    } else {
      // 无文件时仍写出当前内存配置，保证备份完整。
      await prefsService.save(prefsService.preferences);
      final refreshed = await prefsService.preferencesFile();
      if (await refreshed.exists()) {
        await refreshed.copy(
          p.join(backupRoot.path, UserPreferencesService.fileName),
        );
        includedPrefs = true;
      }
    }

    return DataBackupResult(
      targetPath: backupRoot.path,
      memoFileCount: memoCount,
      includedPreferences: includedPrefs,
    );
  }

  /// 从备份目录导入。支持：
  /// - 完整备份根（含 `MindRecall/` + 可选 `user_preferences.json`）
  /// - 直接选中 `MindRecall/` 文档目录
  Future<DataBackupResult> importFromDirectory(String selectedPath) async {
    final selected = Directory(selectedPath);
    if (!await selected.exists()) {
      throw FileSystemException('备份目录不存在', selectedPath);
    }

    final resolved = await _resolveBackupLayout(selected);
    final sourceMemos = resolved.memosDir;
    final prefsFile = resolved.prefsFile;

    final targetMemos = await _appStorage.storageDirectory();
    await _clearDirectoryContents(targetMemos);
    final memoCount = await _copyDirectory(sourceMemos, targetMemos);

    var includedPrefs = false;
    if (prefsFile != null && await prefsFile.exists()) {
      final dest = await prefsService.preferencesFile();
      await dest.parent.create(recursive: true);
      await prefsFile.copy(dest.path);
      await prefsService.load();
      includedPrefs = true;
    }

    return DataBackupResult(
      targetPath: selectedPath,
      memoFileCount: memoCount,
      includedPreferences: includedPrefs,
    );
  }

  Future<({Directory memosDir, File? prefsFile})> _resolveBackupLayout(
    Directory selected,
  ) async {
    final nestedMemos = Directory(p.join(selected.path, memosFolderName));
    final nestedPrefs = File(
      p.join(selected.path, UserPreferencesService.fileName),
    );

    if (await nestedMemos.exists()) {
      return (
        memosDir: nestedMemos,
        prefsFile: await nestedPrefs.exists() ? nestedPrefs : null,
      );
    }

    // 用户直接选中了 MindRecall 文档目录本身。
    final siblingPrefs = File(
      p.join(selected.parent.path, UserPreferencesService.fileName),
    );
    final localPrefs = File(
      p.join(selected.path, UserPreferencesService.fileName),
    );
    File? prefs;
    if (await localPrefs.exists()) {
      prefs = localPrefs;
    } else if (await siblingPrefs.exists()) {
      prefs = siblingPrefs;
    }

    return (memosDir: selected, prefsFile: prefs);
  }

  String _timestampFolderName() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '$backupFolderPrefix'
        '${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  /// 复制目录；返回复制的备忘录正文文件数（`.md` / `.txt`）。
  Future<int> _copyDirectory(Directory source, Directory destination) async {
    if (!await source.exists()) {
      await destination.create(recursive: true);
      return 0;
    }
    await destination.create(recursive: true);
    var memoFiles = 0;
    await for (final entity in source.list(recursive: false, followLinks: false)) {
      final name = p.basename(entity.path);
      if (name == '.' || name == '..') {
        continue;
      }
      // 导出跳过回收站，避免备份体积膨胀。
      if (name == MemoTrashService.folderName) {
        continue;
      }
      if (entity is Directory) {
        memoFiles += await _copyDirectory(
          entity,
          Directory(p.join(destination.path, name)),
        );
      } else if (entity is File) {
        final lower = name.toLowerCase();
        if (lower.endsWith('.md') || lower.endsWith('.txt')) {
          memoFiles++;
        }
        await entity.copy(p.join(destination.path, name));
      }
    }
    return memoFiles;
  }

  Future<void> _clearDirectoryContents(Directory dir) async {
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      return;
    }
    await for (final entity in dir.list(recursive: false, followLinks: false)) {
      try {
        if (entity is Directory) {
          await entity.delete(recursive: true);
        } else if (entity is File) {
          await entity.delete();
        }
      } catch (_) {
        // 尽量清空；个别锁定文件跳过，后续复制可覆盖。
      }
    }
  }
}
