/// 侧栏 / 抽屉文件面板的纯逻辑（便于单测，无 Flutter 依赖）。

import 'package:mind_recall/models/memo_folder.dart';
import 'package:mind_recall/models/user_preferences.dart';
import 'package:mind_recall/services/memo_fs_constants.dart';
import 'package:mind_recall/services/memo_storage_service.dart';

/// 窄屏抽屉边缘拖动手势起始区占屏宽比例（左半屏即可呼出）。
const double kDrawerEdgeDragWidthFraction = 0.5;

/// 是否展示搜索结果列表。
///
/// query 已空时即使 [isSearchActive] 仍为 true（防抖未跑完），也必须回退到文件列表，
/// 否则会短暂或持续显示「无匹配结果」，看起来像文件列表被清空。
bool memoFilePanelShowsSearchResults({
  required bool isSearchActive,
  required String query,
}) {
  return isSearchActive && query.trim().isNotEmpty;
}

/// 非搜索态且不在 `documents/` 根时显示「返回上级」。
bool memoFilePanelShowsParentButton({
  required bool isSearchActive,
  required String query,
  required String currentRelativeDir,
}) {
  if (memoFilePanelShowsSearchResults(
    isSearchActive: isSearchActive,
    query: query,
  )) {
    return false;
  }
  return currentRelativeDir.isNotEmpty;
}

/// 仅当前层中的活动笔记高亮；文件夹不高亮。
bool memoListItemIsHighlighted({
  required bool isFolder,
  required String entryId,
  required String? activeMemoId,
}) {
  if (isFolder) {
    return false;
  }
  return activeMemoId != null && entryId == activeMemoId;
}

/// 当前层四段排序（置顶文件夹 / 置顶文件 / 文件夹 / 文件）。
List<MemoDirEntry> sortMemoDirEntries({
  required List<MemoDirEntry> entries,
  required List<String> pinnedFolderIds,
  required List<String> pinnedMemoIds,
  FileListSort fileListSort = FileListSort.modifiedTime,
  String untitledLabel = '',
}) {
  return MemoStorageService.sortDirEntries(
    entries: entries,
    pinnedFolderIds: pinnedFolderIds,
    pinnedMemoIds: pinnedMemoIds,
    fileListSort: fileListSort,
    untitledLabel: untitledLabel,
  );
}

/// 侧栏行第二行显示的时间：文件夹用目录 mtime，文件用 [Memo.updatedAt]。
DateTime memoDirEntryListTime(MemoDirEntry entry) {
  if (entry.isFolder) {
    return entry.folder!.updatedAt;
  }
  return entry.memo!.updatedAt;
}

/// 选目录树每一层：置顶文件夹靠前（后置顶靠前），其余按 [MemoFolderTreeNode.createdAt] 新→旧。
MemoFolderTreeNode sortMemoFolderTree(
  MemoFolderTreeNode root, {
  required List<String> pinnedFolderIds,
}) {
  List<MemoFolderTreeNode> sortChildren(List<MemoFolderTreeNode> nodes) {
    final pinned = <MemoFolderTreeNode>[];
    final rest = <MemoFolderTreeNode>[];
    for (final node in nodes) {
      final id = node.folderId;
      if (id != null && pinnedFolderIds.contains(id)) {
        pinned.add(node);
      } else {
        rest.add(node);
      }
    }
    pinned.sort(
      (a, b) => pinnedFolderIds
          .indexOf(a.folderId!)
          .compareTo(pinnedFolderIds.indexOf(b.folderId!)),
    );
    rest.sort((a, b) {
      final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final byTime = bTime.compareTo(aTime);
      if (byTime != 0) {
        return byTime;
      }
      return (b.folderId ?? '').compareTo(a.folderId ?? '');
    });
    return [
      for (final node in [...pinned, ...rest])
        node.copyWith(children: sortChildren(node.children)),
    ];
  }

  return root.copyWith(children: sortChildren(root.children));
}

/// 移动文件夹时从树中去掉自身及子孙；根节点始终保留。
MemoFolderTreeNode excludeFolderFromMoveTree(
  MemoFolderTreeNode root, {
  required String movingFolderRelativeDir,
}) {
  List<MemoFolderTreeNode> filter(List<MemoFolderTreeNode> nodes) {
    return [
      for (final node in nodes)
        if (!MemoFs.isSelfOrDescendantRelative(
          candidate: node.relativeDir,
          ancestor: movingFolderRelativeDir,
        ))
          node.copyWith(children: filter(node.children)),
    ];
  }

  return root.copyWith(children: filter(root.children));
}

/// 所选目标与源父目录不同时才允许确认。
bool moveDestinationConfirmEnabled({
  required String sourceParentRelativeDir,
  required String selectedRelativeDir,
}) {
  return sourceParentRelativeDir.replaceAll(r'\', '/') !=
      selectedRelativeDir.replaceAll(r'\', '/');
}

/// 窄屏抽屉边缘拖动手势起始区宽度。
///
/// [screenWidth] 的 [fraction]（默认半屏）；再加左侧安全区，避免刘海裁掉起始点。
double drawerEdgeDragWidthFor({
  required double screenWidth,
  required double leftSafePadding,
  double fraction = kDrawerEdgeDragWidthFraction,
}) {
  return screenWidth * fraction + leftSafePadding;
}

/// 窄屏是否允许边缘拖动手势打开抽屉。
///
/// 宽屏不启用。窄屏只认系统 IME [insetBottomLogical]：键盘可见时禁用，
/// 避免侧滑与键盘下落叠动画。不把「有焦点 / 有光标」当作禁止条件——
/// Android 常在收起键盘后仍保留 TextField 焦点与 caret。
bool drawerOpenDragGestureEnabled({
  required bool isWide,
  required double insetBottomLogical,
}) {
  if (isWide) {
    return false;
  }
  return insetBottomLogical <= 0.5;
}

/// 打开抽屉前是否需要先等 IME 收起。
bool drawerShouldWaitForIme({
  required bool editorFocused,
  required double insetBottomLogical,
}) {
  return editorFocused || insetBottomLogical > 0.5;
}

/// 宽屏侧栏展开揭示状态：先播宽度动画，结束后再挂载面板，避免窄宽溢出。
final class SidebarRevealState {
  SidebarRevealState({
    this.expanded = true,
    this.contentVisible = true,
  });

  bool expanded;
  bool contentVisible;

  bool get shouldBuildPanel => expanded && contentVisible;

  void collapse() {
    expanded = false;
    contentVisible = false;
  }

  void beginExpand() {
    expanded = true;
    contentVisible = false;
  }

  /// 宽度动画 [onEnd] 时调用；若已收起则忽略。
  void onExpandAnimationEnded() {
    if (expanded) {
      contentVisible = true;
    }
  }
}
