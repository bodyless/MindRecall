import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:mind_recall/app_layout_constants.dart';
import 'package:mind_recall/core/ui/ime_height_cache.dart';

/// 将 [ImeHeightCache] 持久化到应用 support 目录（不可随备份迁移）。
///
/// 与 [UserPreferences] 分离：IME 高度是本机键盘几何，换设备无效。
class ImeHeightCacheStore {
  ImeHeightCacheStore({
    Directory? supportDirectory,
    ImeHeightCache? cache,
  })  : _supportDirectory = supportDirectory,
        cache = cache ?? defaultImeHeightCache;

  static const fileName = 'ime_height_cache.json';

  final Directory? _supportDirectory;
  final ImeHeightCache cache;
  Timer? _persistTimer;

  Future<void> load() async {
    try {
      final file = await _cacheFile();
      if (!await file.exists()) {
        cache.hydrate(const {});
        return;
      }
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        cache.hydrate(const {});
        return;
      }
      cache.hydrate(decodeImeHeightCacheJson(jsonDecode(raw)));
    } catch (_) {
      cache.hydrate(const {});
    }
  }

  /// 灌入磁盘后再监听变更；启动路径用这个。
  Future<void> loadAndAttach() async {
    await load();
    attach();
  }

  void attach() {
    cache.onChanged = schedulePersist;
  }

  void detach() {
    _persistTimer?.cancel();
    _persistTimer = null;
    cache.onChanged = null;
  }

  void schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(kImeHeightCachePersistDebounce, () {
      unawaited(persistNow());
    });
  }

  Future<void> persistNow() async {
    try {
      final file = await _cacheFile();
      await file.parent.create(recursive: true);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(
          encodeImeHeightCacheJson(cache.snapshot),
        ),
      );
    } catch (_) {
      // 缓存写失败不影响编辑；下次打开按无缓存走防抖。
    }
  }

  Future<File> _cacheFile() async {
    final dir = _supportDirectory ?? await getApplicationSupportDirectory();
    return File(p.join(dir.path, fileName));
  }
}
