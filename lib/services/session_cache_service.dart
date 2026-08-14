import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 本地会话缓存：仅存操作态临时数据，不可随备份迁移。
///
/// 与 [UserPreferences]（可导出的用户配置）分离，文件位于应用 support 目录。
class SessionCache {
  const SessionCache({
    this.lastOpenedMemoId,
    this.pinnedMemoIds = const [],
  });

  /// 上次打开的文档 id。
  final String? lastOpenedMemoId;

  /// 置顶文档 id，按置顶先后：**后置顶的在前**。
  final List<String> pinnedMemoIds;

  factory SessionCache.defaults() => const SessionCache();

  factory SessionCache.fromJson(Map<String, dynamic> json) {
    final pinned = json['pinnedMemoIds'];
    return SessionCache(
      lastOpenedMemoId: json['lastOpenedMemoId'] as String?,
      pinnedMemoIds: pinned is List
          ? pinned.whereType<String>().toList(growable: false)
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'lastOpenedMemoId': lastOpenedMemoId,
        'pinnedMemoIds': pinnedMemoIds,
      };

  SessionCache copyWith({
    String? lastOpenedMemoId,
    List<String>? pinnedMemoIds,
    bool clearLastOpenedMemoId = false,
  }) {
    return SessionCache(
      lastOpenedMemoId: clearLastOpenedMemoId
          ? null
          : (lastOpenedMemoId ?? this.lastOpenedMemoId),
      pinnedMemoIds: pinnedMemoIds ?? this.pinnedMemoIds,
    );
  }
}

class SessionCacheService {
  static const fileName = 'session_cache.json';

  SessionCache _cache = SessionCache.defaults();

  SessionCache get cache => _cache;

  Future<SessionCache> load() async {
    try {
      final file = await _cacheFile();
      if (!await file.exists()) {
        _cache = SessionCache.defaults();
        return _cache;
      }
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        _cache = SessionCache.defaults();
        return _cache;
      }
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) {
        _cache = SessionCache.defaults();
        return _cache;
      }
      _cache = SessionCache.fromJson(json);
      return _cache;
    } catch (_) {
      _cache = SessionCache.defaults();
      return _cache;
    }
  }

  Future<void> save(SessionCache cache) async {
    _cache = cache;
    final file = await _cacheFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(cache.toJson()),
    );
  }

  Future<void> updateLastOpenedMemoId(String? memoId) {
    if (memoId == null) {
      return save(_cache.copyWith(clearLastOpenedMemoId: true));
    }
    return save(_cache.copyWith(lastOpenedMemoId: memoId));
  }

  /// 切换置顶：未置顶则插到最前；已置顶则取消。
  Future<SessionCache> togglePin(String memoId) async {
    final current = List<String>.from(_cache.pinnedMemoIds);
    if (current.contains(memoId)) {
      current.remove(memoId);
    } else {
      current.insert(0, memoId);
    }
    final next = _cache.copyWith(pinnedMemoIds: current);
    await save(next);
    return next;
  }

  bool isPinned(String memoId) => _cache.pinnedMemoIds.contains(memoId);

  Future<File> _cacheFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, fileName));
  }
}
