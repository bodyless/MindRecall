import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/features/memo/editor/memo_workspace_controller.dart';
import 'package:mind_recall/features/memo/sidebar/memo_file_panel_logic.dart';
import 'package:mind_recall/models/memo.dart';

class _FakeStore implements MemoWorkspaceStore {
  final Map<String, Memo> memos = {};
  int updateCount = 0;

  Memo put({
    required String id,
    String title = '',
    String content = '',
    required DateTime updatedAt,
  }) {
    final memo = Memo(
      id: id,
      title: title,
      content: content,
      filePath: '$id.md',
      createdAt: updatedAt,
      updatedAt: updatedAt,
    );
    memos[id] = memo;
    return memo;
  }

  @override
  Future<List<Memo>> listMemos() async => memos.values.toList();

  @override
  Future<Memo> loadMemo(String id) async {
    final memo = memos[id];
    if (memo == null) {
      throw StateError('missing $id');
    }
    return memo;
  }

  @override
  Future<Memo> createMemo() async {
    return put(
      id: 'new-${memos.length}',
      updatedAt: DateTime(2026, 1, 1),
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
}

class _MemoryPins implements MemoPinStore {
  @override
  List<String> pinnedIds = [];

  @override
  String? lastOpenedMemoId;

  @override
  Future<void> load() async {}

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

  test('置顶后排序：置顶文档排在未置顶之前', () async {
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
    workspace.memos = [newer, older];

    await workspace.togglePin('older');

    expect(workspace.pinnedMemoIds, ['older']);
    expect(workspace.memos.map((m) => m.id).toList(), ['older', 'newer']);
  });
}
