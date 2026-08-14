import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ast/md_block.dart';
import '../ast/md_inline.dart';
import '../parser/markdown_block_parser.dart';
import '../renderer/markdown_image_resolver.dart';
import '../renderer/md_block_chrome.dart';
import '../renderer/md_block_renderer.dart';
import '../renderer/md_block_styles.dart';

/// 解析后的 Markdown 块列表预览（可滚动、可选中复制）。
///
/// 可选中时选区几何对齐**渲染层**（`•` / 标题样式）；复制内容转为**数据层**
/// Markdown（`- ` / `# `），便于粘贴回实时/编辑模式。
class MdBlocksPreview extends StatelessWidget {
  const MdBlocksPreview({
    super.key,
    required this.markdown,
    this.memoFilePath,
    this.resolveLocalImage,
    this.onLinkTap,
    this.resolveLinkLabel,
    this.scrollController,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 24),
    this.selectable = true,
  });

  final String markdown;
  final String? memoFilePath;
  final MarkdownImageResolver? resolveLocalImage;
  final ValueChanged<String>? onLinkTap;
  final String? Function(String href)? resolveLinkLabel;
  final ScrollController? scrollController;
  final EdgeInsets padding;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final blocks = parseMarkdownBlocks(markdown);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    if (blocks.length == 1 &&
        blocks.first is ParagraphBlock &&
        (blocks.first as ParagraphBlock).text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final list = ListView.builder(
      controller: scrollController,
      padding: padding.copyWith(bottom: padding.bottom + bottomInset),
      cacheExtent: 1200,
      itemCount: blocks.length,
      itemBuilder: (context, index) {
        final block = blocks[index];
        final visual = MdBlockRenderer(
          block: block,
          memoFilePath: memoFilePath,
          resolveLocalImage: resolveLocalImage,
          onLinkTap: onLinkTap,
          resolveLinkLabel: resolveLinkLabel,
        );
        return Padding(
          padding: EdgeInsets.only(bottom: MdBlockStyles.bottomSpacingFor(block)),
          child: selectable
              ? _MdBlockDataSelectable(block: block, visual: visual)
              : visual,
        );
      },
    );

    if (!selectable) {
      return list;
    }
    return _PreviewSelectionHost(markdown: markdown, child: list);
  }
}

/// 拦截复制：把选区中的渲染字形（如 `•`）转成 Markdown 数据。
class _PreviewSelectionHost extends StatefulWidget {
  const _PreviewSelectionHost({
    required this.markdown,
    required this.child,
  });

  final String markdown;
  final Widget child;

  @override
  State<_PreviewSelectionHost> createState() => _PreviewSelectionHostState();
}

class _PreviewSelectionHostState extends State<_PreviewSelectionHost> {
  String? _selectedPlain;

  void _copyMarkdown() {
    final selected = _selectedPlain;
    final text = (selected == null || selected.isEmpty)
        ? widget.markdown
        : visualSelectionToMarkdown(selected);
    Clipboard.setData(ClipboardData(text: text));
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyC, control: true):
            CopySelectionTextIntent.copy,
        SingleActivator(LogicalKeyboardKey.keyC, meta: true):
            CopySelectionTextIntent.copy,
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          CopySelectionTextIntent: CallbackAction<CopySelectionTextIntent>(
            onInvoke: (intent) {
              _copyMarkdown();
              return null;
            },
          ),
        },
        child: SelectionArea(
          onSelectionChanged: (selected) {
            _selectedPlain = selected?.plainText;
          },
          contextMenuBuilder: (context, selectableRegionState) {
            final items =
                selectableRegionState.contextMenuButtonItems.map((item) {
              if (item.type == ContextMenuButtonType.copy) {
                return ContextMenuButtonItem(
                  type: ContextMenuButtonType.copy,
                  onPressed: () {
                    _copyMarkdown();
                    selectableRegionState.hideToolbar();
                  },
                );
              }
              return item;
            }).toList();
            return AdaptiveTextSelectionToolbar.buttonItems(
              anchors: selectableRegionState.contextMenuAnchors,
              buttonItems: items,
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}

/// 预览块：选区几何与渲染层一致；复制时再转 Markdown。
class _MdBlockDataSelectable extends StatelessWidget {
  const _MdBlockDataSelectable({
    required this.block,
    required this.visual,
  });

  final MdBlock block;
  final Widget visual;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mirror = _selectionMirrorForBlock(theme, block);

    return Stack(
      alignment: Alignment.topLeft,
      clipBehavior: Clip.none,
      children: [
        SelectionContainer.disabled(child: visual),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: IgnorePointer(child: mirror),
        ),
      ],
    );
  }
}

/// 与 [MdBlockRenderer] 同结构的透明文本，供 SelectionArea 测量选区。
Widget _selectionMirrorForBlock(ThemeData theme, MdBlock block) {
  TextStyle transparent(TextStyle? style) {
    final base = style ?? theme.textTheme.bodyLarge ?? const TextStyle();
    return base.copyWith(
      color: Colors.transparent,
      decoration: TextDecoration.none,
      decorationColor: Colors.transparent,
      shadows: const [],
    );
  }

  String plainOf(String markdown) =>
      plainTextFromInlines(parseInlineMarkdown(markdown));

  return switch (block) {
    HeadingBlock(:final level, :final text) => Text(
        plainOf(text),
        style: transparent(MdBlockStyles.headingStyle(theme, level)),
        strutStyle: MdBlockStyles.strutFor(
          MdBlockStyles.headingStyle(theme, level),
        ),
      ),
    BulletBlock(:final text) || OrderedBlock(:final text) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MdBlockChrome.buildPrefix(
            block,
            transparent(theme.textTheme.bodyLarge),
            visible: true,
          ),
          Expanded(
            child: Text(
              plainOf(text),
              style: transparent(theme.textTheme.bodyLarge),
              strutStyle: MdBlockStyles.strutFor(theme.textTheme.bodyLarge),
            ),
          ),
        ],
      ),
    QuoteBlock(:final text) => Padding(
        padding: MdBlockChrome.quoteBodyPadding(),
        child: Text(
          plainOf(text),
          style: transparent(MdBlockStyles.quoteTextStyle(theme)),
          strutStyle: MdBlockStyles.strutFor(MdBlockStyles.quoteTextStyle(theme)),
        ),
      ),
    CodeBlock(:final code) => Padding(
        padding: MdBlockChrome.codeBlockPadding(),
        child: Text(
          code,
          style: transparent(
            theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
          ),
        ),
      ),
    ImageBlock(:final alt, :final src) => Text(
        alt.isEmpty ? src : alt,
        style: transparent(theme.textTheme.bodyLarge),
      ),
    ParagraphBlock(:final text) => Text(
        plainOf(text),
        style: transparent(theme.textTheme.bodyLarge),
        strutStyle: MdBlockStyles.strutFor(theme.textTheme.bodyLarge),
      ),
  };
}

/// 将预览选区中的渲染纯文本转为 Markdown（`•  ` → `- `）。
@visibleForTesting
String visualSelectionToMarkdown(String selected) {
  const bullet = MdBlockChrome.bulletPrefix;
  return selected.split('\n').map((line) {
    if (line.startsWith(bullet)) {
      return '- ${line.substring(bullet.length)}';
    }
    if (line.startsWith('• ')) {
      return '- ${line.substring(2)}';
    }
    if (line.startsWith('•')) {
      return '- ${line.substring(1).trimLeft()}';
    }
    return line;
  }).join('\n');
}
