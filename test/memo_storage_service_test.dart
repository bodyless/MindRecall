import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/models/memo.dart';
import 'package:mind_recall/models/memo_folder.dart';
import 'package:mind_recall/services/memo_fs_constants.dart';
import 'package:mind_recall/services/memo_storage_service.dart';
import 'package:mind_recall/services/memo_trash_service.dart';
import 'package:path/path.dart' as p;

void main() {
  group('MemoStorageService', () {
    late MemoStorageService service;

    setUp(() {
      service = MemoStorageService();
    });

    test('parseMemoContent handles title and body', () {
      final parsed = service.parseMemoContentForTest('My Title\n\nHello\nWorld');
      expect(parsed.title, 'My Title');
      expect(parsed.content, 'Hello\nWorld');
    });

    test('parseMemoContent handles body only', () {
      final parsed = service.parseMemoContentForTest('Hello\nWorld');
      expect(parsed.title, '');
      expect(parsed.content, 'Hello\nWorld');
    });

    test('parseMemoContent handles empty file', () {
      final parsed = service.parseMemoContentForTest('');
      expect(parsed.title, '');
      expect(parsed.content, '');
    });
  });

  group('documents layout / migration', () {
    late Directory tempRoot;
    late MemoStorageService service;
    late MemoTrashService trash;

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp('mind_recall_storage_');
      trash = MemoTrashService(storageRootOverride: tempRoot);
      service = MemoStorageService(
        storageRootOverride: tempRoot,
        trash: trash,
      );
    });

    tearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    test('migrateLegacyMemosIfNeeded 将根上 md 与 assets 迁入 documents', () async {
      await File(p.join(tempRoot.path, '111.md')).writeAsString('标题\n\n正文');
      final assets = Directory(p.join(tempRoot.path, '111_assets'));
      await assets.create();
      await File(p.join(assets.path, 'a.png')).writeAsBytes([1]);
      await Directory(p.join(tempRoot.path, 'trash')).create();

      await service.migrateLegacyMemosIfNeeded();

      final docs = Directory(p.join(tempRoot.path, MemoFs.documentsFolderName));
      expect(File(p.join(docs.path, '111.md')).existsSync(), isTrue);
      expect(
        File(p.join(docs.path, '111_assets', 'a.png')).existsSync(),
        isTrue,
      );
      expect(File(p.join(tempRoot.path, '111.md')).existsSync(), isFalse);
      expect(Directory(p.join(tempRoot.path, 'trash')).existsSync(), isTrue);
    });

    test('folderFromDirectory 用目录 mtime 作为 updatedAt', () async {
      final folder = await service.createFolder(
        relativeParent: '',
        displayName: '工作',
      );
      final dir = Directory(folder.directoryPath);
      final stat = dir.statSync();
      final fromDisk = service.folderFromDirectory(dir);
      expect(fromDisk.updatedAt, stat.modified);
      expect(fromDisk.createdAt, stat.changed);
    });

    test('createMemo 写入当前相对目录，嵌套路径可 load', () async {
      final folder = await service.createFolder(
        relativeParent: '',
        displayName: '工作',
      );
      final memo = await service.createMemo(relativeParent: folder.id);
      expect(
        p.normalize(p.dirname(memo.filePath)),
        p.normalize(folder.directoryPath),
      );

      final loaded = await service.loadMemo(memo.id);
      expect(loaded.id, memo.id);
      expect(loaded.filePath, memo.filePath);
    });

    test('listDirEntries 排除 assets 与 fileconf，无 conf 回退磁盘名', () async {
      final folder = await service.createFolder(
        relativeParent: '',
        displayName: '工作',
      );
      await service.createMemo(relativeParent: '');
      final nestedMemo = await service.createMemo(relativeParent: folder.id);
      final assets = Directory(
        p.join(folder.directoryPath, '${nestedMemo.id}_assets'),
      );
      await assets.create();

      final rootEntries = await service.listDirEntries('');
      expect(rootEntries.where((e) => e.isFolder).length, 1);
      expect(rootEntries.where((e) => !e.isFolder).length, 1);
      expect(
        rootEntries.any((e) => MemoFs.isAssetsDirectoryName(e.id)),
        isFalse,
      );

      await File(
        p.join(folder.directoryPath, MemoFs.fileConfFileName(folder.id)),
      ).delete();
      final unnamed = await service.listDirEntries('');
      final folderEntry = unnamed.firstWhere((e) => e.isFolder);
      expect(folderEntry.folder!.displayName, folder.id);

      final inner = await service.listDirEntries(folder.id);
      expect(inner.where((e) => !e.isFolder).map((e) => e.id), [nestedMemo.id]);
      expect(inner.any((e) => e.id.endsWith('_assets')), isFalse);
    });

    test('sortDirEntries 四段：置顶文件夹、置顶文件、文件夹、文件', () {
      final folderOld = MemoDirEntry.folder(
        MemoFolder(
          id: 'f-old',
          directoryPath: 'f-old',
          displayName: 'old',
          createdAt: DateTime(2026, 1, 1),
        ),
      );
      final folderNew = MemoDirEntry.folder(
        MemoFolder(
          id: 'f-new',
          directoryPath: 'f-new',
          displayName: 'new',
          createdAt: DateTime(2026, 6, 1),
        ),
      );
      final pinnedFolder = MemoDirEntry.folder(
        MemoFolder(
          id: 'f-pin',
          directoryPath: 'f-pin',
          displayName: 'pin',
          createdAt: DateTime(2020, 1, 1),
        ),
      );
      Memo file({required String id, required DateTime updatedAt}) {
        return Memo(
          id: id,
          title: id,
          content: '',
          filePath: '$id.md',
          createdAt: updatedAt,
          updatedAt: updatedAt,
        );
      }

      final fileOld = MemoDirEntry.file(
        file(id: 'm-old', updatedAt: DateTime(2026, 1, 1)),
      );
      final fileNew = MemoDirEntry.file(
        file(id: 'm-new', updatedAt: DateTime(2026, 8, 1)),
      );
      final pinnedFile = MemoDirEntry.file(
        file(id: 'm-pin', updatedAt: DateTime(2025, 1, 1)),
      );

      final sorted = MemoStorageService.sortDirEntries(
        entries: [
          fileOld,
          folderOld,
          pinnedFile,
          folderNew,
          pinnedFolder,
          fileNew,
        ],
        pinnedFolderIds: ['f-pin'],
        pinnedMemoIds: ['m-pin'],
      );
      expect(sorted.map((e) => e.id).toList(), [
        'f-pin',
        'm-pin',
        'f-new',
        'f-old',
        'm-new',
        'm-old',
      ]);
    });

    test('moveMemo 连 assets 搬到子目录', () async {
      final memo = await service.createMemo();
      final assets = Directory(
        p.join(p.dirname(memo.filePath), '${memo.id}_assets'),
      );
      await assets.create();
      await File(p.join(assets.path, 'a.png')).writeAsBytes([1]);
      final dest = await service.createFolder(
        relativeParent: '',
        displayName: '工作',
      );

      final moved = await service.moveMemo(
        id: memo.id,
        destRelativeDir: dest.id,
      );
      expect(
        p.normalize(p.dirname(moved.filePath)),
        p.normalize(dest.directoryPath),
      );
      expect(File(memo.filePath).existsSync(), isFalse);
      expect(
        File(
          p.join(dest.directoryPath, '${memo.id}_assets', 'a.png'),
        ).existsSync(),
        isTrue,
      );
      final loaded = await service.loadMemo(memo.id);
      expect(loaded.filePath, moved.filePath);
    });

    test('moveMemo 目标已存在同名则失败', () async {
      final memo = await service.createMemo();
      final dest = await service.createFolder(
        relativeParent: '',
        displayName: '工作',
      );
      await File(
        p.join(dest.directoryPath, p.basename(memo.filePath)),
      ).writeAsString('占用');
      await expectLater(
        service.moveMemo(id: memo.id, destRelativeDir: dest.id),
        throwsA(anyOf(isA<FileSystemException>(), isA<StateError>())),
      );
      expect(File(memo.filePath).existsSync(), isTrue);
    });

    test('moveFolder 拒绝搬进自身子孙', () async {
      final parent = await service.createFolder(
        relativeParent: '',
        displayName: 'A',
      );
      final child = await service.createFolder(
        relativeParent: parent.id,
        displayName: 'B',
      );
      await expectLater(
        service.moveFolder(
          id: parent.id,
          destRelativeDir: '${parent.id}/${child.id}',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('moveFolder 目标已存在同 id 则失败', () async {
      final folder = await service.createFolder(
        relativeParent: '',
        displayName: 'A',
      );
      final dest = await service.createFolder(
        relativeParent: '',
        displayName: 'C',
      );
      await Directory(p.join(dest.directoryPath, folder.id)).create();
      await expectLater(
        service.moveFolder(id: folder.id, destRelativeDir: dest.id),
        throwsA(anyOf(isA<FileSystemException>(), isA<StateError>())),
      );
      expect(Directory(folder.directoryPath).existsSync(), isTrue);
    });

    test('moveFolder 整棵搬迁', () async {
      final parent = await service.createFolder(
        relativeParent: '',
        displayName: 'A',
      );
      final child = await service.createFolder(
        relativeParent: parent.id,
        displayName: 'B',
      );
      final nestedMemo = await service.createMemo(
        relativeParent: '${parent.id}/${child.id}',
      );
      final dest = await service.createFolder(
        relativeParent: '',
        displayName: 'C',
      );

      await service.moveFolder(id: parent.id, destRelativeDir: dest.id);
      final loaded = await service.loadMemo(nestedMemo.id);
      expect(
        p.normalize(loaded.filePath),
        p.normalize(
          p.join(dest.directoryPath, parent.id, child.id, '${nestedMemo.id}.md'),
        ),
      );

      final tree = await service.listFolderTree();
      expect(tree.relativeDir, isEmpty);
      expect(tree.children.map((n) => n.folderId), [dest.id]);
      expect(tree.children.single.children.map((n) => n.folderId), [parent.id]);
    });

    test('createFolder 的 conf 无 color 键', () async {
      final folder = await service.createFolder(
        relativeParent: '',
        displayName: '工作',
      );
      expect(folder.colorHex, isNull);
      final decoded = jsonDecode(
        File(
          p.join(folder.directoryPath, MemoFs.fileConfFileName(folder.id)),
        ).readAsStringSync(),
      ) as Map;
      expect(decoded.containsKey('color'), isFalse);
      expect(decoded['displayName'], '工作');
    });

    test('设色后 renameFolder 保留 color，清除删键保留 displayName', () async {
      final folder = await service.createFolder(
        relativeParent: '',
        displayName: '工作',
      );
      await service.updateFolderColor(id: folder.id, colorHex: '#a1b2c3');
      final renamed = await service.renameFolder(
        id: folder.id,
        newDisplayName: '生活',
      );
      expect(renamed.colorHex, '#A1B2C3');
      expect(renamed.displayName, '生活');

      await service.updateFolderColor(id: folder.id, colorHex: null);
      final cleared = service.folderFromDirectory(
        Directory(folder.directoryPath),
      );
      expect(cleared.colorHex, isNull);
      expect(cleared.displayName, '生活');
      final decoded = jsonDecode(
        File(
          p.join(folder.directoryPath, MemoFs.fileConfFileName(folder.id)),
        ).readAsStringSync(),
      ) as Map;
      expect(decoded.containsKey('color'), isFalse);
      expect(decoded['displayName'], '生活');
    });

    test('合并写保留未知键', () async {
      final folder = await service.createFolder(
        relativeParent: '',
        displayName: '工作',
      );
      final conf = File(
        p.join(folder.directoryPath, MemoFs.fileConfFileName(folder.id)),
      );
      await conf.writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'displayName': '工作',
          'extra': 'keep',
        }),
      );
      await service.updateFolderColor(id: folder.id, colorHex: '#112233');
      var decoded = jsonDecode(conf.readAsStringSync()) as Map;
      expect(decoded['extra'], 'keep');
      expect(decoded['color'], '#112233');

      await service.renameFolder(id: folder.id, newDisplayName: '新名');
      decoded = jsonDecode(conf.readAsStringSync()) as Map;
      expect(decoded['extra'], 'keep');
      expect(decoded['displayName'], '新名');
      expect(decoded['color'], '#112233');
    });

    test('缺 conf、坏 JSON、非法 color 不抛错且视为无色', () async {
      final folder = await service.createFolder(
        relativeParent: '',
        displayName: '工作',
      );
      final dir = Directory(folder.directoryPath);
      final conf = File(
        p.join(folder.directoryPath, MemoFs.fileConfFileName(folder.id)),
      );

      await conf.delete();
      final missing = service.folderFromDirectory(dir);
      expect(missing.displayName, folder.id);
      expect(missing.colorHex, isNull);

      await conf.writeAsString('not-json');
      final broken = service.folderFromDirectory(dir);
      expect(broken.displayName, folder.id);
      expect(broken.colorHex, isNull);

      await conf.writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'displayName': '工作',
          'color': '#RGB',
        }),
      );
      final invalid = service.folderFromDirectory(dir);
      expect(invalid.displayName, '工作');
      expect(invalid.colorHex, isNull);
    });
  });

  group('sortMemosStable / sortMemosWithPins', () {
    Memo memo({
      required String id,
      required DateTime updatedAt,
      DateTime? createdAt,
    }) {
      final created = createdAt ?? updatedAt;
      return Memo(
        id: id,
        title: id,
        content: '',
        filePath: '$id.md',
        createdAt: created,
        updatedAt: updatedAt,
      );
    }

    test('sortMemosStable orders by updatedAt descending', () {
      final older = memo(
        id: '200',
        updatedAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 8, 1),
      );
      final newer = memo(
        id: '100',
        updatedAt: DateTime(2026, 8, 1),
        createdAt: DateTime(2026, 1, 1),
      );
      final memos = [older, newer];
      MemoStorageService.sortMemosStable(memos);
      expect(memos.map((m) => m.id), ['100', '200']);
    });

    test('sortMemosWithPins keeps pins first then updatedAt', () {
      final older = memo(id: '1', updatedAt: DateTime(2026, 1, 1));
      final newer = memo(id: '2', updatedAt: DateTime(2026, 8, 1));
      final pinnedOld = memo(id: '9', updatedAt: DateTime(2025, 1, 1));
      final memos = [older, newer, pinnedOld];
      MemoStorageService.sortMemosWithPins(memos, ['9']);
      expect(memos.map((m) => m.id), ['9', '2', '1']);
    });
  });
}
