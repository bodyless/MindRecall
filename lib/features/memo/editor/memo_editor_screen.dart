import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:mind_recall/app_layout_constants.dart';
import 'package:mind_recall/core/debug/cursor_debug_hud.dart';
import 'package:mind_recall/core/debug/debug_timeline.dart';
import 'package:mind_recall/core/debug/ime_debug_hud.dart';
import 'package:mind_recall/core/debug/ime_timeline.dart';
import 'package:mind_recall/l10n/app_localizations.dart';

import 'package:mind_recall/features/memo/editor/markdown_link_actions.dart';
import 'package:mind_recall/features/memo/editor/document_history.dart';
import 'package:mind_recall/features/memo/editor/live/live_markdown_editor.dart';
import 'package:mind_recall/features/memo/editor/mode_input_session.dart';
import 'package:mind_recall/features/memo/editor/plain_text/markdown_editor_helper.dart';
import 'package:mind_recall/features/memo/editor/widgets/markdown_toolbar.dart';
import 'package:mind_recall/features/memo/editor/widgets/memo_markdown_preview.dart';
import 'package:mind_recall/features/memo/sidebar/memo_file_panel_logic.dart';
import 'package:mind_recall/features/memo/memo_markdown_image_resolver.dart';
import 'package:mind_recall/features/memo/sidebar/memo_file_panel.dart';
import 'package:mind_recall/models/memo.dart';
import 'package:mind_recall/models/memo_search_result.dart';
import 'package:mind_recall/models/user_preferences.dart';
import 'package:mind_recall/services/data_backup_service.dart';
import 'package:mind_recall/services/memo_image_service.dart';
import 'package:mind_recall/services/memo_search_service.dart';
import 'package:mind_recall/services/memo_storage_service.dart';
import 'package:mind_recall/services/memo_trash_service.dart';
import 'package:mind_recall/services/session_cache_service.dart';
import 'package:mind_recall/services/user_preferences_service.dart';
import 'package:mind_recall/shared/widgets/settings_panel.dart';
import 'package:package_info_plus/package_info_plus.dart';

enum SaveStatus { idle, saving, saved, error }

enum EditorViewMode { edit, live, preview }

class MemoEditorScreen extends StatefulWidget {
  const MemoEditorScreen({
    super.key,
    required this.themeMode,
    required this.localeCode,
    required this.onThemeChanged,
    required this.onLocaleChanged,
    required this.onFontSizeChanged,
    required this.prefsService,
    this.onDebugToolsChanged,
    this.onDebugShowFpsChanged,
    this.onDebugShowImeHudChanged,
    this.onDebugShowCursorHudChanged,
  });

  final ThemeMode themeMode;
  final String localeCode;
  final ValueChanged<ThemeMode> onThemeChanged;
  final ValueChanged<Locale> onLocaleChanged;
  final ValueChanged<AppFontSize> onFontSizeChanged;
  final ValueChanged<bool>? onDebugToolsChanged;
  final ValueChanged<bool>? onDebugShowFpsChanged;
  final ValueChanged<bool>? onDebugShowImeHudChanged;
  final ValueChanged<bool>? onDebugShowCursorHudChanged;
  final UserPreferencesService prefsService;

  @override
  State<MemoEditorScreen> createState() => _MemoEditorScreenState();
}

class _MemoEditorScreenState extends State<MemoEditorScreen> {
  static const _autoSaveDelay = Duration(milliseconds: 800);
  static const _searchDelay = Duration(milliseconds: 300);
  static const _sidebarWidth = 280.0;
  static const _contentLineHeight = 24.0;
  static const _liveFocusBlurGrace = Duration(milliseconds: 400);
  static const _liveFocusRestoreWait = Duration(milliseconds: 150);
  static const _historyDebounce = Duration(milliseconds: 400);
  static const _sidebarCollapseDuration = Duration(milliseconds: 250);
  static const _sidebarExpandDuration = Duration(milliseconds: 220);
  static const _drawerImePollInterval = Duration(milliseconds: 32);

  final _storage = MemoStorageService();
  final _sessionCache = SessionCacheService();
  final _searchService = MemoSearchService();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _searchController = TextEditingController();
  final _titleFocusNode = FocusNode();
  final _editSession = EditInputSession();
  final _liveSession = LiveInputSession();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _liveEditorKey = GlobalKey<LiveMarkdownEditorState>();
  final _contentFieldKey = GlobalKey();

  List<Memo> _memos = [];
  List<MemoSearchResult> _searchResults = [];
  List<String> _pinnedMemoIds = [];
  String? _activeMemoId;
  String? _appVersionLabel;
  String _savedTitle = '';
  String _savedContent = '';
  SaveStatus _saveStatus = SaveStatus.saved;
  String? _saveError;
  bool _suppressAutoSave = false;
  bool _isInitializing = true;
  bool _isSearchActive = false;
  bool _caseSensitive = false;
  final _sidebarReveal = SidebarRevealState();
  EditorViewMode _viewMode = EditorViewMode.live;
  Timer? _autoSaveTimer;
  Timer? _searchDebounceTimer;
  Timer? _historyTimer;
  /// 编辑模式 IME 滚入：每帧最多调度一次，避免 metrics 连发打爆 ensureVisible。
  bool _editImeScrollScheduled = false;
  /// 键盘 metrics 收稳后做最终留白对齐 + 一次滚入。
  Timer? _editImeSettleTimer;
  /// 打开时工具栏静止后一次性显栏（与正文 settle 解耦）。
  Timer? _editToolbarRevealTimer;
  int? _editImeBurstStartMs;
  int _editImeSettleResetCount = 0;
  double _editImeSettleArmedPending = 0;
  double _editToolbarRevealArmedPending = 0;
  /// 窄屏正文 settled 键盘高度（Live spacer / 与滚入同步；先于此提交）。
  final ValueNotifier<double> _settledImeKeyboardInset = ValueNotifier<double>(0);
  /// 窄屏工具栏贴齐高度；打开时静止后一次性写入，同一次打开不改高度。
  final ValueNotifier<double> _toolbarImeKeyboardInset = ValueNotifier<double>(0);
  final _documentHistory = DocumentHistory();
  bool _applyingHistory = false;

  late final _EditKeyboardMetricsObserver _editKeyboardMetricsObserver =
      _EditKeyboardMetricsObserver(_onEditKeyboardMetricsChanged);

  /// 侧滑开抽屉门禁：仅在系统 IME inset 越过阈值导致「可否侧滑」翻转时 setState。
  late final _EditKeyboardMetricsObserver _drawerImeGateObserver =
      _EditKeyboardMetricsObserver(_syncDrawerOpenDragGestureGate);

  /// 上次采样的系统 IME inset（逻辑像素），用于检测侧滑门禁翻转。
  double _drawerGateInsetLogical = 0;

  /// 当前正文模式对应的 Focus（预览无正文焦点，回落编辑 session）。
  FocusNode get _activeBodyFocus => _viewMode == EditorViewMode.live
      ? _liveSession.focusNode
      : _editSession.focusNode;

  /// 当前正文模式对应的 ScrollController。
  ScrollController get _activeBodyScroll => _viewMode == EditorViewMode.live
      ? _liveSession.scrollController
      : _editSession.scrollController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_editKeyboardMetricsObserver);
    WidgetsBinding.instance.addObserver(_drawerImeGateObserver);
    _titleController.addListener(_onEditorChanged);
    _contentController.addListener(_onContentControllerChanged);
    _editSession.focusNode.addListener(_onEditFocusChanged);
    _liveSession.focusNode.addListener(_onLiveFocusChanged);
    _searchController.addListener(_onSearchChanged);
    unawaited(_initializeWorkspace());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncDrawerOpenDragGestureGate();
    });
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _searchDebounceTimer?.cancel();
    _historyTimer?.cancel();
    _editImeSettleTimer?.cancel();
    _editToolbarRevealTimer?.cancel();
    WidgetsBinding.instance.removeObserver(_editKeyboardMetricsObserver);
    WidgetsBinding.instance.removeObserver(_drawerImeGateObserver);
    _titleController.dispose();
    _contentController.dispose();
    _searchController.dispose();
    _titleFocusNode.dispose();
    _editSession.dispose();
    _liveSession.dispose();
    _settledImeKeyboardInset.dispose();
    _toolbarImeKeyboardInset.dispose();
    super.dispose();
  }

  void _setSettledImeKeyboardInset(double logical) {
    if (_settledImeKeyboardInset.value == logical) {
      return;
    }
    _settledImeKeyboardInset.value = logical;
  }

  void _setToolbarImeKeyboardInset(double logical) {
    if (_toolbarImeKeyboardInset.value == logical) {
      return;
    }
    _toolbarImeKeyboardInset.value = logical;
  }

  void _cancelEditToolbarRevealTimer() {
    _editToolbarRevealTimer?.cancel();
    _editToolbarRevealTimer = null;
  }

  /// 打开：pending 真正静止后一次性显栏；已显示则不再改高度。
  void _armEditToolbarRevealTimer() {
    if (!shouldRevealImeToolbarOnce(
      pendingLogical: _editSession.pendingKeyboardInset,
      toolbarLogical: _toolbarImeKeyboardInset.value,
    )) {
      _cancelEditToolbarRevealTimer();
      return;
    }
    _editToolbarRevealTimer?.cancel();
    _editToolbarRevealArmedPending = _editSession.pendingKeyboardInset;
    _editToolbarRevealTimer = Timer(kImeToolbarOpenSettleDelay, () {
      if (!mounted ||
          _viewMode != EditorViewMode.edit ||
          !_editSession.focusNode.hasFocus ||
          _editorFocusSuspended ||
          _drawerOpen) {
        return;
      }
      final next = _editSession.pendingKeyboardInset;
      if (!shouldRevealImeToolbarOnce(
        pendingLogical: next,
        toolbarLogical: _toolbarImeKeyboardInset.value,
      )) {
        return;
      }
      _setToolbarImeKeyboardInset(next);
      imeTimelineCommit(
        ImeTimelineScope.toolbar,
        pendingLogical: next,
        committedLogical: next,
        reason: 'revealOnce',
      );
      _publishEditImeDebugHud(
        burstMs:
            DateTime.now().millisecondsSinceEpoch - (_editImeBurstStartMs ?? 0),
        focused: true,
        lastCommitReason: 'toolbarReveal',
      );
    });
  }

  void _maybeArmEditToolbarRevealDuringOpen() {
    if (!shouldRevealImeToolbarOnce(
      pendingLogical: _editSession.pendingKeyboardInset,
      toolbarLogical: _toolbarImeKeyboardInset.value,
    )) {
      _cancelEditToolbarRevealTimer();
      return;
    }
    final hadActive = _editToolbarRevealTimer?.isActive ?? false;
    final restart = !hadActive ||
        shouldRestartImeToolbarOpenSettle(
          pendingLogical: _editSession.pendingKeyboardInset,
          armedPendingLogical: _editToolbarRevealArmedPending,
        );
    if (restart) {
      _armEditToolbarRevealTimer();
    }
  }

  /// 收起/切模式：正文留白与工具栏同拍清零。
  void _clearImeInsets() {
    _cancelEditToolbarRevealTimer();
    _setSettledImeKeyboardInset(0);
    _setToolbarImeKeyboardInset(0);
  }

  /// 屏上 IME HUD（仅 debug）；[lastCommitReason] 为 null 时保留上次 reason。
  void _publishEditImeDebugHud({
    required int burstMs,
    required bool focused,
    String? lastCommitReason,
  }) {
    publishImeDebugHud(
      scope: ImeTimelineScope.edit,
      pendingLogical: _editSession.pendingKeyboardInset,
      committedLogical: _editSession.keyboardBottomInset,
      toolbarLogical: _toolbarImeKeyboardInset.value,
      burstMs: burstMs,
      settleResetCount: _editImeSettleResetCount,
      settleActive: (_editImeSettleTimer?.isActive ?? false) ||
          (_editToolbarRevealTimer?.isActive ?? false),
      focused: focused,
      lastCommitReason: lastCommitReason,
    );
  }

  Future<void> _initializeWorkspace() async {
    await debugTimelineAsync('Editor.initWorkspace', () async {
      try {
        try {
          await _sessionCache.load().timeout(const Duration(milliseconds: 300));
          _pinnedMemoIds = List<String>.from(_sessionCache.cache.pinnedMemoIds);
        } catch (_) {
          _pinnedMemoIds = [];
        }

        final memos = await debugTimelineAsync(
          'Editor.listMemos',
          _storage.listMemos,
        );
        MemoStorageService.sortMemosWithPins(memos, _pinnedMemoIds);
        if (!mounted) {
          return;
        }

        setState(() => _memos = memos);

        if (memos.isNotEmpty) {
          final lastOpenedId = _sessionCache.cache.lastOpenedMemoId ??
              widget.prefsService.preferences.lastOpenedMemoId;
          final restoreId = lastOpenedId != null &&
                  memos.any((memo) => memo.id == lastOpenedId)
              ? lastOpenedId
              : memos.first.id;
          await _openMemo(restoreId, refreshList: false);
        } else {
          await _createNewMemo(refreshList: false);
        }
      } catch (error) {
        if (mounted) {
          _showMessage(AppLocalizations.of(context)!.loadFailed('$error'));
        }
      } finally {
        if (mounted) {
          debugTimelineSync('Editor.endInit', () {
            setState(() => _isInitializing = false);
          });
        }
      }
    });
  }

  Future<void> _loadAppVersionLabel() async {
    if (_appVersionLabel != null) {
      return;
    }
    try {
      final info = await PackageInfo.fromPlatform()
          .timeout(const Duration(seconds: 2));
      if (!mounted) {
        return;
      }
      setState(() => _appVersionLabel = '${info.version}+${info.buildNumber}');
    } catch (_) {
      // ????????????????
    }
  }

  bool get _isDirty =>
      _titleController.text != _savedTitle ||
      _contentController.text != _savedContent;

  bool _editorFocusSuspended = false;
  bool _restoreContentFocusAfterSuspend = false;
  bool _restoreTitleFocusAfterSuspend = false;
  bool _drawerOpen = false;

  /// 收起输入法后再开抽屉，避免 IME 下滑与 Drawer 滑入叠动画卡顿。
  /// 关闭抽屉后恢复焦点的缓冲（宜短，避免侧栏↔键盘切换体感拖沓）。
  static const _drawerImeSettleDelay = Duration(milliseconds: 180);

  /// 打开侧栏/设置/菜单等系统界面前：缓存并移除编辑区焦点，避免 IME 误弹出。
  void _suspendEditorFocus() {
    if (_editorFocusSuspended) {
      return;
    }
    _restoreContentFocusAfterSuspend = _editSession.focusNode.hasFocus ||
        _liveSession.focusNode.hasFocus ||
        _liveSession.hadFocus;
    _restoreTitleFocusAfterSuspend = _titleFocusNode.hasFocus;
    _editorFocusSuspended = true;
    _editImeSettleTimer?.cancel();
    // 立刻收起工具栏并 snap 掉 IME 留白，避免键盘下落期间每帧改 padding 与抽屉抢 GPU。
    final hideChrome =
        _editSession.focusNode.hasFocus || _liveSession.inputSessionActive;
    final hadInset = _editSession.keyboardBottomInset != 0 ||
        _settledImeKeyboardInset.value != 0 ||
        _toolbarImeKeyboardInset.value != 0;
    if (hideChrome || hadInset) {
      _liveSession.clearSessionFlags();
      _editSession.resetKeyboardInsets();
      _clearImeInsets();
      setState(() {});
    }
    _editSession.focusNode.unfocus();
    _liveSession.focusNode.unfocus();
    _titleFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  /// 系统界面关闭后，按需恢复此前编辑焦点。
  void _resumeEditorFocus() {
    if (!_editorFocusSuspended) {
      return;
    }
    // Drawer 仍开着时不恢复正文焦点，避免 IME 在侧栏背后弹出。
    if (_drawerOpen) {
      return;
    }
    final shouldRestoreContent = _restoreContentFocusAfterSuspend &&
        _viewMode != EditorViewMode.preview;
    final shouldRestoreTitle = _restoreTitleFocusAfterSuspend &&
        _viewMode != EditorViewMode.preview;
    _editorFocusSuspended = false;
    _restoreContentFocusAfterSuspend = false;
    _restoreTitleFocusAfterSuspend = false;
    if (!mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _editorFocusSuspended || _drawerOpen) {
        return;
      }
      if (shouldRestoreTitle && _titleFocusNode.canRequestFocus) {
        _titleFocusNode.requestFocus();
        return;
      }
      if (!shouldRestoreContent) {
        return;
      }
      final bodyFocus = _activeBodyFocus;
      if (bodyFocus.canRequestFocus) {
        bodyFocus.requestFocus();
        if (_viewMode == EditorViewMode.live) {
          _liveEditorKey.currentState?.restoreFocus();
        }
      }
    });
  }

  /// 移动端打开文件抽屉：先 flush 实时 AST，再等 IME 真正收起后打开。
  Future<void> _openMobileDrawer() async {
    if (_viewMode == EditorViewMode.live) {
      _liveEditorKey.currentState?.flushToParent();
    }

    final view = View.of(context);
    final insetBottom = view.viewInsets.bottom / view.devicePixelRatio;
    final waitForIme = drawerShouldWaitForIme(
      editorFocused: _editSession.focusNode.hasFocus ||
          _liveSession.focusNode.hasFocus ||
          _titleFocusNode.hasFocus,
      insetBottomLogical: insetBottom,
    );

    _suspendEditorFocus();
    if (waitForIme) {
      await _waitForImeSettled();
      if (!mounted) {
        return;
      }
    }
    _scaffoldKey.currentState?.openDrawer();
  }

  /// 轮询直到 viewInsets 收起或超时，避免固定 delay 在慢机上不够。
  Future<void> _waitForImeSettled() async {
    final deadline = DateTime.now().add(kDrawerImeWaitTimeout);
    while (mounted && DateTime.now().isBefore(deadline)) {
      final view = View.of(context);
      final inset = view.viewInsets.bottom / view.devicePixelRatio;
      if (inset <= 0.5) {
        return;
      }
      await Future<void>.delayed(_drawerImePollInterval);
    }
  }

  void _onDrawerChanged(bool isOpened) {
    _drawerOpen = isOpened;
    if (isOpened) {
      _suspendEditorFocus();
      // 防止焦点落到搜索框：IME 残留组字会污染搜索，列表切成「无匹配」。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_drawerOpen) {
          return;
        }
        FocusManager.instance.primaryFocus?.unfocus();
      });
      // 防御：若列表被异常清空，打开时从磁盘拉回。
      if (_memos.isEmpty && !_isInitializing) {
        unawaited(_refreshMemoList(selectId: _activeMemoId));
      }
      return;
    }
    // 等抽屉关闭动画结束再恢复焦点，避免侧栏滑出与 IME 升起叠播。
    Future<void>.delayed(_drawerImeSettleDelay, () {
      if (!mounted || _drawerOpen) {
        return;
      }
      _resumeEditorFocus();
    });
  }

  void _onEditFocusChanged() {
    if (!mounted || _viewMode != EditorViewMode.edit) {
      return;
    }
    final hasFocus = _editSession.focusNode.hasFocus;
    _publishEditCursorDebugHud();
    if (hasFocus) {
      setState(() {});
      // 键盘已展开时立刻滚；正在弹出则等 metrics settle，避免动画中途乱滚。
      if (_editSession.keyboardBottomInset > 0 ||
          _editSession.pendingKeyboardInset > 0) {
        _scheduleScrollEditCaretAboveIme();
      }
      return;
    }
    if (_editorFocusSuspended) {
      return;
    }
    _editSession.resetKeyboardInsets();
    _clearImeInsets();
    setState(() {});
  }

  /// 系统 IME inset 变化时同步侧滑门禁；仅布尔翻转才 setState，避免动画期整树刷新。
  void _syncDrawerOpenDragGestureGate() {
    if (!mounted) {
      return;
    }
    final isWide =
        MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint;
    if (isWide) {
      return;
    }
    final view = View.of(context);
    final inset = view.viewInsets.bottom / view.devicePixelRatio;
    final wasEnabled = drawerOpenDragGestureEnabled(
      isWide: false,
      insetBottomLogical: _drawerGateInsetLogical,
    );
    final nowEnabled = drawerOpenDragGestureEnabled(
      isWide: false,
      insetBottomLogical: inset,
    );
    _drawerGateInsetLogical = inset;
    if (wasEnabled != nowEnabled) {
      setState(() {});
    }
  }

  void _onLiveFocusChanged() {
    if (!mounted || _viewMode != EditorViewMode.live) {
      return;
    }
    final hasFocus = _liveSession.focusNode.hasFocus;
    if (hasFocus) {
      if (!_liveSession.hadFocus) {
        _liveSession.hadFocus = true;
        setState(() {});
      }
      return;
    }
    if (_editorFocusSuspended) {
      return;
    }
    if (_liveSession.deferFocusBlur ||
        (_liveEditorKey.currentState?.layoutTransitionActive ?? false)) {
      _liveEditorKey.currentState?.restoreFocus();
      if (!_liveSession.hadFocus) {
        setState(() => _liveSession.hadFocus = true);
      }
      return;
    }
    Future.delayed(_liveFocusBlurGrace, () {
      if (!mounted || _viewMode != EditorViewMode.live) {
        return;
      }
      if (_liveSession.focusNode.hasFocus) {
        _liveSession.hadFocus = true;
        return;
      }
      if (_titleFocusNode.hasFocus) {
        return;
      }
      // 宽限期后再抢一次；仍无焦点则结束实时输入会话。
      _liveEditorKey.currentState?.restoreFocus();
      Future.delayed(_liveFocusRestoreWait, () {
        if (!mounted || _viewMode != EditorViewMode.live) {
          return;
        }
        if (_liveSession.focusNode.hasFocus) {
          _liveSession.hadFocus = true;
          return;
        }
        if (_liveSession.hadFocus) {
          _clearImeInsets();
          setState(() => _liveSession.hadFocus = false);
        }
      });
    });
  }

  void _onContentControllerChanged() {
    _onEditorChanged();
    if (_viewMode == EditorViewMode.edit) {
      _publishEditCursorDebugHud();
    }
    if (_viewMode != EditorViewMode.edit || !_editSession.focusNode.hasFocus) {
      return;
    }
    final selection = _contentController.selection;
    if (selection == _editSession.lastSelectionForIme) {
      return;
    }
    _editSession.lastSelectionForIme = selection;
    _scheduleScrollEditCaretAboveIme();
  }

  /// 编辑模式光标 HUD（仅 debug）；实时模式由 Live 编辑器自行发布。
  void _publishEditCursorDebugHud() {
    if (!kDebugMode || _viewMode != EditorViewMode.edit) {
      return;
    }
    final text = _contentController.text;
    final selection = _contentController.selection;
    final focused = _editSession.focusNode.hasFocus;
    if (!selection.isValid) {
      publishCursorDebugHud(
        CursorDebugSnapshot(
          mode: 'Edit',
          focused: focused,
          blockType: 'sel invalid',
        ),
      );
      return;
    }
    final caret = selection.extentOffset.clamp(0, text.length);
    final ctx = cursorDebugContextAround(text: text, caretOffset: caret);
    final lineCol = cursorDebugLineColumn(text, caret);
    final composing = _contentController.value.composing;
    publishCursorDebugHud(
      CursorDebugSnapshot(
        mode: 'Edit',
        focused: focused,
        selectionBase: selection.baseOffset,
        selectionExtent: selection.extentOffset,
        collapsed: selection.isCollapsed,
        blockType: 'plain md',
        contextBefore: ctx.before,
        contextAfter: ctx.after,
        composingStart: composing.isValid ? composing.start : null,
        composingEnd: composing.isValid ? composing.end : null,
        docLine: lineCol.line,
        docColumn: lineCol.column,
      ),
    );
  }

  void _armEditImeSettleTimer({required int burstOriginMs}) {
    _editImeSettleTimer?.cancel();
    _editImeSettleArmedPending = _editSession.pendingKeyboardInset;
    _editImeSettleTimer = Timer(kImeInsetSettleDelay, () {
      if (!mounted ||
          _viewMode != EditorViewMode.edit ||
          !_editSession.focusNode.hasFocus ||
          _editorFocusSuspended ||
          _drawerOpen) {
        return;
      }
      final settleBurstMs =
          DateTime.now().millisecondsSinceEpoch - burstOriginMs;
      final willCommit = shouldCommitImeInset(
        pendingLogical: _editSession.pendingKeyboardInset,
        committedLogical: _editSession.keyboardBottomInset,
      );
      imeTimelineSettle(
        ImeTimelineScope.edit,
        pendingLogical: _editSession.pendingKeyboardInset,
        committedLogical: _editSession.keyboardBottomInset,
        burstMs: settleBurstMs,
        settleResetCount: _editImeSettleResetCount,
        willCommit: willCommit,
      );
      if (!willCommit) {
        return;
      }
      final next = _editSession.pendingKeyboardInset;
      // 正文 settle 只改留白；工具栏由静止后 revealOnce 单独弹出。
      setState(() => _editSession.keyboardBottomInset = next);
      imeTimelineCommit(
        ImeTimelineScope.edit,
        pendingLogical: _editSession.pendingKeyboardInset,
        committedLogical: _editSession.keyboardBottomInset,
        reason: 'settle',
      );
      _publishEditImeDebugHud(
        burstMs: settleBurstMs,
        focused: true,
        lastCommitReason: 'settle',
      );
      if (next > 0) {
        _scheduleEditSettleNudge();
      }
    });
  }

  /// 编辑 settle：padding 布局后单次上推（工具栏已同拍显示）。
  void _scheduleEditSettleNudge() {
    if (_editImeScrollScheduled) {
      return;
    }
    _editImeScrollScheduled = true;
    imeTimelineScroll(ImeTimelineScope.edit, reason: 'settle');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _editImeScrollScheduled = false;
      if (!mounted ||
          _viewMode != EditorViewMode.edit ||
          !_editSession.focusNode.hasFocus) {
        return;
      }
      _nudgeEditCaretAboveIme();
    });
  }

  void _onEditKeyboardMetricsChanged() {
    if (!mounted || _viewMode != EditorViewMode.edit) {
      return;
    }
    // 抽屉/系统浮层期间忽略 metrics，避免与侧栏动画抢主线程。
    if (_editorFocusSuspended || _drawerOpen) {
      return;
    }
    final view = View.of(context);
    final inset = view.viewInsets.bottom / view.devicePixelRatio;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final hadActiveSettle = _editImeSettleTimer?.isActive ?? false;
    if (!hadActiveSettle) {
      _editImeBurstStartMs = nowMs;
      _editImeSettleResetCount = 0;
    }
    _editSession.pendingKeyboardInset =
        _editSession.focusNode.hasFocus ? inset : 0;
    final burstOriginMs = _editImeBurstStartMs ?? nowMs;
    final burstMs = nowMs - burstOriginMs;

    if (!_editSession.focusNode.hasFocus) {
      _editImeSettleTimer?.cancel();
      _cancelEditToolbarRevealTimer();
      var clearedForUnfocus = false;
      if (_editSession.keyboardBottomInset != 0 ||
          _settledImeKeyboardInset.value != 0 ||
          _toolbarImeKeyboardInset.value != 0) {
        _clearImeInsets();
        setState(() => _editSession.resetKeyboardInsets());
        clearedForUnfocus = true;
        imeTimelineCommit(
          ImeTimelineScope.edit,
          pendingLogical: 0,
          committedLogical: 0,
          reason: 'unfocused',
        );
      }
      imeTimelineMetrics(
        ImeTimelineScope.edit,
        pendingLogical: _editSession.pendingKeyboardInset,
        committedLogical: _editSession.keyboardBottomInset,
        burstMs: burstMs,
        settleResetCount: _editImeSettleResetCount,
        focused: false,
      );
      _publishEditImeDebugHud(
        burstMs: burstMs,
        focused: false,
        lastCommitReason: clearedForUnfocus ? 'unfocused' : null,
      );
      return;
    }

    if (shouldCommitImeDismissImmediately(
      pendingLogical: _editSession.pendingKeyboardInset,
      committedLogical: _editSession.keyboardBottomInset,
    )) {
      _editImeSettleTimer?.cancel();
      _clearImeInsets();
      setState(() => _editSession.keyboardBottomInset = 0);
      imeTimelineCommit(
        ImeTimelineScope.edit,
        pendingLogical: _editSession.pendingKeyboardInset,
        committedLogical: 0,
        reason: 'dismissImmediate',
      );
      imeTimelineMetrics(
        ImeTimelineScope.edit,
        pendingLogical: _editSession.pendingKeyboardInset,
        committedLogical: 0,
        burstMs: burstMs,
        settleResetCount: _editImeSettleResetCount,
        focused: true,
      );
      _publishEditImeDebugHud(
        burstMs: burstMs,
        focused: true,
        lastCommitReason: 'dismissImmediate',
      );
      return;
    }

    final restart = !hadActiveSettle ||
        shouldRestartImeSettleTimer(
          pendingLogical: _editSession.pendingKeyboardInset,
          armedPendingLogical: _editImeSettleArmedPending,
        );
    if (restart) {
      if (hadActiveSettle) {
        _editImeSettleResetCount++;
      }
      _armEditImeSettleTimer(burstOriginMs: burstOriginMs);
    }
    _maybeArmEditToolbarRevealDuringOpen();

    imeTimelineMetrics(
      ImeTimelineScope.edit,
      pendingLogical: _editSession.pendingKeyboardInset,
      committedLogical: _editSession.keyboardBottomInset,
      burstMs: burstMs,
      settleResetCount: _editImeSettleResetCount,
      focused: true,
    );
    _publishEditImeDebugHud(burstMs: burstMs, focused: true);
  }

  void _scheduleScrollEditCaretAboveIme({String? reason}) {
    if (_editImeScrollScheduled) {
      return;
    }
    _editImeScrollScheduled = true;
    imeTimelineScroll(ImeTimelineScope.edit, reason: reason);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _editImeScrollScheduled = false;
      if (!mounted ||
          _viewMode != EditorViewMode.edit ||
          !_editSession.focusNode.hasFocus) {
        return;
      }
      _scrollEditCaretAboveIme();
    });
  }

  /// 编辑模式：将光标滚出键盘/底部工具栏遮挡区（对齐实时模式 ensureVisible + nudge）。
  void _scrollEditCaretAboveIme() {
    if (_viewMode != EditorViewMode.edit || !_editSession.focusNode.hasFocus) {
      return;
    }
    final selection = _contentController.selection;
    if (!selection.isValid) {
      return;
    }
    final editable = _findEditEditableTextState();
    if (editable == null) {
      return;
    }
    // 先走框架 bringIntoView（尊重 TextField.scrollPadding）。
    editable.bringIntoView(selection.extent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _nudgeEditCaretAboveIme();
      }
    });
  }

  /// 从焦点或 TextField 子树定位 [EditableTextState]（Focus 上下文偶发找不到祖先时兜底）。
  EditableTextState? _findEditEditableTextState() {
    final fromFocus = _editSession.focusNode.context
        ?.findAncestorStateOfType<EditableTextState>();
    if (fromFocus != null) {
      return fromFocus;
    }
    final root = _contentFieldKey.currentContext;
    if (root is! Element) {
      return null;
    }
    EditableTextState? found;
    void visit(Element element) {
      if (found != null) {
        return;
      }
      if (element is StatefulElement && element.state is EditableTextState) {
        found = element.state as EditableTextState;
        return;
      }
      element.visitChildren(visit);
    }

    visit(root);
    return found;
  }

  /// scrollPadding / bringIntoView 不知底部工具栏叠层时，再按实测坐标上推。
  void _nudgeEditCaretAboveIme() {
    if (_viewMode != EditorViewMode.edit || !_editSession.focusNode.hasFocus) {
      return;
    }
    final controller = _editSession.scrollController;
    if (!controller.hasClients) {
      return;
    }
    final editable = _findEditEditableTextState();
    final fieldContext = _contentFieldKey.currentContext;
    if (editable == null || fieldContext == null) {
      return;
    }
    final selection = _contentController.selection;
    if (!selection.isValid) {
      return;
    }

    // 底部 IME spacer 已缩短 TextField 视口时，勿再按满高 obscured 二次上推。
    final isWide =
        MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint;
    final spacer = editImeBottomSpacerHeight(
      keyboardInset: _editSession.keyboardBottomInset,
      focused: true,
      includeToolbar: !isWide,
    );
    if (spacer > 0) {
      return;
    }

    final renderEditable = editable.renderEditable;
    final caretRect = renderEditable.getLocalRectForCaret(
      TextPosition(offset: selection.extentOffset),
    );
    final caretGlobalBottom =
        renderEditable.localToGlobal(Offset(0, caretRect.bottom)).dy;

    final fieldBox = fieldContext.findRenderObject() as RenderBox?;
    if (fieldBox == null || !fieldBox.hasSize) {
      return;
    }
    final viewportGlobalBottom =
        fieldBox.localToGlobal(Offset(0, fieldBox.size.height)).dy;

    final delta = scrollDeltaToClearIme(
      caretOrBlockGlobalBottom: caretGlobalBottom,
      viewportGlobalBottom: viewportGlobalBottom,
      obscuredBottom: kImeCaretGap,
    );
    if (delta <= 0) {
      return;
    }
    final nextOffset = (controller.offset + delta).clamp(
      controller.position.minScrollExtent,
      controller.position.maxScrollExtent,
    );
    if ((nextOffset - controller.offset).abs() < 0.5) {
      // 已顶到 maxScrollExtent：多半是底部 contentPadding 尚未带上 IME 留白。
      return;
    }
    controller.jumpTo(nextOffset);
  }

  Future<void> _refreshMemoList({String? selectId}) async {
    final memos = await _storage.listMemos();
    MemoStorageService.sortMemosWithPins(memos, _pinnedMemoIds);
    if (!mounted) {
      return;
    }
    setState(() {
      _memos = memos;
      if (selectId != null) {
        _activeMemoId = selectId;
      }
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    // 清空时立即退出搜索态，勿等防抖（否则会短暂/卡住「无匹配结果」）。
    if (query.trim().isEmpty && (_isSearchActive || _searchResults.isNotEmpty)) {
      setState(() {
        _searchResults = [];
        _isSearchActive = false;
      });
    } else {
      setState(() {});
    }
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(_searchDelay, _runSearch);
  }

  void _runSearch() {
    final query = _searchController.text;
    if (query.trim().isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _searchResults = [];
        _isSearchActive = false;
      });
      return;
    }

    final results = _searchService.searchMemos(
      memos: _memos,
      query: query,
      caseSensitive: _caseSensitive,
      untitledLabel: AppLocalizations.of(context)!.untitled,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _searchResults = results;
      _isSearchActive = true;
    });
  }

  void _onCaseSensitiveChanged(bool value) {
    setState(() => _caseSensitive = value);
    _runSearch();
  }

  void _onEditorChanged() {
    if (!_applyingHistory && !_suppressAutoSave && _activeMemoId != null) {
      _scheduleHistoryRecord();
    }
    if (_suppressAutoSave || _activeMemoId == null || !_isDirty) {
      return;
    }
    _scheduleAutoSave();
  }

  DocumentSnapshot _currentDocumentSnapshot() {
    return DocumentSnapshot(
      title: _titleController.text,
      content: _contentController.text,
    );
  }

  void _scheduleHistoryRecord() {
    _historyTimer?.cancel();
    _historyTimer = Timer(_historyDebounce, _recordDocumentHistory);
  }

  void _recordDocumentHistory() {
    if (_applyingHistory || _activeMemoId == null) {
      return;
    }
    _documentHistory.record(_currentDocumentSnapshot());
  }

  void _resetDocumentHistory() {
    _historyTimer?.cancel();
    _documentHistory.reset(_currentDocumentSnapshot());
  }

  void _applyDocumentSnapshot(DocumentSnapshot snapshot) {
    _applyingHistory = true;
    _suppressAutoSave = true;

    if (_viewMode == EditorViewMode.live) {
      _liveEditorKey.currentState?.flushToParent();
    }

    _titleController.text = snapshot.title;
    _contentController.text = snapshot.content;

    if (_viewMode == EditorViewMode.live) {
      _liveEditorKey.currentState?.reloadFromMarkdown(snapshot.content);
    }

    _suppressAutoSave = false;
    _applyingHistory = false;
    if (mounted) {
      setState(() {});
    }
  }

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(_autoSaveDelay, () {
      unawaited(_saveActiveMemo());
    });
    if (_saveStatus != SaveStatus.idle) {
      setState(() {
        _saveStatus = SaveStatus.idle;
        _saveError = null;
      });
    }
  }

  Future<void>? _ongoingSave;

  Future<void> _flushSave() async {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
    if (_ongoingSave != null) {
      await _ongoingSave;
    }
    if (_activeMemoId != null && _isDirty) {
      await _saveActiveMemo();
    }
  }

  Future<void> _saveActiveMemo() async {
    final memoId = _activeMemoId;
    if (memoId == null || !_isDirty) {
      return;
    }

    if (_ongoingSave != null) {
      await _ongoingSave;
      if (_activeMemoId != memoId || !_isDirty) {
        return;
      }
    }

    final saveFuture = _performSave(memoId);
    _ongoingSave = saveFuture;
    await saveFuture;
    if (_ongoingSave == saveFuture) {
      _ongoingSave = null;
    }
  }

  Future<void> _performSave(String memoId) async {
    if (!_isDirty) {
      if (mounted) {
        setState(() => _saveStatus = SaveStatus.saved);
      }
      return;
    }

    setState(() {
      _saveStatus = SaveStatus.saving;
      _saveError = null;
    });

    try {
      final updated = await _storage.updateMemo(
        id: memoId,
        title: _titleController.text,
        content: _contentController.text,
      );
      if (!mounted || _activeMemoId != memoId) {
        return;
      }

      _savedTitle = _titleController.text;
      _savedContent = _contentController.text;

      setState(() {
        _saveStatus = SaveStatus.saved;
        _memos = _memos
            .map((memo) => memo.id == updated.id ? updated : memo)
            .toList();
      });
      if (_isSearchActive) {
        _runSearch();
      }
    } catch (error) {
      if (!mounted || _activeMemoId != memoId) {
        return;
      }
      setState(() {
        _saveStatus = SaveStatus.error;
        _saveError = '$error';
      });
    }
  }

  Future<void> _openMemo(
    String id, {
    bool refreshList = true,
    MemoJumpTarget? jumpTarget,
  }) async {
    if (id == _activeMemoId) {
      if (jumpTarget != null) {
        _jumpToTarget(jumpTarget);
        _closeDrawerIfNeeded();
      }
      return;
    }

    await _flushSave();

    try {
      final memo = await debugTimelineAsync(
        'Editor.loadMemo',
        () => _storage.loadMemo(id),
        arguments: {'id': id},
      );
      if (!mounted) {
        return;
      }

      debugTimelineSync('Editor.loadMemoIntoEditor', () {
        _loadMemoIntoEditor(memo, jumpTarget: jumpTarget);
      });
      if (refreshList) {
        await _refreshMemoList(selectId: id);
      } else {
        setState(() => _activeMemoId = id);
      }
      _closeDrawerIfNeeded();
    } catch (error) {
      _showMessage(AppLocalizations.of(context)!.openFailed('$error'));
    }
  }

  Future<void> _openSearchResult(MemoSearchResult result) async {
    await _openMemo(
      result.memoId,
      jumpTarget: result.jumpTarget,
    );
  }

  Future<void> _createNewMemo({bool refreshList = true}) async {
    await _flushSave();

    try {
      final memo = await _storage.createMemo();
      if (!mounted) {
        return;
      }

      _loadMemoIntoEditor(memo);
      if (refreshList) {
        await _refreshMemoList(selectId: memo.id);
      } else {
        setState(() {
          _memos = [memo, ..._memos];
          _activeMemoId = memo.id;
        });
      }
      _activeBodyFocus.requestFocus();
      _closeDrawerIfNeeded();
    } catch (error) {
      _showMessage(AppLocalizations.of(context)!.createFailed('$error'));
    }
  }

  void _loadMemoIntoEditor(Memo memo, {MemoJumpTarget? jumpTarget}) {
    _suppressAutoSave = true;
    _titleController.text = memo.title;
    _contentController.text = memo.content;
    _savedTitle = memo.title;
    _savedContent = memo.content;
    _activeMemoId = memo.id;
    _saveStatus = SaveStatus.saved;
    _saveError = null;
    _suppressAutoSave = false;
    _resetDocumentHistory();

    unawaited(_sessionCache.updateLastOpenedMemoId(memo.id));
    // ?????????????????????????
    unawaited(widget.prefsService.updateLastOpenedMemoId(memo.id));

    if (jumpTarget != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _activeMemoId == memo.id) {
          _jumpToTarget(jumpTarget);
        }
      });
    } else {
      // ???????????????????????? Overlay ????
      _scrollContentToTop();
    }
  }

  void _scrollContentToTop({int retry = 0}) {
    void jump() {
      if (!mounted) {
        return;
      }
      var anyMissingClients = false;
      for (final controller in [
        _editSession.scrollController,
        _liveSession.scrollController,
      ]) {
        if (!controller.hasClients) {
          anyMissingClients = true;
          continue;
        }
        if (controller.offset > 0) {
          controller.jumpTo(0);
        }
      }
      if (anyMissingClients && retry < 3) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollContentToTop(retry: retry + 1);
        });
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => jump());
  }

  void _jumpToTarget(MemoJumpTarget target) {
    if (target.field == MemoJumpField.title) {
      final textLength = _titleController.text.length;
      final start = target.offset.clamp(0, textLength);
      final end = (target.offset + target.length).clamp(0, textLength);
      _titleController.selection = TextSelection(
        baseOffset: start,
        extentOffset: end,
      );
      return;
    }

    final textLength = _contentController.text.length;
    final start = target.offset.clamp(0, textLength);
    final end = (target.offset + target.length).clamp(0, textLength);
    _contentController.selection = TextSelection(
      baseOffset: start,
      extentOffset: end,
    );
    _activeBodyFocus.requestFocus();
    _scrollContentToLine(target.lineNumber);
  }

  void _scrollContentToLine(int lineNumber, {int retry = 0}) {
    final controller = _activeBodyScroll;
    if (!controller.hasClients) {
      if (retry < 3) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _scrollContentToLine(lineNumber, retry: retry + 1);
          }
        });
      }
      return;
    }

    final targetOffset = (lineNumber - 1) * _contentLineHeight;
    final maxScroll = controller.position.maxScrollExtent;
    controller.animateTo(
      targetOffset.clamp(0.0, maxScroll),
      duration: _sidebarCollapseDuration,
      curve: Curves.easeOut,
    );
  }

  void _closeDrawerIfNeeded() {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Memo? _memoById(String id) {
    for (final memo in _memos) {
      if (memo.id == id) {
        return memo;
      }
    }
    return null;
  }

  Future<String?> _showRenameDialog(String currentTitle) {
    return showDialog<String>(
      context: context,
      builder: (context) => _RenameDialog(initialTitle: currentTitle),
    );
  }

  Future<bool> _confirmDelete(String title) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteMemoTitle),
        content: Text(l10n.deleteMemoConfirm(title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  Future<void> _pickAndInsertImage() async {
    final memoId = _activeMemoId;
    if (memoId == null) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty || !mounted) {
      return;
    }

    final sourcePath = result.files.single.path;
    if (sourcePath == null) {
      _showMessage(l10n.imageReadFailed);
      return;
    }

    try {
      final snippet = await memoImageService.copyAndBuildMarkdown(
        memoId: memoId,
        sourcePath: sourcePath,
      );
      if (!mounted) {
        return;
      }

      _suppressAutoSave = true;
      MarkdownEditorHelper.insertAtCursor(
        _contentController,
        '\n$snippet\n',
      );
      _suppressAutoSave = false;
      _onEditorChanged();
      _editSession.focusNode.requestFocus();
    } catch (error) {
      _showMessage(l10n.insertImageFailed('$error'));
    }
  }

  Future<void> _insertMarkdownLink() async {
    final l10n = AppLocalizations.of(context)!;
    final liveState = _liveEditorKey.currentState;
    if (_viewMode == EditorViewMode.live) {
      liveState?.captureForInlineAction();
    }

    var initialText = '';
    if (_viewMode != EditorViewMode.live) {
      final selection = _contentController.selection;
      if (selection.isValid && !selection.isCollapsed) {
        initialText =
            _contentController.text.substring(selection.start, selection.end);
      }
    }

    // ??????????????????/??????
    _suspendEditorFocus();
    final result = await showDialog<({String url, String text})>(
      context: context,
      builder: (context) => _LinkInsertDialog(
        initialText: initialText,
        memos: _memos,
        currentMemoId: _activeMemoId,
        useRelativeFileHref: MarkdownLinkActions.preferRelativeFileHref,
      ),
    );
    if (!mounted) {
      return;
    }
    _resumeEditorFocus();
    if (result == null) {
      return;
    }

    final url = result.url.trim();
    if (url.isEmpty) {
      return;
    }
    final display = result.text.trim();
    final resolvedTitle = MarkdownLinkActions.displayTitleForHref(
      href: url,
      memos: _memos,
      untitledLabel: l10n.untitled,
      currentMemoFilePath: _memoById(_activeMemoId ?? '')?.filePath,
    );
    final label = display.isNotEmpty
        ? display
        : (resolvedTitle ?? (initialText.isNotEmpty ? initialText : url));

    if (_viewMode == EditorViewMode.live) {
      liveState?.applyLink(url: url, displayText: label);
      return;
    }

    MarkdownEditorHelper.applyLink(
      _contentController,
      url: url,
      displayText: label,
    );
    _editSession.focusNode.requestFocus();
  }

  Future<void> _openMarkdownLink(String href) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await MarkdownLinkActions.openHref(
        href: href,
        memos: _memos,
        untitledLabel: l10n.untitled,
        currentMemoFilePath: _memoById(_activeMemoId ?? '')?.filePath,
        openMemo: _openMemo,
      );
    } catch (error) {
      if (mounted) {
        _showMessage(l10n.linkOpenFailed('$error'));
      }
    }
  }

  String? _resolveMarkdownLinkLabel(String href) {
    final l10n = AppLocalizations.of(context)!;
    return MarkdownLinkActions.displayTitleForHref(
      href: href,
      memos: _memos,
      untitledLabel: l10n.untitled,
      currentMemoFilePath: _memoById(_activeMemoId ?? '')?.filePath,
    );
  }

  Future<void> _renameMemo(String id) async {
    final memo = _memoById(id);
    if (memo == null) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final initialTitle = memo.title.isNotEmpty ? memo.title : '';
    final newTitle = await _showRenameDialog(initialTitle);
    if (newTitle == null || !mounted) {
      return;
    }

    try {
      if (id == _activeMemoId) {
        _suppressAutoSave = true;
        _titleController.text = newTitle.trim();
        _suppressAutoSave = false;
        await _flushSave();
      } else {
        await _storage.renameMemo(id: id, newTitle: newTitle);
      }

      await _refreshMemoList(selectId: id);
      if (_isSearchActive) {
        _runSearch();
      }
      _showMessage(l10n.renamed);
    } catch (error) {
      _showMessage(l10n.renameFailed('$error'));
    }
  }

  Future<void> _revealMemoInExplorer(String id) async {
    final memo = _memoById(id);
    if (memo == null) {
      return;
    }

    try {
      await _storage.revealInFileManager(memo.filePath);
    } catch (error) {
      _showMessage(AppLocalizations.of(context)!.revealFailed('$error'));
    }
  }

  Future<void> _deleteMemo(String id) async {
    final memo = _memoById(id);
    if (memo == null) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final confirmed = await _confirmDelete(
      memo.displayTitle(l10n.untitled),
    );
    if (!confirmed || !mounted) {
      return;
    }

    final wasActive = id == _activeMemoId;
    if (wasActive) {
      _autoSaveTimer?.cancel();
      _autoSaveTimer = null;
    }

    try {
      await _storage.deleteMemo(id);
      if (!mounted) {
        return;
      }

      if (_pinnedMemoIds.contains(id)) {
        await _sessionCache.togglePin(id);
        _pinnedMemoIds = List<String>.from(_sessionCache.cache.pinnedMemoIds);
      }

      final remaining = _memos.where((item) => item.id != id).toList();
      MemoStorageService.sortMemosWithPins(remaining, _pinnedMemoIds);
      setState(() {
        _memos = remaining;
        if (wasActive) {
          _activeMemoId = null;
        }
      });

      if (wasActive) {
        if (remaining.isNotEmpty) {
          await _openMemo(remaining.first.id, refreshList: false);
        } else {
          await _createNewMemo(refreshList: false);
        }
      }

      if (_isSearchActive) {
        _runSearch();
      }

      _showMessage(l10n.deleted);
    } catch (error) {
      _showMessage(l10n.deleteFailed('$error'));
    }
  }

  Future<void> _togglePinMemo(String id) async {
    await _sessionCache.togglePin(id);
    if (!mounted) {
      return;
    }
    setState(() {
      _pinnedMemoIds = List<String>.from(_sessionCache.cache.pinnedMemoIds);
      MemoStorageService.sortMemosWithPins(_memos, _pinnedMemoIds);
    });
  }

  Future<void> _openSettings() async {
    _suspendEditorFocus();
    await _loadAppVersionLabel();
    var transferBusy = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SettingsPanel(
          prefsService: widget.prefsService,
          appVersionLabel: _appVersionLabel,
          isTransferBusy: transferBusy,
          onThemeModeChanged: (mode) {
            widget.onThemeChanged(mode);
            setSheetState(() {});
          },
          onLocaleChanged: (code) {
            widget.onLocaleChanged(Locale(code));
            setSheetState(() {});
          },
          onFontSizeChanged: (size) {
            widget.onFontSizeChanged(size);
            setSheetState(() {});
          },
          onDebugToolsChanged: widget.onDebugToolsChanged == null
              ? null
              : (enabled) {
                  widget.onDebugToolsChanged!(enabled);
                  setSheetState(() {});
                },
          onDebugShowFpsChanged: widget.onDebugShowFpsChanged == null
              ? null
              : (enabled) {
                  widget.onDebugShowFpsChanged!(enabled);
                  setSheetState(() {});
                },
          onDebugShowImeHudChanged: widget.onDebugShowImeHudChanged == null
              ? null
              : (enabled) {
                  widget.onDebugShowImeHudChanged!(enabled);
                  setSheetState(() {});
                },
          onDebugShowCursorHudChanged: widget.onDebugShowCursorHudChanged == null
              ? null
              : (enabled) {
                  widget.onDebugShowCursorHudChanged!(enabled);
                  setSheetState(() {});
                },
          onExportData: () => unawaited(() async {
            setSheetState(() => transferBusy = true);
            try {
              await _exportData();
            } finally {
              if (context.mounted) {
                setSheetState(() => transferBusy = false);
              }
            }
          }()),
          onImportData: () => unawaited(() async {
            setSheetState(() => transferBusy = true);
            try {
              final imported = await _importData();
              if (imported && sheetContext.mounted) {
                Navigator.of(sheetContext).pop();
              }
            } finally {
              if (context.mounted) {
                setSheetState(() => transferBusy = false);
              }
            }
          }()),
          onEmptyTrash: () => unawaited(() async {
            setSheetState(() => transferBusy = true);
            try {
              await _emptyTrash();
            } finally {
              if (context.mounted) {
                setSheetState(() => transferBusy = false);
              }
            }
          }()),
          onRestoreFromTrash: () => unawaited(() async {
            setSheetState(() => transferBusy = true);
            try {
              await _restoreFromTrash();
            } finally {
              if (context.mounted) {
                setSheetState(() => transferBusy = false);
              }
            }
          }()),
        ),
      ),
    );
    if (mounted) {
      _resumeEditorFocus();
    }
  }

  Future<void> _exportData() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await _flushSave();
      final dest = await FilePicker.platform.getDirectoryPath(
        dialogTitle: l10n.exportData,
      );
      if (dest == null) {
        if (mounted) {
          _showMessage(l10n.backupPickCancelled);
        }
        return;
      }

      final backup = DataBackupService(prefsService: widget.prefsService);
      final result = await backup.exportToDirectory(dest);
      if (!mounted) {
        return;
      }
      _showMessage(l10n.exportSuccess(result.targetPath));
    } catch (error) {
      if (mounted) {
        _showMessage(l10n.exportFailed('$error'));
      }
    }
  }

  Future<bool> _importData() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.importConfirmTitle),
          content: Text(l10n.importConfirmMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.confirm),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        return false;
      }

      final source = await FilePicker.platform.getDirectoryPath(
        dialogTitle: l10n.importData,
      );
      if (source == null) {
        if (mounted) {
          _showMessage(l10n.backupPickCancelled);
        }
        return false;
      }

      await _flushSave();
      final backup = DataBackupService(prefsService: widget.prefsService);
      final result = await backup.importFromDirectory(source);
      if (!mounted) {
        return false;
      }

      await _applyImportedPreferences();
      await _reloadWorkspaceAfterImport();
      _showMessage(l10n.importSuccess(result.memoFileCount));
      return true;
    } catch (error) {
      if (mounted) {
        _showMessage(l10n.importFailed('$error'));
      }
      return false;
    }
  }

  Future<void> _applyImportedPreferences() async {
    final prefs = await widget.prefsService.load();
    widget.onThemeChanged(prefs.themeMode);
    widget.onLocaleChanged(prefs.locale);
    widget.onFontSizeChanged(prefs.fontSize);
    widget.onDebugToolsChanged?.call(prefs.debugToolsEnabled);
    widget.onDebugShowFpsChanged?.call(prefs.debugShowFps);
    widget.onDebugShowImeHudChanged?.call(prefs.debugShowImeHud);
    widget.onDebugShowCursorHudChanged?.call(prefs.debugShowCursorHud);
  }

  Future<void> _emptyTrash() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.emptyTrashConfirmTitle),
        content: Text(l10n.emptyTrashConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.emptyTrash),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await memoTrashService.emptyTrash();
      if (mounted) {
        _showMessage(l10n.emptyTrashSuccess);
      }
    } catch (error) {
      if (mounted) {
        _showMessage(l10n.deleteFailed('$error'));
      }
    }
  }

  Future<void> _restoreFromTrash() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final items = await memoTrashService.listTrash();
      if (!mounted) {
        return;
      }
      if (items.isEmpty) {
        _showMessage(l10n.trashEmpty);
        return;
      }
      final selected = await showDialog<Set<String>>(
        context: context,
        builder: (context) => _TrashRestoreDialog(items: items),
      );
      if (selected == null || selected.isEmpty || !mounted) {
        return;
      }
      await memoTrashService.restore(selected.toList());
      await _refreshMemoList(selectId: _activeMemoId);
      if (mounted) {
        _showMessage(l10n.restoreTrashSuccess(selected.length));
      }
    } catch (error) {
      if (mounted) {
        _showMessage(l10n.importFailed('$error'));
      }
    }
  }

  Future<void> _reloadWorkspaceAfterImport() async {
    _autoSaveTimer?.cancel();
    _historyTimer?.cancel();
    _documentHistory.reset(
      DocumentSnapshot(
        title: _titleController.text,
        content: _contentController.text,
      ),
    );
    setState(() {
      _isInitializing = true;
      _activeMemoId = null;
      _memos = [];
      _isSearchActive = false;
      _searchResults = [];
    });
    _searchController.clear();
    await _initializeWorkspace();
  }

  void _undo() {
    final current = _currentDocumentSnapshot();
    final previous = _documentHistory.undo(current);
    if (previous != null) {
      _applyDocumentSnapshot(previous);
    }
  }

  void _redo() {
    final current = _currentDocumentSnapshot();
    final next = _documentHistory.redo(current);
    if (next != null) {
      _applyDocumentSnapshot(next);
    }
  }

  Widget _buildFilePanel({VoidCallback? onCollapseSidebar}) {
    return MemoFilePanel(
      memos: _memos,
      activeMemoId: _activeMemoId,
      pinnedMemoIds: _pinnedMemoIds,
      onTogglePinMemo: (id) => unawaited(_togglePinMemo(id)),
      onMemoSelected: (id) => unawaited(_openMemo(id)),
      onCreateMemo: () => unawaited(_createNewMemo()),
      onRenameMemo: (id) => unawaited(_renameMemo(id)),
      onDeleteMemo: (id) => unawaited(_deleteMemo(id)),
      showRevealInExplorer: MemoStorageService.supportsRevealInExplorer,
      onRevealInExplorer: (id) => unawaited(_revealMemoInExplorer(id)),
      searchController: _searchController,
      caseSensitive: _caseSensitive,
      onCaseSensitiveChanged: _onCaseSensitiveChanged,
      isSearchActive: _isSearchActive,
      searchResults: _searchResults,
      onSearchResultSelected: (result) => unawaited(_openSearchResult(result)),
      isSaving: _saveStatus == SaveStatus.saving,
      onCollapseSidebar: onCollapseSidebar,
      onOpenSettings: () => unawaited(_openSettings()),
      onBeforeSystemOverlay: _suspendEditorFocus,
      onAfterSystemOverlay: _resumeEditorFocus,
    );
  }

  void _collapseSidebar() {
    setState(_sidebarReveal.collapse);
  }

  void _expandSidebar() {
    setState(_sidebarReveal.beginExpand);
  }

  void _onSidebarWidthAnimationEnded() {
    if (!mounted || !_sidebarReveal.expanded || _sidebarReveal.contentVisible) {
      return;
    }
    setState(_sidebarReveal.onExpandAnimationEnded);
  }

  Widget _buildSidebarExpandHandle(AppLocalizations l10n) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: _expandSidebar,
        child: Tooltip(
          message: l10n.expandSidebar,
          child: SizedBox(
            width: 28,
            child: Center(
              child: Icon(
                Icons.chevron_right,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSaveStatusChip(AppLocalizations l10n, {bool compact = false}) {
    final theme = Theme.of(context);

    late final String label;
    late final IconData icon;
    late final Color? color;

    if (_saveStatus == SaveStatus.saving) {
      label = l10n.statusSaving;
      icon = Icons.sync;
      color = theme.colorScheme.primary;
    } else if (_saveStatus == SaveStatus.error) {
      label = l10n.statusError;
      icon = Icons.error_outline;
      color = theme.colorScheme.error;
    } else if (_saveStatus == SaveStatus.saved ||
        (_saveStatus == SaveStatus.idle && !_isDirty)) {
      label = l10n.statusSaved;
      icon = Icons.check_circle_outline;
      color = theme.colorScheme.tertiary;
    } else {
      label = l10n.statusEditing;
      icon = Icons.edit_outlined;
      color = theme.colorScheme.onSurfaceVariant;
    }

    return Tooltip(
      message: _saveError ?? label,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 8),
        child: compact
            ? Icon(icon, size: 20, color: color)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(color: color),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildAppBarTitle(AppLocalizations l10n, bool isWide) {
    return Row(
      children: [
        if (!isWide)
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => unawaited(_openMobileDrawer()),
            tooltip: l10n.memos,
          ),
        Expanded(child: _buildTitleField(l10n)),
        IconButton(
          tooltip: l10n.undo,
          onPressed: _documentHistory.canUndo ? _undo : null,
          icon: const Icon(Icons.undo),
        ),
        IconButton(
          tooltip: l10n.redo,
          onPressed: _documentHistory.canRedo ? _redo : null,
          icon: const Icon(Icons.redo),
        ),
        _buildSaveStatusChip(l10n, compact: !isWide),
      ],
    );
  }

  Future<void> _setViewMode(EditorViewMode mode) async {
    if (_viewMode == mode) {
      return;
    }

    final previous = _viewMode;
    if (previous == EditorViewMode.live) {
      _liveEditorKey.currentState?.flushToParent();
    }

    if (mode == EditorViewMode.preview) {
      await _flushSave();
      // 切入预览：主动失焦，不立刻弹键盘。
      _editSession.focusNode.unfocus();
      _liveSession.focusNode.unfocus();
      _titleFocusNode.unfocus();
      FocusManager.instance.primaryFocus?.unfocus();
      _liveSession.clearSessionFlags();
      _editSession.resetKeyboardInsets();
      _clearImeInsets();
    } else if (mode == EditorViewMode.edit) {
      _liveSession.focusNode.unfocus();
      _liveSession.clearSessionFlags();
      _clearImeInsets();
    } else if (mode == EditorViewMode.live) {
      _editSession.focusNode.unfocus();
      _editSession.resetKeyboardInsets();
      _clearImeInsets();
    }

    if (!mounted) {
      return;
    }
    setState(() => _viewMode = mode);
    if (mode == EditorViewMode.preview) {
      publishCursorDebugHud(
        const CursorDebugSnapshot(mode: 'Preview', focused: false),
      );
    } else if (mode == EditorViewMode.edit) {
      _publishEditCursorDebugHud();
    }
    if (mode == EditorViewMode.edit && _editSession.focusNode.hasFocus) {
      _scheduleScrollEditCaretAboveIme();
    }
  }

  Widget _buildViewModeTabs(AppLocalizations l10n) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildViewModeTab(
            label: l10n.modeLive,
            icon: Icons.vertical_split_outlined,
            selected: _viewMode == EditorViewMode.live,
            onTap: () => unawaited(_setViewMode(EditorViewMode.live)),
          ),
          _buildViewModeTab(
            label: l10n.modeEdit,
            icon: Icons.edit_outlined,
            selected: _viewMode == EditorViewMode.edit,
            onTap: () => unawaited(_setViewMode(EditorViewMode.edit)),
          ),
          _buildViewModeTab(
            label: l10n.modePreview,
            icon: Icons.visibility_outlined,
            selected: _viewMode == EditorViewMode.preview,
            onTap: () => unawaited(_setViewMode(EditorViewMode.preview)),
          ),
        ],
      ),
    );
  }

  Widget _buildViewModeTab({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = selected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onLiveInputStabilizing() {
    final alreadyDeferring = _liveSession.deferFocusBlur;
    final alreadyFocused = _liveSession.hadFocus;
    _liveSession.deferFocusBlur = true;
    if (!_liveSession.hadFocus) {
      _liveSession.hadFocus = true;
    }
    // 仅在工具栏可见性真正变化时重建，避免已聚焦换块时整页 setState。
    if (!alreadyFocused || !alreadyDeferring) {
      debugTimelineSync('Editor.toolbarStabilize', () {
        setState(() {});
      });
    }
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        _liveSession.deferFocusBlur = false;
      }
    });
  }

  void _onLiveToolbarPointerDown() {
    _onLiveInputStabilizing();
  }

  Widget _buildMarkdownToolbar() {
    if (_viewMode == EditorViewMode.live) {
      final liveState = _liveEditorKey.currentState;
      return LiveMarkdownToolbar(
        focusNode: _liveSession.focusNode,
        onPrepareToolbarAction: _onLiveToolbarPointerDown,
        onPrepareInlineAction: () => liveState?.captureForInlineAction(),
        onHeading: (level) => liveState?.applyHeading(level),
        onBulletList: () => liveState?.applyBulletList(),
        onOrderedList: () => liveState?.applyOrderedList(),
        onQuote: () => liveState?.applyQuote(),
        onParagraph: () => liveState?.applyParagraph(),
        onBold: () => liveState?.applyBold(),
        onItalic: () => liveState?.applyItalic(),
        onInlineCode: () => liveState?.applyInlineCode(),
        onInsertLink: () => unawaited(_insertMarkdownLink()),
        onInsertImage: _activeMemoId != null
            ? () => unawaited(_pickAndInsertImage())
            : null,
      );
    }

    return MarkdownToolbar(
      controller: _contentController,
      focusNode: _editSession.focusNode,
      onInsertLink: () => unawaited(_insertMarkdownLink()),
      onInsertImage: _activeMemoId != null
          ? () => unawaited(_pickAndInsertImage())
          : null,
    );
  }

  Widget _buildEditorContent(AppLocalizations l10n, bool isWide) {
    if (_isInitializing) {
      return const Center(child: CircularProgressIndicator());
    }

    final isPreview = _viewMode == EditorViewMode.preview;
    final isLive = _viewMode == EditorViewMode.live;
    final isEditing = !isPreview;
    final outline = Theme.of(context).colorScheme.outlineVariant;
    final layoutTransition =
        _liveEditorKey.currentState?.layoutTransitionActive ?? false;
    final liveInputSession = isLive &&
        (_liveSession.inputSessionActive || layoutTransition);
    // ????? viewInsets?????????????????????

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isWide && isEditing) ...[
            _buildMarkdownToolbar(),
            const SizedBox(height: 8),
          ],
          // ????????????????/??/????????????
          _buildViewModeTabs(l10n),
          Expanded(
            // Stack??????????????????????? LayoutBuilder/ListView?
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: isPreview
                      ? DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(color: outline),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: _buildPreviewPane(),
                          ),
                        )
                      : isLive
                          ? DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border.all(color: outline),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LiveMarkdownEditor(
                                  key: _liveEditorKey,
                                  controller: _contentController,
                                  focusNode: _liveSession.focusNode,
                                  scrollController:
                                      _liveSession.scrollController,
                                  keyboardBottomInset:
                                      _settledImeKeyboardInset,
                                  toolbarKeyboardInset:
                                      _toolbarImeKeyboardInset,
                                  memoFilePath:
                                      _memoById(_activeMemoId ?? '')?.filePath,
                                  resolveLocalImage:
                                      defaultMemoMarkdownImageResolver,
                                  onInputStabilizing: _onLiveInputStabilizing,
                                  onLinkTap: (href) =>
                                      unawaited(_openMarkdownLink(href)),
                                  resolveLinkLabel: _resolveMarkdownLinkLabel,
                                  onUndo: () {
                                    if (_documentHistory.canUndo) {
                                      _undo();
                                    }
                                  },
                                  onRedo: () {
                                    if (_documentHistory.canRedo) {
                                      _redo();
                                    }
                                  },
                                ),
                              ),
                            )
                          : _buildContentField(),
                ),
                if (!isWide && isEditing)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _KeyboardAwareMarkdownToolbar(
                      sessionActive: isLive
                          ? liveInputSession
                          : _editSession.focusNode.hasFocus,
                      keyboardInset: _toolbarImeKeyboardInset,
                      child: _buildMarkdownToolbar(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainArea(AppLocalizations l10n, bool isWide) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isWide)
          ClipRect(
            child: AnimatedContainer(
              duration: _sidebarExpandDuration,
              curve: Curves.easeInOut,
              width: _sidebarReveal.expanded ? _sidebarWidth : 0,
              onEnd: _onSidebarWidthAnimationEnded,
              child: _sidebarReveal.shouldBuildPanel
                  ? _buildFilePanel(onCollapseSidebar: _collapseSidebar)
                  : const SizedBox.shrink(),
            ),
          ),
        if (isWide && _sidebarReveal.expanded) const VerticalDivider(width: 1),
        if (isWide && !_sidebarReveal.expanded) _buildSidebarExpandHandle(l10n),
        Expanded(child: _buildEditorContent(l10n, isWide)),
      ],
    );
  }

  Widget _buildTitleField(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final bodyStyle = theme.textTheme.bodyLarge;
    final titleStyle = bodyStyle?.copyWith(
      fontSize: (bodyStyle.fontSize ?? 16) + 2,
      fontWeight: FontWeight.w500,
      height: bodyStyle.height,
    );
    return TextField(
      controller: _titleController,
      focusNode: _titleFocusNode,
      decoration: InputDecoration(
        hintText: l10n.untitled,
        hintStyle: titleStyle?.copyWith(
          fontWeight: FontWeight.normal,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      style: titleStyle,
      textInputAction: TextInputAction.next,
      onSubmitted: (_) => _activeBodyFocus.requestFocus(),
    );
  }

  Widget _buildContentField() {
    final theme = Theme.of(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    // 仅用 session settle 后的 inset；勿订阅 MediaQuery.viewInsets。
    final keyboardInset = _editSession.keyboardBottomInset;
    final isWide =
        MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint;
    // 窄屏工具栏叠在键盘上方；宽屏工具栏在编辑区顶部，不占底部。
    // IME 用视口下方 spacer（对齐实时尾部 spacer），勿塞进 contentPadding 当底遮罩。
    final imeSpacer = editImeBottomSpacerHeight(
      keyboardInset: keyboardInset,
      focused: _editSession.focusNode.hasFocus,
      includeToolbar: !isWide,
    );
    final boxBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(
        color: theme.colorScheme.outlineVariant,
        width: 1,
      ),
    );
    // 与实时 ListView：基础底距 + 安全区；IME 高度在 Column spacer。
    final contentBottom = editFieldContentBottomPadding(
      bottomSafe: bottomSafe,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: TextField(
            key: _contentFieldKey,
            controller: _contentController,
            focusNode: _editSession.focusNode,
            scrollController: _editSession.scrollController,
            decoration: InputDecoration(
              border: boxBorder,
              enabledBorder: boxBorder,
              focusedBorder: boxBorder,
              contentPadding: EdgeInsets.fromLTRB(16, 16, 16, contentBottom),
            ),
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            keyboardType: TextInputType.multiline,
            style: theme.textTheme.bodyLarge,
            // spacer 已抬高视口底边；仅保留光标间隙给框架 bringIntoView。
            scrollPadding: const EdgeInsets.only(bottom: kImeCaretGap),
          ),
        ),
        if (imeSpacer > 0) SizedBox(height: imeSpacer),
      ],
    );
  }

  Widget _buildPreviewPane() {
    return MemoMarkdownPreview(
      content: _contentController.text,
      memoFilePath: _memoById(_activeMemoId ?? '')?.filePath,
      resolveLocalImage: defaultMemoMarkdownImageResolver,
      onLinkTap: (href) => unawaited(_openMarkdownLink(href)),
      resolveLinkLabel: _resolveMarkdownLinkLabel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final media = MediaQuery.of(context);
    final isWide = media.size.width >= kWideLayoutBreakpoint;
    final edgeDragWidth = drawerEdgeDragWidthFor(
      screenWidth: media.size.width,
      leftSafePadding: media.padding.left,
    );
    final view = View.of(context);
    final insetBottomLogical = view.viewInsets.bottom / view.devicePixelRatio;

    return Scaffold(
      key: _scaffoldKey,
      resizeToAvoidBottomInset: false,
      drawerEdgeDragWidth: isWide ? null : edgeDragWidth,
      // 方案 A：侧滑只认系统 IME inset；有焦点/光标仍可在键盘收起后侧滑。
      // inset 越过阈值时由 _syncDrawerOpenDragGestureGate 触发重建。
      drawerEnableOpenDragGesture: drawerOpenDragGestureEnabled(
        isWide: isWide,
        insetBottomLogical: insetBottomLogical,
      ),
      onDrawerChanged: isWide ? null : _onDrawerChanged,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        toolbarHeight: 48,
        title: _buildAppBarTitle(l10n, isWide),
      ),
      drawer: isWide
          ? null
          : Drawer(
              child: MediaQuery.removeViewInsets(
                removeBottom: true,
                context: context,
                child: RepaintBoundary(
                  child: SafeArea(child: _buildFilePanel()),
                ),
              ),
            ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: _buildMainArea(l10n, isWide),
      ),
    );
  }
}

class _TrashRestoreDialog extends StatefulWidget {
  const _TrashRestoreDialog({required this.items});

  final List<TrashItem> items;

  @override
  State<_TrashRestoreDialog> createState() => _TrashRestoreDialogState();
}

class _TrashRestoreDialogState extends State<_TrashRestoreDialog> {
  final _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.restoreTrashTitle),
      content: SizedBox(
        width: 360,
        height: 360,
        child: ListView.builder(
          itemCount: widget.items.length,
          itemBuilder: (context, index) {
            final item = widget.items[index];
            final checked = _selected.contains(item.id);
            return CheckboxListTile(
              value: checked,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selected.add(item.id);
                  } else {
                    _selected.remove(item.id);
                  }
                });
              },
              title: Text(item.displayTitle(l10n.untitled)),
              controlAffinity: ListTileControlAffinity.leading,
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
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.of(context).pop(Set<String>.from(_selected)),
          child: Text(l10n.confirm),
        ),
      ],
    );
  }
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initialTitle});

  final String initialTitle;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.renameTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: l10n.renameLabel,
          hintText: l10n.renameHint,
          border: const OutlineInputBorder(),
        ),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.confirm),
        ),
      ],
    );
  }
}

class _LinkInsertDialog extends StatefulWidget {
  const _LinkInsertDialog({
    this.initialText = '',
    required this.memos,
    this.currentMemoId,
    required this.useRelativeFileHref,
  });

  final String initialText;
  final List<Memo> memos;
  final String? currentMemoId;
  final bool useRelativeFileHref;

  @override
  State<_LinkInsertDialog> createState() => _LinkInsertDialogState();
}

class _LinkInsertDialogState extends State<_LinkInsertDialog> {
  late final TextEditingController _urlController;
  late final TextEditingController _textController;
  late final FocusNode _urlFocusNode;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
    _textController = TextEditingController(text: widget.initialText);
    _urlFocusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _urlFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _urlFocusNode.dispose();
    _urlController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop((
      url: _urlController.text,
      text: _textController.text,
    ));
  }

  List<Memo> get _selectableMemos {
    final currentId = widget.currentMemoId;
    if (currentId == null) {
      return widget.memos;
    }
    return widget.memos.where((m) => m.id != currentId).toList(growable: false);
  }

  Future<void> _pickDocument() async {
    final l10n = AppLocalizations.of(context)!;
    final candidates = _selectableMemos;
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.linkNoOtherDocuments)));
      return;
    }

    final selected = await showModalBottomSheet<Memo>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.55;
        return SafeArea(
          child: SizedBox(
            height: maxHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                    l10n.linkSelectDocumentTitle,
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: candidates.length,
                    itemBuilder: (context, index) {
                      final memo = candidates[index];
                      final title = memo.displayTitle(l10n.untitled);
                      return ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: Text(title),
                        onTap: () => Navigator.of(sheetContext).pop(memo),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected == null || !mounted) {
      return;
    }

    final title = selected.displayTitle(l10n.untitled);
    final href = MarkdownLinkActions.hrefForMemo(
      memo: selected,
      useRelativeFileHref: widget.useRelativeFileHref,
      untitledLabel: l10n.untitled,
    );
    setState(() {
      _urlController.text = href;
      _textController.text = title;
    });
    _urlFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final urlHint = widget.useRelativeFileHref
        ? l10n.linkUrlHintDesktop
        : l10n.linkUrlHintMobile;
    return AlertDialog(
      title: Text(l10n.linkDialogTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: _pickDocument,
              icon: const Icon(Icons.folder_open_outlined),
              label: Text(l10n.linkSelectDocument),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlController,
              focusNode: _urlFocusNode,
              decoration: InputDecoration(
                labelText: l10n.linkUrlLabel,
                hintText: urlHint,
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              decoration: InputDecoration(
                labelText: l10n.linkTextLabel,
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.confirm),
        ),
      ],
    );
  }
}


/// 编辑模式监听键盘 metrics，驱动光标滚出遮挡区（与实时模式同源策略）。
class _EditKeyboardMetricsObserver with WidgetsBindingObserver {
  _EditKeyboardMetricsObserver(this.onMetricsChanged);

  final VoidCallback onMetricsChanged;

  @override
  void didChangeMetrics() => onMetricsChanged();
}

/// 窄屏底部工具栏：跟随 [_toolbarImeKeyboardInset]。
///
/// 展开：键盘 pending 静止后一次性写入 inset（同一次打开不爬升高度）；
/// 收起：与正文 dismissImmediate 同拍清零。
class _KeyboardAwareMarkdownToolbar extends StatelessWidget {
  const _KeyboardAwareMarkdownToolbar({
    required this.sessionActive,
    required this.keyboardInset,
    required this.child,
  });

  /// 输入会话是否激活（聚焦 / 实时过渡宽限等）。
  final bool sessionActive;

  /// 与正文 settle 同拍的工具栏贴齐高度（逻辑像素）。
  final ValueListenable<double> keyboardInset;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: keyboardInset,
      builder: (context, inset, _) {
        if (!sessionActive || inset <= 0) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: EdgeInsets.only(bottom: inset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 4),
              Material(
                elevation: 4,
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
                clipBehavior: Clip.antiAlias,
                child: child,
              ),
            ],
          ),
        );
      },
    );
  }
}
