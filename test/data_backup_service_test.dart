import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/models/user_preferences.dart';
import 'package:mind_recall/services/app_storage_service.dart';
import 'package:mind_recall/services/data_backup_service.dart';
import 'package:mind_recall/services/user_preferences_service.dart';
import 'package:path/path.dart' as p;

class _FakeAppStorage extends AppStorageService {
  _FakeAppStorage(this._dir);

  final Directory _dir;

  @override
  Future<Directory> storageDirectory() async {
    if (!await _dir.exists()) {
      await _dir.create(recursive: true);
    }
    return _dir;
  }
}

void main() {
  late Directory tempRoot;
  late Directory memosDir;
  late Directory prefsHome;
  late UserPreferencesService prefsService;
  late DataBackupService backup;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('mind_recall_backup_');
    memosDir = Directory(p.join(tempRoot.path, 'MindRecall'));
    prefsHome = Directory(p.join(tempRoot.path, 'prefs'));
    await memosDir.create(recursive: true);
    await prefsHome.create(recursive: true);

    prefsService = UserPreferencesService(documentsDirectory: prefsHome);
    await prefsService.save(
      const UserPreferences(
        themeMode: ThemeMode.dark,
        localeCode: 'en',
        fontSize: AppFontSize.large,
        lastOpenedMemoId: '111',
      ),
    );

    backup = DataBackupService(
      prefsService: prefsService,
      appStorage: _FakeAppStorage(memosDir),
    );
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  test('export copies memos and preferences into timestamped folder', () async {
    await File(p.join(memosDir.path, '111.md')).writeAsString('标题\n\n正文');
    final assets = Directory(p.join(memosDir.path, '111_assets'));
    await assets.create();
    await File(p.join(assets.path, 'a.png')).writeAsBytes([1, 2, 3]);

    final exportParent = Directory(p.join(tempRoot.path, 'export'));
    await exportParent.create();
    final result = await backup.exportToDirectory(exportParent.path);

    expect(result.memoFileCount, 1);
    expect(result.includedPreferences, isTrue);
    expect(Directory(result.targetPath).existsSync(), isTrue);

    final exportedMemo = File(
      p.join(result.targetPath, 'MindRecall', '111.md'),
    );
    expect(await exportedMemo.readAsString(), '标题\n\n正文');
    expect(
      File(p.join(result.targetPath, 'MindRecall', '111_assets', 'a.png'))
          .existsSync(),
      isTrue,
    );
    expect(
      File(p.join(result.targetPath, 'user_preferences.json')).existsSync(),
      isTrue,
    );
  });

  test('import restores memos and overwrites existing preferences', () async {
    final backupRoot = Directory(p.join(tempRoot.path, 'MindRecall_Backup_x'));
    final backupMemos = Directory(p.join(backupRoot.path, 'MindRecall'));
    await backupMemos.create(recursive: true);
    await File(p.join(backupMemos.path, '222.md')).writeAsString(
      '导入\n\n![图](./222_assets/pic.png)',
    );
    final backupAssets = Directory(p.join(backupMemos.path, '222_assets'));
    await backupAssets.create();
    await File(p.join(backupAssets.path, 'pic.png')).writeAsBytes([9, 8, 7]);
    await File(p.join(backupRoot.path, 'user_preferences.json')).writeAsString(
      '{"themeMode":"dark","localeCode":"en","fontSize":"large"}',
    );

    await File(p.join(memosDir.path, 'old.md')).writeAsString('旧');
    await File(p.join(prefsHome.path, 'user_preferences.json')).writeAsString(
      '{"themeMode":"light","localeCode":"zh","fontSize":"small"}',
    );

    final result = await backup.importFromDirectory(
      backupRoot.path,
      mode: DataBackupImportMode.overwrite,
    );
    expect(result.memoFileCount, 1);
    expect(result.includedPreferences, isTrue);
    expect(File(p.join(memosDir.path, '222.md')).existsSync(), isTrue);
    expect(File(p.join(memosDir.path, 'old.md')).existsSync(), isFalse);
    expect(
      File(p.join(memosDir.path, '222_assets', 'pic.png')).readAsBytesSync(),
      [9, 8, 7],
    );
    expect(prefsService.preferences.themeMode, ThemeMode.dark);
    expect(prefsService.preferences.localeCode, 'en');
  });

  test('merge import 空备份不清空本地文档', () async {
    await File(p.join(memosDir.path, 'old.md')).writeAsString('旧');
    final backupRoot = Directory(p.join(tempRoot.path, 'MindRecall_Backup_empty'));
    final backupMemos = Directory(p.join(backupRoot.path, 'MindRecall'));
    await backupMemos.create(recursive: true);

    final result = await backup.importFromDirectory(backupRoot.path);
    expect(result.memoFileCount, 0);
    expect(File(p.join(memosDir.path, 'old.md')).existsSync(), isTrue);
    expect(await File(p.join(memosDir.path, 'old.md')).readAsString(), '旧');
  });

  test('merge import 按文件名添加并覆盖同名', () async {
    await File(p.join(memosDir.path, 'keep.md')).writeAsString('保留');
    await File(p.join(memosDir.path, 'same.md')).writeAsString('旧同名');
    final backupRoot = Directory(p.join(tempRoot.path, 'MindRecall_Backup_merge'));
    final backupMemos = Directory(p.join(backupRoot.path, 'MindRecall'));
    await backupMemos.create(recursive: true);
    await File(p.join(backupMemos.path, 'same.md')).writeAsString('新同名');
    await File(p.join(backupMemos.path, 'new.md')).writeAsString('新增');

    final result = await backup.importFromDirectory(
      backupRoot.path,
      mode: DataBackupImportMode.merge,
    );
    expect(result.memoFileCount, 2);
    expect(await File(p.join(memosDir.path, 'keep.md')).readAsString(), '保留');
    expect(await File(p.join(memosDir.path, 'same.md')).readAsString(), '新同名');
    expect(await File(p.join(memosDir.path, 'new.md')).readAsString(), '新增');
  });

  test('overwrite import 空备份会清空本地文档', () async {
    await File(p.join(memosDir.path, 'old.md')).writeAsString('旧');
    final backupRoot = Directory(p.join(tempRoot.path, 'MindRecall_Backup_empty2'));
    final backupMemos = Directory(p.join(backupRoot.path, 'MindRecall'));
    await backupMemos.create(recursive: true);

    final result = await backup.importFromDirectory(
      backupRoot.path,
      mode: DataBackupImportMode.overwrite,
    );
    expect(result.memoFileCount, 0);
    expect(File(p.join(memosDir.path, 'old.md')).existsSync(), isFalse);
  });

  test('copyFileReplacing 覆盖已存在的目标文件', () async {
    final source = File(p.join(tempRoot.path, 'src.json'));
    final dest = File(p.join(tempRoot.path, 'dest.json'));
    await source.writeAsString('new');
    await dest.writeAsString('old');
    await copyFileReplacing(source, dest);
    expect(await dest.readAsString(), 'new');
  });

  test('localAssetRelativePathsFromMarkdown 取出相对资源路径', () {
    expect(
      localAssetRelativePathsFromMarkdown(
        '文\n\n![a](./111_assets/x.png)\n![b](222_assets/y.jpg)',
      ),
      ['111_assets/x.png', '222_assets/y.jpg'],
    );
  });

  test('copyReferencedBackupAssets 在目录列举漏掉资源时仍能补拷', () async {
    final source = Directory(p.join(tempRoot.path, 'src_memos'));
    final dest = Directory(p.join(tempRoot.path, 'dest_memos'));
    await source.create();
    await dest.create();
    await File(p.join(source.path, '333.md')).writeAsString(
      '![p](./333_assets/a.png)',
    );
    await Directory(p.join(source.path, '333_assets')).create();
    await File(p.join(source.path, '333_assets', 'a.png')).writeAsBytes([4, 5]);
    // 只拷了正文，模拟 Android 未列出媒体目录。
    await File(p.join(dest.path, '333.md')).writeAsString(
      '![p](./333_assets/a.png)',
    );

    await copyReferencedBackupAssets(source, dest);
    expect(
      File(p.join(dest.path, '333_assets', 'a.png')).readAsBytesSync(),
      [4, 5],
    );
  });
}
