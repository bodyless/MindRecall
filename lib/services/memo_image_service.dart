import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// 笔记本地图片：复制到与 `.md` 同级的 `{memoId}_assets/`，Markdown 使用相对路径。
class MemoImageService {
  static String assetsDirName(String memoId) => '${memoId}_assets';

  Directory assetsDirectoryFor({
    required String memoId,
    required String memoFilePath,
  }) {
    return Directory(
      p.join(p.dirname(memoFilePath), assetsDirName(memoId)),
    );
  }

  Future<Directory> assetsDirectory({
    required String memoId,
    required String memoFilePath,
  }) async {
    final dir = assetsDirectoryFor(memoId: memoId, memoFilePath: memoFilePath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 将 [sourcePath] 复制到笔记资源目录，返回可插入正文的 Markdown 片段。
  Future<String> copyAndBuildMarkdown({
    required String memoId,
    required String memoFilePath,
    required String sourcePath,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('图片不存在', sourcePath);
    }

    final assetsDir = await assetsDirectory(
      memoId: memoId,
      memoFilePath: memoFilePath,
    );
    final fileName = _uniqueFileName(assetsDir, p.basename(sourcePath));
    final dest = File(p.join(assetsDir.path, fileName));
    await source.copy(dest.path);

    final relativePath =
        './${assetsDirName(memoId)}/$fileName'.replaceAll(r'\', '/');
    final alt = p.basenameWithoutExtension(fileName);
    return '![$alt]($relativePath)';
  }

  /// 解析 Markdown 图片 URI 为本地 [File]；网络 URL 返回 null。
  File? resolveLocalImage({
    required String memoFilePath,
    required Uri uri,
  }) {
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      return null;
    }

    final memoDir = p.normalize(p.dirname(memoFilePath));
    final resolved = _resolvePath(memoDir, uri);
    if (resolved == null) {
      return null;
    }

    final file = File(resolved);
    return file.existsSync() ? file : null;
  }

  Future<void> deleteAssets({
    required String memoId,
    required String memoFilePath,
  }) async {
    final dir = assetsDirectoryFor(memoId: memoId, memoFilePath: memoFilePath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  @visibleForTesting
  String uniqueFileNameForTest(Directory assetsDir, String originalName) {
    return _uniqueFileName(assetsDir, originalName);
  }

  @visibleForTesting
  String? resolvePathForTest(String memoDir, Uri uri) {
    return _resolvePath(p.normalize(memoDir), uri);
  }

  String _uniqueFileName(Directory assetsDir, String originalName) {
    final baseName = p.basename(originalName);
    if (baseName.isEmpty) {
      return '${DateTime.now().millisecondsSinceEpoch}.png';
    }

    var candidate = baseName;
    var index = 1;
    while (File(p.join(assetsDir.path, candidate)).existsSync()) {
      final stem = p.basenameWithoutExtension(baseName);
      final ext = p.extension(baseName);
      candidate = '${stem}_$index$ext';
      index++;
    }
    return candidate;
  }

  String? _resolvePath(String memoDir, Uri uri) {
    late final String rawPath;

    if (uri.scheme == 'file') {
      rawPath = uri.toFilePath(windows: Platform.isWindows);
    } else if (uri.scheme.isEmpty) {
      rawPath = uri.path;
    } else {
      return null;
    }

    final normalized = p.normalize(
      rawPath.startsWith('.')
          ? p.join(memoDir, rawPath)
          : p.isAbsolute(rawPath)
              ? rawPath
              : p.join(memoDir, rawPath),
    );

    if (!p.isWithin(memoDir, normalized) && normalized != memoDir) {
      return null;
    }

    return normalized;
  }
}

final memoImageService = MemoImageService();
