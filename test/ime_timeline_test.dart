import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/core/debug/ime_timeline.dart';

void main() {
  group('imeTimelineArgs', () {
    test('includes pending committed and optional diagnostics', () {
      final args = imeTimelineArgs(
        pendingLogical: 280.25,
        committedLogical: 0,
        burstMs: 940,
        settleResetCount: 12,
        willCommit: true,
        focused: true,
        reason: 'settle',
      );
      expect(args['pending'], '280.3');
      expect(args['committed'], '0.0');
      expect(args['burstMs'], '940');
      expect(args['settleResetCount'], '12');
      expect(args['willCommit'], 'true');
      expect(args['focused'], 'true');
      expect(args['reason'], 'settle');
    });

    test('omits null optional fields', () {
      final args = imeTimelineArgs(
        pendingLogical: 0,
        committedLogical: 0,
      );
      expect(args.keys, ['pending', 'committed']);
    });
  });

  group('imeTimelineVisualArgs', () {
    test('includes phase and optional shift diagnostics', () {
      final args = imeTimelineVisualArgs(
        phase: 'nudge',
        reason: 'settle',
        offsetBefore: 10,
        offsetAfter: 40.25,
        delta: 30.25,
        pendingLogical: 280,
        committedLogical: 280,
        toolbarLogical: 0,
        obscuredBottom: 364,
        applied: true,
      );
      expect(args['phase'], 'nudge');
      expect(args['reason'], 'settle');
      expect(args['off0'], '10.0');
      expect(args['off1'], '40.3');
      expect(args['delta'], '30.3');
      expect(args['applied'], 'true');
      expect(args['obscured'], '364.0');
    });

    test('omits null optional fields', () {
      final args = imeTimelineVisualArgs(phase: 'spacerCommit');
      expect(args.keys, ['phase']);
    });
  });
}
