import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/features/memo/editor/markdown_link_actions.dart';
import 'package:mind_recall/models/memo.dart';

Memo _memo({
  required String id,
  required String title,
  required String filePath,
  String content = '',
}) {
  final now = DateTime(2026, 1, 1);
  return Memo(
    id: id,
    title: title,
    content: content,
    filePath: filePath,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  const untitled = '无标题';

  final memos = [
    _memo(
      id: '1700000000000',
      title: '旅行计划',
      filePath: r'D:\notes\1700000000000.md',
    ),
    _memo(
      id: '1700000000001',
      title: '',
      content: '首行当标题\n正文',
      filePath: r'D:\notes\1700000000001.md',
    ),
  ];

  test('resolveLocalMemo matches relative file path', () {
    final memo = MarkdownLinkActions.resolveLocalMemo(
      href: './1700000000000.md',
      memos: memos,
      untitledLabel: untitled,
      currentMemoFilePath: r'D:\notes\other.md',
    );
    expect(memo?.id, '1700000000000');
  });

  test('resolveLocalMemo matches document title', () {
    final memo = MarkdownLinkActions.resolveLocalMemo(
      href: '旅行计划',
      memos: memos,
      untitledLabel: untitled,
    );
    expect(memo?.id, '1700000000000');
  });

  test('resolveLocalMemo matches untitled display title from content', () {
    final memo = MarkdownLinkActions.resolveLocalMemo(
      href: '首行当标题',
      memos: memos,
      untitledLabel: untitled,
    );
    expect(memo?.id, '1700000000001');
  });

  test('hrefForMemo uses title on mobile-style mode', () {
    final href = MarkdownLinkActions.hrefForMemo(
      memo: memos.first,
      useRelativeFileHref: false,
      untitledLabel: untitled,
    );
    expect(href, '旅行计划');
  });

  test('hrefForMemo uses relative path on desktop-style mode', () {
    final href = MarkdownLinkActions.hrefForMemo(
      memo: memos.first,
      useRelativeFileHref: true,
      untitledLabel: untitled,
    );
    expect(href, './1700000000000.md');
  });
}
