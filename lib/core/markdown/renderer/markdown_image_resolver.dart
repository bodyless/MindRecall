import 'dart:io';

/// 解析 Markdown 图片 URI 为本地文件。
///
/// 由 feature 层注入，避免 core 依赖 [MemoImageService]。
typedef MarkdownImageResolver = File? Function({
  required String memoFilePath,
  required Uri uri,
});
