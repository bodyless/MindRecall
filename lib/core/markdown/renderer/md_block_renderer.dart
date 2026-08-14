import 'package:flutter/material.dart';

import '../ast/md_block.dart';
import 'markdown_image_resolver.dart';
import 'md_block_chrome.dart';
import 'md_block_styles.dart';
import 'md_inline_renderer.dart';

/// 将单个 [MdBlock] 渲染为 WYSIWYG Widget（不显示块级 markdown 语法）。
///
/// 通过 [resolveLocalImage] 注入本地图片解析，不依赖业务层 Service。
/// 列表前缀 / 引用缩进 / 代码区内边距须走 [MdBlockChrome]，与 chromeless Overlay 对齐。
class MdBlockRenderer extends StatelessWidget {
  const MdBlockRenderer({
    super.key,
    required this.block,
    this.memoFilePath,
    this.resolveLocalImage,
    this.onLinkTap,
    this.resolveLinkLabel,
  });

  final MdBlock block;
  final String? memoFilePath;

  /// 在 [memoFilePath] 上下文下解析 `./assets/...` 类 URI。
  final MarkdownImageResolver? resolveLocalImage;
  final ValueChanged<String>? onLinkTap;
  final String? Function(String href)? resolveLinkLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (block.plainText.trim().isEmpty && block is! ImageBlock) {
      return _emptyBlockChrome(theme, block);
    }

    return switch (block) {
      HeadingBlock(:final level, :final text) => MdInlineText(
          markdown: text.isEmpty ? ' ' : text,
          style: MdBlockStyles.headingStyle(theme, level),
          onLinkTap: onLinkTap,
          resolveLinkLabel: resolveLinkLabel,
        ),
      BulletBlock(:final text) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MdBlockChrome.buildPrefix(
              block,
              theme.textTheme.bodyLarge,
              visible: true,
            ),
            Expanded(
              child: MdInlineText(
                markdown: text,
                style: theme.textTheme.bodyLarge,
                onLinkTap: onLinkTap,
                resolveLinkLabel: resolveLinkLabel,
              ),
            ),
          ],
        ),
      OrderedBlock(:final text) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MdBlockChrome.buildPrefix(
              block,
              theme.textTheme.bodyLarge,
              visible: true,
            ),
            Expanded(
              child: MdInlineText(
                markdown: text,
                style: theme.textTheme.bodyLarge,
                onLinkTap: onLinkTap,
                resolveLinkLabel: resolveLinkLabel,
              ),
            ),
          ],
        ),
      QuoteBlock(:final text) => DecoratedBox(
          decoration: MdBlockStyles.quoteDecoration(theme),
          child: Padding(
            padding: MdBlockChrome.quoteBodyPadding(),
            child: MdInlineText(
              markdown: text,
              style: MdBlockStyles.quoteTextStyle(theme),
              onLinkTap: onLinkTap,
              resolveLinkLabel: resolveLinkLabel,
            ),
          ),
        ),
      CodeBlock(:final code) => Container(
          width: double.infinity,
          padding: MdBlockChrome.codeBlockPadding(),
          decoration: MdBlockStyles.codeBlockDecoration(theme),
          child: Text(
            code,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
            ),
          ),
        ),
      ImageBlock(:final alt, :final src) => _ImageContent(
          alt: alt,
          src: src,
          memoFilePath: memoFilePath,
          resolveLocalImage: resolveLocalImage,
        ),
      ParagraphBlock(:final text) => MdInlineText(
          markdown: text,
          style: theme.textTheme.bodyLarge,
          onLinkTap: onLinkTap,
          resolveLinkLabel: resolveLinkLabel,
        ),
    };
  }

  Widget _emptyBlockChrome(ThemeData theme, MdBlock block) {
    // 空块用透明空格保留 RenderParagraph，供实时模式测量光标；不显示「…」。
    final bodyPlaceholder = MdBlockChrome.emptyBodyPlaceholderText(
      theme.textTheme.bodyLarge,
    );

    return switch (block) {
      HeadingBlock(:final level) => MdBlockChrome.emptyBodyPlaceholderText(
          MdBlockStyles.headingStyle(theme, level),
        ),
      BulletBlock() || OrderedBlock() => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MdBlockChrome.buildPrefix(
              block,
              theme.textTheme.bodyLarge,
              visible: true,
            ),
            Expanded(child: bodyPlaceholder),
          ],
        ),
      QuoteBlock() => DecoratedBox(
          decoration: MdBlockStyles.quoteDecoration(theme),
          child: Padding(
            padding: MdBlockChrome.quoteBodyPadding(),
            child: bodyPlaceholder,
          ),
        ),
      CodeBlock() => Padding(
          padding: MdBlockChrome.codeBlockPadding(),
          child: bodyPlaceholder,
        ),
      _ => bodyPlaceholder,
    };
  }
}

class _ImageContent extends StatelessWidget {
  const _ImageContent({
    required this.alt,
    required this.src,
    this.memoFilePath,
    this.resolveLocalImage,
  });

  final String alt;
  final String src;
  final String? memoFilePath;
  final MarkdownImageResolver? resolveLocalImage;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(src);
    if (uri == null) {
      return Text(alt.isEmpty ? src : alt);
    }

    if (uri.scheme == 'http' || uri.scheme == 'https') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Image.network(src, fit: BoxFit.contain),
      );
    }

    final memoPath = memoFilePath;
    final resolver = resolveLocalImage;
    if (memoPath == null || resolver == null) {
      return Text(alt.isEmpty ? src : alt);
    }

    final file = resolver(memoFilePath: memoPath, uri: uri);
    if (file == null) {
      return Text(alt.isEmpty ? src : alt);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Image.file(file, fit: BoxFit.contain),
    );
  }
}
