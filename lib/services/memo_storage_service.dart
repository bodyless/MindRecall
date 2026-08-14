import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models/memo.dart';
import 'app_storage_service.dart';
import 'memo_image_service.dart';
import 'memo_trash_service.dart';

class MemoStorageService {
  static const _memoExtensions = ['.md', '.txt'];

  AppStorageService get _storage => appStorageService;

  Future<Directory> memosDirectory() => _storage.storageDirectory();

  Future<List<Memo>> listMemos() async {
    final memosDir = await memosDirectory();
    final files = memosDir
        .listSync()
        .whereType<File>()
        .where((file) => _memoExtensions.contains(p.extension(file.path)))
        .toList();

    final memos = files.map(_memoFromFile).toList();
    sortMemosStable(memos);
    return memos;
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

  Future<Memo> createMemo() async {
    final memosDir = await memosDirectory();
    final createdAt = DateTime.now();
    final id = createdAt.millisecondsSinceEpoch.toString();
    final filePath = p.join(memosDir.path, '$id.md');
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
      await memoImageService.deleteAssets(id);
      return;
    }
    final memo = _memoFromFile(file);
    if (MemoTrashService.hasContent(memo)) {
      await memoTrashService.moveToTrash(memo);
      return;
    }
    await file.delete();
    await memoImageService.deleteAssets(id);
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

  Future<File> _fileForId(String id) async {
    final memosDir = await memosDirectory();
    for (final extension in _memoExtensions) {
      final file = File(p.join(memosDir.path, '$id$extension'));
      if (await file.exists()) {
        return file;
      }
    }
    return File(p.join(memosDir.path, '$id.md'));
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
