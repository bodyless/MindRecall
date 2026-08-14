import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/memo.dart';
import 'app_storage_service.dart';
import 'memo_image_service.dart';

/// 回收站中的条目（文档 + 可选资源目录）。
class TrashItem {
  const TrashItem({
    required this.id,
    required this.filePath,
    required this.title,
    required this.contentPreview,
    required this.trashedAt,
    this.assetsPath,
  });

  final String id;
  final String filePath;
  final String title;
  final String contentPreview;
  final DateTime trashedAt;
  final String? assetsPath;

  String displayTitle(String untitledLabel) {
    final t = title.trim();
    if (t.isNotEmpty) {
      return t;
    }
    final preview = contentPreview.trim();
    if (preview.isEmpty) {
      return untitledLabel;
    }
    final first = preview.split('\n').first.trim();
    return first.isEmpty ? untitledLabel : first;
  }
}

/// `MindRecall/trash/` 回收站：有内容的删除先移入，空文档直接删。
class MemoTrashService {
  static const folderName = 'trash';
  static const _memoExtensions = ['.md', '.txt'];

  Future<Directory> trashDirectory() async {
    final root = await appStorageService.storageDirectory();
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
    final files = trash
        .listSync()
        .whereType<File>()
        .where((f) => _memoExtensions.contains(p.extension(f.path)))
        .toList();
    final items = files.map(_itemFromFile).toList();
    items.sort((a, b) => b.trashedAt.compareTo(a.trashedAt));
    return items;
  }

  /// 移入回收站（覆盖同 id 旧条目）。
  Future<void> moveToTrash(Memo memo) async {
    final trash = await trashDirectory();
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

    final assetsSrc = await memoImageService.assetsDirectory(memo.id);
    if (await assetsSrc.exists()) {
      final assetsDest = Directory(p.join(trash.path, '${memo.id}_assets'));
      if (await assetsDest.exists()) {
        await assetsDest.delete(recursive: true);
      }
      await assetsSrc.rename(assetsDest.path);
    }
  }

  Future<void> restore(List<String> ids) async {
    if (ids.isEmpty) {
      return;
    }
    final trash = await trashDirectory();
    final memosRoot = await appStorageService.storageDirectory();
    for (final id in ids) {
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
      final dest = File(p.join(memosRoot.path, p.basename(srcFile.path)));
      if (await dest.exists()) {
        await dest.delete();
      }
      await srcFile.rename(dest.path);

      final assetsSrc = Directory(p.join(trash.path, '${id}_assets'));
      if (await assetsSrc.exists()) {
        final assetsDest = Directory(p.join(memosRoot.path, '${id}_assets'));
        if (await assetsDest.exists()) {
          await assetsDest.delete(recursive: true);
        }
        await assetsSrc.rename(assetsDest.path);
      }
    }
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

  TrashItem _itemFromFile(File file) {
    final stat = file.statSync();
    final id = p.basenameWithoutExtension(file.path);
    final raw = file.readAsStringSync();
    final parsed = _parseMemoContent(raw);
    final assets = Directory(p.join(file.parent.path, '${id}_assets'));
    return TrashItem(
      id: id,
      filePath: file.path,
      title: parsed.title,
      contentPreview: parsed.content,
      trashedAt: stat.modified,
      assetsPath: assets.existsSync() ? assets.path : null,
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
