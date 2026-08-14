import 'package:flutter/material.dart';
import 'package:mind_recall/l10n/app_localizations.dart';

import 'package:mind_recall/features/memo/sidebar/memo_file_panel_logic.dart';
import 'package:mind_recall/models/memo.dart';
import 'package:mind_recall/models/memo_search_result.dart';
import 'package:mind_recall/shared/widgets/highlighted_text.dart';

class MemoFilePanel extends StatelessWidget {
  const MemoFilePanel({
    super.key,
    required this.memos,
    required this.activeMemoId,
    required this.onMemoSelected,
    required this.onCreateMemo,
    required this.onRenameMemo,
    required this.onDeleteMemo,
    required this.searchController,
    required this.caseSensitive,
    required this.onCaseSensitiveChanged,
    required this.isSearchActive,
    required this.searchResults,
    required this.onSearchResultSelected,
    this.pinnedMemoIds = const [],
    this.onTogglePinMemo,
    this.showRevealInExplorer = false,
    this.onRevealInExplorer,
    this.isSaving = false,
    this.onCollapseSidebar,
    this.onOpenSettings,
    this.onBeforeSystemOverlay,
    this.onAfterSystemOverlay,
  });

  final List<Memo> memos;
  final String? activeMemoId;
  final ValueChanged<String> onMemoSelected;
  final VoidCallback onCreateMemo;
  final ValueChanged<String> onRenameMemo;
  final ValueChanged<String> onDeleteMemo;
  final TextEditingController searchController;
  final bool caseSensitive;
  final ValueChanged<bool> onCaseSensitiveChanged;
  final bool isSearchActive;
  final List<MemoSearchResult> searchResults;
  final ValueChanged<MemoSearchResult> onSearchResultSelected;
  final List<String> pinnedMemoIds;
  final ValueChanged<String>? onTogglePinMemo;
  final bool showRevealInExplorer;
  final ValueChanged<String>? onRevealInExplorer;
  final bool isSaving;
  final VoidCallback? onCollapseSidebar;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onBeforeSystemOverlay;
  final VoidCallback? onAfterSystemOverlay;

  static const _tilePadding = EdgeInsets.symmetric(horizontal: 12, vertical: 4);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.memos,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.newMemo,
                onPressed: isSaving ? null : onCreateMemo,
                icon: const Icon(Icons.add),
              ),
              if (onCollapseSidebar != null)
                IconButton(
                  tooltip: l10n.collapseSidebar,
                  onPressed: onCollapseSidebar,
                  icon: const Icon(Icons.chevron_left),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: l10n.searchHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: l10n.clear,
                      onPressed: searchController.clear,
                      icon: const Icon(Icons.clear),
                    ),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            textInputAction: TextInputAction.search,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => onCaseSensitiveChanged(!caseSensitive),
              icon: Icon(
                caseSensitive ? Icons.check_box : Icons.check_box_outline_blank,
                size: 18,
              ),
              label: Text(
                caseSensitive ? l10n.caseSensitive : l10n.caseInsensitive,
              ),
              style: TextButton.styleFrom(
                foregroundColor: caseSensitive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ),
        if (memoFilePanelShowsSearchResults(
          isSearchActive: isSearchActive,
          query: searchController.text,
        ))
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              l10n.searchResultCount(searchResults.length),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        Expanded(
          child: memoFilePanelShowsSearchResults(
                isSearchActive: isSearchActive,
                query: searchController.text,
              )
              ? _buildSearchResults(context, l10n)
              : _buildMemoList(context, l10n),
        ),
        if (onOpenSettings != null)
          SafeArea(
            top: false,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: IconButton(
                  tooltip: l10n.settings,
                  onPressed: onOpenSettings,
                  icon: const Icon(Icons.settings_outlined),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchResults(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final keywords = HighlightedText.splitKeywords(searchController.text);

    if (searchResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.noSearchResults,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    // 勿占用 Scaffold PrimaryScrollController：抽屉反复开关时残留 offset
    // 会让列表滚到空白区，看起来像「文件没了」。
    return ListView.builder(
      primary: false,
      itemCount: searchResults.length,
      itemBuilder: (context, index) {
        final result = searchResults[index];
        final isActive = result.memoId == activeMemoId;

        return _MemoListItem(
          key: ValueKey('search-${result.memoId}'),
          selected: isActive,
          pinned: pinnedMemoIds.contains(result.memoId),
          icon: Icons.manage_search,
          title: HighlightedText(
            text: result.title,
            keywords: keywords,
            caseSensitive: caseSensitive,
            style: theme.textTheme.bodyLarge,
            maxLines: 2,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HighlightedText(
                text: result.snippet,
                keywords: keywords,
                caseSensitive: caseSensitive,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 2),
              Text(
                l10n.matchCount(result.matchCount),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          onTap: () => onSearchResultSelected(result),
        );
      },
    );
  }

  Widget _buildMemoList(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);

    if (memos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.emptyMemoList,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      primary: false,
      itemCount: memos.length,
      itemBuilder: (context, index) {
        final memo = memos[index];
        final isActive = memo.id == activeMemoId;

        return Builder(
          builder: (itemContext) => _MemoListItem(
            key: ValueKey(memo.id),
            selected: isActive,
            pinned: pinnedMemoIds.contains(memo.id),
            icon: isActive ? Icons.description : Icons.description_outlined,
            title: Text(
              memo.displayTitle(l10n.untitled),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(_formatUpdatedAt(memo.updatedAt, l10n)),
            onTap: () => onMemoSelected(memo.id),
            onLongPress: () =>
                _showMemoActionMenu(itemContext, l10n, theme, memo.id),
            trailing: PopupMenuButton<_MemoFileAction>(
              tooltip: l10n.moreActions,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onOpened: onBeforeSystemOverlay,
              onCanceled: onAfterSystemOverlay,
              onSelected: (action) {
                onAfterSystemOverlay?.call();
                _handleMemoFileAction(action, memo.id);
              },
              itemBuilder: (context) => _memoFileMenuItems(l10n, theme, memo.id),
            ),
          ),
        );
      },
    );
  }

  void _handleMemoFileAction(_MemoFileAction action, String memoId) {
    switch (action) {
      case _MemoFileAction.revealInExplorer:
        onRevealInExplorer?.call(memoId);
      case _MemoFileAction.pin:
        onTogglePinMemo?.call(memoId);
      case _MemoFileAction.rename:
        onRenameMemo(memoId);
      case _MemoFileAction.delete:
        onDeleteMemo(memoId);
    }
  }

  List<PopupMenuEntry<_MemoFileAction>> _memoFileMenuItems(
    AppLocalizations l10n,
    ThemeData theme,
    String memoId,
  ) {
    final pinned = pinnedMemoIds.contains(memoId);
    return [
      if (onTogglePinMemo != null)
        PopupMenuItem(
          value: _MemoFileAction.pin,
          child: Row(
            children: [
              Icon(pinned ? Icons.push_pin : Icons.push_pin_outlined),
              const SizedBox(width: 12),
              Text(pinned ? l10n.unpinMemo : l10n.pinMemo),
            ],
          ),
        ),
      if (showRevealInExplorer)
        PopupMenuItem(
          value: _MemoFileAction.revealInExplorer,
          child: Row(
            children: [
              const Icon(Icons.folder_open_outlined),
              const SizedBox(width: 12),
              Text(l10n.revealInExplorer),
            ],
          ),
        ),
      PopupMenuItem(
        value: _MemoFileAction.rename,
        child: Row(
          children: [
            const Icon(Icons.drive_file_rename_outline),
            const SizedBox(width: 12),
            Text(l10n.rename),
          ],
        ),
      ),
      PopupMenuItem(
        value: _MemoFileAction.delete,
        child: Row(
          children: [
            Icon(
              Icons.delete_outline,
              color: theme.colorScheme.error,
            ),
            const SizedBox(width: 12),
            Text(
              l10n.delete,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
        ),
      ),
    ];
  }

  Future<void> _showMemoActionMenu(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    String memoId,
  ) async {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return;
    }
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final topLeft = box.localToGlobal(Offset.zero);
    final rect = RelativeRect.fromRect(
      topLeft & box.size,
      Offset.zero & overlay.size,
    );
    onBeforeSystemOverlay?.call();
    final action = await showMenu<_MemoFileAction>(
      context: context,
      position: rect,
      items: _memoFileMenuItems(l10n, theme, memoId),
    );
    onAfterSystemOverlay?.call();
    if (action != null) {
      _handleMemoFileAction(action, memoId);
    }
  }

  String _formatUpdatedAt(DateTime time, AppLocalizations l10n) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final memoDay = DateTime(time.year, time.month, time.day);

    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final timeLabel = '$hour:$minute';

    if (memoDay == today) {
      return l10n.todayAt(timeLabel);
    }
    if (memoDay == today.subtract(const Duration(days: 1))) {
      return l10n.yesterdayAt(timeLabel);
    }

    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    return l10n.dateAt('$month-$day', timeLabel);
  }
}

class _MemoListItem extends StatelessWidget {
  const _MemoListItem({
    super.key,
    required this.selected,
    required this.pinned,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.onLongPress,
    this.trailing,
  });

  final bool selected;
  final bool pinned;
  final IconData icon;
  final Widget title;
  final Widget subtitle;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: selected
          ? colorScheme.primaryContainer.withValues(alpha: 0.35)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(
          children: [
            Padding(
              padding: MemoFilePanel._tilePadding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 24,
                    child: Icon(
                      icon,
                      size: 22,
                      color: selected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DefaultTextStyle.merge(
                          style: theme.textTheme.bodyLarge,
                          child: title,
                        ),
                        const SizedBox(height: 2),
                        DefaultTextStyle.merge(
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          child: subtitle,
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
            if (pinned)
              Positioned(
                top: 0,
                left: 0,
                child: CustomPaint(
                  size: const Size(18, 18),
                  painter: _PinCornerBadgePainter(
                    color: colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 置顶条目左上角三角角标（使用主题 primary，浅色为青绿）。
class _PinCornerBadgePainter extends CustomPainter {
  const _PinCornerBadgePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PinCornerBadgePainter oldDelegate) =>
      oldDelegate.color != color;
}

enum _MemoFileAction { revealInExplorer, pin, rename, delete }
