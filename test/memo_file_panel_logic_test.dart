import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/features/memo/sidebar/memo_file_panel_logic.dart';

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
