import 'dart:io';

import 'package:path/path.dart' as p;

/// 笔记树与侧栏列举共用的路径约定。
abstract final class MemoFs {
  static const documentsFolderName = 'documents';
  static const fileConfExtension = '.fileconf';

  static bool isAssetsDirectoryName(String name) => name.endsWith('_assets');

  static bool isFileConfName(String name) =>
      p.extension(name) == fileConfExtension;

  static String fileConfFileName(String folderId) =>
      '$folderId$fileConfExtension';

  static String relativeDirFromDocs(Directory docs, String absoluteDir) {
    final docsPath = p.normalize(docs.path);
    final dirPath = p.normalize(absoluteDir);
    if (p.equals(dirPath, docsPath)) {
      return '';
    }
    final rel = p.relative(dirPath, from: docsPath);
    if (rel == '.' || rel == './') {
      return '';
    }
    if (rel.startsWith('..')) {
      return '';
    }
    return rel.replaceAll(r'\', '/');
  }

  static String parentRelativeDir(String currentRelativeDir) {
    final trimmed = currentRelativeDir.replaceAll(r'\', '/');
    if (trimmed.isEmpty || trimmed == '.') {
      return '';
    }
    final parent = p.dirname(trimmed);
    if (parent == '.' || parent == '/' || parent == '') {
      return '';
    }
    return parent.replaceAll(r'\', '/');
  }

  /// [candidate] 是否为 [ancestor] 自身或其子孙相对路径。根（空串）不当祖先用于剔除。
  static bool isSelfOrDescendantRelative({
    required String candidate,
    required String ancestor,
  }) {
    final child = candidate.replaceAll(r'\', '/');
    final parent = ancestor.replaceAll(r'\', '/');
    if (parent.isEmpty) {
      return false;
    }
    return child == parent || child.startsWith('$parent/');
  }

  static Directory resolveRelativeDir(Directory docs, String relativeParent) {
    final raw = relativeParent.replaceAll(r'\', '/').trim();
    if (raw.isEmpty || raw == '.') {
      return docs;
    }
    final normalized = p.normalize(raw);
    if (p.isAbsolute(normalized) ||
        normalized == '..' ||
        normalized.startsWith('..${p.separator}') ||
        normalized.startsWith('../')) {
      throw ArgumentError('非法相对路径');
    }
    final dir = Directory(p.join(docs.path, normalized));
    final docsPath = p.normalize(docs.path);
    final dirPath = p.normalize(dir.path);
    if (!p.isWithin(docsPath, dirPath) && dirPath != docsPath) {
      throw ArgumentError('非法相对路径');
    }
    return dir;
  }
}
