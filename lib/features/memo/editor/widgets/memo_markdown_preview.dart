import 'package:flutter/material.dart';
import 'package:mind_recall/l10n/app_localizations.dart';

import 'package:mind_recall/core/markdown/markdown.dart';

class MemoMarkdownPreview extends StatefulWidget {
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
  State<MemoMarkdownPreview> createState() => _MemoMarkdownPreviewState();
}

class _MemoMarkdownPreviewState extends State<MemoMarkdownPreview> {
  /// 桌面不继承 [PrimaryScrollController]，预览滚动条须自持控制器。
  static const _desktopPreviewScrollPlatforms = <TargetPlatform>{
    TargetPlatform.windows,
    TargetPlatform.linux,
    TargetPlatform.macOS,
  };

  /// 仅桌面使用；移动端不传给滚动条，以免脱离 [PrimaryScrollController]。
  final ScrollController _desktopScrollController = ScrollController();

  @override
  void dispose() {
    _desktopScrollController.dispose();
    super.dispose();
  }

  bool _useDesktopScrollController(BuildContext context) {
    final platform = ScrollConfiguration.of(context).getPlatform(context);
    return _desktopPreviewScrollPlatforms.contains(platform);
  }

  Widget _previewList({ScrollController? scrollController}) {
    return MdBlocksPreview(
      markdown: widget.content,
      memoFilePath: widget.memoFilePath,
      resolveLocalImage: widget.resolveLocalImage,
      onLinkTap: widget.onLinkTap,
      resolveLinkLabel: widget.resolveLinkLabel,
      scrollController: scrollController,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    if (widget.content.trim().isEmpty) {
      return Center(
        child: Text(
          l10n.previewEmpty,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    if (!_useDesktopScrollController(context)) {
      return Scrollbar(
        controller: widget.scrollController,
        child: _previewList(scrollController: widget.scrollController),
      );
    }

    final controller = widget.scrollController ?? _desktopScrollController;
    return Scrollbar(
      controller: controller,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: _previewList(scrollController: controller),
      ),
    );
  }
}
