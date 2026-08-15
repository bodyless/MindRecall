import 'package:flutter/material.dart';
import 'package:mind_recall/l10n/app_localizations.dart';

import '../plain_text/markdown_editor_helper.dart';

class MarkdownToolbar extends StatelessWidget {
  const MarkdownToolbar({
    super.key,
    required this.controller,
    required this.focusNode,
    this.onInsertImage,
    this.onInsertLink,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback? onInsertImage;
  final VoidCallback? onInsertLink;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            _ToolbarButton(
              label: 'H1',
              tooltip: l10n.toolbarH1,
              onPressed: () => _apply(() {
                MarkdownEditorHelper.applyHeading(controller, 1);
              }),
            ),
            _ToolbarButton(
              label: 'H2',
              tooltip: l10n.toolbarH2,
              onPressed: () => _apply(() {
                MarkdownEditorHelper.applyHeading(controller, 2);
              }),
            ),
            _ToolbarButton(
              label: 'H3',
              tooltip: l10n.toolbarH3,
              onPressed: () => _apply(() {
                MarkdownEditorHelper.applyHeading(controller, 3);
              }),
            ),
            const _ToolbarDivider(),
            _ToolbarButton(
              icon: Icons.format_bold,
              tooltip: l10n.toolbarBold,
              onPressed: () => _apply(() {
                MarkdownEditorHelper.wrapSelection(
                  controller,
                  left: '**',
                  right: '**',
                );
              }),
            ),
            _ToolbarButton(
              icon: Icons.format_italic,
              tooltip: l10n.toolbarItalic,
              onPressed: () => _apply(() {
                MarkdownEditorHelper.wrapSelection(
                  controller,
                  left: '*',
                  right: '*',
                );
              }),
            ),
            _ToolbarButton(
              icon: Icons.code,
              tooltip: l10n.toolbarCode,
              onPressed: () => _apply(() {
                MarkdownEditorHelper.wrapSelection(
                  controller,
                  left: '`',
                  right: '`',
                );
              }),
            ),
            const _ToolbarDivider(),
            _ToolbarButton(
              icon: Icons.format_list_bulleted,
              tooltip: l10n.toolbarBulletList,
              onPressed: () => _apply(() {
                MarkdownEditorHelper.applyLinePrefix(
                  controller,
                  prefix: '- ',
                  replaceExisting: RegExp(
                    r'^(?:[-*+]\s+\[[ xX]\]\s*|[-*+]\s*)',
                  ),
                );
              }),
            ),
            _ToolbarButton(
              icon: Icons.format_list_numbered,
              tooltip: l10n.toolbarOrderedList,
              onPressed: () => _apply(() {
                MarkdownEditorHelper.applyOrderedList(controller);
              }),
            ),
            _ToolbarButton(
              icon: Icons.check_box_outline_blank,
              tooltip: l10n.toolbarTaskList,
              onPressed: () => _apply(() {
                MarkdownEditorHelper.applyTaskList(controller);
              }),
            ),
            _ToolbarButton(
              icon: Icons.format_quote,
              tooltip: l10n.toolbarQuote,
              onPressed: () => _apply(() {
                MarkdownEditorHelper.applyLinePrefix(
                  controller,
                  prefix: '> ',
                  replaceExisting: RegExp(r'^>\s*'),
                );
              }),
            ),
            if (onInsertImage != null || onInsertLink != null) ...[
              const _ToolbarDivider(),
              if (onInsertLink != null)
                _ToolbarButton(
                  icon: Icons.link,
                  tooltip: l10n.toolbarInsertLink,
                  onPressed: () => _apply(onInsertLink!),
                ),
              if (onInsertImage != null)
                _ToolbarButton(
                  icon: Icons.image_outlined,
                  tooltip: l10n.toolbarInsertImage,
                  onPressed: () => _apply(onInsertImage!),
                ),
            ],
          ],
        ),
      ),
    );
  }

  void _apply(VoidCallback action) {
    focusNode.requestFocus();
    action();
  }
}

/// 实时模式工具栏：切换块类型，不插入可见 Markdown 语法。
class LiveMarkdownToolbar extends StatelessWidget {
  const LiveMarkdownToolbar({
    super.key,
    required this.focusNode,
    required this.onHeading,
    required this.onBulletList,
    required this.onOrderedList,
    required this.onTaskList,
    required this.onQuote,
    required this.onParagraph,
    this.onPrepareToolbarAction,
    this.onPrepareInlineAction,
    this.onBold,
    this.onItalic,
    this.onInlineCode,
    this.onInsertImage,
    this.onInsertLink,
  });

  final FocusNode focusNode;
  final ValueChanged<int> onHeading;
  final VoidCallback onBulletList;
  final VoidCallback onOrderedList;
  final VoidCallback onTaskList;
  final VoidCallback onQuote;
  final VoidCallback onParagraph;
  final VoidCallback? onPrepareToolbarAction;
  final VoidCallback? onPrepareInlineAction;
  final VoidCallback? onBold;
  final VoidCallback? onItalic;
  final VoidCallback? onInlineCode;
  final VoidCallback? onInsertImage;
  final VoidCallback? onInsertLink;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      child: Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            _ToolbarButton(
              label: 'H1',
              tooltip: l10n.toolbarH1,
              onPrepare: onPrepareToolbarAction,
              onPressed: () => _apply(() => onHeading(1)),
            ),
            _ToolbarButton(
              label: 'H2',
              tooltip: l10n.toolbarH2,
              onPrepare: onPrepareToolbarAction,
              onPressed: () => _apply(() => onHeading(2)),
            ),
            _ToolbarButton(
              label: 'H3',
              tooltip: l10n.toolbarH3,
              onPrepare: onPrepareToolbarAction,
              onPressed: () => _apply(() => onHeading(3)),
            ),
            if (onBold != null || onItalic != null || onInlineCode != null) ...[
              const _ToolbarDivider(),
              if (onBold != null)
                _ToolbarButton(
                  icon: Icons.format_bold,
                  tooltip: l10n.toolbarBold,
                  onPrepare: () {
                    onPrepareToolbarAction?.call();
                    onPrepareInlineAction?.call();
                  },
                  onPressed: () => _apply(onBold!),
                ),
              if (onItalic != null)
                _ToolbarButton(
                  icon: Icons.format_italic,
                  tooltip: l10n.toolbarItalic,
                  onPrepare: () {
                    onPrepareToolbarAction?.call();
                    onPrepareInlineAction?.call();
                  },
                  onPressed: () => _apply(onItalic!),
                ),
              if (onInlineCode != null)
                _ToolbarButton(
                  icon: Icons.code,
                  tooltip: l10n.toolbarCode,
                  onPrepare: () {
                    onPrepareToolbarAction?.call();
                    onPrepareInlineAction?.call();
                  },
                  onPressed: () => _apply(onInlineCode!),
                ),
            ],
            const _ToolbarDivider(),
            _ToolbarButton(
              icon: Icons.format_list_bulleted,
              tooltip: l10n.toolbarBulletList,
              onPrepare: onPrepareToolbarAction,
              onPressed: () => _apply(onBulletList),
            ),
            _ToolbarButton(
              icon: Icons.format_list_numbered,
              tooltip: l10n.toolbarOrderedList,
              onPrepare: onPrepareToolbarAction,
              onPressed: () => _apply(onOrderedList),
            ),
            _ToolbarButton(
              icon: Icons.check_box_outline_blank,
              tooltip: l10n.toolbarTaskList,
              onPrepare: onPrepareToolbarAction,
              onPressed: () => _apply(onTaskList),
            ),
            _ToolbarButton(
              icon: Icons.format_quote,
              tooltip: l10n.toolbarQuote,
              onPrepare: onPrepareToolbarAction,
              onPressed: () => _apply(onQuote),
            ),
            _ToolbarButton(
              icon: Icons.notes,
              tooltip: l10n.toolbarParagraph,
              onPrepare: onPrepareToolbarAction,
              onPressed: () => _apply(onParagraph),
            ),
            if (onInsertImage != null || onInsertLink != null) ...[
              const _ToolbarDivider(),
              if (onInsertLink != null)
                _ToolbarButton(
                  icon: Icons.link,
                  tooltip: l10n.toolbarInsertLink,
                  onPrepare: onPrepareToolbarAction,
                  onPressed: () => _apply(onInsertLink!),
                ),
              if (onInsertImage != null)
                _ToolbarButton(
                  icon: Icons.image_outlined,
                  tooltip: l10n.toolbarInsertImage,
                  onPrepare: onPrepareToolbarAction,
                  onPressed: () => _apply(onInsertImage!),
                ),
            ],
          ],
        ),
      ),
      ),
    );
  }

  void _apply(VoidCallback action) {
    onPrepareToolbarAction?.call();
    action();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (focusNode.canRequestFocus && !focusNode.hasFocus) {
        focusNode.requestFocus();
      }
    });
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    this.label,
    this.icon,
    required this.tooltip,
    required this.onPressed,
    this.onPrepare,
  }) : assert(label != null || icon != null);

  final String? label;
  final IconData? icon;
  final String tooltip;
  final VoidCallback onPressed;
  final VoidCallback? onPrepare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => onPrepare?.call(),
        child: Tooltip(
          message: tooltip,
          child: InkWell(
            onTap: onPressed,
            focusColor: Colors.transparent,
            hoverColor: theme.colorScheme.onSurface.withValues(alpha: 0.08),
            splashColor: theme.colorScheme.onSurface.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              child: icon != null
                  ? Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant)
                  : Text(
                      label!,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6),
    );
  }
}
