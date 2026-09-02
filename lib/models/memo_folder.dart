import 'package:mind_recall/models/memo.dart';

/// 用户文件夹（磁盘名为时间戳 id）。
class MemoFolder {
  const MemoFolder({
    required this.id,
    required this.directoryPath,
    required this.displayName,
    required this.createdAt,
    DateTime? updatedAt,
    this.colorHex,
  }) : updatedAt = updatedAt ?? createdAt;

  static final _colorHexPattern = RegExp(r'^#[0-9A-Fa-f]{6}$');

  final String id;
  final String directoryPath;
  final String displayName;
  final DateTime createdAt;
  /// 目录 `stat.modified`；侧栏第二行与文件共用同一套时间格式。
  final DateTime updatedAt;
  /// 已归一化的 `#RRGGBB`；无自定义色为 `null`。
  final String? colorHex;

  /// 仅接受 `#` + 6 位十六进制；非法或非字符串返回 `null`。
  static String? parseColorHex(Object? raw) {
    if (raw is! String) {
      return null;
    }
    final trimmed = raw.trim();
    if (!_colorHexPattern.hasMatch(trimmed)) {
      return null;
    }
    return trimmed.toUpperCase();
  }

  /// 把 r/g/b（0–255）格式化为 `#RRGGBB` 大写。
  static String formatColorHex({
    required int r,
    required int g,
    required int b,
  }) {
    return '#${_hexByte(r)}${_hexByte(g)}${_hexByte(b)}';
  }

  static String _hexByte(int value) {
    return value.clamp(0, 255).toRadixString(16).padLeft(2, '0').toUpperCase();
  }
}

/// 当前目录一层的侧栏条目：文件夹或笔记。
class MemoDirEntry {
  const MemoDirEntry.folder(this.folder) : memo = null;

  const MemoDirEntry.file(this.memo) : folder = null;

  final MemoFolder? folder;
  final Memo? memo;

  bool get isFolder => folder != null;

  String get id => folder?.id ?? memo!.id;
}

/// 选目录对话框用的文件夹树；根节点 [folderId] / [createdAt] 为空，[relativeDir] 为空串。
class MemoFolderTreeNode {
  const MemoFolderTreeNode({
    required this.relativeDir,
    required this.displayName,
    this.folderId,
    this.createdAt,
    this.children = const [],
  });

  /// 根为 `null`。
  final String? folderId;
  final String relativeDir;
  final String displayName;
  final DateTime? createdAt;
  final List<MemoFolderTreeNode> children;

  bool get isRoot => folderId == null;

  MemoFolderTreeNode copyWith({
    List<MemoFolderTreeNode>? children,
  }) {
    return MemoFolderTreeNode(
      folderId: folderId,
      relativeDir: relativeDir,
      displayName: displayName,
      createdAt: createdAt,
      children: children ?? this.children,
    );
  }
}
