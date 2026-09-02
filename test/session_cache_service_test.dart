import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/services/session_cache_service.dart';

void main() {
  test('缺字段时当前目录视为根，仅 pinnedMemoIds 的旧 JSON 仍可解析', () {
    final cache = SessionCache.fromJson({
      'lastOpenedMemoId': '111',
      'pinnedMemoIds': ['a', 'b'],
    });
    expect(cache.lastOpenedMemoId, '111');
    expect(cache.pinnedMemoIds, ['a', 'b']);
    expect(cache.pinnedFolderIds, isEmpty);
    expect(cache.currentRelativeDir, '');
  });

  test('解析当前目录与文件夹置顶', () {
    final cache = SessionCache.fromJson({
      'pinnedMemoIds': ['m1'],
      'pinnedFolderIds': ['f1', 'f2'],
      'currentRelativeDir': 'f1/f2',
    });
    expect(cache.pinnedFolderIds, ['f1', 'f2']);
    expect(cache.currentRelativeDir, 'f1/f2');
  });
}
