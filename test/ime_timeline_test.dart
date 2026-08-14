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
}
