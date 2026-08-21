import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:mind_recall/models/memo.dart';
import 'package:mind_recall/models/memo_search_result.dart';
import 'package:mind_recall/services/data_backup_service.dart';
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
  Future<Memo> loadMemo(String id);
  Future<Memo> createMemo();
  Future<Memo> updateMemo({
    required String id,
    required String title,
    required String content,
  });
  Future<Memo> renameMemo({required String id, required String newTitle});
  Future<void> deleteMemo(String id);
}

class DiskMemoWorkspaceStore implements MemoWorkspaceStore {
  DiskMemoWorkspaceStore([MemoStorageService? storage])
      : _storage = storage ?? MemoStorageService();

  final MemoStorageService _storage;

  @override
  Future<List<Memo>> listMemos() => _storage.listMemos();

  @override
  Future<Memo> loadMemo(String id) => _storage.loadMemo(id);

  @override
  Future<Memo> createMemo() => _storage.createMemo();

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
}

/// 置顶与上次打开，便于单测注入。
abstract class MemoPinStore {
  List<String> get pinnedIds;
  String? get lastOpenedMemoId;

  Future<void> load();
  Future<void> updateLastOpenedMemoId(String id);
  Future<List<String>> togglePin(String id);
}

class SessionMemoPinStore implements MemoPinStore {
  SessionMemoPinStore([SessionCacheService? cache])
      : _cache = cache ?? SessionCacheService();

  final SessionCacheService _cache;

  @override
  List<String> get pinnedIds => _cache.cache.pinnedMemoIds;

  @override
  String? get lastOpenedMemoId => _cache.cache.lastOpenedMemoId;

  @override
  Future<void> load() async {
    await _cache.load().timeout(const Duration(milliseconds: 300));
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
  String untitledLabel = 'Untitled';

  List<Memo> memos = [];
  List<MemoSearchResult> searchResults = [];
  List<String> pinnedMemoIds = [];
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
      pinnedMemoIds = List<String>.from(_pins.pinnedIds);
    } catch (_) {
      pinnedMemoIds = [];
    }
    final listed = await _store.listMemos();
    MemoStorageService.sortMemosWithPins(listed, pinnedMemoIds);
    memos = listed;
    notifyListeners();
  }

  Future<void> refreshList({String? selectId}) async {
    final listed = await _store.listMemos();
    MemoStorageService.sortMemosWithPins(listed, pinnedMemoIds);
    memos = listed;
    if (selectId != null) {
      activeMemoId = selectId;
    }
    notifyListeners();
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
    if (refreshList) {
      await this.refreshList(selectId: id);
    }
    return memo;
  }

  /// 新建文档：先 flush，再创建并写入编辑器。不含滚动跳转。
  Future<Memo> createNewMemo({bool refreshList = true}) async {
    await flushSave();
    final memo = await _store.createMemo();
    applyMemoToEditors(memo);
    if (refreshList) {
      await this.refreshList(selectId: memo.id);
    } else if (!memos.any((item) => item.id == memo.id)) {
      memos = [memo, ...memos];
      notifyListeners();
    }
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
    final remaining = memos.where((item) => item.id != id).toList();
    MemoStorageService.sortMemosWithPins(remaining, pinnedMemoIds);
    memos = remaining;
    if (wasActive) {
      activeMemoId = null;
    }
    notifyListeners();
    if (isSearchActive) {
      runSearch();
    }
    return (wasActive: wasActive, remaining: remaining);
  }

  Future<void> togglePin(String id) async {
    pinnedMemoIds = await _pins.togglePin(id);
    MemoStorageService.sortMemosWithPins(memos, pinnedMemoIds);
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
  }) async {
    await flushSave();
    final result = await DataBackupService(prefsService: prefsService)
        .importFromDirectory(selectedPath);
    resetAfterImport();
    return result;
  }

  void resetAfterImport() {
    activeMemoId = null;
    memos = [];
    isSearchActive = false;
    searchResults = [];
    searchController.clear();
    notifyListeners();
  }
}
