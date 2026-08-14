import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/features/memo/editor/document_history.dart';

void main() {
  group('DocumentHistory', () {
    test('undo and redo restore previous snapshots', () {
      final history = DocumentHistory();
      const a = DocumentSnapshot(title: 'A', content: 'one');
      const b = DocumentSnapshot(title: 'A', content: 'two');
      const c = DocumentSnapshot(title: 'A', content: 'three');

      history.reset(a);
      history.record(b);
      history.record(c);

      expect(history.undo(c), b);
      expect(history.redo(b), c);
    });
  });
}
