import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models/memo.dart';
import '../models/memo_folder.dart';
import 'app_storage_service.dart';
import 'memo_fs_constants.dart';
import 'memo_image_service.dart';
import 'memo_trash_service.dart';

class MemoStorageService {
  MemoStorageService({
    Directory? storageRootOverride,
    MemoTrashService? trash,
  })  : _storageRootOverride = storageRootOverride,
        _trash = trash;

  static const documentsFolderName = MemoFs.documentsFolderName;
  static const fileConfExtension = MemoFs.fileConfExtension;
  static const _fileConfDisplayNameKey = 'displayName';
  static const _fileConfColorKey = 'color';
  static const _memoExtensions = ['.md', '.txt'];

  final Directory? _storageRootOverride;
  final MemoTrashService? _trash;

  MemoTrashService get _trashService => _trash ?? memoTrashService;

  AppStorageService get _storage => appStorageService;

  /// `MindRecall/` 根（与 `trash/` 同级）。
  Future<Directory> storageRoot() async {
    if (_storageRootOverride != null) {
      return _storageRootOverride!;
    }
    return _storage.storageDirectory();
  }

  /// 笔记树根：`MindRecall/documents/`。
  Future<Directory> memosDirectory() async {
    final root = await storageRoot();
    final docs = Directory(p.join(root.path, documentsFolderName));
    if (!await docs.exists()) {
      await docs.create(recursive: true);
    }
    await migrateLegacyMemosIfNeeded();
    return docs;
  }

  /// 把 `MindRecall/` 根上遗留的笔记与 `{id}_assets` 迁入 `documents/`。
  Future<void> migrateLegacyMemosIfNeeded() async {
    final root = await storageRoot();
    final docs = Directory(p.join(root.path, documentsFolderName));
    if (!await docs.exists()) {
      await docs.create(recursive: true);
    }

    for (final entity in root.listSync(followLinks: false)) {
      final name = p.basename(entity.path);
      if (name == documentsFolderName || name == MemoTrashService.folderName) {
        continue;
      }
      if (entity is File) {
        final ext = p.extension(entity.path);
        if (!_memoExtensions.contains(ext)) {
          continue;
        }
        final dest = File(p.join(docs.path, name));
        if (await dest.exists()) {
          continue;
        }
        await entity.rename(dest.path);
      } else if (entity is Directory && isAssetsDirectoryName(name)) {
        final dest = Directory(p.join(docs.path, name));
        if (await dest.exists()) {
          continue;
        }
        await entity.rename(dest.path);
      }
    }
  }

  static bool isAssetsDirectoryName(String name) =>
      MemoFs.isAssetsDirectoryName(name);

  static bool isFileConfName(String name) => MemoFs.isFileConfName(name);

  static String fileConfFileName(String folderId) =>
      MemoFs.fileConfFileName(folderId);

  /// 全库递归列出所有笔记（不含文件夹）。
  Future<List<Memo>> listMemos() async {
    final memosDir = await memosDirectory();
    final memos = <Memo>[];
    _collectMemos(memosDir, memos);
    sortMemosStable(memos);
    return memos;
  }

  /// 当前相对目录一层：文件夹 + 笔记。 [relativeParent] 空表示 `documents/` 根。
  Future<List<MemoDirEntry>> listDirEntries(String relativeParent) async {
    final docs = await memosDirectory();
    final dir = resolveRelativeDir(docs, relativeParent);
    if (!await dir.exists()) {
      return [];
    }

    final entries = <MemoDirEntry>[];
    for (final entity in dir.listSync(followLinks: false)) {
      final name = p.basename(entity.path);
      if (entity is Directory) {
        if (isAssetsDirectoryName(name)) {
          continue;
        }
        entries.add(MemoDirEntry.folder(folderFromDirectory(entity)));
      } else if (entity is File) {
        if (isFileConfName(name)) {
          continue;
        }
        final ext = p.extension(entity.path);
        if (_memoExtensions.contains(ext)) {
          entries.add(MemoDirEntry.file(_memoFromFile(entity)));
        }
      }
    }
    return entries;
  }

  /// 置顶优先（[pinnedIds] 中越靠前越靠前），其余按 [Memo.updatedAt] 降序
  ///（最近修改在前）；时间相同再比 id。
  static void sortMemosWithPins(List<Memo> memos, List<String> pinnedIds) {
    memos.sort((a, b) {
      final ai = pinnedIds.indexOf(a.id);
      final bi = pinnedIds.indexOf(b.id);
      final aPinned = ai >= 0;
      final bPinned = bi >= 0;
      if (aPinned && bPinned) {
        return ai.compareTo(bi);
      }
      if (aPinned) {
        return -1;
      }
      if (bPinned) {
        return 1;
      }
      return _compareByUpdatedAtDesc(a, b);
    });
  }

  /// 当前层四段排序：置顶文件夹 → 置顶文件 → 文件夹（建立时间新→旧）→ 文件（修改时间新→旧）。
  static List<MemoDirEntry> sortDirEntries({
    required List<MemoDirEntry> entries,
    required List<String> pinnedFolderIds,
    required List<String> pinnedMemoIds,
  }) {
    final pinnedFolders = <MemoDirEntry>[];
    final pinnedFiles = <MemoDirEntry>[];
    final folders = <MemoDirEntry>[];
    final files = <MemoDirEntry>[];

    for (final entry in entries) {
      if (entry.isFolder) {
        if (pinnedFolderIds.contains(entry.id)) {
          pinnedFolders.add(entry);
        } else {
          folders.add(entry);
        }
      } else if (pinnedMemoIds.contains(entry.id)) {
        pinnedFiles.add(entry);
      } else {
        files.add(entry);
      }
    }

    int pinOrder(List<String> ids, MemoDirEntry a, MemoDirEntry b) {
      return ids.indexOf(a.id).compareTo(ids.indexOf(b.id));
    }

    pinnedFolders.sort((a, b) => pinOrder(pinnedFolderIds, a, b));
    pinnedFiles.sort((a, b) => pinOrder(pinnedMemoIds, a, b));
    folders.sort((a, b) {
      final byTime = b.folder!.createdAt.compareTo(a.folder!.createdAt);
      if (byTime != 0) {
        return byTime;
      }
      return b.id.compareTo(a.id);
    });
    files.sort((a, b) => _compareByUpdatedAtDesc(a.memo!, b.memo!));
    return [...pinnedFolders, ...pinnedFiles, ...folders, ...files];
  }

  /// 按 [Memo.updatedAt] 降序（最近修改在前）；时间相同再比 id。
  static void sortMemosStable(List<Memo> memos) {
    memos.sort(_compareByUpdatedAtDesc);
  }

  static int _compareByUpdatedAtDesc(Memo a, Memo b) {
    final byTime = b.updatedAt.compareTo(a.updatedAt);
    if (byTime != 0) {
      return byTime;
    }
    final aId = int.tryParse(a.id) ?? 0;
    final bId = int.tryParse(b.id) ?? 0;
    return bId.compareTo(aId);
  }

  Future<Memo> loadMemo(String id) async {
    final file = await _fileForId(id);
    if (!await file.exists()) {
      throw FileSystemException('备忘录不存在', file.path);
    }
    return _memoFromFile(file);
  }

  Future<Memo> createMemo({String relativeParent = ''}) async {
    final docs = await memosDirectory();
    final parent = resolveRelativeDir(docs, relativeParent);
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    final createdAt = DateTime.now();
    final id = await allocateUniqueId();
    final filePath = p.join(parent.path, '$id.md');
    final file = File(filePath);
    await file.writeAsString('');

    return Memo(
      id: id,
      title: '',
      content: '',
      filePath: filePath,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }

  Future<MemoFolder> createFolder({
    required String relativeParent,
    required String displayName,
  }) async {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('文件夹名不能为空');
    }
    final docs = await memosDirectory();
    final parent = resolveRelativeDir(docs, relativeParent);
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    final id = await allocateUniqueId();
    final dir = Directory(p.join(parent.path, id));
    await dir.create(recursive: true);
    await writeFolderDisplayName(dir, id, trimmed);
    return folderFromDirectory(dir);
  }

  Future<MemoFolder> renameFolder({
    required String id,
    required String newDisplayName,
  }) async {
    final trimmed = newDisplayName.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('文件夹名不能为空');
    }
    final dir = await directoryForFolderId(id);
    if (dir == null || !await dir.exists()) {
      throw FileSystemException('文件夹不存在', id);
    }
    await writeFolderDisplayName(dir, id, trimmed);
    return folderFromDirectory(dir);
  }

  /// 写入或清除文件夹自定义颜色；[colorHex] 为 `null` 则删键。
  Future<MemoFolder> updateFolderColor({
    required String id,
    String? colorHex,
  }) async {
    final dir = await directoryForFolderId(id);
    if (dir == null || !await dir.exists()) {
      throw FileSystemException('文件夹不存在', id);
    }
    final map = _readFolderConfMap(dir, id);
    if (colorHex == null) {
      map.remove(_fileConfColorKey);
    } else {
      final parsed = MemoFolder.parseColorHex(colorHex);
      if (parsed == null) {
        throw ArgumentError('非法颜色');
      }
      map[_fileConfColorKey] = parsed;
    }
    await _writeFolderConfMap(dir, id, map);
    return folderFromDirectory(dir);
  }

  /// 全库文件夹树；根节点代表 `documents/`，不含笔记与 `*_assets`。
  Future<MemoFolderTreeNode> listFolderTree() async {
    final docs = await memosDirectory();
    return MemoFolderTreeNode(
      relativeDir: '',
      displayName: '',
      children: _folderTreeChildren(docs, ''),
    );
  }

  List<MemoFolderTreeNode> _folderTreeChildren(
    Directory dir,
    String parentRelative,
  ) {
    if (!dir.existsSync()) {
      return const [];
    }
    final children = <MemoFolderTreeNode>[];
    for (final entity in dir.listSync(followLinks: false)) {
      if (entity is! Directory) {
        continue;
      }
      final name = p.basename(entity.path);
      if (isAssetsDirectoryName(name)) {
        continue;
      }
      final relative = parentRelative.isEmpty ? name : '$parentRelative/$name';
      final folder = folderFromDirectory(entity);
      children.add(
        MemoFolderTreeNode(
          folderId: folder.id,
          relativeDir: relative,
          displayName: folder.displayName,
          createdAt: folder.createdAt,
          children: _folderTreeChildren(entity, relative),
        ),
      );
    }
    return children;
  }

  Future<Memo> moveMemo({
    required String id,
    required String destRelativeDir,
  }) async {
    final file = await _fileForId(id);
    if (!await file.exists()) {
      throw FileSystemException('备忘录不存在', file.path);
    }
    final docs = await memosDirectory();
    final destParent = resolveRelativeDir(docs, destRelativeDir);
    if (!await destParent.exists()) {
      throw FileSystemException('目标目录不存在', destParent.path);
    }
    if (p.equals(p.normalize(file.parent.path), p.normalize(destParent.path))) {
      throw StateError('已在目标目录');
    }
    final destFile = File(p.join(destParent.path, p.basename(file.path)));
    if (await destFile.exists()) {
      throw FileSystemException('目标已存在同名文件', destFile.path);
    }
    final assetsSrc = memoImageService.assetsDirectoryFor(
      memoId: id,
      memoFilePath: file.path,
    );
    final assetsDest = Directory(
      p.join(destParent.path, MemoImageService.assetsDirName(id)),
    );
    if (await assetsSrc.exists() && await assetsDest.exists()) {
      throw FileSystemException('目标已存在同名资源目录', assetsDest.path);
    }
    await file.rename(destFile.path);
    if (await assetsSrc.exists()) {
      await assetsSrc.rename(assetsDest.path);
    }
    return _memoFromFile(destFile);
  }

  Future<MemoFolder> moveFolder({
    required String id,
    required String destRelativeDir,
  }) async {
    final dir = await directoryForFolderId(id);
    if (dir == null || !await dir.exists()) {
      throw FileSystemException('文件夹不存在', id);
    }
    final docs = await memosDirectory();
    final sourceRelative = MemoFs.relativeDirFromDocs(docs, dir.path);
    if (MemoFs.isSelfOrDescendantRelative(
      candidate: destRelativeDir,
      ancestor: sourceRelative,
    )) {
      throw ArgumentError('不能移动到自身或子目录');
    }
    final destParent = resolveRelativeDir(docs, destRelativeDir);
    if (!await destParent.exists()) {
      throw FileSystemException('目标目录不存在', destParent.path);
    }
    if (p.equals(p.normalize(dir.parent.path), p.normalize(destParent.path))) {
      throw StateError('已在目标目录');
    }
    final destDir = Directory(p.join(destParent.path, id));
    if (await destDir.exists()) {
      throw FileSystemException('目标已存在同名文件夹', destDir.path);
    }
    await dir.rename(destDir.path);
    return folderFromDirectory(destDir);
  }

  Future<void> deleteFolder(String id) async {
    final dir = await directoryForFolderId(id);
    if (dir == null || !await dir.exists()) {
      return;
    }
    final folder = folderFromDirectory(dir);
    await _trashService.moveFolderToTrash(folder);
  }

  Future<bool> folderContainsMemo(String folderId, String memoId) async {
    final dir = await directoryForFolderId(folderId);
    if (dir == null || !await dir.exists()) {
      return false;
    }
    return _findMemoFile(dir, memoId) != null;
  }

  Future<Memo> updateMemo({
    required String id,
    required String title,
    required String content,
  }) async {
    final file = await _fileForId(id);
    if (!await file.exists()) {
      throw FileSystemException('备忘录不存在', file.path);
    }

    final buffer = StringBuffer();
    final trimmedTitle = title.trim();
    if (trimmedTitle.isNotEmpty) {
      buffer.writeln(trimmedTitle);
      buffer.writeln();
    }
    buffer.write(content);

    await file.writeAsString(buffer.toString());
    return _memoFromFile(file);
  }

  Future<void> deleteMemo(String id) async {
    final file = await _fileForId(id);
    if (!await file.exists()) {
      return;
    }
    final memo = _memoFromFile(file);
    if (MemoTrashService.hasContent(memo)) {
      await _trashService.moveToTrash(memo);
      return;
    }
    await file.delete();
    await memoImageService.deleteAssets(
      memoId: id,
      memoFilePath: memo.filePath,
    );
  }

  Future<Memo> renameMemo({
    required String id,
    required String newTitle,
  }) async {
    final memo = await loadMemo(id);
    return updateMemo(
      id: id,
      title: newTitle.trim(),
      content: memo.content,
    );
  }

  /// 笔记文件所在目录相对 `documents/`；根目录返回空串。
  Future<String> relativeParentOfPath(String absolutePath) async {
    final docs = await memosDirectory();
    final parent = p.dirname(absolutePath);
    return MemoFs.relativeDirFromDocs(docs, parent);
  }

  /// 文件夹自身相对 `documents/`。
  Future<String> relativeDirOfFolder(String directoryPath) async {
    final docs = await memosDirectory();
    return MemoFs.relativeDirFromDocs(docs, directoryPath);
  }

  static String relativeDirFromDocs(Directory docs, String absoluteDir) =>
      MemoFs.relativeDirFromDocs(docs, absoluteDir);

  static String parentRelativeDir(String currentRelativeDir) =>
      MemoFs.parentRelativeDir(currentRelativeDir);

  static Directory resolveRelativeDir(Directory docs, String relativeParent) =>
      MemoFs.resolveRelativeDir(docs, relativeParent);

  Future<bool> isValidRelativeDir(String relativeParent) async {
    if (relativeParent.isEmpty) {
      return true;
    }
    try {
      final docs = await memosDirectory();
      final dir = resolveRelativeDir(docs, relativeParent);
      return await dir.exists();
    } catch (_) {
      return false;
    }
  }

  static bool get supportsRevealInExplorer {
    if (kIsWeb) {
      return false;
    }
    return Platform.isWindows ||
        Platform.isMacOS ||
        Platform.isLinux ||
        Platform.isAndroid;
  }

  Future<void> revealInFileManager(String filePath) async {
    if (!supportsRevealInExplorer) {
      throw UnsupportedError('当前平台不支持打开文件目录');
    }

    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('文件不存在', filePath);
    }

    if (Platform.isWindows) {
      final normalized = p.normalize(filePath);
      await Process.run('explorer.exe', ['/select,$normalized']);
      return;
    }

    if (Platform.isMacOS) {
      await Process.run('open', ['-R', filePath]);
      return;
    }

    if (Platform.isLinux) {
      await Process.run('xdg-open', [p.dirname(filePath)]);
      return;
    }

    if (Platform.isAndroid) {
      final folder = p.dirname(filePath);
      await Process.run('am', [
        'start',
        '-a',
        'android.intent.action.VIEW',
        '-d',
        'file://$folder',
      ]);
    }
  }

  @visibleForTesting
  Future<String> allocateUniqueId() async {
    final occupied = await collectOccupiedIds();
    var id = DateTime.now().millisecondsSinceEpoch.toString();
    while (occupied.contains(id)) {
      id = (int.parse(id) + 1).toString();
    }
    return id;
  }

  @visibleForTesting
  Future<Set<String>> collectOccupiedIds() async {
    final docs = await memosDirectory();
    final ids = <String>{};
    _collectIds(docs, ids);
    return ids;
  }

  void _collectIds(Directory dir, Set<String> ids) {
    for (final entity in dir.listSync(followLinks: false)) {
      final name = p.basename(entity.path);
      if (entity is Directory) {
        if (isAssetsDirectoryName(name)) {
          continue;
        }
        ids.add(name);
        _collectIds(entity, ids);
      } else if (entity is File) {
        final ext = p.extension(entity.path);
        if (_memoExtensions.contains(ext)) {
          ids.add(p.basenameWithoutExtension(entity.path));
        }
      }
    }
  }

  void _collectMemos(Directory dir, List<Memo> out) {
    for (final entity in dir.listSync(followLinks: false)) {
      final name = p.basename(entity.path);
      if (entity is Directory) {
        if (isAssetsDirectoryName(name)) {
          continue;
        }
        _collectMemos(entity, out);
      } else if (entity is File) {
        final ext = p.extension(entity.path);
        if (_memoExtensions.contains(ext)) {
          out.add(_memoFromFile(entity));
        }
      }
    }
  }

  Future<File> _fileForId(String id) async {
    final memosDir = await memosDirectory();
    final found = _findMemoFile(memosDir, id);
    if (found != null) {
      return found;
    }
    return File(p.join(memosDir.path, '$id.md'));
  }

  File? _findMemoFile(Directory dir, String id) {
    for (final entity in dir.listSync(followLinks: false)) {
      final name = p.basename(entity.path);
      if (entity is Directory) {
        if (isAssetsDirectoryName(name)) {
          continue;
        }
        final nested = _findMemoFile(entity, id);
        if (nested != null) {
          return nested;
        }
      } else if (entity is File) {
        if (!_memoExtensions.contains(p.extension(entity.path))) {
          continue;
        }
        if (p.basenameWithoutExtension(entity.path) == id) {
          return entity;
        }
      }
    }
    return null;
  }

  Future<Directory?> directoryForFolderId(String id) async {
    final docs = await memosDirectory();
    return _findFolderDir(docs, id);
  }

  Directory? _findFolderDir(Directory dir, String id) {
    for (final entity in dir.listSync(followLinks: false)) {
      if (entity is! Directory) {
        continue;
      }
      final name = p.basename(entity.path);
      if (isAssetsDirectoryName(name)) {
        continue;
      }
      if (name == id) {
        return entity;
      }
      final nested = _findFolderDir(entity, id);
      if (nested != null) {
        return nested;
      }
    }
    return null;
  }

  MemoFolder folderFromDirectory(Directory dir) {
    final stat = dir.statSync();
    final id = p.basename(dir.path);
    final conf = _loadFolderConf(dir, id);
    return MemoFolder(
      id: id,
      directoryPath: dir.path,
      displayName: conf.displayName,
      createdAt: stat.changed,
      updatedAt: stat.modified,
      colorHex: conf.colorHex,
    );
  }

  String readFolderDisplayName(Directory dir, String id) {
    return _loadFolderConf(dir, id).displayName;
  }

  Future<void> writeFolderDisplayName(
    Directory dir,
    String id,
    String displayName,
  ) async {
    final map = _readFolderConfMap(dir, id);
    map[_fileConfDisplayNameKey] = displayName;
    await _writeFolderConfMap(dir, id, map);
  }

  /// 一次解析 conf：坏文件当空 Map，不抛给调用方。
  ({String displayName, String? colorHex}) _loadFolderConf(
    Directory dir,
    String id,
  ) {
    final map = _readFolderConfMap(dir, id);
    return (
      displayName: _displayNameFromConfMap(map, id),
      colorHex: MemoFolder.parseColorHex(map[_fileConfColorKey]),
    );
  }

  Map<String, dynamic> _readFolderConfMap(Directory dir, String id) {
    final conf = File(p.join(dir.path, fileConfFileName(id)));
    if (!conf.existsSync()) {
      return <String, dynamic>{};
    }
    try {
      final decoded = jsonDecode(conf.readAsStringSync());
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  String _displayNameFromConfMap(Map<String, dynamic> map, String id) {
    final raw = map[_fileConfDisplayNameKey];
    if (raw is String) {
      final name = raw.trim();
      if (name.isNotEmpty) {
        return name;
      }
    }
    return id;
  }

  Future<void> _writeFolderConfMap(
    Directory dir,
    String id,
    Map<String, dynamic> map,
  ) async {
    final conf = File(p.join(dir.path, fileConfFileName(id)));
    await conf.writeAsString(
      const JsonEncoder.withIndent('  ').convert(map),
    );
  }

  Memo _memoFromFile(File file) {
    final stat = file.statSync();
    final id = p.basenameWithoutExtension(file.path);
    final raw = file.readAsStringSync();
    final parsed = _parseMemoContent(raw);

    return Memo(
      id: id,
      title: parsed.title,
      content: parsed.content,
      filePath: file.path,
      createdAt: stat.changed,
      updatedAt: stat.modified,
    );
  }

  ({String title, String content}) _parseMemoContent(String raw) {
    if (raw.isEmpty) {
      return (title: '', content: '');
    }

    final lines = raw.split('\n');
    if (lines.length >= 2 && lines[1].trim().isEmpty) {
      return (
        title: lines.first,
        content: lines.sublist(2).join('\n'),
      );
    }

    return (title: '', content: raw);
  }

  @visibleForTesting
  ({String title, String content}) parseMemoContentForTest(String raw) {
    return _parseMemoContent(raw);
  }
}
