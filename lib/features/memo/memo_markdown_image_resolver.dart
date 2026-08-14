import 'package:mind_recall/services/memo_image_service.dart';

import '../../../core/markdown/renderer/markdown_image_resolver.dart';

/// 将 [MemoImageService] 桥接为 core 层 [MarkdownImageResolver]。
MarkdownImageResolver memoMarkdownImageResolver(MemoImageService service) {
  return ({
    required String memoFilePath,
    required Uri uri,
  }) {
    return service.resolveLocalImage(
      memoFilePath: memoFilePath,
      uri: uri,
    );
  };
}

/// 使用应用单例 [memoImageService] 的默认 resolver。
MarkdownImageResolver get defaultMemoMarkdownImageResolver =>
    memoMarkdownImageResolver(memoImageService);
