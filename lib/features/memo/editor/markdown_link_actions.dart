import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mind_recall/models/memo.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

/// Markdown 链接解析与打开：网页 / 本地文档（相对路径或标题）。
abstract final class MarkdownLinkActions {
  /// 桌面端插入本地链接时使用 `./文件名.md`；移动端使用文档标题。
  static bool get preferRelativeFileHref {
    if (kIsWeb) {
      return false;
    }
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  /// 为「选择文档」生成写入 Markdown 的 href。
  static String hrefForMemo({
    required Memo memo,
    required bool useRelativeFileHref,
    required String untitledLabel,
  }) {
    if (useRelativeFileHref) {
      return './${p.basename(memo.filePath)}';
    }
    return memo.displayTitle(untitledLabel);
  }

  /// 根据 href 解析本地备忘录；匹配文件名、相对路径、id 或文档标题。
  static Memo? resolveLocalMemo({
    required String href,
    required List<Memo> memos,
    required String untitledLabel,
    String? currentMemoFilePath,
  }) {
    final trimmed = href.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri != null &&
        (uri.scheme == 'http' ||
            uri.scheme == 'https' ||
            uri.scheme == 'mailto')) {
      return null;
    }

    final baseName = p.basename(trimmed.replaceAll('\\', '/'));
    final stem = p.basenameWithoutExtension(baseName);

    for (final memo in memos) {
      final fileName = p.basename(memo.filePath);
      final fileStem = p.basenameWithoutExtension(fileName);
      if (fileName == baseName ||
          fileStem == stem ||
          fileStem == baseName ||
          memo.id == stem ||
          memo.id == trimmed) {
        return memo;
      }
    }

    if (currentMemoFilePath != null) {
      final resolved = p.normalize(
        p.join(p.dirname(currentMemoFilePath), trimmed.replaceAll('\\', '/')),
      );
      for (final memo in memos) {
        if (p.equals(memo.filePath, resolved) ||
            p.equals(p.normalize(memo.filePath), resolved)) {
          return memo;
        }
      }
      final asFile = File(resolved);
      if (asFile.existsSync()) {
        for (final memo in memos) {
          if (p.equals(p.normalize(memo.filePath), p.normalize(asFile.path))) {
            return memo;
          }
        }
      }
    }

    // 移动端以标题作为链接：精确匹配展示标题或已填标题字段。
    for (final memo in memos) {
      final title = memo.title.trim();
      if (title.isNotEmpty && title == trimmed) {
        return memo;
      }
      if (memo.displayTitle(untitledLabel) == trimmed) {
        return memo;
      }
    }

    return null;
  }

  static String? displayTitleForHref({
    required String href,
    required List<Memo> memos,
    required String untitledLabel,
    String? currentMemoFilePath,
  }) {
    final memo = resolveLocalMemo(
      href: href,
      memos: memos,
      untitledLabel: untitledLabel,
      currentMemoFilePath: currentMemoFilePath,
    );
    return memo?.displayTitle(untitledLabel);
  }

  static Future<void> openHref({
    required String href,
    required List<Memo> memos,
    required String untitledLabel,
    required Future<void> Function(String memoId) openMemo,
    String? currentMemoFilePath,
  }) async {
    final local = resolveLocalMemo(
      href: href,
      memos: memos,
      untitledLabel: untitledLabel,
      currentMemoFilePath: currentMemoFilePath,
    );
    if (local != null) {
      await openMemo(local.id);
      return;
    }

    var target = href.trim();
    if (!target.contains('://') &&
        !target.startsWith('mailto:') &&
        RegExp(r'^[\w.-]+\.[\w.-]+').hasMatch(target)) {
      target = 'https://$target';
    }
    final uri = Uri.tryParse(target);
    if (uri == null) {
      throw FormatException('invalid uri: $href');
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      throw StateError('launchUrl returned false');
    }
  }
}
