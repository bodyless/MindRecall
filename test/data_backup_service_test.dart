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

  test('import restores memos from backup root', () async {
    final backupRoot = Directory(p.join(tempRoot.path, 'MindRecall_Backup_x'));
    final backupMemos = Directory(p.join(backupRoot.path, 'MindRecall'));
    await backupMemos.create(recursive: true);
    await File(p.join(backupMemos.path, '222.md')).writeAsString('导入\n\n内容');

    await File(p.join(memosDir.path, 'old.md')).writeAsString('旧');

    final result = await backup.importFromDirectory(backupRoot.path);
    expect(result.memoFileCount, 1);
    expect(File(p.join(memosDir.path, '222.md')).existsSync(), isTrue);
    expect(File(p.join(memosDir.path, 'old.md')).existsSync(), isFalse);
  });
}
