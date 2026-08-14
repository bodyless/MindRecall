import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/models/memo.dart';
import 'package:mind_recall/services/memo_storage_service.dart';

void main() {
  group('MemoStorageService', () {
    late MemoStorageService service;

    setUp(() {
      service = MemoStorageService();
    });

    test('parseMemoContent handles title and body', () {
      final parsed = service.parseMemoContentForTest('My Title\n\nHello\nWorld');
      expect(parsed.title, 'My Title');
      expect(parsed.content, 'Hello\nWorld');
    });

    test('parseMemoContent handles body only', () {
      final parsed = service.parseMemoContentForTest('Hello\nWorld');
      expect(parsed.title, '');
      expect(parsed.content, 'Hello\nWorld');
    });

    test('parseMemoContent handles empty file', () {
      final parsed = service.parseMemoContentForTest('');
      expect(parsed.title, '');
      expect(parsed.content, '');
    });
  });

  group('sortMemosStable / sortMemosWithPins', () {
    Memo memo({
      required String id,
      required DateTime updatedAt,
      DateTime? createdAt,
    }) {
      final created = createdAt ?? updatedAt;
      return Memo(
        id: id,
        title: id,
        content: '',
        filePath: '$id.md',
        createdAt: created,
        updatedAt: updatedAt,
      );
    }

    test('sortMemosStable orders by updatedAt descending', () {
      final older = memo(
        id: '200',
        updatedAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 8, 1),
      );
      final newer = memo(
        id: '100',
        updatedAt: DateTime(2026, 8, 1),
        createdAt: DateTime(2026, 1, 1),
      );
      final memos = [older, newer];
      MemoStorageService.sortMemosStable(memos);
      expect(memos.map((m) => m.id), ['100', '200']);
    });

    test('sortMemosWithPins keeps pins first then updatedAt', () {
      final older = memo(id: '1', updatedAt: DateTime(2026, 1, 1));
      final newer = memo(id: '2', updatedAt: DateTime(2026, 8, 1));
      final pinnedOld = memo(id: '9', updatedAt: DateTime(2025, 1, 1));
      final memos = [older, newer, pinnedOld];
      MemoStorageService.sortMemosWithPins(memos, ['9']);
      expect(memos.map((m) => m.id), ['9', '2', '1']);
    });
  });
}
