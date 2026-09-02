import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/memo.dart';
import '../models/memo_folder.dart';
import 'app_storage_service.dart';
import 'memo_fs_constants.dart';
import 'memo_image_service.dart';

enum TrashItemKind { file, folder }

/// 回收站中的条目（文档或整棵文件夹）。
class TrashItem {
  const TrashItem({
    required this.id,
    required this.kind,
    required this.filePath,
    required this.title,
    required this.contentPreview,
    required this.trashedAt,
    this.assetsPath,
  });

  final String id;
  final TrashItemKind kind;
  final String filePath;
  final String title;
  final String contentPreview;
  final DateTime trashedAt;
  final String? assetsPath;

  bool get isFolder => kind == TrashItemKind.folder;

  String displayTitle(String untitledLabel) {
    final t = title.trim();
    if (t.isNotEmpty) {
      return t;
    }
    if (isFolder) {
      return id;
    }
    final preview = contentPreview.trim();
    if (preview.isEmpty) {
      return untitledLabel;
    }
    final first = preview.split('\n').first.trim();
    return first.isEmpty ? untitledLabel : first;
  }
}

class TrashManifestEntry {
  const TrashManifestEntry({
    required this.id,
    required this.kind,
    required this.relativeParent,
  });

  final String id;
  final TrashItemKind kind;

  /// 相对 `documents/` 的原父路径；空串表示文档根。
  final String relativeParent;

  factory TrashManifestEntry.fromJson(Map<String, dynamic> json) {
    final kindRaw = json['kind'] as String? ?? 'file';
    return TrashManifestEntry(
      id: json['id'] as String,
      kind: kindRaw == 'folder' ? TrashItemKind.folder : TrashItemKind.file,
      relativeParent: (json['relativeParent'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind == TrashItemKind.folder ? 'folder' : 'file',
        'relativeParent': relativeParent,
      };
}

/// `MindRecall/trash/` 回收站：有内容的删除先移入，空文档直接删。
class MemoTrashService {
  MemoTrashService({Directory? storageRootOverride})
      : _storageRootOverride = storageRootOverride;

  static const folderName = 'trash';
  static const manifestFileName = 'manifest.json';
  static const _memoExtensions = ['.md', '.txt'];

  final Directory? _storageRootOverride;

  Future<Directory> storageRoot() async {
    if (_storageRootOverride != null) {
      return _storageRootOverride!;
    }
    return appStorageService.storageDirectory();
  }

  Future<Directory> documentsDirectory() async {
    final root = await storageRoot();
    final dir = Directory(
      p.join(root.path, MemoFs.documentsFolderName),
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> trashDirectory() async {
    final root = await storageRoot();
    final dir = Directory(p.join(root.path, folderName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 文档是否有可保留内容（标题或正文非空）。
  static bool hasContent(Memo memo) {
    return memo.title.trim().isNotEmpty || memo.content.trim().isNotEmpty;
  }

  Future<List<TrashItem>> listTrash() async {
    final trash = await trashDirectory();
    final items = <TrashItem>[];
    for (final entity in trash.listSync(followLinks: false)) {
      final name = p.basename(entity.path);
      if (name == manifestFileName) {
        continue;
      }
      if (entity is File) {
        if (!_memoExtensions.contains(p.extension(entity.path))) {
          continue;
        }
        items.add(_itemFromFile(entity));
      } else if (entity is Directory) {
        if (MemoFs.isAssetsDirectoryName(name)) {
          continue;
        }
        items.add(_itemFromFolder(entity));
      }
    }
    items.sort((a, b) => b.trashedAt.compareTo(a.trashedAt));
    return items;
  }

  /// 移入回收站（覆盖同 id 旧条目）。
  Future<void> moveToTrash(Memo memo) async {
    final trash = await trashDirectory();
    final docs = await documentsDirectory();
    final relativeParent = MemoFs.relativeDirFromDocs(
      docs,
      p.dirname(memo.filePath),
    );
    await _upsertManifest(
      TrashManifestEntry(
        id: memo.id,
        kind: TrashItemKind.file,
        relativeParent: relativeParent,
      ),
    );

    final ext = p.extension(memo.filePath);
    final destPath = p.join(trash.path, '${memo.id}$ext');
    final source = File(memo.filePath);
    if (await source.exists()) {
      final dest = File(destPath);
      if (await dest.exists()) {
        await dest.delete();
      }
      await source.rename(destPath);
    }

    final assetsSrc = memoImageService.assetsDirectoryFor(
      memoId: memo.id,
      memoFilePath: memo.filePath,
    );
    if (await assetsSrc.exists()) {
      final assetsDest = Directory(p.join(trash.path, '${memo.id}_assets'));
      if (await assetsDest.exists()) {
        await assetsDest.delete(recursive: true);
      }
      await assetsSrc.rename(assetsDest.path);
    }
  }

  Future<void> moveFolderToTrash(MemoFolder folder) async {
    final trash = await trashDirectory();
    final docs = await documentsDirectory();
    final relativeParent = MemoFs.relativeDirFromDocs(
      docs,
      p.dirname(folder.directoryPath),
    );
    await _upsertManifest(
      TrashManifestEntry(
        id: folder.id,
        kind: TrashItemKind.folder,
        relativeParent: relativeParent,
      ),
    );

    final source = Directory(folder.directoryPath);
    if (!await source.exists()) {
      return;
    }
    final dest = Directory(p.join(trash.path, folder.id));
    if (await dest.exists()) {
      await dest.delete(recursive: true);
    }
    await source.rename(dest.path);
  }

  Future<void> restore(List<String> ids) async {
    if (ids.isEmpty) {
      return;
    }
    final trash = await trashDirectory();
    final docs = await documentsDirectory();
    final manifest = await _readManifest();

    for (final id in ids) {
      final entry = manifest[id];
      final destParent = await _restoreParentDir(
        docs,
        entry?.relativeParent ?? '',
      );

      final folderSrc = Directory(p.join(trash.path, id));
      if (await folderSrc.exists()) {
        final dest = Directory(p.join(destParent.path, id));
        if (await dest.exists()) {
          await dest.delete(recursive: true);
        }
        await folderSrc.rename(dest.path);
        await _removeManifest(id);
        continue;
      }

      File? srcFile;
      for (final ext in _memoExtensions) {
        final candidate = File(p.join(trash.path, '$id$ext'));
        if (await candidate.exists()) {
          srcFile = candidate;
          break;
        }
      }
      if (srcFile == null) {
        continue;
      }
      final dest = File(p.join(destParent.path, p.basename(srcFile.path)));
      if (await dest.exists()) {
        await dest.delete();
      }
      await srcFile.rename(dest.path);

      final assetsSrc = Directory(p.join(trash.path, '${id}_assets'));
      if (await assetsSrc.exists()) {
        final assetsDest = Directory(
          p.join(destParent.path, '${id}_assets'),
        );
        if (await assetsDest.exists()) {
          await assetsDest.delete(recursive: true);
        }
        await assetsSrc.rename(assetsDest.path);
      }
      await _removeManifest(id);
    }
  }

  Future<Directory> _restoreParentDir(
    Directory docs,
    String relativeParent,
  ) async {
    if (relativeParent.isEmpty) {
      return docs;
    }
    try {
      final dir = MemoFs.resolveRelativeDir(docs, relativeParent);
      if (await dir.exists()) {
        return dir;
      }
    } catch (_) {}
    return docs;
  }

  Future<void> emptyTrash() async {
    final trash = await trashDirectory();
    if (!await trash.exists()) {
      return;
    }
    await for (final entity in trash.list(recursive: false)) {
      try {
        if (entity is Directory) {
          await entity.delete(recursive: true);
        } else if (entity is File) {
          await entity.delete();
        }
      } catch (_) {}
    }
  }

  Future<Map<String, TrashManifestEntry>> _readManifest() async {
    final trash = await trashDirectory();
    final file = File(p.join(trash.path, manifestFileName));
    if (!await file.exists()) {
      return {};
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return {};
      }
      final rawEntries = decoded['entries'];
      if (rawEntries is! List) {
        return {};
      }
      final map = <String, TrashManifestEntry>{};
      for (final item in rawEntries) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        final entry = TrashManifestEntry.fromJson(item);
        map[entry.id] = entry;
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeManifest(Map<String, TrashManifestEntry> entries) async {
    final trash = await trashDirectory();
    final file = File(p.join(trash.path, manifestFileName));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'entries': entries.values.map((e) => e.toJson()).toList(),
      }),
    );
  }

  Future<void> _upsertManifest(TrashManifestEntry entry) async {
    final map = await _readManifest();
    map[entry.id] = entry;
    await _writeManifest(map);
  }

  Future<void> _removeManifest(String id) async {
    final map = await _readManifest();
    if (map.remove(id) != null) {
      await _writeManifest(map);
    }
  }

  TrashItem _itemFromFile(File file) {
    final stat = file.statSync();
    final id = p.basenameWithoutExtension(file.path);
    final raw = file.readAsStringSync();
    final parsed = _parseMemoContent(raw);
    final assets = Directory(p.join(file.parent.path, '${id}_assets'));
    return TrashItem(
      id: id,
      kind: TrashItemKind.file,
      filePath: file.path,
      title: parsed.title,
      contentPreview: parsed.content,
      trashedAt: stat.modified,
      assetsPath: assets.existsSync() ? assets.path : null,
    );
  }

  TrashItem _itemFromFolder(Directory dir) {
    final stat = dir.statSync();
    final id = p.basename(dir.path);
    final conf = File(
      p.join(dir.path, MemoFs.fileConfFileName(id)),
    );
    var title = id;
    if (conf.existsSync()) {
      try {
        final decoded = jsonDecode(conf.readAsStringSync());
        if (decoded is Map && decoded['displayName'] is String) {
          final name = (decoded['displayName'] as String).trim();
          if (name.isNotEmpty) {
            title = name;
          }
        }
      } catch (_) {}
    }
    return TrashItem(
      id: id,
      kind: TrashItemKind.folder,
      filePath: dir.path,
      title: title,
      contentPreview: '',
      trashedAt: stat.modified,
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
}

final memoTrashService = MemoTrashService();
