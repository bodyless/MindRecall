import 'package:flutter/material.dart';
import 'package:mind_recall/l10n/app_localizations.dart';

import 'package:mind_recall/core/markdown/markdown.dart';

class MemoMarkdownPreview extends StatelessWidget {
  const MemoMarkdownPreview({
    super.key,
    required this.content,
    this.memoFilePath,
    this.resolveLocalImage,
    this.onLinkTap,
    this.resolveLinkLabel,
    this.scrollController,
  });

  final String content;
  final String? memoFilePath;
  final MarkdownImageResolver? resolveLocalImage;
  final ValueChanged<String>? onLinkTap;
  final String? Function(String href)? resolveLinkLabel;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    if (content.trim().isEmpty) {
      return Center(
        child: Text(
          l10n.previewEmpty,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Scrollbar(
      controller: scrollController,
      child: MdBlocksPreview(
        markdown: content,
        memoFilePath: memoFilePath,
        resolveLocalImage: resolveLocalImage,
        onLinkTap: onLinkTap,
        resolveLinkLabel: resolveLinkLabel,
        scrollController: scrollController,
      ),
    );
  }
}
