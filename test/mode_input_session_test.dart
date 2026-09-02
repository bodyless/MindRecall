import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/app_layout_constants.dart';
import 'package:mind_recall/features/memo/editor/mode_input_session.dart';

void main() {
  group('EditInputSession', () {
    test('resetKeyboardInsets clears pending and applied inset', () {
      final session = EditInputSession();
      addTearDown(session.dispose);
      session.keyboardBottomInset = 280;
      session.pendingKeyboardInset = 300;
      session.resetKeyboardInsets();
      expect(session.keyboardBottomInset, 0);
      expect(session.pendingKeyboardInset, 0);
    });
  });

  group('LiveInputSession', () {
    test('inputSessionActive follows hadFocus and deferFocusBlur', () {
      final session = LiveInputSession();
      addTearDown(session.dispose);
      expect(session.inputSessionActive, isFalse);

      session.hadFocus = true;
      expect(session.inputSessionActive, isTrue);

      session.hadFocus = false;
      session.deferFocusBlur = true;
      expect(session.inputSessionActive, isTrue);

      session.clearSessionFlags();
      expect(session.hadFocus, isFalse);
      expect(session.deferFocusBlur, isFalse);
      expect(session.inputSessionActive, isFalse);
    });

    test('edit and live use distinct FocusNode and ScrollController', () {
      final edit = EditInputSession();
      final live = LiveInputSession();
      addTearDown(() {
        edit.dispose();
        live.dispose();
      });
      expect(identical(edit.focusNode, live.focusNode), isFalse);
      expect(
        identical(edit.scrollController, live.scrollController),
        isFalse,
      );
    });
  });

  group('shouldRestoreEditorFocusAfterSuspend', () {
    test('同篇且请求恢复 → 真', () {
      expect(
        shouldRestoreEditorFocusAfterSuspend(
          restoreRequested: true,
          suppressRestore: false,
          suspendedMemoId: 'a',
          activeMemoId: 'a',
        ),
        isTrue,
      );
    });

    test('换篇不恢复', () {
      expect(
        shouldRestoreEditorFocusAfterSuspend(
          restoreRequested: true,
          suppressRestore: false,
          suspendedMemoId: 'a',
          activeMemoId: 'b',
        ),
        isFalse,
      );
    });

    test('suppressRestore 即使同篇也不恢复', () {
      expect(
        shouldRestoreEditorFocusAfterSuspend(
          restoreRequested: true,
          suppressRestore: true,
          suspendedMemoId: 'a',
          activeMemoId: 'a',
        ),
        isFalse,
      );
    });

    test('suspendedMemoId 空不恢复', () {
      expect(
        shouldRestoreEditorFocusAfterSuspend(
          restoreRequested: true,
          suppressRestore: false,
          suspendedMemoId: null,
          activeMemoId: 'a',
        ),
        isFalse,
      );
    });

    test('未请求恢复则为假', () {
      expect(
        shouldRestoreEditorFocusAfterSuspend(
          restoreRequested: false,
          suppressRestore: false,
          suspendedMemoId: 'a',
          activeMemoId: 'a',
        ),
        isFalse,
      );
    });
  });

  group('shouldUnfocusOnImeUserDismiss', () {
    test('已聚焦且键盘正在落下 → unfocus', () {
      expect(
        shouldUnfocusOnImeUserDismiss(
          hasFocus: true,
          editorFocusSuspended: false,
          layoutTransitionActive: false,
          deferFocusBlur: false,
          imeDismissed: true,
        ),
        isTrue,
      );
    });

    test('点选后 inset 仍为 0 不 unfocus', () {
      expect(
        shouldUnfocusOnImeUserDismiss(
          hasFocus: true,
          editorFocusSuspended: false,
          layoutTransitionActive: false,
          deferFocusBlur: false,
          imeDismissed: false,
        ),
        isFalse,
      );
    });

    test('suspend 中不 unfocus', () {
      expect(
        shouldUnfocusOnImeUserDismiss(
          hasFocus: true,
          editorFocusSuspended: true,
          layoutTransitionActive: false,
          deferFocusBlur: false,
          imeDismissed: true,
        ),
        isFalse,
      );
    });

    test('换块 layoutTransition 不 unfocus', () {
      expect(
        shouldUnfocusOnImeUserDismiss(
          hasFocus: true,
          editorFocusSuspended: false,
          layoutTransitionActive: true,
          deferFocusBlur: false,
          imeDismissed: true,
        ),
        isFalse,
      );
    });

    test('换块 deferFocusBlur 不 unfocus', () {
      expect(
        shouldUnfocusOnImeUserDismiss(
          hasFocus: true,
          editorFocusSuspended: false,
          layoutTransitionActive: false,
          deferFocusBlur: true,
          imeDismissed: true,
        ),
        isFalse,
      );
    });

    test('无焦点不 unfocus', () {
      expect(
        shouldUnfocusOnImeUserDismiss(
          hasFocus: false,
          editorFocusSuspended: false,
          layoutTransitionActive: false,
          deferFocusBlur: false,
          imeDismissed: true,
        ),
        isFalse,
      );
    });

    test('与 shouldCommitImeDismissImmediately 组合：落下才 dismiss', () {
      final dismissed = shouldCommitImeDismissImmediately(
        pendingLogical: 0,
        committedLogical: 280,
      );
      expect(dismissed, isTrue);
      expect(
        shouldUnfocusOnImeUserDismiss(
          hasFocus: true,
          editorFocusSuspended: false,
          layoutTransitionActive: false,
          deferFocusBlur: false,
          imeDismissed: dismissed,
        ),
        isTrue,
      );

      final stillClosed = shouldCommitImeDismissImmediately(
        pendingLogical: 0,
        committedLogical: 0,
      );
      expect(stillClosed, isFalse);
      expect(
        shouldUnfocusOnImeUserDismiss(
          hasFocus: true,
          editorFocusSuspended: false,
          layoutTransitionActive: false,
          deferFocusBlur: false,
          imeDismissed: stillClosed,
        ),
        isFalse,
      );

      expect(
        shouldUnfocusOnImeUserDismiss(
          hasFocus: true,
          editorFocusSuspended: true,
          layoutTransitionActive: false,
          deferFocusBlur: false,
          imeDismissed: dismissed,
        ),
        isFalse,
      );
      expect(
        shouldUnfocusOnImeUserDismiss(
          hasFocus: true,
          editorFocusSuspended: false,
          layoutTransitionActive: true,
          deferFocusBlur: false,
          imeDismissed: dismissed,
        ),
        isFalse,
      );
    });
  });

  group('liveOverlayIgnoresPointers', () {
    test('失焦忽略命中，聚焦不忽略', () {
      expect(liveOverlayIgnoresPointers(hasFocus: false), isTrue);
      expect(liveOverlayIgnoresPointers(hasFocus: true), isFalse);
    });
  });
}
