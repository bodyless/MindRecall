import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/models/memo.dart';
import 'package:mind_recall/models/memo_search_result.dart';
import 'package:mind_recall/services/memo_search_service.dart';

void main() {
  group('MemoSearchService', () {
    late MemoSearchService service;

    setUp(() {
      service = MemoSearchService();
    });

    Memo memo({
      required String id,
      required String title,
      required String content,
    }) {
      final now = DateTime(2026, 7, 3, 12);
      return Memo(
        id: id,
        title: title,
        content: content,
        filePath: '/tmp/$id.txt',
        createdAt: now,
        updatedAt: now,
      );
    }

    test('splitKeywords supports multiple keywords', () {
      expect(service.splitKeywords('foo bar  baz'), ['foo', 'bar', 'baz']);
      expect(service.splitKeywords('  '), isEmpty);
    });

    test('requires all keywords to match', () {
      expect(
        service.containsAllKeywords(
          title: '购物清单',
          content: '买苹果和牛奶',
          keywords: ['苹果', '牛奶'],
          caseSensitive: false,
        ),
        isTrue,
      );
      expect(
        service.containsAllKeywords(
          title: '购物清单',
          content: '买苹果',
          keywords: ['苹果', '牛奶'],
          caseSensitive: false,
        ),
        isFalse,
      );
    });

    test('case sensitivity can be toggled', () {
      expect(
        service.containsAllKeywords(
          title: '',
          content: 'Hello World',
          keywords: ['hello'],
          caseSensitive: false,
        ),
        isTrue,
      );
      expect(
        service.containsAllKeywords(
          title: '',
          content: 'Hello World',
          keywords: ['hello'],
          caseSensitive: true,
        ),
        isFalse,
      );
    });

    test('findFirstJumpTarget prefers title then content', () {
      final target = service.findFirstJumpTarget(
        title: '项目计划',
        content: '第一步：调研\n第二步：开发',
        keywords: ['开发'],
        caseSensitive: false,
      );

      expect(target?.field, MemoJumpField.content);
      expect(target?.lineNumber, 2);
    });

    test('searchMemos returns snippet and jump target', () {
      final results = service.searchMemos(
        memos: [
          memo(
            id: '1',
            title: '学习笔记',
            content: 'Flutter 搜索功能\nDart 关键字',
          ),
          memo(id: '2', title: '其他', content: '无关内容'),
        ],
        query: 'Flutter 搜索',
        caseSensitive: false,
      );

      expect(results, hasLength(1));
      expect(results.first.memoId, '1');
      expect(results.first.snippet, contains('Flutter'));
      expect(results.first.jumpTarget.field, MemoJumpField.content);
    });
  });
}
