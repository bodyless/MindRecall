import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/features/memo/sidebar/memo_file_panel_logic.dart';
import 'package:mind_recall/models/memo.dart';
import 'package:mind_recall/models/memo_folder.dart';

void main() {
  group('memoFilePanelShowsSearchResults', () {
    test('active + non-empty query → search list', () {
      expect(
        memoFilePanelShowsSearchResults(
          isSearchActive: true,
          query: 'foo',
        ),
        isTrue,
      );
    });

    test('active but empty query → file list (debounce race)', () {
      expect(
        memoFilePanelShowsSearchResults(
          isSearchActive: true,
          query: '   ',
        ),
        isFalse,
      );
    });

    test('inactive → file list', () {
      expect(
        memoFilePanelShowsSearchResults(
          isSearchActive: false,
          query: 'foo',
        ),
        isFalse,
      );
    });
  });

  group('memoFilePanelShowsParentButton', () {
    test('root hides', () {
      expect(
        memoFilePanelShowsParentButton(
          isSearchActive: false,
          query: '',
          currentRelativeDir: '',
        ),
        isFalse,
      );
    });

    test('nested dir shows', () {
      expect(
        memoFilePanelShowsParentButton(
          isSearchActive: false,
          query: '',
          currentRelativeDir: 'abc',
        ),
        isTrue,
      );
    });

    test('search hides even in nested dir', () {
      expect(
        memoFilePanelShowsParentButton(
          isSearchActive: true,
          query: 'foo',
          currentRelativeDir: 'abc',
        ),
        isFalse,
      );
    });
  });

  group('memoListItemIsHighlighted', () {
    test('file highlights when active', () {
      expect(
        memoListItemIsHighlighted(
          isFolder: false,
          entryId: 'a',
          activeMemoId: 'a',
        ),
        isTrue,
      );
    });

    test('folder never highlights', () {
      expect(
        memoListItemIsHighlighted(
          isFolder: true,
          entryId: 'a',
          activeMemoId: 'a',
        ),
        isFalse,
      );
    });
  });

  group('memoDirEntryListTime', () {
    test('folder uses updatedAt', () {
      final folder = MemoDirEntry.folder(
        MemoFolder(
          id: 'f',
          directoryPath: 'f',
          displayName: 'F',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 8, 1),
        ),
      );
      expect(memoDirEntryListTime(folder), DateTime(2026, 8, 1));
    });

    test('file uses memo updatedAt', () {
      final file = MemoDirEntry.file(
        Memo(
          id: 'm',
          title: 'm',
          content: '',
          filePath: 'm.md',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 7, 1),
        ),
      );
      expect(memoDirEntryListTime(file), DateTime(2026, 7, 1));
    });
  });

  group('move picker logic', () {
    MemoFolderTreeNode node({
      required String id,
      required DateTime createdAt,
      List<MemoFolderTreeNode> children = const [],
    }) {
      return MemoFolderTreeNode(
        folderId: id,
        relativeDir: id.contains('/') ? id : id,
        displayName: id,
        createdAt: createdAt,
        children: children,
      );
    }

    test('excludeFolderFromMoveTree 去掉自身与子孙，保留根', () {
      final workChild = MemoFolderTreeNode(
        folderId: 'child',
        relativeDir: 'work/child',
        displayName: 'child',
        createdAt: DateTime(2026, 2, 1),
      );
      final work = MemoFolderTreeNode(
        folderId: 'work',
        relativeDir: 'work',
        displayName: 'work',
        createdAt: DateTime(2026, 1, 1),
        children: [workChild],
      );
      final life = MemoFolderTreeNode(
        folderId: 'life',
        relativeDir: 'life',
        displayName: 'life',
        createdAt: DateTime(2026, 3, 1),
      );
      final root = MemoFolderTreeNode(
        relativeDir: '',
        displayName: '',
        children: [work, life],
      );
      final filtered = excludeFolderFromMoveTree(
        root,
        movingFolderRelativeDir: 'work',
      );
      expect(filtered.relativeDir, isEmpty);
      expect(filtered.children.map((n) => n.folderId), ['life']);
    });

    test('moveDestinationConfirmEnabled：源父禁用，其它与根启用', () {
      expect(
        moveDestinationConfirmEnabled(
          sourceParentRelativeDir: 'work',
          selectedRelativeDir: 'work',
        ),
        isFalse,
      );
      expect(
        moveDestinationConfirmEnabled(
          sourceParentRelativeDir: 'work',
          selectedRelativeDir: 'life',
        ),
        isTrue,
      );
      expect(
        moveDestinationConfirmEnabled(
          sourceParentRelativeDir: 'work',
          selectedRelativeDir: '',
        ),
        isTrue,
      );
      expect(
        moveDestinationConfirmEnabled(
          sourceParentRelativeDir: '',
          selectedRelativeDir: '',
        ),
        isFalse,
      );
    });

    test('sortMemoFolderTree 每层置顶靠前，其余 createdAt 新→旧', () {
      final old = node(id: 'old', createdAt: DateTime(2026, 1, 1));
      final newer = node(id: 'new', createdAt: DateTime(2026, 6, 1));
      final pinned = node(id: 'pin', createdAt: DateTime(2020, 1, 1));
      final nestedOld = node(id: 'n-old', createdAt: DateTime(2026, 1, 1));
      final nestedNew = node(
        id: 'n-new',
        createdAt: DateTime(2026, 8, 1),
      );
      final parent = MemoFolderTreeNode(
        folderId: 'p',
        relativeDir: 'p',
        displayName: 'p',
        createdAt: DateTime(2026, 1, 1),
        children: [nestedOld, nestedNew],
      );
      final root = MemoFolderTreeNode(
        relativeDir: '',
        displayName: '',
        children: [old, parent, newer, pinned],
      );
      final sorted = sortMemoFolderTree(
        root,
        pinnedFolderIds: ['pin'],
      );
      expect(sorted.children.map((n) => n.folderId), [
        'pin',
        'new',
        'p',
        'old',
      ]);
      expect(sorted.children[2].children.map((n) => n.folderId), [
        'n-new',
        'n-old',
      ]);
    });
  });

  group('sortMemoDirEntries', () {
    test('pinned folder then pinned file', () {
      final folder = MemoDirEntry.folder(
        MemoFolder(
          id: 'f',
          directoryPath: 'f',
          displayName: 'F',
          createdAt: DateTime(2026, 1, 1),
        ),
      );
      final file = MemoDirEntry.file(
        Memo(
          id: 'm',
          title: 'm',
          content: '',
          filePath: 'm.md',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      );
      final sorted = sortMemoDirEntries(
        entries: [file, folder],
        pinnedFolderIds: ['f'],
        pinnedMemoIds: ['m'],
      );
      expect(sorted.map((e) => e.id), ['f', 'm']);
    });
  });

  group('drawerEdgeDragWidthFor', () {
    test('half screen plus left safe padding', () {
      expect(
        drawerEdgeDragWidthFor(screenWidth: 400, leftSafePadding: 20),
        220,
      );
    });

    test('custom fraction', () {
      expect(
        drawerEdgeDragWidthFor(
          screenWidth: 400,
          leftSafePadding: 0,
          fraction: 0.25,
        ),
        100,
      );
    });
  });

  group('drawerOpenDragGestureEnabled', () {
    test('narrow + ime dismissed enables', () {
      expect(
        drawerOpenDragGestureEnabled(
          isWide: false,
          insetBottomLogical: 0,
        ),
        isTrue,
      );
    });

    test('wide disables', () {
      expect(
        drawerOpenDragGestureEnabled(
          isWide: true,
          insetBottomLogical: 0,
        ),
        isFalse,
      );
    });

    test('visible ime inset disables even if would-be focused', () {
      expect(
        drawerOpenDragGestureEnabled(
          isWide: false,
          insetBottomLogical: 120,
        ),
        isFalse,
      );
    });

    test('ime just settled enables', () {
      expect(
        drawerOpenDragGestureEnabled(
          isWide: false,
          insetBottomLogical: 0.5,
        ),
        isTrue,
      );
    });
  });

  group('drawerShouldWaitForIme', () {
    test('focused editor waits', () {
      expect(
        drawerShouldWaitForIme(editorFocused: true, insetBottomLogical: 0),
        isTrue,
      );
    });

    test('visible inset waits', () {
      expect(
        drawerShouldWaitForIme(editorFocused: false, insetBottomLogical: 120),
        isTrue,
      );
    });

    test('idle does not wait', () {
      expect(
        drawerShouldWaitForIme(editorFocused: false, insetBottomLogical: 0),
        isFalse,
      );
    });
  });

  group('SidebarRevealState', () {
    test('collapse hides panel', () {
      final state = SidebarRevealState();
      state.collapse();
      expect(state.expanded, isFalse);
      expect(state.contentVisible, isFalse);
      expect(state.shouldBuildPanel, isFalse);
    });

    test('expand begins hidden then reveal on animation end', () {
      final state = SidebarRevealState(expanded: false, contentVisible: false);
      state.beginExpand();
      expect(state.expanded, isTrue);
      expect(state.shouldBuildPanel, isFalse);

      state.onExpandAnimationEnded();
      expect(state.contentVisible, isTrue);
      expect(state.shouldBuildPanel, isTrue);
    });

    test('animation end ignored after collapse mid-flight', () {
      final state = SidebarRevealState(expanded: false, contentVisible: false);
      state.beginExpand();
      state.collapse();
      state.onExpandAnimationEnded();
      expect(state.shouldBuildPanel, isFalse);
      expect(state.contentVisible, isFalse);
    });

    test('rapid beginExpand stays revealable', () {
      final state = SidebarRevealState(expanded: false, contentVisible: false);
      state.beginExpand();
      state.beginExpand();
      state.onExpandAnimationEnded();
      expect(state.shouldBuildPanel, isTrue);
    });
  });
}
