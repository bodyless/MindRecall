import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:mind_recall/models/memo.dart';
import 'package:mind_recall/models/memo_folder.dart';
import 'package:mind_recall/models/memo_search_result.dart';
import 'package:mind_recall/models/user_preferences.dart';
import 'package:mind_recall/services/data_backup_service.dart';
import 'package:mind_recall/services/memo_fs_constants.dart';
import 'package:mind_recall/services/memo_search_service.dart';
import 'package:mind_recall/services/memo_storage_service.dart';
import 'package:mind_recall/services/memo_trash_service.dart';
import 'package:mind_recall/services/process_text_capture.dart';
import 'package:mind_recall/services/session_cache_service.dart';
import 'package:mind_recall/services/user_preferences_service.dart';

enum SaveStatus { idle, saving, saved, error }

/// 工作区磁盘访问，便于单测注入。
abstract class MemoWorkspaceStore {
  Future<List<Memo>> listMemos();
  Future<List<MemoDirEntry>> listDirEntries(String relativeParent);
  Future<Memo> loadMemo(String id);
  Future<Memo> createMemo({String relativeParent = ''});
  Future<Memo> importExternalMemo({
    required String sourcePath,
    required String relativeParent,
  });
  Future<Memo> updateMemo({
    required String id,
    required String title,
    required String content,
  });
  Future<Memo> renameMemo({required String id, required String newTitle});
  Future<void> deleteMemo(String id);
  Future<MemoFolder> createFolder({
    required String relativeParent,
    required String displayName,
  });
  Future<MemoFolder> renameFolder({
    required String id,
    required String newDisplayName,
  });
  Future<void> deleteFolder(String id);
  Future<bool> folderContainsMemo(String folderId, String memoId);
  Future<String> relativeParentOfPath(String absolutePath);
  Future<String> relativeDirOfFolder(String directoryPath);
  Future<bool> isValidRelativeDir(String relativeParent);
  Future<MemoFolderTreeNode> listFolderTree();
  Future<Memo> moveMemo({required String id, required String destRelativeDir});
  Future<MemoFolder> moveFolder({
    required String id,
    required String destRelativeDir,
  });
  Future<MemoFolder> updateFolderColor({
    required String id,
    String? colorHex,
  });
}

class DiskMemoWorkspaceStore implements MemoWorkspaceStore {
  DiskMemoWorkspaceStore([MemoStorageService? storage])
      : _storage = storage ?? MemoStorageService();

  final MemoStorageService _storage;

  @override
  Future<List<Memo>> listMemos() => _storage.listMemos();

  @override
  Future<List<MemoDirEntry>> listDirEntries(String relativeParent) {
    return _storage.listDirEntries(relativeParent);
  }

  @override
  Future<Memo> loadMemo(String id) => _storage.loadMemo(id);

  @override
  Future<Memo> createMemo({String relativeParent = ''}) {
    return _storage.createMemo(relativeParent: relativeParent);
  }

  @override
  Future<Memo> importExternalMemo({
    required String sourcePath,
    required String relativeParent,
  }) {
    return _storage.importExternalMemo(
      sourcePath: sourcePath,
      relativeParent: relativeParent,
    );
  }

  @override
  Future<Memo> updateMemo({
    required String id,
    required String title,
    required String content,
  }) {
    return _storage.updateMemo(id: id, title: title, content: content);
  }

  @override
  Future<Memo> renameMemo({required String id, required String newTitle}) {
    return _storage.renameMemo(id: id, newTitle: newTitle);
  }

  @override
  Future<void> deleteMemo(String id) => _storage.deleteMemo(id);

  @override
  Future<MemoFolder> createFolder({
    required String relativeParent,
    required String displayName,
  }) {
    return _storage.createFolder(
      relativeParent: relativeParent,
      displayName: displayName,
    );
  }

  @override
  Future<MemoFolder> renameFolder({
    required String id,
    required String newDisplayName,
  }) {
    return _storage.renameFolder(id: id, newDisplayName: newDisplayName);
  }

  @override
  Future<void> deleteFolder(String id) => _storage.deleteFolder(id);

  @override
  Future<bool> folderContainsMemo(String folderId, String memoId) {
    return _storage.folderContainsMemo(folderId, memoId);
  }

  @override
  Future<String> relativeParentOfPath(String absolutePath) {
    return _storage.relativeParentOfPath(absolutePath);
  }

  @override
  Future<String> relativeDirOfFolder(String directoryPath) {
    return _storage.relativeDirOfFolder(directoryPath);
  }

  @override
  Future<bool> isValidRelativeDir(String relativeParent) {
    return _storage.isValidRelativeDir(relativeParent);
  }

  @override
  Future<MemoFolderTreeNode> listFolderTree() => _storage.listFolderTree();

  @override
  Future<Memo> moveMemo({
    required String id,
    required String destRelativeDir,
  }) {
    return _storage.moveMemo(id: id, destRelativeDir: destRelativeDir);
  }

  @override
  Future<MemoFolder> moveFolder({
    required String id,
    required String destRelativeDir,
  }) {
    return _storage.moveFolder(id: id, destRelativeDir: destRelativeDir);
  }

  @override
  Future<MemoFolder> updateFolderColor({
    required String id,
    String? colorHex,
  }) {
    return _storage.updateFolderColor(id: id, colorHex: colorHex);
  }
}

/// 置顶与上次打开，便于单测注入。
abstract class MemoPinStore {
  List<String> get pinnedIds;
  List<String> get pinnedFolderIds;
  String? get lastOpenedMemoId;
  String get currentRelativeDir;

  Future<void> load();
  Future<void> updateLastOpenedMemoId(String id);
  Future<List<String>> togglePin(String id);
  Future<List<String>> toggleFolderPin(String id);
  Future<void> updateCurrentRelativeDir(String relativeDir);
}

class SessionMemoPinStore implements MemoPinStore {
  SessionMemoPinStore([SessionCacheService? cache])
      : _cache = cache ?? SessionCacheService();

  final SessionCacheService _cache;

  @override
  List<String> get pinnedIds => _cache.cache.pinnedMemoIds;

  @override
  List<String> get pinnedFolderIds => _cache.cache.pinnedFolderIds;

  @override
  String? get lastOpenedMemoId => _cache.cache.lastOpenedMemoId;

  @override
  String get currentRelativeDir => _cache.cache.currentRelativeDir;

  @override
  Future<void> load() async {
    // 必须等 session 读完再画侧栏；短 timeout 会让界面当成「无置顶」，
    // 而磁盘加载仍继续，之后任意一次 toggle 又把全部置顶带回来。
    await _cache.load();
  }

  @override
  Future<void> updateLastOpenedMemoId(String id) {
    return _cache.updateLastOpenedMemoId(id);
  }

  @override
  Future<List<String>> togglePin(String id) async {
    await _cache.togglePin(id);
    return List<String>.from(_cache.cache.pinnedMemoIds);
  }

  @override
  Future<List<String>> toggleFolderPin(String id) async {
    await _cache.toggleFolderPin(id);
    return List<String>.from(_cache.cache.pinnedFolderIds);
  }

  @override
  Future<void> updateCurrentRelativeDir(String relativeDir) {
    return _cache.updateCurrentRelativeDir(relativeDir);
  }
}

/// 列表 / 当前文档 / 保存 / 搜索 / 置顶。标题与正文仍用 Screen 传入的 controller。
class MemoWorkspaceController extends ChangeNotifier {
  MemoWorkspaceController({
    required this.titleController,
    required this.contentController,
    required this.searchController,
    MemoWorkspaceStore? store,
    MemoPinStore? pins,
    MemoSearchService? searchService,
    this.searchDelay = const Duration(milliseconds: 300),
  })  : _store = store ?? DiskMemoWorkspaceStore(),
        _pins = pins ?? SessionMemoPinStore(),
        _searchService = searchService ?? MemoSearchService();

  final TextEditingController titleController;
  final TextEditingController contentController;
  final TextEditingController searchController;
  final Duration searchDelay;
  final MemoWorkspaceStore _store;
  final MemoPinStore _pins;
  final MemoSearchService _searchService;

  /// 搜索无标题文档时的展示文案；由 Screen 按当前语言写入。
  /// 名称排序也用它，与侧栏 [Memo.displayTitle] 一致。
  String untitledLabel = 'Untitled';

  /// 当前目录非置顶段的排序；缺省为修改时间。
  FileListSort fileListSort = FileListSort.modifiedTime;

  /// 全库笔记索引（搜索 / 文档链接）。
  List<Memo> memos = [];

  /// 当前目录一层（侧栏普通列表）。
  List<MemoDirEntry> dirEntries = [];

  List<MemoSearchResult> searchResults = [];
  List<String> pinnedMemoIds = [];
  List<String> pinnedFolderIds = [];
  String currentRelativeDir = '';
  String? activeMemoId;
  String savedTitle = '';
  String savedContent = '';
  SaveStatus saveStatus = SaveStatus.saved;
  String? saveError;
  bool isSearchActive = false;
  bool caseSensitive = false;

  Timer? _searchDebounceTimer;
  Future<void>? _ongoingSave;

  bool get isDirty =>
      titleController.text != savedTitle ||
      contentController.text != savedContent;

  bool get isAtDocumentsRoot => currentRelativeDir.isEmpty;

  String? get lastOpenedMemoId => _pins.lastOpenedMemoId;

  Memo? memoById(String id) {
    for (final memo in memos) {
      if (memo.id == id) {
        return memo;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  Future<void> loadPinsAndList() async {
    try {
      await _pins.load();
    } catch (_) {
      // 读失败时仍以 store 当前内存为准，禁止假定「无置顶」。
    }
    pinnedMemoIds = List<String>.from(_pins.pinnedIds);
    pinnedFolderIds = List<String>.from(_pins.pinnedFolderIds);
    memos = await _store.listMemos();
    await _restoreCurrentDirectoryAfterLoad();
    await _reloadDirEntries();
    notifyListeners();
  }

  Future<void> _restoreCurrentDirectoryAfterLoad() async {
    final lastId = _pins.lastOpenedMemoId;
    Memo? lastMemo;
    if (lastId != null) {
      for (final memo in memos) {
        if (memo.id == lastId) {
          lastMemo = memo;
          break;
        }
      }
    }
    if (lastMemo != null) {
      currentRelativeDir = await _store.relativeParentOfPath(lastMemo.filePath);
      await _pins.updateCurrentRelativeDir(currentRelativeDir);
      return;
    }
    final persisted = _pins.currentRelativeDir;
    if (await _store.isValidRelativeDir(persisted)) {
      currentRelativeDir = persisted;
    } else {
      currentRelativeDir = '';
    }
  }

  Future<void> refreshList({String? selectId}) async {
    memos = await _store.listMemos();
    if (selectId != null) {
      activeMemoId = selectId;
    }
    await _reloadDirEntries();
    notifyListeners();
  }

  Future<void> _reloadDirEntries() async {
    final listed = await _store.listDirEntries(currentRelativeDir);
    dirEntries = MemoStorageService.sortDirEntries(
      entries: listed,
      pinnedFolderIds: pinnedFolderIds,
      pinnedMemoIds: pinnedMemoIds,
      fileListSort: fileListSort,
      untitledLabel: untitledLabel,
    );
  }

  /// 按当前排序重排已加载的目录条目，不读磁盘、不重跑搜索。
  void resortDirEntries() {
    dirEntries = MemoStorageService.sortDirEntries(
      entries: dirEntries,
      pinnedFolderIds: pinnedFolderIds,
      pinnedMemoIds: pinnedMemoIds,
      fileListSort: fileListSort,
      untitledLabel: untitledLabel,
    );
    notifyListeners();
  }

  void setFileListSort(FileListSort value) {
    fileListSort = value;
    resortDirEntries();
  }

  Future<void> enterFolder(String folderId) async {
    MemoFolder? folder;
    for (final entry in dirEntries) {
      if (entry.isFolder && entry.id == folderId) {
        folder = entry.folder;
        break;
      }
    }
    if (folder == null) {
      return;
    }
    currentRelativeDir = await _store.relativeDirOfFolder(folder.directoryPath);
    await _pins.updateCurrentRelativeDir(currentRelativeDir);
    await _reloadDirEntries();
    notifyListeners();
  }

  Future<void> goToParentDirectory() async {
    if (currentRelativeDir.isEmpty) {
      return;
    }
    currentRelativeDir = MemoFs.parentRelativeDir(currentRelativeDir);
    await _pins.updateCurrentRelativeDir(currentRelativeDir);
    await _reloadDirEntries();
    notifyListeners();
  }

  Future<MemoFolder> createFolder(String displayName) async {
    final folder = await _store.createFolder(
      relativeParent: currentRelativeDir,
      displayName: displayName,
    );
    await _reloadDirEntries();
    notifyListeners();
    return folder;
  }

  Future<void> renameFolder({
    required String id,
    required String newDisplayName,
  }) async {
    await _store.renameFolder(id: id, newDisplayName: newDisplayName);
    await _reloadDirEntries();
    notifyListeners();
  }

  /// 写入或清除文件夹颜色；不改当前目录与活动篇。
  Future<void> updateFolderColor({
    required String id,
    String? colorHex,
  }) async {
    await _store.updateFolderColor(id: id, colorHex: colorHex);
    await _reloadDirEntries();
    notifyListeners();
  }

  Future<MemoFolderTreeNode> listFolderTree() => _store.listFolderTree();

  /// 移动笔记到目标相对目录；不改当前目录与活动篇，不重写编辑器。
  Future<void> moveMemo({
    required String id,
    required String destRelativeDir,
  }) async {
    await flushSave();
    await _store.moveMemo(id: id, destRelativeDir: destRelativeDir);
    memos = await _store.listMemos();
    await _reloadDirEntries();
    notifyListeners();
  }

  /// 移动文件夹到目标相对目录；不改当前目录与活动篇。
  Future<void> moveFolder({
    required String id,
    required String destRelativeDir,
  }) async {
    await flushSave();
    await _store.moveFolder(id: id, destRelativeDir: destRelativeDir);
    memos = await _store.listMemos();
    await _reloadDirEntries();
    notifyListeners();
  }

  /// 删除文件夹；[wasActive] 表示当前打开篇在该树内。
  Future<({bool wasActive, List<Memo> remaining})> deleteFolder(String id) async {
    final activeId = activeMemoId;
    final containedActive = activeId != null &&
        await _store.folderContainsMemo(id, activeId);
    await _store.deleteFolder(id);
    if (pinnedFolderIds.contains(id)) {
      pinnedFolderIds = await _pins.toggleFolderPin(id);
    }
    memos = await _store.listMemos();
    if (containedActive) {
      activeMemoId = null;
    }
    await _reloadDirEntries();
    notifyListeners();
    if (isSearchActive) {
      runSearch();
    }
    return (wasActive: containedActive, remaining: List<Memo>.from(memos));
  }

  void onSearchChanged() {
    final query = searchController.text;
    if (query.trim().isEmpty && (isSearchActive || searchResults.isNotEmpty)) {
      searchResults = [];
      isSearchActive = false;
      notifyListeners();
    } else {
      notifyListeners();
    }
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(searchDelay, runSearch);
  }

  void runSearch() {
    final query = searchController.text;
    if (query.trim().isEmpty) {
      searchResults = [];
      isSearchActive = false;
      notifyListeners();
      return;
    }
    searchResults = _searchService.searchMemos(
      memos: memos,
      query: query,
      caseSensitive: caseSensitive,
      untitledLabel: untitledLabel,
    );
    isSearchActive = true;
    notifyListeners();
  }

  void setCaseSensitive(bool value) {
    caseSensitive = value;
    notifyListeners();
    runSearch();
  }

  Future<void> flushSave() async {
    if (_ongoingSave != null) {
      await _ongoingSave;
    }
    if (activeMemoId != null && isDirty) {
      await saveActive();
    }
  }

  Future<void> saveActive() async {
    final memoId = activeMemoId;
    if (memoId == null || !isDirty) {
      return;
    }
    if (_ongoingSave != null) {
      await _ongoingSave;
      if (activeMemoId != memoId || !isDirty) {
        return;
      }
    }
    final saveFuture = performSave(memoId);
    _ongoingSave = saveFuture;
    await saveFuture;
    if (_ongoingSave == saveFuture) {
      _ongoingSave = null;
    }
  }

  Future<void> performSave(String memoId) async {
    if (!isDirty) {
      saveStatus = SaveStatus.saved;
      notifyListeners();
      return;
    }
    saveStatus = SaveStatus.saving;
    saveError = null;
    notifyListeners();
    try {
      final updated = await _store.updateMemo(
        id: memoId,
        title: titleController.text,
        content: contentController.text,
      );
      if (activeMemoId != memoId) {
        return;
      }
      savedTitle = titleController.text;
      savedContent = contentController.text;
      saveStatus = SaveStatus.saved;
      memos = memos
          .map((memo) => memo.id == updated.id ? updated : memo)
          .toList();
      dirEntries = [
        for (final entry in dirEntries)
          if (!entry.isFolder && entry.id == updated.id)
            MemoDirEntry.file(updated)
          else
            entry,
      ];
      notifyListeners();
      if (isSearchActive) {
        runSearch();
      }
    } catch (error) {
      if (activeMemoId != memoId) {
        return;
      }
      saveStatus = SaveStatus.error;
      saveError = '$error';
      notifyListeners();
    }
  }

  void markIdleIfDirty() {
    if (saveStatus != SaveStatus.idle) {
      saveStatus = SaveStatus.idle;
      saveError = null;
      notifyListeners();
    }
  }

  /// 写入标题/正文 controller 与 saved 快照；滚动/历史由 Screen 处理。
  void applyMemoToEditors(Memo memo) {
    titleController.text = memo.title;
    contentController.text = memo.content;
    savedTitle = memo.title;
    savedContent = memo.content;
    activeMemoId = memo.id;
    saveStatus = SaveStatus.saved;
    saveError = null;
    notifyListeners();
    unawaited(_pins.updateLastOpenedMemoId(memo.id));
  }

  Future<Memo> loadMemo(String id) => _store.loadMemo(id);

  /// 切文档：先 flush 当前脏文档，再加载目标。不含滚动跳转。
  Future<Memo> openMemo(String id, {bool refreshList = true}) async {
    await flushSave();
    final memo = await _store.loadMemo(id);
    applyMemoToEditors(memo);
    currentRelativeDir = await _store.relativeParentOfPath(memo.filePath);
    await _pins.updateCurrentRelativeDir(currentRelativeDir);
    if (refreshList) {
      await this.refreshList(selectId: id);
    } else {
      await _reloadDirEntries();
      notifyListeners();
    }
    return memo;
  }

  /// 新建文档：先 flush，再创建并写入编辑器。不含滚动跳转。
  Future<Memo> createNewMemo({bool refreshList = true}) async {
    await flushSave();
    final memo = await _store.createMemo(relativeParent: currentRelativeDir);
    applyMemoToEditors(memo);
    if (refreshList) {
      await this.refreshList(selectId: memo.id);
    } else {
      if (!memos.any((item) => item.id == memo.id)) {
        memos = [memo, ...memos];
      }
      await _reloadDirEntries();
      notifyListeners();
    }
    return memo;
  }

  /// 导入外部 txt/md 到当前目录并打开。不退出搜索，与 [createNewMemo] 相同。
  Future<Memo> importExternalMemo(String sourcePath) async {
    await flushSave();
    final memo = await _store.importExternalMemo(
      sourcePath: sourcePath,
      relativeParent: currentRelativeDir,
    );
    applyMemoToEditors(memo);
    await refreshList(selectId: memo.id);
    return memo;
  }

  /// 将已规范化的选区文本写入笔记并立刻保存。
  ///
  /// 当前活动篇标题与正文都为空时复用该篇，否则先 [createNewMemo]。
  Future<Memo> captureTextAsMemo(String text) async {
    final reuse = shouldReuseEmptyActiveMemo(
          title: titleController.text,
          content: contentController.text,
        ) &&
        activeMemoId != null;
    if (!reuse) {
      await createNewMemo();
    }
    titleController.text = '';
    contentController.text = text;
    await flushSave();
    final id = activeMemoId;
    if (id == null) {
      throw StateError('captureTextAsMemo: 无活动笔记');
    }
    return memoById(id) ?? await loadMemo(id);
  }

  Future<void> renameMemo({
    required String id,
    required String newTitle,
  }) async {
    if (id == activeMemoId) {
      titleController.text = newTitle.trim();
      await flushSave();
    } else {
      await _store.renameMemo(id: id, newTitle: newTitle);
    }
    await refreshList(selectId: id);
    if (isSearchActive) {
      runSearch();
    }
  }

  /// 删除磁盘记录并更新列表；不负责打开下一篇。
  Future<({bool wasActive, List<Memo> remaining})> deleteMemo(String id) async {
    final wasActive = id == activeMemoId;
    await _store.deleteMemo(id);
    if (pinnedMemoIds.contains(id)) {
      pinnedMemoIds = await _pins.togglePin(id);
    }
    memos = memos.where((item) => item.id != id).toList();
    if (wasActive) {
      activeMemoId = null;
    }
    await _reloadDirEntries();
    notifyListeners();
    if (isSearchActive) {
      runSearch();
    }
    return (wasActive: wasActive, remaining: List<Memo>.from(memos));
  }

  Future<void> togglePin(String id) async {
    pinnedMemoIds = await _pins.togglePin(id);
    dirEntries = MemoStorageService.sortDirEntries(
      entries: dirEntries,
      pinnedFolderIds: pinnedFolderIds,
      pinnedMemoIds: pinnedMemoIds,
      fileListSort: fileListSort,
      untitledLabel: untitledLabel,
    );
    notifyListeners();
  }

  Future<void> toggleFolderPin(String id) async {
    pinnedFolderIds = await _pins.toggleFolderPin(id);
    dirEntries = MemoStorageService.sortDirEntries(
      entries: dirEntries,
      pinnedFolderIds: pinnedFolderIds,
      pinnedMemoIds: pinnedMemoIds,
      fileListSort: fileListSort,
      untitledLabel: untitledLabel,
    );
    notifyListeners();
  }

  Future<List<TrashItem>> listTrash() => memoTrashService.listTrash();

  Future<void> emptyTrash() => memoTrashService.emptyTrash();

  Future<void> restoreTrash(List<String> ids) async {
    await memoTrashService.restore(ids);
    await refreshList(selectId: activeMemoId);
  }

  Future<DataBackupResult> exportToDirectory({
    required UserPreferencesService prefsService,
    required String destinationParent,
  }) async {
    await flushSave();
    return DataBackupService(prefsService: prefsService)
        .exportToDirectory(destinationParent);
  }

  Future<DataBackupResult> importFromDirectory({
    required UserPreferencesService prefsService,
    required String selectedPath,
    DataBackupImportMode mode = DataBackupImportMode.merge,
  }) async {
    await flushSave();
    final result = await DataBackupService(prefsService: prefsService)
        .importFromDirectory(selectedPath, mode: mode);
    resetAfterImport();
    return result;
  }

  void resetAfterImport() {
    activeMemoId = null;
    memos = [];
    dirEntries = [];
    currentRelativeDir = '';
    isSearchActive = false;
    searchResults = [];
    searchController.clear();
    notifyListeners();
  }
}
