import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/core/debug/debug_fps_overlay.dart';

void main() {
  group('summarizeDebugFps', () {
    test('empty window stays green at 60', () {
      final summary = summarizeDebugFps(const []);
      expect(summary.fps, 60);
      expect(summary.janky, isFalse);
    });

    test('16ms frames are smooth green', () {
      final frames = List<Duration>.filled(
        10,
        const Duration(milliseconds: 16),
      );
      final summary = summarizeDebugFps(frames);
      expect(summary.fps, closeTo(62.5, 1));
      expect(summary.janky, isFalse);
    });

    test('slow frame in window turns janky red', () {
      final frames = <Duration>[
        ...List<Duration>.filled(9, const Duration(milliseconds: 16)),
        const Duration(milliseconds: 40),
      ];
      final summary = summarizeDebugFps(frames);
      expect(summary.janky, isTrue);
    });

    test('consistently low fps is janky', () {
      final frames = List<Duration>.filled(
        10,
        const Duration(milliseconds: 30),
      );
      final summary = summarizeDebugFps(frames);
      expect(summary.fps, closeTo(33.3, 1));
      expect(summary.janky, isTrue);
    });
  });
}
