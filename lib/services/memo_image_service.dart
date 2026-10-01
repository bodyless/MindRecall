import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../core/markdown/parser/md_syntax_patterns.dart';

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

  static const _httpPrefix = 'http://';
  static const _httpsPrefix = 'https://';

  /// 导入外部文档时改写单独成行的本地图片。
  ///
  /// 路径相对源文件所在目录解析，不走 [_resolvePath]（那个会拒绝笔记目录外的文件）。
  /// 同一绝对路径只拷一份。http/https 与拷贝失败的行保持原文。
  Future<String> rewriteImportedLocalImages({
    required String markdown,
    required String sourceFilePath,
    required String memoId,
    required String memoFilePath,
  }) async {
    final sourceDir = p.dirname(sourceFilePath);
    final copiedRelativeBySource = <String, String>{};
    final lines = markdown.split('\n');
    final rewritten = <String>[];
    for (final line in lines) {
      rewritten.add(
        await _rewriteImportedImageLine(
          line: line,
          sourceDir: sourceDir,
          memoId: memoId,
          memoFilePath: memoFilePath,
          copiedRelativeBySource: copiedRelativeBySource,
        ),
      );
    }
    if (copiedRelativeBySource.isEmpty) {
      await deleteAssets(memoId: memoId, memoFilePath: memoFilePath);
    }
    return rewritten.join('\n');
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

  Future<String> _rewriteImportedImageLine({
    required String line,
    required String sourceDir,
    required String memoId,
    required String memoFilePath,
    required Map<String, String> copiedRelativeBySource,
  }) async {
    final parsed = parseStandaloneImageLine(line);
    if (parsed == null || _isRemoteImageDestination(parsed.destination)) {
      return line;
    }
    final absolute = _absoluteImportImagePath(sourceDir, parsed.destination);
    if (absolute == null) {
      return line;
    }
    final normalized = p.normalize(absolute);
    final existing = copiedRelativeBySource[normalized];
    if (existing != null) {
      return formatStandaloneImageLine(
        alt: parsed.alt,
        destination: existing,
        title: parsed.title,
      );
    }
    final source = File(normalized);
    if (!await source.exists()) {
      return line;
    }
    try {
      final relative = await _copyFileIntoAssets(
        source: source,
        memoId: memoId,
        memoFilePath: memoFilePath,
      );
      copiedRelativeBySource[normalized] = relative;
      return formatStandaloneImageLine(
        alt: parsed.alt,
        destination: relative,
        title: parsed.title,
      );
    } catch (_) {
      return line;
    }
  }

  bool _isRemoteImageDestination(String destination) {
    final lower = destination.trim().toLowerCase();
    return lower.startsWith(_httpPrefix) || lower.startsWith(_httpsPrefix);
  }

  /// 相对路径相对源文件目录；绝对路径原样。不用展示用的目录内限制。
  String? _absoluteImportImagePath(String sourceDir, String destination) {
    final trimmed = destination.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (p.isAbsolute(trimmed)) {
      return trimmed;
    }
    return p.join(sourceDir, trimmed);
  }

  Future<String> _copyFileIntoAssets({
    required File source,
    required String memoId,
    required String memoFilePath,
  }) async {
    final assetsDir = await assetsDirectory(
      memoId: memoId,
      memoFilePath: memoFilePath,
    );
    final fileName = _uniqueFileName(assetsDir, p.basename(source.path));
    final dest = File(p.join(assetsDir.path, fileName));
    await source.copy(dest.path);
    return './${assetsDirName(memoId)}/$fileName'.replaceAll(r'\', '/');
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
