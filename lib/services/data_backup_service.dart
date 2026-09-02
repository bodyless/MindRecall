import 'dart:io';

import 'package:path/path.dart' as p;

import 'android_storage_permission.dart';
import 'app_storage_service.dart';
import 'memo_trash_service.dart';
import 'user_preferences_service.dart';

/// 导入策略：合并按文件名添加/覆盖同名；覆盖先清空本地再写入备份。
enum DataBackupImportMode {
  merge,
  overwrite,
}

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
    final memoCount = await _copyMemosDirectory(sourceMemos, destMemos);

    final prefsSource = await prefsService.preferencesFile();
    var includedPrefs = false;
    if (await prefsSource.exists()) {
      final prefsDest = p.join(
        backupRoot.path,
        UserPreferencesService.fileName,
      );
      await copyFileReplacing(prefsSource, File(prefsDest));
      includedPrefs = true;
    } else {
      // 无文件时仍写出当前内存配置，保证备份完整。
      await prefsService.save(prefsService.preferences);
      final refreshed = await prefsService.preferencesFile();
      if (await refreshed.exists()) {
        await copyFileReplacing(
          refreshed,
          File(p.join(backupRoot.path, UserPreferencesService.fileName)),
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
  ///
  /// [mode] 默认 [DataBackupImportMode.merge]：按文件名拷贝，同名覆盖、新名添加，
  /// 空备份不会清空本地文档。 [DataBackupImportMode.overwrite] 先清空再写入。
  Future<DataBackupResult> importFromDirectory(
    String selectedPath, {
    DataBackupImportMode mode = DataBackupImportMode.merge,
  }) async {
    final selected = Directory(selectedPath);
    if (!await selected.exists()) {
      throw FileSystemException('备份目录不存在', selectedPath);
    }

    final resolved = await _resolveBackupLayout(selected);
    final sourceMemos = resolved.memosDir;
    final prefsFile = resolved.prefsFile;

    final targetMemos = await _appStorage.storageDirectory();
    if (mode == DataBackupImportMode.overwrite) {
      await _clearDirectoryContents(targetMemos);
    }
    final memoCount = await _copyMemosDirectory(sourceMemos, targetMemos);

    var includedPrefs = false;
    if (prefsFile != null && await prefsFile.exists()) {
      final dest = await prefsService.preferencesFile();
      await copyFileReplacing(prefsFile, dest);
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

  /// 复制文档目录（含 `{id}_assets/` 图片）。Android 优先走 Java listFiles。
  Future<int> _copyMemosDirectory(Directory source, Directory destination) async {
    final nativeCount = await AndroidStoragePermission.copyDirectoryTree(
      sourcePath: source.path,
      destPath: destination.path,
      skipName: MemoTrashService.folderName,
    );
    final memoCount = nativeCount ?? await _copyDirectory(source, destination);
    await copyReferencedBackupAssets(source, destination);
    return memoCount;
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
      final type = FileSystemEntity.typeSync(entity.path, followLinks: false);
      if (type == FileSystemEntityType.directory) {
        memoFiles += await _copyDirectory(
          Directory(entity.path),
          Directory(p.join(destination.path, name)),
        );
      } else if (type == FileSystemEntityType.file) {
        final lower = name.toLowerCase();
        final isMemo = lower.endsWith('.md') || lower.endsWith('.txt');
        if (isMemo) {
          memoFiles++;
        }
        try {
          await copyFileReplacing(
            File(entity.path),
            File(p.join(destination.path, name)),
          );
        } on FileSystemException {
          // 媒体文件可能列得出但读不了；后面按 Markdown 引用再补拷。
          if (isMemo) {
            rethrow;
          }
        }
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

/// 覆盖复制文件。Android 上 [File.copy] 对公共目录里「非本安装创建」的文件常 EACCES，
/// 先删目标再 copy；仍失败则读写字节。调用方须已具备可读源文件的存储权限。
Future<void> copyFileReplacing(File source, File dest) async {
  await dest.parent.create(recursive: true);
  if (await dest.exists()) {
    await dest.delete();
  }
  try {
    await source.copy(dest.path);
  } on FileSystemException {
    final bytes = await source.readAsBytes();
    await dest.writeAsBytes(bytes, flush: true);
  }
}

/// 从 Markdown 取出指向 `{id}_assets/` 的相对路径（去掉开头 `./`）。
List<String> localAssetRelativePathsFromMarkdown(String markdown) {
  final matches = RegExp(
    r'!\[[^\]]*\]\((?:\./)?([^)\s]+_assets/[^)\s]+)\)',
  ).allMatches(markdown);
  return [
    for (final match in matches) match.group(1)!.replaceAll(r'\', '/'),
  ];
}

/// 按正文里的 `./{id}_assets/…` 引用补拷，不依赖 Directory.list 是否列出媒体目录。
Future<void> copyReferencedBackupAssets(
  Directory source,
  Directory destination,
) async {
  if (!await destination.exists()) {
    return;
  }
  await for (final entity in destination.list(
    recursive: false,
    followLinks: false,
  )) {
    if (entity is! File) {
      continue;
    }
    final lower = entity.path.toLowerCase();
    if (!lower.endsWith('.md') && !lower.endsWith('.txt')) {
      continue;
    }
    final markdown = await entity.readAsString();
    for (final relative in localAssetRelativePathsFromMarkdown(markdown)) {
      final destFile = File(p.join(destination.path, relative));
      if (await destFile.exists() && await destFile.length() > 0) {
        continue;
      }
      final srcFile = File(p.join(source.path, relative));
      if (!await srcFile.exists()) {
        continue;
      }
      await copyFileReplacing(srcFile, destFile);
    }
  }
}
