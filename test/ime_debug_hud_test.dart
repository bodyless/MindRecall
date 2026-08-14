import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/core/debug/ime_debug_hud.dart';

void main() {
  tearDown(() {
    imeDebugHud.value = ImeDebugSnapshot.empty;
  });

  group('formatImeDebugHudLines', () {
    test('empty snapshot shows placeholder', () {
      expect(formatImeDebugHudLines(ImeDebugSnapshot.empty), ['IME —']);
    });

    test('formats pending committed toolbar and settle diagnostics', () {
      final lines = formatImeDebugHudLines(
        const ImeDebugSnapshot(
          scope: 'Live',
          pendingLogical: 348.2,
          committedLogical: 0,
          toolbarLogical: 0,
          burstMs: 420,
          settleResetCount: 7,
          settleActive: true,
          focused: true,
          lastCommitReason: 'settle',
        ),
      );
      expect(lines, [
        'IME Live F',
        'p=348 c=0 t=0',
        'burst=420 rst=7 settle',
        'commit=settle',
      ]);
    });

    test('omits commit line and settle tag when idle unfocused', () {
      final lines = formatImeDebugHudLines(
        const ImeDebugSnapshot(
          scope: 'Edit',
          pendingLogical: 0,
          committedLogical: 0,
          toolbarLogical: 0,
          burstMs: 12,
          settleResetCount: 0,
          settleActive: false,
          focused: false,
        ),
      );
      expect(lines, [
        'IME Edit U',
        'p=0 c=0 t=0',
        'burst=12 rst=0',
      ]);
    });
  });

  group('publishImeDebugHud', () {
    test('updates notifier and preserves reason when omitted', () {
      publishImeDebugHud(
        scope: 'Live',
        pendingLogical: 100,
        committedLogical: 100,
        toolbarLogical: 100,
        burstMs: 80,
        settleResetCount: 1,
        settleActive: false,
        focused: true,
        lastCommitReason: 'settle',
      );
      expect(imeDebugHud.value.lastCommitReason, 'settle');
      expect(imeDebugHud.value.toolbarLogical, 100);

      publishImeDebugHud(
        scope: 'Live',
        pendingLogical: 120,
        committedLogical: 100,
        toolbarLogical: 100,
        burstMs: 100,
        settleResetCount: 2,
        settleActive: true,
        focused: true,
      );
      expect(imeDebugHud.value.pendingLogical, 120);
      expect(imeDebugHud.value.settleResetCount, 2);
      expect(imeDebugHud.value.lastCommitReason, 'settle');
    });

    test('skips notify when snapshot unchanged', () {
      publishImeDebugHud(
        scope: 'Edit',
        pendingLogical: 10,
        committedLogical: 10,
        toolbarLogical: 10,
        burstMs: 1,
        settleResetCount: 0,
        settleActive: false,
        focused: true,
        lastCommitReason: 'settle',
      );
      final first = imeDebugHud.value;
      var notifies = 0;
      void listener() => notifies++;
      imeDebugHud.addListener(listener);
      publishImeDebugHud(
        scope: 'Edit',
        pendingLogical: 10,
        committedLogical: 10,
        toolbarLogical: 10,
        burstMs: 1,
        settleResetCount: 0,
        settleActive: false,
        focused: true,
        lastCommitReason: 'settle',
      );
      imeDebugHud.removeListener(listener);
      expect(notifies, 0);
      expect(identical(imeDebugHud.value, first) || imeDebugHud.value == first, isTrue);
    });
  });
}
