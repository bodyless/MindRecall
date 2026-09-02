import 'package:mind_recall/app_layout_constants.dart';

class Memo {
  const Memo({
    required this.id,
    required this.title,
    required this.content,
    required this.filePath,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String content;
  final String filePath;
  final DateTime createdAt;
  final DateTime updatedAt;

  String displayTitle(String untitledLabel) {
    if (title.trim().isNotEmpty) {
      return title.trim();
    }
    final preview = content.trim();
    if (preview.isEmpty) {
      return untitledLabel;
    }
    final firstLine = preview.split('\n').first.trim();
    if (firstLine.length <= kMemoTitlePreviewMaxLength) {
      return firstLine;
    }
    return '${firstLine.substring(0, kMemoTitlePreviewMaxLength)}…';
  }

  Memo copyWith({
    String? title,
    String? content,
    String? filePath,
    DateTime? updatedAt,
  }) {
    return Memo(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      filePath: filePath ?? this.filePath,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
