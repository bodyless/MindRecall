import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/features/memo/editor/memo_workspace_controller.dart';
import 'package:mind_recall/features/memo/sidebar/memo_file_panel_logic.dart';
import 'package:mind_recall/models/memo.dart';
import 'package:mind_recall/models/memo_folder.dart';
import 'package:mind_recall/services/memo_fs_constants.dart';
import 'package:path/path.dart' as p;

class _FakeStore implements MemoWorkspaceStore {
  final Map<String, Memo> memos = {};
  final Map<String, MemoFolder> folders = {};
  int updateCount = 0;
  int createCount = 0;
  String lastCreateParent = '';

  Memo put({
    required String id,
    String title = '',
    String content = '',
    required DateTime updatedAt,
    String? filePath,
  }) {
    final memo = Memo(
      id: id,
      title: title,
      content: content,
      filePath: filePath ?? '$id.md',
      createdAt: updatedAt,
      updatedAt: updatedAt,
    );
    memos[id] = memo;
    return memo;
  }

  String _parentOf(String path) {
    final normalized = path.replaceAll(r'\', '/');
    final parent = p.dirname(normalized);
    if (parent == '.' || parent == '/' || parent == '') {
      return '';
    }
    return parent;
  }

  @override
  Future<List<Memo>> listMemos() async => memos.values.toList();

  @override
  Future<List<MemoDirEntry>> listDirEntries(String relativeParent) async {
    final rel = relativeParent.replaceAll(r'\', '/');
    final entries = <MemoDirEntry>[];
    for (final folder in folders.values) {
      if (_parentOf(folder.directoryPath) == rel) {
        entries.add(MemoDirEntry.folder(folder));
      }
    }
    for (final memo in memos.values) {
      if (_parentOf(memo.filePath) == rel) {
        entries.add(MemoDirEntry.file(memo));
      }
    }
    return entries;
  }

  @override
  Future<Memo> loadMemo(String id) async {
    final memo = memos[id];
    if (memo == null) {
      throw StateError('missing $id');
    }
    return memo;
  }

  @override
  Future<Memo> createMemo({String relativeParent = ''}) async {
    createCount++;
    lastCreateParent = relativeParent;
    final id = 'new-${memos.length}';
    final filePath =
        relativeParent.isEmpty ? '$id.md' : '$relativeParent/$id.md';
    return put(
      id: id,
      updatedAt: DateTime(2026, 1, 1),
      filePath: filePath,
    );
  }

  @override
  Future<Memo> updateMemo({
    required String id,
    required String title,
    required String content,
  }) async {
    updateCount++;
    final current = await loadMemo(id);
    final next = current.copyWith(
      title: title,
      content: content,
      updatedAt: DateTime(2026, 8, 15),
    );
    memos[id] = next;
    return next;
  }

  @override
  Future<Memo> renameMemo({
    required String id,
    required String newTitle,
  }) {
    return updateMemo(id: id, title: newTitle, content: memos[id]?.content ?? '');
  }

  @override
  Future<void> deleteMemo(String id) async {
    memos.remove(id);
  }

  @override
  Future<MemoFolder> createFolder({
    required String relativeParent,
    required String displayName,
  }) async {
    final id = 'folder-${folders.length}';
    final directoryPath =
        relativeParent.isEmpty ? id : '$relativeParent/$id';
    final folder = MemoFolder(
      id: id,
      directoryPath: directoryPath,
      displayName: displayName,
      createdAt: DateTime(2026, 1, 1),
    );
    folders[id] = folder;
    return folder;
  }

  @override
  Future<MemoFolder> renameFolder({
    required String id,
    required String newDisplayName,
  }) async {
    final current = folders[id]!;
    final next = MemoFolder(
      id: current.id,
      directoryPath: current.directoryPath,
      displayName: newDisplayName,
      createdAt: current.createdAt,
      colorHex: current.colorHex,
    );
    folders[id] = next;
    return next;
  }

  @override
  Future<void> deleteFolder(String id) async {
    final folder = folders.remove(id);
    if (folder == null) {
      return;
    }
    final prefix = '${folder.directoryPath}/';
    memos.removeWhere((_, memo) => memo.filePath.replaceAll(r'\', '/').startsWith(prefix));
    folders.removeWhere(
      (_, item) =>
          item.id != id &&
          item.directoryPath.replaceAll(r'\', '/').startsWith(prefix),
    );
  }

  @override
  Future<bool> folderContainsMemo(String folderId, String memoId) async {
    final folder = folders[folderId];
    if (folder == null) {
      return false;
    }
    final memo = memos[memoId];
    if (memo == null) {
      return false;
    }
    return memo.filePath.replaceAll(r'\', '/').startsWith(
          '${folder.directoryPath}/',
        );
  }

  @override
  Future<String> relativeParentOfPath(String absolutePath) async {
    return _parentOf(absolutePath);
  }

  @override
  Future<String> relativeDirOfFolder(String directoryPath) async {
    return directoryPath.replaceAll(r'\', '/');
  }

  @override
  Future<bool> isValidRelativeDir(String relativeParent) async {
    if (relativeParent.isEmpty) {
      return true;
    }
    return folders.values.any(
      (folder) => folder.directoryPath.replaceAll(r'\', '/') == relativeParent,
    );
  }

  List<MemoFolderTreeNode> _childFolderNodes(String parentRel) {
    final children = <MemoFolderTreeNode>[];
    for (final folder in folders.values) {
      if (_parentOf(folder.directoryPath) == parentRel) {
        final rel = folder.directoryPath.replaceAll(r'\', '/');
        children.add(
          MemoFolderTreeNode(
            folderId: folder.id,
            relativeDir: rel,
            displayName: folder.displayName,
            createdAt: folder.createdAt,
            children: _childFolderNodes(rel),
          ),
        );
      }
    }
    return children;
  }

  @override
  Future<MemoFolderTreeNode> listFolderTree() async {
    return MemoFolderTreeNode(
      relativeDir: '',
      displayName: '',
      children: _childFolderNodes(''),
    );
  }

  @override
  Future<Memo> moveMemo({
    required String id,
    required String destRelativeDir,
  }) async {
    final memo = memos[id];
    if (memo == null) {
      throw StateError('missing $id');
    }
    final dest = destRelativeDir.replaceAll(r'\', '/');
    if (_parentOf(memo.filePath) == dest) {
      throw StateError('已在目标目录');
    }
    final name = p.basename(memo.filePath);
    final destPath = dest.isEmpty ? name : '$dest/$name';
    final next = memo.copyWith(filePath: destPath);
    memos[id] = next;
    return next;
  }

  @override
  Future<MemoFolder> moveFolder({
    required String id,
    required String destRelativeDir,
  }) async {
    final folder = folders[id];
    if (folder == null) {
      throw StateError('missing $id');
    }
    final oldRel = folder.directoryPath.replaceAll(r'\', '/');
    final dest = destRelativeDir.replaceAll(r'\', '/');
    if (MemoFs.isSelfOrDescendantRelative(
      candidate: dest,
      ancestor: oldRel,
    )) {
      throw ArgumentError('不能移动到自身或子目录');
    }
    if (_parentOf(oldRel) == dest) {
      throw StateError('已在目标目录');
    }
    final newRel = dest.isEmpty ? id : '$dest/$id';
    folders[id] = MemoFolder(
      id: folder.id,
      directoryPath: newRel,
      displayName: folder.displayName,
      createdAt: folder.createdAt,
      updatedAt: folder.updatedAt,
      colorHex: folder.colorHex,
    );
    for (final entry in memos.entries.toList()) {
      final path = entry.value.filePath.replaceAll(r'\', '/');
      if (path.startsWith('$oldRel/')) {
        memos[entry.key] = entry.value.copyWith(
          filePath: '$newRel${path.substring(oldRel.length)}',
        );
      }
    }
    for (final entry in folders.entries.toList()) {
      if (entry.key == id) {
        continue;
      }
      final path = entry.value.directoryPath.replaceAll(r'\', '/');
      if (path == oldRel || path.startsWith('$oldRel/')) {
        folders[entry.key] = MemoFolder(
          id: entry.value.id,
          directoryPath: '$newRel${path.substring(oldRel.length)}',
          displayName: entry.value.displayName,
          createdAt: entry.value.createdAt,
          updatedAt: entry.value.updatedAt,
          colorHex: entry.value.colorHex,
        );
      }
    }
    return folders[id]!;
  }

  @override
  Future<MemoFolder> updateFolderColor({
    required String id,
    String? colorHex,
  }) async {
    final current = folders[id];
    if (current == null) {
      throw StateError('missing $id');
    }
    final parsed =
        colorHex == null ? null : MemoFolder.parseColorHex(colorHex);
    if (colorHex != null && parsed == null) {
      throw ArgumentError('非法颜色');
    }
    final next = MemoFolder(
      id: current.id,
      directoryPath: current.directoryPath,
      displayName: current.displayName,
      createdAt: current.createdAt,
      updatedAt: current.updatedAt,
      colorHex: parsed,
    );
    folders[id] = next;
    return next;
  }
}

class _MemoryPins implements MemoPinStore {
  @override
  List<String> pinnedIds = [];

  @override
  List<String> pinnedFolderIds = [];

  @override
  String? lastOpenedMemoId;

  @override
  String currentRelativeDir = '';

  Duration loadDelay = Duration.zero;
  bool loadShouldThrow = false;

  @override
  Future<void> load() async {
    if (loadDelay > Duration.zero) {
      await Future<void>.delayed(loadDelay);
    }
    if (loadShouldThrow) {
      throw StateError('pin load failed');
    }
  }

  @override
  Future<void> updateLastOpenedMemoId(String id) async {
    lastOpenedMemoId = id;
  }

  @override
  Future<List<String>> togglePin(String id) async {
    if (pinnedIds.contains(id)) {
      pinnedIds.remove(id);
    } else {
      pinnedIds.insert(0, id);
    }
    return List<String>.from(pinnedIds);
  }

  @override
  Future<List<String>> toggleFolderPin(String id) async {
    if (pinnedFolderIds.contains(id)) {
      pinnedFolderIds.remove(id);
    } else {
      pinnedFolderIds.insert(0, id);
    }
    return List<String>.from(pinnedFolderIds);
  }

  @override
  Future<void> updateCurrentRelativeDir(String relativeDir) async {
    currentRelativeDir = relativeDir;
  }
}

void main() {
  late TextEditingController title;
  late TextEditingController content;
  late TextEditingController search;
  late _FakeStore store;
  late _MemoryPins pins;
  late MemoWorkspaceController workspace;

  setUp(() {
    title = TextEditingController();
    content = TextEditingController();
    search = TextEditingController();
    store = _FakeStore();
    pins = _MemoryPins();
    workspace = MemoWorkspaceController(
      titleController: title,
      contentController: content,
      searchController: search,
      store: store,
      pins: pins,
      searchDelay: Duration.zero,
    );
  });

  tearDown(() {
    workspace.dispose();
    title.dispose();
    content.dispose();
    search.dispose();
  });

  test('dirty 才保存', () async {
    final memo = store.put(
      id: 'a',
      title: 'T',
      content: 'body',
      updatedAt: DateTime(2026, 1, 2),
    );
    workspace.applyMemoToEditors(memo);

    await workspace.saveActive();
    expect(store.updateCount, 0);

    title.text = 'T2';
    await workspace.saveActive();
    expect(store.updateCount, 1);
    expect(store.memos['a']?.title, 'T2');
    expect(workspace.isDirty, isFalse);
  });

  test('切文档先 flush 当前脏文档', () async {
    final first = store.put(
      id: 'a',
      title: 'A',
      content: 'one',
      updatedAt: DateTime(2026, 1, 3),
    );
    store.put(
      id: 'b',
      title: 'B',
      content: 'two',
      updatedAt: DateTime(2026, 1, 2),
    );
    workspace.memos = store.memos.values.toList();
    workspace.applyMemoToEditors(first);
    content.text = 'one-dirty';

    await workspace.openMemo('b', refreshList: false);

    expect(store.updateCount, 1);
    expect(store.memos['a']?.content, 'one-dirty');
    expect(workspace.activeMemoId, 'b');
    expect(content.text, 'two');
    expect(workspace.isDirty, isFalse);
  });

  test('空搜索 query 不展示搜索空态', () {
    final memo = store.put(
      id: 'a',
      title: 'alpha',
      content: 'hello',
      updatedAt: DateTime(2026, 1, 1),
    );
    workspace.memos = [memo];
    search.text = 'alpha';
    workspace.runSearch();
    expect(workspace.isSearchActive, isTrue);
    expect(
      memoFilePanelShowsSearchResults(
        isSearchActive: workspace.isSearchActive,
        query: search.text,
      ),
      isTrue,
    );

    search.text = '';
    workspace.onSearchChanged();
    expect(workspace.isSearchActive, isFalse);
    expect(workspace.searchResults, isEmpty);
    expect(
      memoFilePanelShowsSearchResults(
        isSearchActive: workspace.isSearchActive,
        query: search.text,
      ),
      isFalse,
    );
  });

  test('置顶后当前层：置顶文件排在未置顶之前', () async {
    final newer = store.put(
      id: 'newer',
      title: 'new',
      updatedAt: DateTime(2026, 2, 1),
    );
    final older = store.put(
      id: 'older',
      title: 'old',
      updatedAt: DateTime(2026, 1, 1),
    );
    workspace.dirEntries = [
      MemoDirEntry.file(newer),
      MemoDirEntry.file(older),
    ];

    await workspace.togglePin('older');

    expect(workspace.pinnedMemoIds, ['older']);
    expect(workspace.dirEntries.map((e) => e.id).toList(), ['older', 'newer']);
  });

  test('loadPinsAndList 在 pin store 慢于 300ms 时仍应用置顶', () async {
    pins.pinnedIds = ['older'];
    pins.loadDelay = const Duration(milliseconds: 400);
    store.put(
      id: 'newer',
      title: 'new',
      updatedAt: DateTime(2026, 2, 1),
    );
    store.put(
      id: 'older',
      title: 'old',
      updatedAt: DateTime(2026, 1, 1),
    );

    await workspace.loadPinsAndList();

    expect(workspace.pinnedMemoIds, ['older']);
    expect(workspace.dirEntries.map((e) => e.id).toList(), ['older', 'newer']);
  });

  test('loadPinsAndList 在 pin load 抛错时仍使用 store 已有置顶', () async {
    pins.pinnedIds = ['older'];
    pins.loadShouldThrow = true;
    store.put(
      id: 'newer',
      title: 'new',
      updatedAt: DateTime(2026, 2, 1),
    );
    store.put(
      id: 'older',
      title: 'old',
      updatedAt: DateTime(2026, 1, 1),
    );

    await workspace.loadPinsAndList();

    expect(workspace.pinnedMemoIds, ['older']);
    expect(workspace.dirEntries.map((e) => e.id).toList(), ['older', 'newer']);
  });

  test('活动笔记为空时 captureTextAsMemo 只更新正文', () async {
    final empty = store.put(
      id: 'empty',
      updatedAt: DateTime(2026, 1, 1),
    );
    workspace.memos = [empty];
    workspace.applyMemoToEditors(empty);

    final captured = await workspace.captureTextAsMemo('选区正文');

    expect(store.createCount, 0);
    expect(store.memos.length, 1);
    expect(captured.id, 'empty');
    expect(captured.title, '');
    expect(captured.content, '选区正文');
    expect(content.text, '选区正文');
    expect(title.text, '');
  });

  test('已有非空活动笔记时 captureTextAsMemo 会新建', () async {
    final existing = store.put(
      id: 'a',
      title: '已有',
      content: '旧正文',
      updatedAt: DateTime(2026, 1, 2),
    );
    workspace.memos = [existing];
    workspace.applyMemoToEditors(existing);

    final captured = await workspace.captureTextAsMemo('新选区');

    expect(store.createCount, 1);
    expect(store.memos.length, 2);
    expect(captured.id, isNot('a'));
    expect(captured.title, '');
    expect(captured.content, '新选区');
    expect(store.memos['a']?.content, '旧正文');
  });

  test('当前层只含本目录；进入/返回不改活动篇', () async {
    store.put(id: 'root', updatedAt: DateTime(2026, 1, 1));
    final folder = await store.createFolder(
      relativeParent: '',
      displayName: '工作',
    );
    store.put(
      id: 'inner',
      updatedAt: DateTime(2026, 1, 2),
      filePath: '${folder.directoryPath}/inner.md',
    );
    workspace.applyMemoToEditors(store.memos['root']!);
    await workspace.refreshList();

    expect(workspace.dirEntries.map((e) => e.id), containsAll(['root', folder.id]));
    expect(workspace.dirEntries.any((e) => e.id == 'inner'), isFalse);

    await workspace.enterFolder(folder.id);
    expect(workspace.activeMemoId, 'root');
    expect(workspace.currentRelativeDir, folder.id);
    expect(workspace.dirEntries.map((e) => e.id), ['inner']);

    await workspace.goToParentDirectory();
    expect(workspace.activeMemoId, 'root');
    expect(workspace.currentRelativeDir, '');
  });

  test('新建落在当前目录', () async {
    final folder = await store.createFolder(
      relativeParent: '',
      displayName: '工作',
    );
    await workspace.refreshList();
    await workspace.enterFolder(folder.id);
    await workspace.createNewMemo();
    expect(store.lastCreateParent, folder.id);
    expect(store.lastCreateParent, isNotEmpty);
  });

  test('搜索命中子目录文件；打开后当前目录为该文件父目录', () async {
    final folder = await store.createFolder(
      relativeParent: '',
      displayName: '工作',
    );
    final inner = store.put(
      id: 'nested',
      title: '独特标题',
      content: '正文',
      updatedAt: DateTime(2026, 1, 1),
      filePath: '${folder.directoryPath}/nested.md',
    );
    workspace.memos = store.memos.values.toList();
    search.text = '独特标题';
    workspace.runSearch();
    expect(workspace.searchResults.map((r) => r.memoId), [inner.id]);

    await workspace.openMemo(inner.id, refreshList: false);
    expect(workspace.currentRelativeDir, folder.id);
    expect(workspace.dirEntries.map((e) => e.id), ['nested']);
  });

  test('moveMemo 不改当前目录与活动篇，只更新路径', () async {
    store.put(
      id: 'a',
      title: 'Keep',
      content: 'body',
      updatedAt: DateTime(2026, 1, 1),
      filePath: 'a.md',
    );
    final folder = await store.createFolder(
      relativeParent: '',
      displayName: '工作',
    );
    workspace.applyMemoToEditors(store.memos['a']!);
    await workspace.refreshList();
    title.text = 'Keep';
    content.text = 'body';

    await workspace.moveMemo(id: 'a', destRelativeDir: folder.id);

    expect(workspace.currentRelativeDir, '');
    expect(workspace.activeMemoId, 'a');
    expect(workspace.memoById('a')?.filePath, '${folder.id}/a.md');
    expect(workspace.dirEntries.any((e) => e.id == 'a'), isFalse);
    expect(title.text, 'Keep');
    expect(content.text, 'body');
  });

  test('moveFolder 活动篇仍打开且路径已更新，当前目录不变', () async {
    final folder = await store.createFolder(
      relativeParent: '',
      displayName: '工作',
    );
    store.put(
      id: 'inner',
      title: '内',
      content: 'x',
      updatedAt: DateTime(2026, 1, 2),
      filePath: '${folder.directoryPath}/inner.md',
    );
    final dest = await store.createFolder(
      relativeParent: '',
      displayName: '目标',
    );
    workspace.applyMemoToEditors(store.memos['inner']!);
    await workspace.refreshList();

    await workspace.moveFolder(id: folder.id, destRelativeDir: dest.id);

    expect(workspace.activeMemoId, 'inner');
    expect(workspace.currentRelativeDir, '');
    expect(
      workspace.memoById('inner')?.filePath,
      '${dest.id}/${folder.id}/inner.md',
    );
    expect(title.text, '内');
    expect(content.text, 'x');
  });

  test('updateFolderColor 刷新当前层且不改目录与活动篇', () async {
    final folder = await workspace.createFolder('工作');
    final memo = store.put(
      id: 'm1',
      updatedAt: DateTime(2026, 1, 1),
    );
    workspace.memos = [memo];
    workspace.activeMemoId = 'm1';
    workspace.currentRelativeDir = '';

    await workspace.updateFolderColor(id: folder.id, colorHex: '#aabbcc');

    final colored = workspace.dirEntries.firstWhere((e) => e.isFolder);
    expect(colored.folder!.colorHex, '#AABBCC');
    expect(workspace.currentRelativeDir, '');
    expect(workspace.activeMemoId, 'm1');

    await workspace.updateFolderColor(id: folder.id, colorHex: null);
    final cleared = workspace.dirEntries.firstWhere((e) => e.isFolder);
    expect(cleared.folder!.colorHex, isNull);
    expect(workspace.currentRelativeDir, '');
    expect(workspace.activeMemoId, 'm1');
  });
}
