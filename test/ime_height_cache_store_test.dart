import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/core/ui/ime_height_cache.dart';
import 'package:mind_recall/services/ime_height_cache_store.dart';

void main() {
  test('落盘后再 load 恢复分桶高度', () async {
    final dir = await Directory.systemTemp.createTemp('ime_height_cache_');
    addTearDown(() => dir.delete(recursive: true));

    final written = ImeHeightCache();
    final writer = ImeHeightCacheStore(supportDirectory: dir, cache: written);
    written.store('360x800', 348.1);
    written.store('800x360', 240);
    await writer.persistNow();

    final loaded = ImeHeightCache();
    final reader = ImeHeightCacheStore(supportDirectory: dir, cache: loaded);
    await reader.load();
    expect(loaded.lookup('360x800'), 348.1);
    expect(loaded.lookup('800x360'), 240);
  });

  test('hydrate 后同高度 store 不改文件语义', () async {
    final cache = ImeHeightCache();
    var writes = 0;
    cache.onChanged = () => writes++;
    cache.hydrate({'360x800': 348.1});
    cache.store('360x800', 348.1);
    expect(writes, 0);
    cache.store('360x800', 400);
    expect(writes, 1);
  });
}
