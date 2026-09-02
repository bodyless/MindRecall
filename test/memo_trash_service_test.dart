import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/models/memo.dart';
import 'package:mind_recall/services/memo_fs_constants.dart';
import 'package:mind_recall/services/memo_storage_service.dart';
import 'package:mind_recall/services/memo_trash_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempRoot;
  late MemoStorageService storage;
  late MemoTrashService trash;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('mind_recall_trash_');
    trash = MemoTrashService(storageRootOverride: tempRoot);
    storage = MemoStorageService(
      storageRootOverride: tempRoot,
      trash: trash,
    );
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  test('有内容文件进 trash，恢复回原父目录', () async {
    final folder = await storage.createFolder(
      relativeParent: '',
      displayName: '工作',
    );
    final created = await storage.createMemo(relativeParent: folder.id);
    await storage.updateMemo(
      id: created.id,
      title: '标题',
      content: '正文',
    );
    final memo = await storage.loadMemo(created.id);

    await trash.moveToTrash(memo);

    expect(File(memo.filePath).existsSync(), isFalse);
    final items = await trash.listTrash();
    expect(items.single.id, memo.id);
    expect(items.single.isFolder, isFalse);

    await trash.restore([memo.id]);
    expect(File(memo.filePath).existsSync(), isTrue);
    expect(await trash.listTrash(), isEmpty);
  });

  test('原父目录不存在时恢复到 documents 根', () async {
    final folder = await storage.createFolder(
      relativeParent: '',
      displayName: '将删除',
    );
    final created = await storage.createMemo(relativeParent: folder.id);
    await storage.updateMemo(
      id: created.id,
      title: 'A',
      content: 'b',
    );
    final memo = await storage.loadMemo(created.id);
    await trash.moveToTrash(memo);
    await Directory(folder.directoryPath).delete(recursive: true);

    await trash.restore([memo.id]);
    final docs = Directory(p.join(tempRoot.path, MemoFs.documentsFolderName));
    expect(
      File(p.join(docs.path, p.basename(memo.filePath))).existsSync(),
      isTrue,
    );
  });

  test('文件夹整棵进站与恢复，manifest 覆盖并在恢复后移除', () async {
    final folder = await storage.createFolder(
      relativeParent: '',
      displayName: '归档',
    );
    final nested = await storage.createMemo(relativeParent: folder.id);
    await storage.updateMemo(id: nested.id, title: '内', content: '文');

    await storage.deleteFolder(folder.id);
    expect(Directory(folder.directoryPath).existsSync(), isFalse);
    final listed = await trash.listTrash();
    expect(listed.single.id, folder.id);
    expect(listed.single.isFolder, isTrue);
    expect(listed.single.title, '归档');

    await trash.restore([folder.id]);
    expect(Directory(folder.directoryPath).existsSync(), isTrue);
    expect(await storage.loadMemo(nested.id), isNotNull);
    expect(await trash.listTrash(), isEmpty);
  });
}
