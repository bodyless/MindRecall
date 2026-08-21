import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/app_layout_constants.dart';

void main() {
  group('imeBottomScrollPadding', () {
    test('zero when not focused', () {
      expect(
        imeBottomScrollPadding(keyboardInset: 300, focused: false),
        0,
      );
    });

    test('includes keyboard plus toolbar and caret gap when focused', () {
      expect(
        imeBottomScrollPadding(keyboardInset: 280, focused: true),
        280 + kMarkdownImeToolbarHeight + kImeCaretGap,
      );
    });

    test('body settle padding already includes toolbar before toolbar reveal', () {
      // 窄屏时序：先按含工具栏的 obscured 留白并滚入，再显工具栏；
      // 显栏不得再改变 obscured（否则会二次上推正文）。
      final afterBodySettle = imeBottomScrollPadding(
        keyboardInset: 300,
        focused: true,
      );
      expect(
        afterBodySettle,
        300 + kMarkdownImeToolbarHeight + kImeCaretGap,
      );
      final afterToolbarReveal = imeBottomScrollPadding(
        keyboardInset: 300,
        focused: true,
      );
      expect(afterToolbarReveal, afterBodySettle);
    });

    test('can omit toolbar for wide layout edit field', () {
      expect(
        imeBottomScrollPadding(
          keyboardInset: 280,
          focused: true,
          includeToolbar: false,
        ),
        280 + kImeCaretGap,
      );
    });

    test('still reserves toolbar space when keyboard height is zero', () {
      expect(
        imeBottomScrollPadding(keyboardInset: 0, focused: true),
        kMarkdownImeToolbarHeight + kImeCaretGap,
      );
    });
  });

  group('editFieldContentBottomPadding', () {
    test('only base and safe inset (IME is not contentPadding)', () {
      expect(
        editFieldContentBottomPadding(bottomSafe: 20),
        kEditorBodyBottomPadding + 20,
      );
    });

    test('base padding matches live ListView bottom padding', () {
      expect(kEditorBodyBottomPadding, 24);
    });
  });

  group('editImeBottomSpacerHeight', () {
    test('zero when keyboard closed so bottom mask does not cover last line', () {
      expect(
        editImeBottomSpacerHeight(
          keyboardInset: 0,
          focused: true,
        ),
        0,
      );
      expect(
        editImeBottomSpacerHeight(
          keyboardInset: 280,
          focused: false,
        ),
        0,
      );
    });

    test('matches live spacer when keyboard open and focused', () {
      expect(
        editImeBottomSpacerHeight(
          keyboardInset: 280,
          focused: true,
        ),
        liveListImeSpacerHeight(
          keyboardInset: 280,
          focused: true,
        ),
      );
    });
  });

  group('shouldCommitImeInset', () {
    test('commits when pending diverges beyond epsilon', () {
      expect(
        shouldCommitImeInset(pendingLogical: 280, committedLogical: 0),
        isTrue,
      );
    });

    test('skips tiny jitter within epsilon', () {
      expect(
        shouldCommitImeInset(pendingLogical: 280.2, committedLogical: 280),
        isFalse,
      );
    });
  });

  group('kImeInsetSettleDelay', () {
    test('settle window is long enough to skip mid-animation frames', () {
      expect(kImeInsetSettleDelay.inMilliseconds, greaterThanOrEqualTo(32));
    });
  });

  group('shouldHideImeToolbarImmediately', () {
    test('hides as soon as pending drops below committed', () {
      expect(
        shouldHideImeToolbarImmediately(
          pendingLogical: 200,
          committedLogical: 280,
        ),
        isTrue,
      );
    });

    test('does not hide while opening or stable', () {
      expect(
        shouldHideImeToolbarImmediately(
          pendingLogical: 100,
          committedLogical: 0,
        ),
        isFalse,
      );
      expect(
        shouldHideImeToolbarImmediately(
          pendingLogical: 280,
          committedLogical: 280,
        ),
        isFalse,
      );
    });

    test('套用缓存后 pending 低于 committed 不算收起', () {
      expect(
        shouldHideImeToolbarImmediately(
          pendingLogical: 296.9,
          committedLogical: 348.1,
          appliedCacheThisOpen: true,
          previousPendingLogical: 280,
        ),
        isFalse,
      );
    });

    test('套用缓存后 pending 相对上一帧明显下降才收起', () {
      expect(
        shouldHideImeToolbarImmediately(
          pendingLogical: 300,
          committedLogical: 348.1,
          appliedCacheThisOpen: true,
          previousPendingLogical: 348.1,
        ),
        isTrue,
      );
    });
  });

  group('liveListImeSpacerHeight', () {
    test('matches imeBottomScrollPadding so trailing spacer clears IME', () {
      expect(
        liveListImeSpacerHeight(keyboardInset: 280, focused: true),
        imeBottomScrollPadding(keyboardInset: 280, focused: true),
      );
      expect(
        liveListImeSpacerHeight(keyboardInset: 280, focused: false),
        0,
      );
    });

    test('reserves toolbar space when keyboard height is still zero', () {
      expect(
        liveListImeSpacerHeight(keyboardInset: 0, focused: true),
        kMarkdownImeToolbarHeight + kImeCaretGap,
      );
    });
  });

  group('shouldRestartImeSettleTimer', () {
    test('restarts on large pending steps during animation', () {
      expect(
        shouldRestartImeSettleTimer(
          pendingLogical: 120,
          armedPendingLogical: 100,
        ),
        isTrue,
      );
    });

    test('does not restart on small end-of-animation deltas', () {
      expect(
        shouldRestartImeSettleTimer(
          pendingLogical: 348.1,
          armedPendingLogical: 342,
        ),
        isFalse,
      );
      expect(
        shouldRestartImeSettleTimer(
          pendingLogical: 348.1,
          armedPendingLogical: 348.1,
        ),
        isFalse,
      );
    });

    test('restart threshold matches kImeSettleRestartMinDelta', () {
      expect(kImeSettleRestartMinDelta, 8);
      expect(
        shouldRestartImeSettleTimer(
          pendingLogical: 108,
          armedPendingLogical: 100,
        ),
        isTrue,
      );
      expect(
        shouldRestartImeSettleTimer(
          pendingLogical: 107.9,
          armedPendingLogical: 100,
        ),
        isFalse,
      );
    });
  });

  group('ime toolbar open reveal once', () {
    test('open settle restarts on ~1px pending drift while hidden', () {
      expect(kImeToolbarOpenSettleRestartDelta, 1);
      expect(
        shouldRestartImeToolbarOpenSettle(
          pendingLogical: 300.5,
          armedPendingLogical: 299.4,
        ),
        isTrue,
      );
      expect(
        shouldRestartImeToolbarOpenSettle(
          pendingLogical: 300.4,
          armedPendingLogical: 300,
        ),
        isFalse,
      );
    });

    test('toolbar bottom padding is keyboard height plus kImeToolbarKeyboardGap', () {
      expect(
        imeToolbarBottomPadding(keyboardInset: 348.1),
        348.1 + kImeToolbarKeyboardGap,
      );
      expect(imeToolbarBottomPadding(keyboardInset: 0), 0);
    });

    test('editor page bottom padding drops when IME toolbar is visible', () {
      expect(editorPageBottomPadding(imeToolbarVisible: false), kEditorPagePadding);
      expect(editorPageBottomPadding(imeToolbarVisible: true), 0);
    });

    test('reveals only when toolbar hidden and pending positive', () {
      expect(
        shouldRevealImeToolbarOnce(
          pendingLogical: 320,
          toolbarLogical: 0,
        ),
        isTrue,
      );
      expect(
        shouldRevealImeToolbarOnce(
          pendingLogical: 320,
          toolbarLogical: 300,
        ),
        isFalse,
      );
      expect(
        shouldRevealImeToolbarOnce(
          pendingLogical: 0,
          toolbarLogical: 0,
        ),
        isFalse,
      );
    });
  });

  group('shouldNudgeImeAfterContentWrap', () {
    test('no baseline still checks once', () {
      expect(
        shouldNudgeImeAfterContentWrap(
          previousSlotHeight: null,
          nextSlotHeight: 24,
        ),
        isTrue,
      );
    });

    test('same height does not nudge', () {
      expect(
        shouldNudgeImeAfterContentWrap(
          previousSlotHeight: 40,
          nextSlotHeight: 40,
        ),
        isFalse,
      );
    });

    test('slot grew from wrap → nudge', () {
      expect(
        shouldNudgeImeAfterContentWrap(
          previousSlotHeight: 24,
          nextSlotHeight: 48,
        ),
        isTrue,
      );
    });

    test('sub-pixel jitter does not count as wrap', () {
      expect(
        shouldNudgeImeAfterContentWrap(
          previousSlotHeight: 40,
          nextSlotHeight: 40.2,
        ),
        isFalse,
      );
    });
  });
}
