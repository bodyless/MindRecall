import 'package:flutter/material.dart';
import 'package:mind_recall/features/memo/sidebar/memo_file_panel_logic.dart';
import 'package:mind_recall/l10n/app_localizations.dart';
import 'package:mind_recall/models/memo_folder.dart';

/// 选择移动目标目录：根 + 文件夹树，确认后返回相对 `documents/` 路径。
class MoveToFolderDialog extends StatefulWidget {
  const MoveToFolderDialog({
    super.key,
    required this.tree,
    required this.sourceParentRelativeDir,
  });

  final MemoFolderTreeNode tree;
  final String sourceParentRelativeDir;

  @override
  State<MoveToFolderDialog> createState() => _MoveToFolderDialogState();
}

class _MoveToFolderDialogState extends State<MoveToFolderDialog> {
  static const _dialogSize = 360.0;
  static const _depthIndent = 20.0;
  static const _expandButtonSize = 36.0;

  late String _selectedRelativeDir;
  late Set<String> _expandedRelativeDirs;

  @override
  void initState() {
    super.initState();
    _selectedRelativeDir = widget.sourceParentRelativeDir;
    _expandedRelativeDirs = {''};
  }

  bool get _canConfirm => moveDestinationConfirmEnabled(
        sourceParentRelativeDir: widget.sourceParentRelativeDir,
        selectedRelativeDir: _selectedRelativeDir,
      );

  List<({MemoFolderTreeNode node, int depth})> _visibleRows() {
    final rows = <({MemoFolderTreeNode node, int depth})>[];
    void visit(MemoFolderTreeNode node, int depth) {
      rows.add((node: node, depth: depth));
      if (!_expandedRelativeDirs.contains(node.relativeDir)) {
        return;
      }
      for (final child in node.children) {
        visit(child, depth + 1);
      }
    }

    visit(widget.tree, 0);
    return rows;
  }

  void _toggleExpanded(String relativeDir) {
    setState(() {
      if (_expandedRelativeDirs.contains(relativeDir)) {
        _expandedRelativeDirs.remove(relativeDir);
      } else {
        _expandedRelativeDirs.add(relativeDir);
      }
    });
  }

  String _label(AppLocalizations l10n, MemoFolderTreeNode node) {
    if (node.isRoot) {
      return l10n.moveToRoot;
    }
    return node.displayName;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final rows = _visibleRows();

    return AlertDialog(
      title: Text(l10n.moveToTitle),
      content: SizedBox(
        width: _dialogSize,
        height: _dialogSize,
        child: ListView.builder(
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final row = rows[index];
            final node = row.node;
            final selected = node.relativeDir == _selectedRelativeDir;
            final hasChildren = node.children.isNotEmpty;
            final expanded = _expandedRelativeDirs.contains(node.relativeDir);

            return Material(
              color: selected
                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
                  : Colors.transparent,
              child: Padding(
                padding: EdgeInsets.only(
                  left: row.depth * _depthIndent,
                  right: 8,
                  top: 4,
                  bottom: 4,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: _expandButtonSize,
                      height: _expandButtonSize,
                      child: hasChildren
                          ? IconButton(
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              onPressed: () =>
                                  _toggleExpanded(node.relativeDir),
                              icon: Icon(
                                expanded
                                    ? Icons.expand_more
                                    : Icons.chevron_right,
                              ),
                            )
                          : null,
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedRelativeDir = node.relativeDir;
                          });
                        },
                        child: Row(
                          children: [
                            const Icon(Icons.folder_outlined, size: 22),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _label(l10n, node),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _canConfirm
              ? () => Navigator.of(context).pop(_selectedRelativeDir)
              : null,
          child: Text(l10n.confirm),
        ),
      ],
    );
  }
}
