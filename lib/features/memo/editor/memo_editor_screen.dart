import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mind_recall/app_layout_constants.dart';
import 'package:mind_recall/core/debug/cursor_debug_hud.dart';
import 'package:mind_recall/core/debug/debug_timeline.dart';
import 'package:mind_recall/core/markdown/editor/md_block_editor_field.dart';
import 'package:mind_recall/core/markdown/live_block_tap_ops.dart';
import 'package:mind_recall/core/markdown/md_block_chrome_metrics.dart';
import 'package:mind_recall/core/ui/ime_height_cache.dart';
import 'package:mind_recall/core/ui/ime_metrics_observer.dart';
import 'package:mind_recall/l10n/app_localizations.dart';

import 'package:mind_recall/features/memo/editor/markdown_link_actions.dart';
import 'package:mind_recall/features/memo/editor/document_history.dart';
import 'package:mind_recall/features/memo/editor/live/live_markdown_editor.dart';
import 'package:mind_recall/features/memo/editor/memo_workspace_controller.dart';
import 'package:mind_recall/features/memo/editor/edit_ime_coordinator.dart';
import 'package:mind_recall/features/memo/editor/mode_input_session.dart';
import 'package:mind_recall/features/memo/editor/plain_text/markdown_editor_helper.dart';
import 'package:mind_recall/features/memo/editor/widgets/markdown_toolbar.dart';
import 'package:mind_recall/features/memo/editor/widgets/memo_markdown_preview.dart';
import 'package:mind_recall/features/memo/editor/widgets/rename_memo_dialog.dart';
import 'package:mind_recall/features/memo/editor/widgets/trash_restore_dialog.dart';
import 'package:mind_recall/features/memo/editor/widgets/link_insert_dialog.dart';
import 'package:mind_recall/features/memo/editor/widgets/keyboard_aware_markdown_toolbar.dart';
import 'package:mind_recall/features/memo/sidebar/memo_file_panel_logic.dart';
import 'package:mind_recall/features/memo/memo_markdown_image_resolver.dart';
import 'package:mind_recall/features/memo/sidebar/memo_file_panel.dart';
import 'package:mind_recall/models/memo.dart';
import 'package:mind_recall/models/memo_search_result.dart';
import 'package:mind_recall/models/user_preferences.dart';
import 'package:mind_recall/services/android_process_text.dart';
import 'package:mind_recall/services/android_storage_permission.dart';
import 'package:mind_recall/services/memo_image_service.dart';
import 'package:mind_recall/services/memo_storage_service.dart';
import 'package:mind_recall/services/process_text_capture.dart';
import 'package:mind_recall/services/user_preferences_service.dart';
import 'package:mind_recall/shared/widgets/settings_panel.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
  static const _sidebarWidth = 280.0;
  static const _contentLineHeight = 24.0;
  static const _liveFocusBlurGrace = Duration(milliseconds: 400);
  static const _liveFocusRestoreWait = Duration(milliseconds: 150);
  static const _historyDebounce = Duration(milliseconds: 400);
  static const _sidebarCollapseDuration = Duration(milliseconds: 250);
  static const _sidebarExpandDuration = Duration(milliseconds: 220);
  static const _drawerImePollInterval = Duration(milliseconds: 32);

  final _storage = MemoStorageService();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _searchController = TextEditingController();
  final _titleFocusNode = FocusNode();
  final _editSession = EditInputSession();
  final _liveSession = LiveInputSession();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _liveEditorKey = GlobalKey<LiveMarkdownEditorState>();
  final _contentFieldKey = GlobalKey();

  late final MemoWorkspaceController _workspace = MemoWorkspaceController(
    titleController: _titleController,
    contentController: _contentController,
    searchController: _searchController,
  );

  late final EditImeCoordinator _editIme = EditImeCoordinator(
    session: _editSession,
    contentController: _contentController,
    contentFieldKey: _contentFieldKey,
    isMounted: () => mounted,
    isEditMode: () => _viewMode == EditorViewMode.edit,
    isSuspended: () => _editorFocusSuspended,
    isDrawerOpen: () => _drawerOpen,
    layoutWidth: () => MediaQuery.sizeOf(context).width,
    rebuild: (fn) {
      if (mounted) {
        setState(fn);
      }
    },
  );

  ValueNotifier<double> get _settledImeKeyboardInset =>
      _editIme.keyboardBottomInset;
  ValueNotifier<double> get _toolbarImeKeyboardInset =>
      _editIme.toolbarKeyboardInset;

  List<Memo> get _memos => _workspace.memos;
  List<MemoSearchResult> get _searchResults => _workspace.searchResults;
  List<String> get _pinnedMemoIds => _workspace.pinnedMemoIds;
  String? get _activeMemoId => _workspace.activeMemoId;
  SaveStatus get _saveStatus => _workspace.saveStatus;
  String? get _saveError => _workspace.saveError;
  bool get _isSearchActive => _workspace.isSearchActive;
  bool get _caseSensitive => _workspace.caseSensitive;
  bool get _isDirty => _workspace.isDirty;

  String? _appVersionLabel;
  bool _suppressAutoSave = false;
  bool _isInitializing = true;
  StreamSubscription<String>? _processTextSubscription;
  Future<void> _processTextChain = Future<void>.value();
  final _sidebarReveal = SidebarRevealState();
  EditorViewMode _viewMode = EditorViewMode.live;
  Timer? _autoSaveTimer;
  Timer? _historyTimer;
  final _documentHistory = DocumentHistory();
  bool _applyingHistory = false;

  late final ImeMetricsObserver _editKeyboardMetricsObserver =
      ImeMetricsObserver(_onEditKeyboardMetricsChanged);

  /// 侧滑开抽屉门禁：仅在系统 IME inset 越过阈值导致「可否侧滑」翻转时 setState。
  late final ImeMetricsObserver _drawerImeGateObserver =
      ImeMetricsObserver(_syncDrawerOpenDragGestureGate);

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
    _workspace.addListener(_onWorkspaceChanged);
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
    _processTextSubscription?.cancel();
    _processTextSubscription = null;
    _autoSaveTimer?.cancel();
    _historyTimer?.cancel();
    _workspace.removeListener(_onWorkspaceChanged);
    _workspace.dispose();
    _editIme.dispose();
    WidgetsBinding.instance.removeObserver(_editKeyboardMetricsObserver);
    WidgetsBinding.instance.removeObserver(_drawerImeGateObserver);
    _titleController.dispose();
    _contentController.dispose();
    _searchController.dispose();
    _titleFocusNode.dispose();
    _editSession.dispose();
    _liveSession.dispose();
    super.dispose();
  }

  /// 收起/切模式：正文留白与工具栏同拍清零。
  void _clearImeInsets() {
    _editIme.clearInsets();
  }

  void _onWorkspaceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _initializeWorkspace() async {
    await debugTimelineAsync('Editor.initWorkspace', () async {
      try {
        await debugTimelineAsync(
          'Editor.listMemos',
          _workspace.loadPinsAndList,
        );
        if (!mounted) {
          return;
        }

        if (_workspace.memos.isNotEmpty) {
          final lastOpenedId = _workspace.lastOpenedMemoId ??
              widget.prefsService.preferences.lastOpenedMemoId;
          final restoreId = lastOpenedId != null &&
                  _workspace.memos.any((memo) => memo.id == lastOpenedId)
              ? lastOpenedId
              : _workspace.memos.first.id;
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
          _subscribeProcessTextEvents();
        }
      }
    });
  }

  /// 工作区就绪后再听系统选区，避免与恢复上次文档抢跑。
  void _subscribeProcessTextEvents() {
    _processTextSubscription?.cancel();
    _processTextSubscription = AndroidProcessText.events().listen((raw) {
      _processTextChain = _processTextChain.then((_) {
        return _onCapturedProcessText(raw);
      });
    });
  }

  Future<void> _onCapturedProcessText(String raw) async {
    final text = normalizeCapturedProcessText(raw);
    if (text == null || !mounted) {
      return;
    }
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
    _suppressAutoSave = true;
    try {
      if (_viewMode == EditorViewMode.live) {
        _liveEditorKey.currentState?.flushToParent();
      }
      final memo = await _workspace.captureTextAsMemo(text);
      if (!mounted) {
        return;
      }
      _loadMemoIntoEditor(memo);
      _activeBodyFocus.requestFocus();
      _closeDrawerIfNeeded();
    } catch (error) {
      if (mounted) {
        _showMessage(AppLocalizations.of(context)!.createFailed('$error'));
      }
    } finally {
      _suppressAutoSave = false;
    }
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
    _editIme.cancelSettleTimer();
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
        _editIme.scheduleScrollCaretAboveIme();
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
    _editIme.scheduleScrollCaretAboveIme();
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
  void _onEditKeyboardMetricsChanged() {
    if (!mounted || _viewMode != EditorViewMode.edit) {
      return;
    }
    final view = View.of(context);
    final inset = view.viewInsets.bottom / view.devicePixelRatio;
    _editIme.onKeyboardMetricsChanged(
      cacheKey: imeHeightCacheKeyForView(view),
      inset: inset,
    );
  }

  Future<void> _refreshMemoList({String? selectId}) {
    return _workspace.refreshList(selectId: selectId);
  }

  void _onSearchChanged() {
    final l10n = AppLocalizations.of(context);
    if (l10n != null) {
      _workspace.untitledLabel = l10n.untitled;
    }
    _workspace.onSearchChanged();
  }

  void _onCaseSensitiveChanged(bool value) {
    final l10n = AppLocalizations.of(context);
    if (l10n != null) {
      _workspace.untitledLabel = l10n.untitled;
    }
    _workspace.setCaseSensitive(value);
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
      unawaited(_workspace.saveActive());
    });
    _workspace.markIdleIfDirty();
  }

  Future<void> _flushSave() async {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
    await _workspace.flushSave();
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

    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
    _suppressAutoSave = true;
    try {
      final memo = await debugTimelineAsync(
        'Editor.loadMemo',
        () => _workspace.openMemo(id, refreshList: refreshList),
        arguments: {'id': id},
      );
      if (!mounted) {
        return;
      }

      debugTimelineSync('Editor.loadMemoIntoEditor', () {
        _loadMemoIntoEditor(memo, jumpTarget: jumpTarget);
      });
      _closeDrawerIfNeeded();
    } catch (error) {
      _showMessage(AppLocalizations.of(context)!.openFailed('$error'));
    } finally {
      _suppressAutoSave = false;
    }
  }

  Future<void> _openSearchResult(MemoSearchResult result) async {
    await _openMemo(
      result.memoId,
      jumpTarget: result.jumpTarget,
    );
  }

  Future<void> _createNewMemo({bool refreshList = true}) async {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
    _suppressAutoSave = true;
    try {
      final memo = await _workspace.createNewMemo(refreshList: refreshList);
      if (!mounted) {
        return;
      }

      _loadMemoIntoEditor(memo);
      _activeBodyFocus.requestFocus();
      _closeDrawerIfNeeded();
    } catch (error) {
      _showMessage(AppLocalizations.of(context)!.createFailed('$error'));
    } finally {
      _suppressAutoSave = false;
    }
  }

  /// 文档已由 Controller 写入编辑器；此处只做历史重置、偏好记录与滚动。
  void _loadMemoIntoEditor(Memo memo, {MemoJumpTarget? jumpTarget}) {
    _resetDocumentHistory();
    unawaited(widget.prefsService.updateLastOpenedMemoId(memo.id));

    if (jumpTarget != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _activeMemoId == memo.id) {
          _jumpToTarget(jumpTarget);
        }
      });
    } else {
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

  Memo? _memoById(String id) => _workspace.memoById(id);

  Future<String?> _showRenameDialog(String currentTitle) {
    return showDialog<String>(
      context: context,
      builder: (context) => RenameMemoDialog(initialTitle: currentTitle),
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
      builder: (context) => LinkInsertDialog(
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

    _suppressAutoSave = true;
    try {
      await _workspace.renameMemo(id: id, newTitle: newTitle);
      if (mounted) {
        _showMessage(l10n.renamed);
      }
    } catch (error) {
      _showMessage(l10n.renameFailed('$error'));
    } finally {
      _suppressAutoSave = false;
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
      final result = await _workspace.deleteMemo(id);
      if (!mounted) {
        return;
      }

      if (result.wasActive) {
        if (result.remaining.isNotEmpty) {
          await _openMemo(result.remaining.first.id, refreshList: false);
        } else {
          await _createNewMemo(refreshList: false);
        }
      }

      _showMessage(l10n.deleted);
    } catch (error) {
      _showMessage(l10n.deleteFailed('$error'));
    }
  }

  Future<void> _togglePinMemo(String id) {
    return _workspace.togglePin(id);
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
      if (!await AndroidStoragePermission.requestIfNeeded()) {
        if (mounted) {
          _showMessage(l10n.storageAllFilesAccessRequired);
        }
        return;
      }
      final dest = await FilePicker.platform.getDirectoryPath(
        dialogTitle: l10n.exportData,
      );
      if (dest == null) {
        if (mounted) {
          _showMessage(l10n.backupPickCancelled);
        }
        return;
      }

      final result = await _workspace.exportToDirectory(
        prefsService: widget.prefsService,
        destinationParent: dest,
      );
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

      if (!await AndroidStoragePermission.requestIfNeeded()) {
        if (mounted) {
          _showMessage(l10n.storageAllFilesAccessRequired);
        }
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

      final result = await _workspace.importFromDirectory(
        prefsService: widget.prefsService,
        selectedPath: source,
      );
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
      await _workspace.emptyTrash();
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
      final items = await _workspace.listTrash();
      if (!mounted) {
        return;
      }
      if (items.isEmpty) {
        _showMessage(l10n.trashEmpty);
        return;
      }
      final selected = await showDialog<Set<String>>(
        context: context,
        builder: (context) => TrashRestoreDialog(items: items),
      );
      if (selected == null || selected.isEmpty || !mounted) {
        return;
      }
      await _workspace.restoreTrash(selected.toList());
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
    setState(() => _isInitializing = true);
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
      _editIme.scheduleScrollCaretAboveIme();
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
        onTaskList: () => liveState?.applyTaskList(),
        onQuote: () => liveState?.applyQuote(),
        onInsertThematicBreak: () => liveState?.insertThematicBreak(),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            kEditorPagePadding,
            0,
            kEditorPagePadding,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isWide && isEditing) ...[
                _buildMarkdownToolbar(),
                const SizedBox(height: 8),
              ],
              _buildViewModeTabs(l10n),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: ValueListenableBuilder<double>(
                  valueListenable: _toolbarImeKeyboardInset,
                  builder: (context, toolbarInset, _) {
                    return Padding(
                      padding: EdgeInsets.fromLTRB(
                        kEditorPagePadding,
                        0,
                        kEditorPagePadding,
                        editorPageBottomPadding(
                          imeToolbarVisible:
                              !isWide && isEditing && toolbarInset > 0.5,
                        ),
                      ),
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
                                      memoFilePath: _memoById(
                                              _activeMemoId ?? '')
                                          ?.filePath,
                                      resolveLocalImage:
                                          defaultMemoMarkdownImageResolver,
                                      onInputStabilizing:
                                          _onLiveInputStabilizing,
                                      onLinkTap: (href) =>
                                          unawaited(_openMarkdownLink(href)),
                                      resolveLinkLabel:
                                          _resolveMarkdownLinkLabel,
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
                    );
                  },
                ),
              ),
              if (!isWide && isEditing)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: KeyboardAwareMarkdownToolbar(
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
          color: theme.colorScheme.onSurfaceVariant.withValues(
            alpha: MdBlockChromeMetrics.hintColorAlpha,
          ),
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      style: titleStyle,
      textInputAction: TextInputAction.next,
      cursorWidth: kTextCaretWidth,
      selectionControls: alignedCollapsedHandleControls,
      onSubmitted: (_) => _activeBodyFocus.requestFocus(),
    );
  }

  Widget _buildContentField() {
    final theme = Theme.of(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final isWide =
        MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint;
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
    return ValueListenableBuilder<double>(
      valueListenable: _editIme.keyboardBottomInset,
      builder: (context, keyboardInset, _) {
        // 仅用 Coordinator settle 后的 inset；勿订阅 MediaQuery.viewInsets。
        final imeSpacer = editImeBottomSpacerHeight(
          keyboardInset: keyboardInset,
          focused: _editSession.focusNode.hasFocus,
          includeToolbar: !isWide,
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
                  contentPadding:
                      EdgeInsets.fromLTRB(16, 16, 16, contentBottom),
                ),
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
                style: theme.textTheme.bodyLarge,
                cursorWidth: kTextCaretWidth,
                selectionControls: alignedCollapsedHandleControls,
                // spacer 已抬高视口底边；仅保留光标间隙给框架 bringIntoView。
                scrollPadding: const EdgeInsets.only(bottom: kImeCaretGap),
              ),
            ),
            if (imeSpacer > 0) SizedBox(height: imeSpacer),
          ],
        );
      },
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
