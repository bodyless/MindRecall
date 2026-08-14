import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:mind_recall/core/debug/cursor_debug_hud.dart';
import 'package:mind_recall/core/debug/debug_timeline.dart';
import 'package:mind_recall/core/debug/ime_debug_hud.dart';
import 'package:mind_recall/core/debug/ime_timeline.dart';
import 'package:mind_recall/core/markdown/markdown.dart';
import 'package:mind_recall/app_layout_constants.dart';

/// 基于 [MdBlock] AST 的块级实时 Markdown 编辑器。
///
/// 与持有 Markdown 源码的父级 [TextEditingController] 双向同步。
/// 使用固定 Overlay 单例 [MdBlockEditorField]，换块时不销毁 [TextField] 以保持焦点。
class LiveMarkdownEditor extends StatefulWidget {
  const LiveMarkdownEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.scrollController,
    this.keyboardBottomInset,
    this.toolbarKeyboardInset,
    this.memoFilePath,
    this.resolveLocalImage,
    this.onInputStabilizing,
    this.onUndo,
    this.onRedo,
    this.onLinkTap,
    this.resolveLinkLabel,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ScrollController scrollController;

  /// 正文尾部 spacer 的 settled 键盘高度（打开时先写此值并滚入）。
  ///
  /// 未提供时自建 notifier（单测 / 独立宿主）。
  final ValueNotifier<double>? keyboardBottomInset;

  /// 窄屏工具栏贴齐高度；与正文 settled inset 同拍写入（键盘就绪即显栏）。
  final ValueNotifier<double>? toolbarKeyboardInset;
  final String? memoFilePath;
  final MarkdownImageResolver? resolveLocalImage;

  /// 换块/拆行等导致短暂失焦时通知父级，便于保持键盘工具栏与 IME 稳定。
  final VoidCallback? onInputStabilizing;

  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final ValueChanged<String>? onLinkTap;
  final String? Function(String href)? resolveLinkLabel;

  @override
  State<LiveMarkdownEditor> createState() => LiveMarkdownEditorState();
}

class LiveMarkdownEditorState extends State<LiveMarkdownEditor> {
  static const _activeEditorKey = ValueKey<String>('live-active-editor');
  static const _activeFocusKey = ValueKey<String>('live-active-focus');
  static const _syncToParentDebounce = Duration(milliseconds: 120);
  static const _scrollIntoViewDuration = Duration(milliseconds: 250);
  static const _imageDeleteButtonInset = 4.0;
  static const _imageDeleteIconSize = 18.0;
  static const _imageDeleteTapPadding = 6.0;

  final _activeFieldController = TextEditingController();
  final _idGenerator = MdBlockIdGenerator();
  final _activeOverlayLink = LayerLink();
  final _contentStackKey = GlobalKey();
  final _overlayStackKey = GlobalKey();
  final Map<String, GlobalKey> _blockSlotKeys = {};

  List<MdBlock> _blocks = [];
  String? _activeBlockId;
  bool _syncingToParent = false;
  bool _programmaticFieldUpdate = false;
  bool _splitInProgress = false;
  bool _layoutTransitionActive = false;
  Timer? _saveTimer;
  String? _capturedPlainText;
  TextSelection? _capturedSelection;
  String? _lastExpandedText;
  TextSelection? _lastExpandedSelection;
  bool _activeOverlayInView = true;
  /// 非活动块 InkWell 的 onTapDown 全局坐标；激活时映射为落点 caret。
  Offset? _pendingActivateTapGlobal;
  /// IME 滚入每帧最多调度一次。
  bool _keyboardScrollScheduled = false;
  /// 键盘 metrics 收稳后最终对齐留白并滚入一次。
  Timer? _keyboardSettleTimer;
  /// 打开时工具栏独立「静止后一次性显栏」（与正文 settle 解耦）。
  Timer? _toolbarRevealTimer;
  bool _firstBuildTraced = false;
  /// 已提交的键盘遮挡高度；经 ValueNotifier 驱动尾部 spacer，避免整树 setState。
  late final ValueNotifier<double> _keyboardBottomInset;
  late final bool _ownsKeyboardBottomInset;
  /// 与 inset 合并驱动 spacer；聚焦不再 setState 整棵块树。
  final ValueNotifier<bool> _imeSessionFocused = ValueNotifier<bool>(false);
  double _pendingKeyboardInset = 0;
  /// 启动当前 settle 计时器时的 pending；小变化不重置计时。
  double _imeSettleArmedPending = 0;
  /// 工具栏显栏计时武装时的 pending。
  double _toolbarRevealArmedPending = 0;
  /// 本轮 IME metrics 爆发起点（用于 Timeline burstMs）。
  int? _imeBurstStartMs;
  int _imeSettleResetCount = 0;

  @override
  void initState() {
    super.initState();
    _ownsKeyboardBottomInset = widget.keyboardBottomInset == null;
    _keyboardBottomInset =
        widget.keyboardBottomInset ?? ValueNotifier<double>(0);
    WidgetsBinding.instance.addObserver(_keyboardMetricsObserver);
    _activeFieldController.addListener(_onActiveFieldChanged);
    widget.controller.addListener(_onExternalControllerChanged);
    widget.focusNode.addListener(_onEditorFocusChanged);
    widget.scrollController.addListener(_onScrollForOverlayVisibility);
    _imeSessionFocused.value = widget.focusNode.hasFocus;
    _loadFromMarkdown(widget.controller.text, preferLastBlock: true);
  }

  late final _KeyboardMetricsObserver _keyboardMetricsObserver =
      _KeyboardMetricsObserver(_onKeyboardMetricsChanged);

  void _commitKeyboardInset(double logical, {String? reason}) {
    final changed = _keyboardBottomInset.value != logical;
    if (changed) {
      _keyboardBottomInset.value = logical;
      imeTimelineCommit(
        ImeTimelineScope.live,
        pendingLogical: _pendingKeyboardInset,
        committedLogical: logical,
        reason: reason,
      );
    }
    // 收起：工具栏与正文同拍隐藏。
    if (logical <= 0) {
      _setToolbarKeyboardInset(0);
    }
  }

  void _setToolbarKeyboardInset(double logical) {
    final toolbar = widget.toolbarKeyboardInset;
    if (toolbar == null || toolbar.value == logical) {
      return;
    }
    toolbar.value = logical;
  }

  double get _toolbarInsetLogical => widget.toolbarKeyboardInset?.value ?? 0;

  void _cancelToolbarRevealTimer() {
    _toolbarRevealTimer?.cancel();
    _toolbarRevealTimer = null;
  }

  /// 打开：pending 真正静止后一次性显栏；已显示则不再改高度。
  void _armToolbarRevealTimer() {
    final toolbar = widget.toolbarKeyboardInset;
    if (toolbar == null) {
      return;
    }
    if (!shouldRevealImeToolbarOnce(
      pendingLogical: _pendingKeyboardInset,
      toolbarLogical: toolbar.value,
    )) {
      _cancelToolbarRevealTimer();
      return;
    }
    _toolbarRevealTimer?.cancel();
    _toolbarRevealArmedPending = _pendingKeyboardInset;
    _toolbarRevealTimer = Timer(kImeToolbarOpenSettleDelay, () {
      if (!mounted || !widget.focusNode.hasFocus) {
        return;
      }
      final next = _pendingKeyboardInset;
      if (!shouldRevealImeToolbarOnce(
        pendingLogical: next,
        toolbarLogical: toolbar.value,
      )) {
        return;
      }
      _setToolbarKeyboardInset(next);
      imeTimelineCommit(
        ImeTimelineScope.toolbar,
        pendingLogical: next,
        committedLogical: next,
        reason: 'revealOnce',
      );
      _publishImeDebugHud(
        burstMs: DateTime.now().millisecondsSinceEpoch - (_imeBurstStartMs ?? 0),
        focused: true,
        lastCommitReason: 'toolbarReveal',
      );
    });
  }

  /// 打开过程中跟手重武装工具栏显栏计时（正文 settle 仍用 8px/48ms）。
  void _maybeArmToolbarRevealDuringOpen() {
    final toolbar = widget.toolbarKeyboardInset;
    if (toolbar == null) {
      return;
    }
    if (!shouldRevealImeToolbarOnce(
      pendingLogical: _pendingKeyboardInset,
      toolbarLogical: toolbar.value,
    )) {
      _cancelToolbarRevealTimer();
      return;
    }
    final hadActive = _toolbarRevealTimer?.isActive ?? false;
    final restart = !hadActive ||
        shouldRestartImeToolbarOpenSettle(
          pendingLogical: _pendingKeyboardInset,
          armedPendingLogical: _toolbarRevealArmedPending,
        );
    if (restart) {
      _armToolbarRevealTimer();
    }
  }

  /// 屏上 IME HUD（仅 debug）；[lastCommitReason] 为 null 时保留上次 reason。
  void _publishImeDebugHud({
    required int burstMs,
    required bool focused,
    String? lastCommitReason,
  }) {
    publishImeDebugHud(
      scope: ImeTimelineScope.live,
      pendingLogical: _pendingKeyboardInset,
      committedLogical: _keyboardBottomInset.value,
      toolbarLogical: _toolbarInsetLogical,
      burstMs: burstMs,
      settleResetCount: _imeSettleResetCount,
      settleActive: (_keyboardSettleTimer?.isActive ?? false) ||
          (_toolbarRevealTimer?.isActive ?? false),
      focused: focused,
      lastCommitReason: lastCommitReason,
    );
  }

  /// settle 后单次上推（工具栏已在 commit 同拍显示，不再延后显栏）。
  void _scheduleSettleNudge() {
    if (_keyboardScrollScheduled) {
      return;
    }
    _keyboardScrollScheduled = true;
    imeTimelineScroll(ImeTimelineScope.live, reason: 'settle');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _keyboardScrollScheduled = false;
      if (!mounted || !widget.focusNode.hasFocus) {
        return;
      }
      // settle 路径只用 nudge，避免 ensureVisible 再造一拍。
      _nudgeActiveBlockAboveIme();
    });
  }

  void _armImeSettleTimer({required int burstOriginMs}) {
    _keyboardSettleTimer?.cancel();
    _imeSettleArmedPending = _pendingKeyboardInset;
    _keyboardSettleTimer = Timer(kImeInsetSettleDelay, () {
      if (!mounted || !widget.focusNode.hasFocus) {
        return;
      }
      final settleBurstMs =
          DateTime.now().millisecondsSinceEpoch - burstOriginMs;
      final willCommit = shouldCommitImeInset(
        pendingLogical: _pendingKeyboardInset,
        committedLogical: _keyboardBottomInset.value,
      );
      imeTimelineSettle(
        ImeTimelineScope.live,
        pendingLogical: _pendingKeyboardInset,
        committedLogical: _keyboardBottomInset.value,
        burstMs: settleBurstMs,
        settleResetCount: _imeSettleResetCount,
        willCommit: willCommit,
      );
      // 回调读最新 pending：末段小步进未重置计时时仍能吃到最终高度。
      if (!willCommit) {
        return;
      }
      final next = _pendingKeyboardInset;
      // 正文 settle 只改留白；工具栏由静止后 revealOnce 单独弹出。
      _commitKeyboardInset(next, reason: 'settle');
      _publishImeDebugHud(
        burstMs: settleBurstMs,
        focused: true,
        lastCommitReason: 'settle',
      );
      if (next > 0) {
        _scheduleSettleNudge();
      }
    });
  }

  void _onKeyboardMetricsChanged() {
    if (!mounted) {
      return;
    }
    final view = View.of(context);
    final inset = view.viewInsets.bottom / view.devicePixelRatio;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final hadActiveSettle = _keyboardSettleTimer?.isActive ?? false;
    if (!hadActiveSettle) {
      _imeBurstStartMs = nowMs;
      _imeSettleResetCount = 0;
    }
    _pendingKeyboardInset = widget.focusNode.hasFocus ? inset : 0;
    final burstOriginMs = _imeBurstStartMs ?? nowMs;
    final burstMs = nowMs - burstOriginMs;

    if (!widget.focusNode.hasFocus) {
      _keyboardSettleTimer?.cancel();
      _cancelToolbarRevealTimer();
      // 短暂失焦且键盘仍在：保留 settled inset 给窄屏工具栏；
      // spacer 已由 _imeSessionFocused=false 归零。键盘落尽再清。
      if (inset <= 0.5) {
        _commitKeyboardInset(0, reason: 'unfocused');
      }
      imeTimelineMetrics(
        ImeTimelineScope.live,
        pendingLogical: _pendingKeyboardInset,
        committedLogical: _keyboardBottomInset.value,
        burstMs: burstMs,
        settleResetCount: _imeSettleResetCount,
        focused: false,
      );
      _publishImeDebugHud(
        burstMs: burstMs,
        focused: false,
        lastCommitReason: inset <= 0.5 ? 'unfocused' : null,
      );
      return;
    }

    // 收起：立刻清留白与工具栏，避免再等 settle。
    if (shouldCommitImeDismissImmediately(
      pendingLogical: _pendingKeyboardInset,
      committedLogical: _keyboardBottomInset.value,
    )) {
      _keyboardSettleTimer?.cancel();
      _cancelToolbarRevealTimer();
      _commitKeyboardInset(0, reason: 'dismissImmediate');
      imeTimelineMetrics(
        ImeTimelineScope.live,
        pendingLogical: _pendingKeyboardInset,
        committedLogical: _keyboardBottomInset.value,
        burstMs: burstMs,
        settleResetCount: _imeSettleResetCount,
        focused: true,
      );
      _publishImeDebugHud(
        burstMs: burstMs,
        focused: true,
        lastCommitReason: 'dismissImmediate',
      );
      return;
    }

    final restart = !hadActiveSettle ||
        shouldRestartImeSettleTimer(
          pendingLogical: _pendingKeyboardInset,
          armedPendingLogical: _imeSettleArmedPending,
        );
    if (restart) {
      if (hadActiveSettle) {
        _imeSettleResetCount++;
      }
      _armImeSettleTimer(burstOriginMs: burstOriginMs);
    }
    _maybeArmToolbarRevealDuringOpen();

    imeTimelineMetrics(
      ImeTimelineScope.live,
      pendingLogical: _pendingKeyboardInset,
      committedLogical: _keyboardBottomInset.value,
      burstMs: burstMs,
      settleResetCount: _imeSettleResetCount,
      focused: true,
    );
    _publishImeDebugHud(burstMs: burstMs, focused: true);
  }

  @override
  void didUpdateWidget(covariant LiveMarkdownEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onEditorFocusChanged);
      widget.focusNode.addListener(_onEditorFocusChanged);
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onExternalControllerChanged);
      widget.controller.addListener(_onExternalControllerChanged);
      _loadFromMarkdown(widget.controller.text, preferLastBlock: true);
    }
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_onScrollForOverlayVisibility);
      widget.scrollController.addListener(_onScrollForOverlayVisibility);
    }
  }

  /// 换块/拆行等布局过渡中；父级可据此避免误判失焦。
  bool get layoutTransitionActive => _layoutTransitionActive;

  void _markLayoutTransition() {
    debugTimelineSync('Live.markLayoutTransition', () {
      _layoutTransitionActive = true;
      widget.onInputStabilizing?.call();
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          _layoutTransitionActive = false;
        }
      });
    });
  }

  /// 换块/工具栏操作后保持输入焦点，并在帧末滚入可视区域。
  ///
  /// [notifyParent] 为 false 时不触发父级 setState（已聚焦换块场景），
  /// 避免与 IME/键盘动画叠加重建。
  void _stabilizeInputFocus({bool force = false, bool notifyParent = true}) {
    if (notifyParent) {
      _markLayoutTransition();
    } else {
      _layoutTransitionActive = true;
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          _layoutTransitionActive = false;
        }
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _scrollActiveBlockIntoView();
      if (!widget.focusNode.canRequestFocus) {
        return;
      }
      if (force || !widget.focusNode.hasFocus) {
        restoreFocus();
      }
    });
    if (force) {
      for (final delayMs in [16, 50, 120]) {
        Future.delayed(Duration(milliseconds: delayMs), () {
          if (mounted &&
              widget.focusNode.canRequestFocus &&
              !widget.focusNode.hasFocus) {
            restoreFocus();
          }
        });
      }
    }
  }

  /// 换块等操作导致短暂失焦后，重新请求输入焦点。
  void restoreFocus() {
    if (!mounted || !widget.focusNode.canRequestFocus) {
      return;
    }
    widget.focusNode.requestFocus();
  }

  void _onEditorFocusChanged() {
    if (!mounted) {
      return;
    }
    if (!widget.focusNode.hasFocus) {
      _keyboardSettleTimer?.cancel();
      _pendingKeyboardInset = 0;
      _imeSessionFocused.value = false;
      _publishLiveCursorDebugHud();
      // 短暂失焦勿清 settled inset：spacer 已靠 focused=false 归零；
      // 窄屏工具栏共用该 notifier，须等 dismissImmediate / 会话结束再清。
      return;
    }
    // 只通知 spacer；禁止 setState 重建全部块槽。
    _imeSessionFocused.value = true;
    _publishLiveCursorDebugHud();
    // 键盘已在时立刻滚；正在弹出则等 metrics settle，避免动画中途乱滚。
    if (_keyboardBottomInset.value > 0 || _pendingKeyboardInset > 0) {
      _scheduleScrollActiveIntoView(reason: 'focusGained');
    }
  }

  void _scheduleScrollActiveIntoView({String? reason}) {
    if (_keyboardScrollScheduled) {
      return;
    }
    _keyboardScrollScheduled = true;
    imeTimelineScroll(ImeTimelineScope.live, reason: reason);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _keyboardScrollScheduled = false;
      if (mounted && widget.focusNode.hasFocus) {
        _scrollActiveBlockIntoView();
      }
    });
  }

  static const _estimatedBlockExtent = 40.0;

  /// 聚焦时底部留白 = 键盘 + 工具栏 + 间隙；键盘高度在 metrics 收稳后写入 notifier。
  double get _focusedBottomScrollPadding => liveListImeSpacerHeight(
        keyboardInset: _keyboardBottomInset.value,
        focused: _imeSessionFocused.value || widget.focusNode.hasFocus,
      );

  /// 将活动块滚入可视区域（考虑键盘与底部工具栏遮挡）。
  void _scrollActiveBlockIntoView() {
    debugTimelineSync('Live.scrollIntoView', () {
      final activeId = _activeBlockId;
      if (activeId == null) {
        return;
      }
      final controller = widget.scrollController;
      if (!controller.hasClients) {
        return;
      }

      var slotContext = _blockSlotKeys[activeId]?.currentContext;
      if (slotContext == null) {
        // ListView 未构建该槽位时，先按估算高度跳到附近再确保可见。
        final index = _indexOf(activeId);
        if (index < 0) {
          return;
        }
        final estimated = (index * _estimatedBlockExtent).clamp(
          controller.position.minScrollExtent,
          controller.position.maxScrollExtent,
        );
        controller.jumpTo(estimated);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _scrollActiveBlockIntoView();
          }
        });
        return;
      }

      // 不经 MediaQuery.viewInsets，避免误订阅导致键盘动画期整树重建。
      final keyboardOpen = _keyboardBottomInset.value > 0;
      // 键盘弹出时用瞬时滚动，避免光标（Overlay）先上移而正文仍在动画中。
      // alignment 偏上：把活动块留在未被键盘/工具栏遮住的可视区。
      final useInstant = keyboardOpen || _layoutTransitionActive;
      Scrollable.ensureVisible(
        slotContext,
        alignment: keyboardOpen ? 0.12 : 0.35,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
        duration: useInstant ? Duration.zero : _scrollIntoViewDuration,
        curve: Curves.easeOut,
      );
      // ensureVisible 按完整 viewport 计算，不知底部键盘/工具栏；帧后再上推。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _nudgeActiveBlockAboveIme();
        }
      });
    });
  }

  /// 若活动块底边仍落在键盘/工具栏遮挡区内，继续上滚。
  void _nudgeActiveBlockAboveIme() {
    final obscured = _focusedBottomScrollPadding;
    if (obscured <= 0) {
      return;
    }
    final activeId = _activeBlockId;
    if (activeId == null) {
      return;
    }
    final controller = widget.scrollController;
    if (!controller.hasClients) {
      return;
    }
    final slotContext = _blockSlotKeys[activeId]?.currentContext;
    final stackContext = _contentStackKey.currentContext;
    if (slotContext == null || stackContext == null) {
      return;
    }
    final slotBox = slotContext.findRenderObject() as RenderBox?;
    final stackBox = stackContext.findRenderObject() as RenderBox?;
    if (slotBox == null ||
        stackBox == null ||
        !slotBox.hasSize ||
        !stackBox.hasSize) {
      return;
    }

    final slotBottom = slotBox.localToGlobal(Offset(0, slotBox.size.height)).dy;
    final stackBottom = stackBox.localToGlobal(Offset(0, stackBox.size.height)).dy;
    final delta = scrollDeltaToClearIme(
      caretOrBlockGlobalBottom: slotBottom,
      viewportGlobalBottom: stackBottom,
      obscuredBottom: obscured,
    );
    if (delta <= 0) {
      return;
    }
    controller.jumpTo(
      (controller.offset + delta).clamp(
        controller.position.minScrollExtent,
        controller.position.maxScrollExtent,
      ),
    );
  }

  /// 从外部 markdown 重新加载块 AST（用于文档级撤回/重做）。
  void reloadFromMarkdown(String markdown) {
    _loadFromMarkdown(markdown);
  }

  GlobalKey _slotKeyFor(String blockId) =>
      _blockSlotKeys.putIfAbsent(blockId, GlobalKey.new);

  void _publishLiveCursorDebugHud() {
    if (!kDebugMode) {
      return;
    }
    final focused = widget.focusNode.hasFocus;
    final block = _activeBlock;
    final value = _activeFieldController.value;
    final selection = value.selection;
    if (block == null || !selection.isValid) {
      publishCursorDebugHud(
        CursorDebugSnapshot(
          mode: 'Live',
          focused: focused,
          blockCount: _blocks.length,
          blockType: block == null ? 'no block' : 'sel invalid',
        ),
      );
      return;
    }
    final index = _indexOf(block.id);
    final text = value.text;
    final caret = selection.extentOffset.clamp(0, text.length);
    final ctx = cursorDebugContextAround(text: text, caretOffset: caret);
    final composing = value.composing;
    publishCursorDebugHud(
      CursorDebugSnapshot(
        mode: 'Live',
        focused: focused,
        selectionBase: selection.baseOffset,
        selectionExtent: selection.extentOffset,
        collapsed: selection.isCollapsed,
        blockType: mdBlockDebugTypeLabel(block),
        blockIndex: index < 0 ? null : index,
        blockCount: _blocks.length,
        blockId: mdBlockDebugIdShort(block.id),
        contextBefore: ctx.before,
        contextAfter: ctx.after,
        composingStart: composing.isValid ? composing.start : null,
        composingEnd: composing.isValid ? composing.end : null,
      ),
    );
  }

  void _switchToActiveBlock({
    required String blockId,
    required TextSelection selection,
    bool notifyParent = true,
    bool forceFocus = false,
  }) {
    debugTimelineSync('Live.switchBlock', () {
      final index = _indexOf(blockId);
      if (index < 0) {
        return;
      }
      final block = _blocks[index];
      _activeBlockId = blockId;
      _updateActiveController(editableTextForBlock(block), selection);
      _publishLiveCursorDebugHud();
      if (mounted) {
        setState(() {});
      }
      // 换块类型时 TextField 周边布局曾会重挂载；force 可把 IME 拉回。
      _stabilizeInputFocus(
        force: forceFocus || notifyParent,
        notifyParent: notifyParent,
      );
    });
  }

  void _restoreFocusAfterBlockChange({bool force = false}) {
    if (!mounted || !widget.focusNode.canRequestFocus) {
      return;
    }
    if (!force && widget.focusNode.hasFocus) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.focusNode.canRequestFocus) {
        return;
      }
      if (!force && widget.focusNode.hasFocus) {
        return;
      }
      widget.focusNode.requestFocus();
    });
  }

  /// 提交活动块并将 markdown 同步到 [widget.controller]。
  void flushToParent() {
    _saveTimer?.cancel();
    _commitActiveBlock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_keyboardMetricsObserver);
    _keyboardSettleTimer?.cancel();
    _cancelToolbarRevealTimer();
    widget.focusNode.removeListener(_onEditorFocusChanged);
    widget.scrollController.removeListener(_onScrollForOverlayVisibility);
    flushToParent();
    _activeFieldController.removeListener(_onActiveFieldChanged);
    widget.controller.removeListener(_onExternalControllerChanged);
    _activeFieldController.dispose();
    if (_ownsKeyboardBottomInset) {
      _keyboardBottomInset.dispose();
    }
    _imeSessionFocused.dispose();
    super.dispose();
  }

  void _onScrollForOverlayVisibility() {
    _updateActiveOverlayVisibility();
  }

  /// 活动块滚出可视区时隐藏 Overlay，避免光标漂到列表顶部。
  void _updateActiveOverlayVisibility() {
    final visible = _isActiveBlockInViewport();
    if (visible == _activeOverlayInView) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() => _activeOverlayInView = visible);
  }

  bool _isActiveBlockInViewport() {
    final activeId = _activeBlockId;
    if (activeId == null) {
      return false;
    }
    final slotContext = _blockSlotKeys[activeId]?.currentContext;
    // ListView 尚未构建该槽位 / 布局未完成时假定可见，避免误 Offstage
    // 导致活动块（Visibility 已隐藏）出现「空行」。
    if (slotContext == null) {
      return true;
    }
    final box = slotContext.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) {
      return true;
    }
    final stackContext = _contentStackKey.currentContext;
    if (stackContext == null) {
      return true;
    }
    final stackBox = stackContext.findRenderObject();
    if (stackBox is! RenderBox || !stackBox.hasSize) {
      return true;
    }
    final topLeft = box.localToGlobal(Offset.zero, ancestor: stackBox);
    final bottom = topLeft.dy + box.size.height;
    final viewportH = stackBox.size.height;
    // 与视口略有重叠即视为可见。
    return bottom > 0 && topLeft.dy < viewportH;
  }

  int _indexOf(String blockId) => _blocks.indexWhere((b) => b.id == blockId);

  MdBlock? get _activeBlock {
    final id = _activeBlockId;
    if (id == null) {
      return null;
    }
    final index = _indexOf(id);
    if (index < 0) {
      return null;
    }
    return _blocks[index];
  }

  void _clearInlineActionCache() {
    _capturedPlainText = null;
    _capturedSelection = null;
    _lastExpandedText = null;
    _lastExpandedSelection = null;
  }

  /// 工具栏 pointer-down 时调用，在失焦前缓存选区（Android 防丢选区）。
  void captureForInlineAction() {
    var value = _activeFieldController.value;
    if (value.composing.isValid) {
      value = value.copyWith(composing: TextRange.empty);
      _activeFieldController.value = value;
    }
    _capturedPlainText = value.text;
    if (value.selection.isValid && !value.selection.isCollapsed) {
      _capturedSelection = value.selection;
    } else if (_lastExpandedText == value.text &&
        _lastExpandedSelection != null &&
        !_lastExpandedSelection!.isCollapsed) {
      _capturedSelection = _lastExpandedSelection;
    } else if (value.selection.isValid) {
      _capturedSelection = value.selection;
    } else {
      _capturedSelection = TextSelection.collapsed(offset: value.text.length);
    }
  }

  void _loadFromMarkdown(String markdown, {bool preferLastBlock = false}) {
    debugTimelineSync(
      'Live.loadFromMarkdown',
      () {
        _clearInlineActionCache();
        final preservedActiveId = _activeBlockId;
        late final ({List<MdBlock> blocks, String activeBlockId}) prepared;
        debugTimelineSync('Live.parseBlocks', () {
          prepared = prepareLiveBlocksFromMarkdown(
            markdown,
            idGenerator: _idGenerator,
            preferredActiveId: preferLastBlock ? null : preservedActiveId,
            preferLastBlock: preferLastBlock,
          );
        });
        _blocks = prepared.blocks;
        _activeBlockId = prepared.activeBlockId;
        // 换文档/重载后先显示 Overlay；帧末再按真实视口校正。
        _activeOverlayInView = true;
        _pruneBlockSlotKeys();
        _syncActiveFieldFromBlock();
        if (mounted) {
          debugTimelineSync('Live.loadSetState', () {
            setState(() {});
          });
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          _updateActiveOverlayVisibility();
        });
        // 大文档首次滑动卡顿：预热 ListView 缓存区。
        if (_blocks.length > 80) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final controller = widget.scrollController;
            if (!mounted || !controller.hasClients) {
              return;
            }
            final pos = controller.position;
            if (pos.maxScrollExtent <= 0) {
              return;
            }
            final original = pos.pixels;
            final warm = (original + 1).clamp(
              pos.minScrollExtent,
              pos.maxScrollExtent,
            );
            controller.jumpTo(warm);
            controller.jumpTo(original);
            _updateActiveOverlayVisibility();
          });
        }
      },
      arguments: {'chars': '${markdown.length}'},
    );
  }

  /// 丢弃已不在当前 AST 中的槽位 key，避免换文档后引用失效。
  void _pruneBlockSlotKeys() {
    final liveIds = _blocks.map((b) => b.id).toSet();
    _blockSlotKeys.removeWhere((id, _) => !liveIds.contains(id));
  }

  void _updateActiveController(String text, TextSelection selection) {
    final current = _activeFieldController.value;
    final start = selection.start.clamp(0, text.length);
    final end = selection.end.clamp(0, text.length);
    final newSelection = TextSelection(baseOffset: start, extentOffset: end);
    if (current.text == text && current.selection == newSelection) {
      return;
    }
    _programmaticFieldUpdate = true;
    _activeFieldController.removeListener(_onActiveFieldChanged);
    _activeFieldController.value = TextEditingValue(
      text: text,
      selection: newSelection,
      composing: TextRange.empty,
    );
    _activeFieldController.addListener(_onActiveFieldChanged);
    _programmaticFieldUpdate = false;
  }

  void _syncActiveFieldFromBlock({TextSelection? selection}) {
    final block = _activeBlock;
    if (block == null) {
      return;
    }
    final text = editableTextForBlock(block);
    _updateActiveController(
      text,
      selection ?? TextSelection.collapsed(offset: text.length),
    );
  }

  void _syncToParentDeferred() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncToParent();
      }
    });
  }

  void _onExternalControllerChanged() {
    if (_syncingToParent) {
      return;
    }
    final serialized = serializeMdBlocks(_blocks);
    if (widget.controller.text == serialized) {
      return;
    }
    _loadFromMarkdown(widget.controller.text);
  }

  /// 将活动输入框内容同步回块 AST。
  ///
  /// 含行内格式时必须用 [applyPlainTextChange]，勿用 plain text 直接覆盖。
  void _onActiveFieldChanged() {
    if (_programmaticFieldUpdate) {
      return;
    }
    _publishLiveCursorDebugHud();
    final activeId = _activeBlockId;
    if (activeId == null) {
      return;
    }
    final index = _indexOf(activeId);
    if (index < 0) {
      return;
    }

    final value = _activeFieldController.value;
    if (value.selection.isValid && !value.selection.isCollapsed) {
      _lastExpandedSelection = value.selection;
      _lastExpandedText = value.text;
    }

    final text = value.text;
    final previous = _blocks[index];
    MdBlock block = previous;

    final triggered = applyBlockTrigger(block, text);
    if (triggered != null) {
      block = triggered;
      final markdownChanged = inlineMarkdownForBlock(block) !=
          inlineMarkdownForBlock(previous);
      final typeChanged = block.runtimeType != previous.runtimeType;
      _blocks[index] = block;
      _scheduleSyncToParent();
      if (mounted &&
          (typeChanged ||
              markdownChanged ||
              hasRenderedInlineFormatting(block) ||
              hasRenderedInlineFormatting(previous))) {
        if (typeChanged) {
          _markLayoutTransition();
        }
        setState(() {});
      }
      if (text != block.plainText) {
        final plain = block.plainText;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _activeBlockId != activeId) {
            return;
          }
          _updateActiveController(
            plain,
            TextSelection.collapsed(offset: plain.length),
          );
        });
      }
      return;
    } else if (text.isEmpty && block is! ParagraphBlock) {
      if (index > 0) {
        final previous = _blocks[index - 1];
        final previousText = editableTextForBlock(previous);
        _blocks.removeAt(index);
        _maybeRenumberOrderedBlocksAfterRemoval(index);
        _scheduleSyncToParent(immediate: true);
        _switchToActiveBlock(
          blockId: previous.id,
          selection: TextSelection.collapsed(offset: previousText.length),
        );
        return;
      }
      block = ParagraphBlock(id: block.id, text: '');
    } else {
      final normalized =
          isSingleLineBlock(block) ? text.split('\n').first : text;
      if (supportsInlineFormatting(block)) {
        final previousPlain = editableTextForBlock(previous);
        if (normalized != previousPlain) {
          block = block.copyWithPlainText(
            applyPlainTextChange(
              markdown: inlineMarkdownForBlock(previous),
              previousPlain: previousPlain,
              newPlain: normalized,
            ),
          );
        }
      } else {
        block = block.copyWithPlainText(normalized);
      }
    }

    final markdownChanged = inlineMarkdownForBlock(block) !=
        inlineMarkdownForBlock(previous);
    final typeChanged = block.runtimeType != previous.runtimeType;
    _blocks[index] = block;
    _scheduleSyncToParent();
    if (mounted &&
        (typeChanged ||
            markdownChanged ||
            hasRenderedInlineFormatting(block) ||
            hasRenderedInlineFormatting(previous))) {
      setState(() {});
    }
  }

  void _scheduleSyncToParent({bool immediate = false}) {
    _saveTimer?.cancel();
    if (immediate) {
      _syncToParent();
      return;
    }
    _saveTimer = Timer(_syncToParentDebounce, _syncToParent);
  }

  void _syncToParent() {
    _syncingToParent = true;
    final markdown = serializeMdBlocks(_blocks);
    if (widget.controller.text != markdown) {
      widget.controller.value = widget.controller.value.copyWith(
        text: markdown,
        selection: TextSelection.collapsed(offset: markdown.length),
        composing: TextRange.empty,
      );
    }
    _syncingToParent = false;
  }

  void _activateBlock(String blockId) {
    debugTimelineSync('Live.activateBlock', () {
      if (blockId == _activeBlockId) {
        _pendingActivateTapGlobal = null;
        restoreFocus();
        return;
      }
      debugTimelineSync('Live.commitActive', _commitActiveBlock);
      _clearInlineActionCache();
      final nextIndex = _indexOf(blockId);
      if (nextIndex < 0) {
        _pendingActivateTapGlobal = null;
        return;
      }
      final previousId = _activeBlockId;
      final previousIndex =
          previousId == null ? -1 : _indexOf(previousId);
      final typeChanged = previousIndex >= 0 &&
          _blocks[previousIndex].runtimeType !=
              _blocks[nextIndex].runtimeType;
      final nextBlock = _blocks[nextIndex];
      final text = editableTextForBlock(nextBlock);
      final caretOffset = _consumeActivateTapPlainOffset(
            block: nextBlock,
            plainText: text,
          ) ??
          text.length;
      // 已聚焦时换块不必通知父级整页 setState，减轻与 IME 弹出的叠加卡顿。
      final alreadyFocused = widget.focusNode.hasFocus;
      _switchToActiveBlock(
        blockId: blockId,
        selection: TextSelection.collapsed(offset: caretOffset),
        notifyParent: !alreadyFocused,
        // 不同类型块切换时强制抢回焦点，避免 IME 被系统收起。
        forceFocus: typeChanged || alreadyFocused,
      );
      _activeOverlayInView = true;
      _scheduleScrollActiveIntoView();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _updateActiveOverlayVisibility();
        }
      });
    });
  }

  /// 消费非活动块点击坐标，映射为 plain caret；失败则清空并返回 null。
  int? _consumeActivateTapPlainOffset({
    required MdBlock block,
    required String plainText,
  }) {
    final global = _pendingActivateTapGlobal;
    _pendingActivateTapGlobal = null;
    if (global == null || block is ImageBlock) {
      return null;
    }
    final slotContext = _slotKeyFor(block.id).currentContext;
    if (slotContext == null) {
      return null;
    }
    final displayMarkdown =
        supportsInlineFormatting(block) ? inlineMarkdownForBlock(block) : null;
    return plainOffsetAtGlobalTap(
      slotRoot: slotContext.findRenderObject(),
      globalPosition: global,
      plainText: plainText,
      findBodyParagraph: _findBodyParagraph,
      displayMarkdown: displayMarkdown,
      resolveLinkLabel: widget.resolveLinkLabel,
    );
  }

  /// 删除指定块（实时模式图片 × 等）；删空后补空段落。
  void _deleteBlockById(String blockId) {
    final index = _indexOf(blockId);
    if (index < 0) {
      return;
    }
    _saveTimer?.cancel();
    _clearInlineActionCache();
    if (_activeBlockId == blockId) {
      // 图片块无 plain 编辑内容，无需 commit 文本。
      if (_blocks[index] is! ImageBlock) {
        _commitActiveBlock();
      }
    } else {
      _commitActiveBlock();
    }

    final removed = removeBlockAt(
      _blocks,
      index: index,
      idGenerator: _idGenerator,
    );
    _blocks = removed.blocks;
    final next = _blocks[removed.activeIndex];
    _syncToParent();
    _switchToActiveBlock(
      blockId: next.id,
      selection: TextSelection.collapsed(
        offset: editableTextForBlock(next).length,
      ),
      forceFocus: next is! ImageBlock,
    );
  }

  /// 粘贴含换行的 Markdown（预览复制的列表等）到活动块选区。
  void pasteMarkdownAtCaret(String pastedMarkdown) {
    final activeId = _activeBlockId;
    if (activeId == null) {
      return;
    }
    final index = _indexOf(activeId);
    if (index < 0) {
      return;
    }
    _saveTimer?.cancel();
    _clearInlineActionCache();

    final block = _blocks[index];
    final plain = _activeFieldController.text;
    final selection = _activeFieldController.selection;
    final start = selection.isValid
        ? selection.start.clamp(0, plain.length)
        : plain.length;
    final end = selection.isValid
        ? selection.end.clamp(0, plain.length)
        : plain.length;
    final before = plain.substring(0, start);
    final after = plain.substring(end);

    final pasted = pasteMarkdownIntoBlocks(
      blocks: _blocks,
      activeIndex: index,
      activeBlock: block,
      beforePlain: before,
      afterPlain: after,
      pastedMarkdown: pastedMarkdown,
      idGenerator: _idGenerator,
    );
    _blocks = pasted.blocks;
    final next = _blocks[pasted.activeIndex];
    _syncToParent();
    _switchToActiveBlock(
      blockId: next.id,
      selection: TextSelection.collapsed(
        offset: editableTextForBlock(next).length,
      ),
      forceFocus: true,
    );
  }

  String _resolvedInlineMarkdown(MdBlock block, String plainText) {
    return resolvedInlineMarkdownForEdit(block, plainText);
  }

  void _commitActiveBlock() {
    _saveTimer?.cancel();
    final activeId = _activeBlockId;
    if (activeId == null) {
      return;
    }
    final index = _indexOf(activeId);
    if (index < 0) {
      return;
    }
    final block = _blocks[index];
    _blocks[index] = commitPlainToBlock(block, _activeFieldController.text);
    _syncToParent();
  }

  /// 在 plain 光标处拆分活动块（Enter）。
  void splitBlockAt(int cursorOffset) {
    if (_splitInProgress) {
      return;
    }
    _splitInProgress = true;
    _saveTimer?.cancel();
    _clearInlineActionCache();
    final activeId = _activeBlockId;
    if (activeId == null) {
      _splitInProgress = false;
      return;
    }
    final index = _indexOf(activeId);
    if (index < 0) {
      _splitInProgress = false;
      return;
    }

    final block = _blocks[index];
    if (!supportsMultilineEditing(block)) {
      _insertSingleLineBlockBelow(index, cursorOffset);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _splitInProgress = false;
      });
      return;
    }

    final plainText = _activeFieldController.text;
    final cursor = cursorOffset.clamp(0, plainText.length);
    final resolvedMarkdown = resolvedInlineMarkdownForEdit(block, plainText);
    final split = splitMultilineBlockAt(
      blocks: _blocks,
      index: index,
      resolvedMarkdownBeforeEdit: resolvedMarkdown,
      plainCursor: cursor,
      idGenerator: _idGenerator,
    );
    _blocks = split.blocks;

    _syncToParentDeferred();
    _switchToActiveBlock(
      blockId: split.newActiveId,
      selection: TextSelection.collapsed(offset: 0),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _splitInProgress = false;
    });
  }

  void _insertSingleLineBlockBelow(int index, int cursorOffset) {
    _commitActiveBlock();
    final text = _activeFieldController.text;
    final cursor = cursorOffset.clamp(0, text.length);
    final before = text.substring(0, cursor);
    final after = text.substring(cursor);

    final inserted = insertBlockBelowSingleLine(
      blocks: _blocks,
      index: index,
      beforePlain: before,
      afterPlain: after,
      idGenerator: _idGenerator,
    );
    _blocks = inserted.blocks;

    _syncToParentDeferred();
    _switchToActiveBlock(
      blockId: inserted.newActiveId,
      selection: TextSelection.collapsed(offset: 0),
    );
  }

  int _orderedRunStart(int index) => orderedRunStart(_blocks, index);

  void _renumberOrderedBlocksFrom(int start) {
    renumberOrderedBlocksFrom(_blocks, start);
  }

  void _maybeRenumberOrderedBlocksAfterRemoval(int removedAtIndex) {
    renumberOrderedBlocksAfterRemoval(_blocks, removedAtIndex);
  }

  void insertBlockBelow() {
    final activeId = _activeBlockId;
    if (activeId == null) {
      return;
    }
    final cursor = _activeFieldController.selection.baseOffset;
    splitBlockAt(cursor);
  }

  void _handleBackspaceAtBlockStart() {
    final activeId = _activeBlockId;
    if (activeId == null) {
      return;
    }
    final index = _indexOf(activeId);
    if (index < 0) {
      return;
    }

    final text = _activeFieldController.text;
    final cursor = _activeFieldController.selection.baseOffset;
    if (cursor != 0) {
      return;
    }

    _saveTimer?.cancel();

    // 文档首块：行首 Backspace 取消列表/标题等块级样式，而非无操作。
    if (index == 0) {
      final block = _blocks[index];
      if (text.isEmpty) {
        if (block is! ParagraphBlock) {
          _blocks[index] = ParagraphBlock(id: block.id, text: '');
          setState(() => _syncActiveFieldFromBlock());
          _syncToParentDeferred();
        }
        return;
      }
      if (isSingleLineBlock(block)) {
        _blocks[index] = reparseBlockFromLineMarkdown(
          block,
          lineMarkdown: applyParagraphLineMarkdown(block.toMarkdown()),
        );
        setState(() => _syncActiveFieldFromBlock());
        _syncToParentDeferred();
        return;
      }
      return;
    }

    if (text.isEmpty) {
      final previous = _blocks[index - 1];
      final hasNext = index + 1 < _blocks.length;
      _blocks.removeAt(index);
      _maybeRenumberOrderedBlocksAfterRemoval(index);
      if (previous is ParagraphBlock) {
        _blocks[index - 1] = previous.copyWith(continuesWithNext: hasNext);
      }
      final previousText = editableTextForBlock(_blocks[index - 1]);
      _syncToParentDeferred();
      _switchToActiveBlock(
        blockId: _blocks[index - 1].id,
        selection: TextSelection.collapsed(offset: previousText.length),
      );
    } else {
      final previous = _blocks[index - 1];
      final current = _blocks[index];
      final previousPlain = editableTextForBlock(previous);
      final mergedMarkdown = mergeInlineMarkdown(
        inlineMarkdownForBlock(previous),
        _resolvedInlineMarkdown(current, text),
      );
      final inheritFlow =
          current is ParagraphBlock && current.continuesWithNext;
      _blocks[index - 1] = copyWithContinuesWithNext(
        copyBlockInlineMarkdown(previous, mergedMarkdown),
        continuesWithNext: inheritFlow,
      );
      _blocks.removeAt(index);
      _maybeRenumberOrderedBlocksAfterRemoval(index);
      _syncToParentDeferred();
      _switchToActiveBlock(
        blockId: previous.id,
        selection: TextSelection.collapsed(offset: previousPlain.length),
      );
    }
  }

  bool _isShortcutModifierPressed() {
    final keyboard = HardwareKeyboard.instance;
    return keyboard.isControlPressed || keyboard.isMetaPressed;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final composing = _activeFieldController.value.composing;
    if (composing.isValid) {
      return KeyEventResult.ignored;
    }

    if (_isShortcutModifierPressed()) {
      final key = event.logicalKey;
      final keyboard = HardwareKeyboard.instance;
      if (key == LogicalKeyboardKey.keyB) {
        applyBold();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyI) {
        applyItalic();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.backquote) {
        applyInlineCode();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyZ && !keyboard.isShiftPressed) {
        widget.onUndo?.call();
        return KeyEventResult.handled;
      }
      if ((key == LogicalKeyboardKey.keyY) ||
          (key == LogicalKeyboardKey.keyZ && keyboard.isShiftPressed)) {
        widget.onRedo?.call();
        return KeyEventResult.handled;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.enter &&
        !HardwareKeyboard.instance.isShiftPressed) {
      final block = _activeBlock;
      if (block != null && isSingleLineBlock(block)) {
        final cursor = _activeFieldController.selection.baseOffset;
        splitBlockAt(cursor);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace &&
        _activeFieldController.selection.isCollapsed &&
        _activeFieldController.selection.baseOffset == 0) {
      _handleBackspaceAtBlockStart();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void applyHeading(int level) {
    _applyLineMarkdownTransform((line) => applyHeadingLineMarkdown(line, level));
  }

  void applyBulletList() {
    _applyLineMarkdownTransform(applyBulletLineMarkdown);
  }

  void applyOrderedList() {
    _applyLineMarkdownTransform(applyOrderedLineMarkdown);
  }

  void applyQuote() {
    _applyLineMarkdownTransform(applyQuoteLineMarkdown);
  }

  void applyParagraph() {
    _applyLineMarkdownTransform(applyParagraphLineMarkdown);
  }

  void applyBold() => _applyInlineStyle(InlineStyle.bold);

  void applyItalic() => _applyInlineStyle(InlineStyle.italic);

  void applyInlineCode() => _applyInlineStyle(InlineStyle.code);

  /// 在选区包裹或于光标处插入 Markdown 链接。
  void applyLink({required String url, String? displayText}) {
    final activeId = _activeBlockId;
    if (activeId == null) {
      return;
    }
    final index = _indexOf(activeId);
    if (index < 0) {
      return;
    }
    final block = _blocks[index];
    if (!supportsInlineFormatting(block)) {
      return;
    }

    _saveTimer?.cancel();
    final usedCapture = _capturedPlainText != null;
    var plainText = _capturedPlainText ?? _activeFieldController.text;
    var selection = _capturedSelection ?? _activeFieldController.selection;
    _capturedPlainText = null;
    _capturedSelection = null;

    if (!usedCapture &&
        selection.isValid &&
        selection.isCollapsed &&
        _lastExpandedSelection != null &&
        _lastExpandedText == plainText) {
      selection = _lastExpandedSelection!;
    }
    if (!selection.isValid) {
      selection = TextSelection.collapsed(offset: plainText.length);
    }

    final selStart = selection.start.clamp(0, plainText.length);
    final selEnd = selection.end.clamp(0, plainText.length);
    final selected = selStart == selEnd
        ? ''
        : plainText.substring(
            selStart < selEnd ? selStart : selEnd,
            selStart < selEnd ? selEnd : selStart,
          );
    final label = (displayText != null && displayText.trim().isNotEmpty)
        ? displayText.trim()
        : (selected.isNotEmpty ? selected : url);

    final blockMarkdown = inlineMarkdownForBlock(block);
    final blockPlain = plainTextFromInlines(parseInlineMarkdown(blockMarkdown));
    final markdownSource =
        blockPlain == plainText ? blockMarkdown : plainText;
    final start = selStart < selEnd ? selStart : selEnd;
    final end = selStart < selEnd ? selEnd : selStart;
    final nodes = parseInlineMarkdown(markdownSource);
    final (beforeNodes, rest) = splitInlineNodesAt(nodes, start);
    final (_, afterNodes) = splitInlineNodesAt(rest, end - start);
    final newMarkdown = serializeInlineMarkdown([
      ...beforeNodes,
      LinkInline(label: label, href: url),
      ...afterNodes,
    ]);

    _blocks[index] = copyBlockInlineMarkdown(block, newMarkdown);
    final display = plainTextFromInlines(parseInlineMarkdown(newMarkdown));
    final caret = (start + label.length).clamp(0, display.length);
    setState(() {
      _syncActiveFieldFromBlock(
        selection: TextSelection.collapsed(offset: caret),
      );
    });
    _syncToParent();
    _stabilizeInputFocus(force: true);
  }

  void _applyInlineStyle(InlineStyle style) {
    final activeId = _activeBlockId;
    if (activeId == null) {
      return;
    }
    final index = _indexOf(activeId);
    if (index < 0) {
      return;
    }
    final block = _blocks[index];
    if (!supportsInlineFormatting(block)) {
      return;
    }

    _saveTimer?.cancel();

    final usedCapture = _capturedPlainText != null;
    var plainText = _capturedPlainText ?? _activeFieldController.text;
    var selection =
        _capturedSelection ?? _activeFieldController.selection;
    _capturedPlainText = null;
    _capturedSelection = null;

    if (!usedCapture &&
        selection.isValid &&
        selection.isCollapsed &&
        _lastExpandedSelection != null &&
        _lastExpandedText == plainText) {
      selection = _lastExpandedSelection!;
    }

    if (!selection.isValid) {
      selection = TextSelection.collapsed(offset: plainText.length);
    }

    var selStart = selection.start.clamp(0, plainText.length);
    var selEnd = selection.end.clamp(0, plainText.length);
    if (selStart > selEnd) {
      final temp = selStart;
      selStart = selEnd;
      selEnd = temp;
    }

    if (selStart == selEnd) {
      return;
    }

    final blockMarkdown = inlineMarkdownForBlock(block);
    final blockPlain = plainTextFromInlines(parseInlineMarkdown(blockMarkdown));
    final markdownSource =
        blockPlain == plainText ? blockMarkdown : plainText;

    final inlines = parseInlineMarkdown(markdownSource);
    final updated = applyInlineStyle(
      inlines,
      selStart,
      selEnd,
      style,
    );
    final markdown = serializeInlineMarkdown(updated);
    if (markdown == markdownSource) {
      return;
    }

    _blocks[index] = copyBlockInlineMarkdown(_blocks[index], markdown);

    final displayText = plainTextFromInlines(parseInlineMarkdown(markdown));
    final newSelection = TextSelection(
      baseOffset: selStart.clamp(0, displayText.length),
      extentOffset: selEnd.clamp(0, displayText.length),
    );

    setState(() {
      _syncActiveFieldFromBlock(selection: newSelection);
    });
    _syncToParent();
    _stabilizeInputFocus(force: true);
  }

  void _applyLineMarkdownTransform(
    String Function(String lineMarkdown) transform,
  ) {
    _commitActiveBlock();
    final activeId = _activeBlockId;
    if (activeId == null) {
      return;
    }
    var index = _indexOf(activeId);
    if (index < 0) {
      return;
    }

    var block = _blocks[index];
    if (block is ParagraphBlock && block.text.contains('\n')) {
      final split = splitMultilineParagraphAtPlainOffset(
        block: block,
        plainOffset: _activeFieldController.selection.baseOffset,
        idGenerator: _idGenerator,
      );
      _blocks.removeAt(index);
      _blocks.insertAll(index, split.blocks);
      index += split.activeLineIndex;
      block = _blocks[index];
      _activeBlockId = block.id;
    }

    final newLineMd = transform(block.toMarkdown());
    final reparsed = reparseBlockFromLineMarkdown(
      block,
      lineMarkdown: newLineMd,
    );
    final typeChanged = reparsed.runtimeType != block.runtimeType;
    final oldPlain = editableTextForBlock(block);
    final newPlain = editableTextForBlock(reparsed);
    _blocks[index] = reparsed;
    if (reparsed is OrderedBlock) {
      _renumberOrderedBlocksFrom(_orderedRunStart(index));
    }
    final selection = _activeFieldController.selection;
    if (newPlain != oldPlain || newPlain != _activeFieldController.text) {
      _updateActiveController(
        newPlain,
        selection.isValid
            ? TextSelection(
                baseOffset: selection.start.clamp(0, newPlain.length),
                extentOffset: selection.end.clamp(0, newPlain.length),
              )
            : TextSelection.collapsed(offset: newPlain.length),
      );
    }
    if (mounted && typeChanged) {
      setState(() {});
    } else if (reparsed is OrderedBlock) {
      setState(() {});
    }
    _syncToParentDeferred();
    _stabilizeInputFocus(force: typeChanged);
  }

  Widget _buildBlockSlot(
    MdBlock block, {
    MdBlock? previous,
    required bool isActive,
  }) {
    Widget buildRenderer(MdBlock displayBlock) {
      return Padding(
        padding: MdBlockStyles.slotPaddingFor(displayBlock, previous: previous),
        child: MdBlockRenderer(
          block: displayBlock,
          memoFilePath: widget.memoFilePath,
          resolveLocalImage: widget.resolveLocalImage,
          onLinkTap: widget.onLinkTap,
          resolveLinkLabel: widget.resolveLinkLabel,
        ),
      );
    }

    // 图片块：点击选中后右上角显示 ×，不走透明 TextField Overlay。
    if (block is ImageBlock) {
      final imageBody = Stack(
        clipBehavior: Clip.none,
        children: [
          buildRenderer(block),
          if (isActive)
            Positioned(
              top: _imageDeleteButtonInset,
              right: _imageDeleteButtonInset,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _deleteBlockById(block.id),
                child: const Material(
                  color: Colors.black54,
                  shape: CircleBorder(),
                  child: Padding(
                    padding: EdgeInsets.all(_imageDeleteTapPadding),
                    child: Icon(
                      Icons.close,
                      size: _imageDeleteIconSize,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
      final content = isActive
          ? imageBody
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTapDown: (details) {
                  _pendingActivateTapGlobal = details.globalPosition;
                },
                onTap: () => _activateBlock(block.id),
                borderRadius: BorderRadius.circular(4),
                child: imageBody,
              ),
            );
      return KeyedSubtree(
        key: _slotKeyFor(block.id),
        child: RepaintBoundary(child: content),
      );
    }

    // 活动块：列表内渲染层跟 controller 更新（所见即所得），Overlay 只叠透明输入框。
    final content = isActive
        ? ListenableBuilder(
            listenable: _activeFieldController,
            builder: (context, _) =>
                buildRenderer(_displayBlockForActiveField(block)),
          )
        : Material(
            color: Colors.transparent,
            child: InkWell(
              onTapDown: (details) {
                _pendingActivateTapGlobal = details.globalPosition;
              },
              onTap: () => _activateBlock(block.id),
              borderRadius: BorderRadius.circular(4),
              child: buildRenderer(block),
            ),
          );

    // 每块始终挂 key；活动块同时作为 Overlay 的 LayerLink 锚点。
    final keyed = KeyedSubtree(
      key: _slotKeyFor(block.id),
      child: RepaintBoundary(child: content),
    );
    if (isActive) {
      return CompositedTransformTarget(
        link: _activeOverlayLink,
        child: keyed,
      );
    }
    return keyed;
  }

  /// 将活动输入框中的 plain text 映射为用于列表渲染的块（不写回 AST）。
  MdBlock _displayBlockForActiveField(MdBlock block) {
    final plain = _activeFieldController.text;
    if (supportsInlineFormatting(block)) {
      final previousPlain = editableTextForBlock(block);
      if (plain == previousPlain) {
        return block;
      }
      final markdown = applyPlainTextChange(
        markdown: inlineMarkdownForBlock(block),
        previousPlain: previousPlain,
        newPlain: plain,
      );
      return copyBlockInlineMarkdown(block, markdown);
    }
    if (plain == block.plainText) {
      return block;
    }
    return block.copyWithPlainText(plain);
  }

  @override
  Widget build(BuildContext context) {
    if (!_firstBuildTraced) {
      _firstBuildTraced = true;
      debugTimelineInstant('Live.firstBuild');
    }
    final activeId = _activeBlockId;
    final activeBlock = _activeBlock;
    final activeIndex =
        activeId == null ? -1 : _blocks.indexWhere((b) => b.id == activeId);
    // ListView 不包在 LayoutBuilder 内，避免键盘/Drawer 约束抖动触发整表 rebuild。
    // Overlay 单独用 LayoutBuilder 只算宽度；锚点已在 ListView padding 内，勿再加左缩进。
    // IME 留白放尾部 spacer（ValueNotifier），避免改 padding / setState 重建全部块槽。
    const listPadding = EdgeInsets.fromLTRB(16, 12, 16, kEditorBodyBottomPadding);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;

    return Stack(
      key: _contentStackKey,
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        ListView.builder(
          controller: widget.scrollController,
          padding: listPadding.copyWith(
            bottom: listPadding.bottom + bottomSafe,
          ),
          cacheExtent: 1600,
          itemCount: _blocks.length + 1,
          itemBuilder: (context, i) {
            if (i == _blocks.length) {
              return ListenableBuilder(
                listenable: Listenable.merge([
                  _keyboardBottomInset,
                  _imeSessionFocused,
                ]),
                builder: (context, _) {
                  return SizedBox(
                    height: liveListImeSpacerHeight(
                      keyboardInset: _keyboardBottomInset.value,
                      focused: _imeSessionFocused.value,
                    ),
                  );
                },
              );
            }
            return Padding(
              padding: EdgeInsets.only(
                bottom: MdBlockStyles.bottomSpacingFor(_blocks[i]),
              ),
              child: _buildBlockSlot(
                _blocks[i],
                previous: i > 0 ? _blocks[i - 1] : null,
                isActive: _blocks[i].id == activeId,
              ),
            );
          },
        ),
        if (activeBlock != null && activeBlock is! ImageBlock)
          LayoutBuilder(
            builder: (context, constraints) {
              // 锚点已在 ListView content 区内，宽度与 list children 约束一致。
              final overlayWidth =
                  (constraints.maxWidth - listPadding.horizontal)
                      .clamp(0.0, double.infinity);
              return CompositedTransformFollower(
                link: _activeOverlayLink,
                showWhenUnlinked: false,
                child: Offstage(
                  offstage: !_activeOverlayInView,
                  // 必须按内容收缩高度：Stack 会给满屏 maxHeight，否则透明
                  // TextField 命中区盖住下方所有块，导致点不到其它块。
                  child: Align(
                    alignment: Alignment.topLeft,
                    widthFactor: 1.0,
                    heightFactor: 1.0,
                    child: SizedBox(
                      width: overlayWidth,
                      child: Stack(
                        key: _overlayStackKey,
                        clipBehavior: Clip.none,
                        children: [
                          Padding(
                            padding: MdBlockStyles.slotPaddingFor(
                              activeBlock,
                              previous: activeIndex > 0
                                  ? _blocks[activeIndex - 1]
                                  : null,
                            ),
                            child: Focus(
                              key: _activeFocusKey,
                              onKeyEvent: _handleKeyEvent,
                              child: MdBlockEditorField(
                                key: _activeEditorKey,
                                block: activeBlock,
                                controller: _activeFieldController,
                                focusNode: widget.focusNode,
                                onSplitBlockAt: splitBlockAt,
                                onPasteMarkdown: pasteMarkdownAtCaret,
                                resolveLocalImage: widget.resolveLocalImage,
                                onLinkTap: widget.onLinkTap,
                                resolveLinkLabel: widget.resolveLinkLabel,
                                chromeless: true,
                              ),
                            ),
                          ),
                          // 光标按列表内 MdBlockRenderer 实测位置绘制，避免透明
                          // TextField 与 rich text 字形宽度不一致造成「字后空白」。
                          _RendererSyncedCaret(
                            slotKey: _slotKeyFor(activeBlock.id),
                            overlayKey: _overlayStackKey,
                            controller: _activeFieldController,
                            focusNode: widget.focusNode,
                            cursorColor: Theme.of(context).colorScheme.primary,
                            resolveLinkLabel: widget.resolveLinkLabel,
                            displayMarkdownOf: () {
                              final block = _activeBlock;
                              if (block == null ||
                                  !supportsInlineFormatting(block)) {
                                return null;
                              }
                              return inlineMarkdownForBlock(
                                _displayBlockForActiveField(block),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// 将 [didChangeMetrics] 从 State 中拆出，避免 State 直接 mix-in 增加耦合。
class _KeyboardMetricsObserver with WidgetsBindingObserver {
  _KeyboardMetricsObserver(this.onMetricsChanged);

  final VoidCallback onMetricsChanged;

  @override
  void didChangeMetrics() => onMetricsChanged();
}

/// 按列表内渲染层 [RenderParagraph] 实测位置绘制光标。
///
/// chromeless 透明 [TextField] 与 [MdInlineText]（粗体描边、链接标题等）字形宽度
/// 不一致时，系统光标会看起来浮在字后空白处；删除却仍作用于最后一个实字符。
class _RendererSyncedCaret extends StatefulWidget {
  const _RendererSyncedCaret({
    required this.slotKey,
    required this.overlayKey,
    required this.controller,
    required this.focusNode,
    required this.cursorColor,
    required this.displayMarkdownOf,
    this.resolveLinkLabel,
  });

  final GlobalKey slotKey;
  final GlobalKey overlayKey;
  final TextEditingController controller;
  final FocusNode focusNode;
  final Color cursorColor;
  final String? Function() displayMarkdownOf;
  final String? Function(String href)? resolveLinkLabel;

  @override
  State<_RendererSyncedCaret> createState() => _RendererSyncedCaretState();
}

class _RendererSyncedCaretState extends State<_RendererSyncedCaret> {
  static const _caretWidth = 2.0;
  static const _blinkPeriod = Duration(milliseconds: 500);

  Timer? _blinkTimer;
  bool _caretVisible = true;
  Offset? _caretTopLeft;
  double _caretHeight = 0;
  bool _measureScheduled = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextOrSelectionChanged);
    widget.focusNode.addListener(_onFocusChanged);
    _onFocusChanged();
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(covariant _RendererSyncedCaret oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextOrSelectionChanged);
      widget.controller.addListener(_onTextOrSelectionChanged);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChanged);
      widget.focusNode.addListener(_onFocusChanged);
      _onFocusChanged();
    }
    _scheduleMeasure();
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    widget.controller.removeListener(_onTextOrSelectionChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onTextOrSelectionChanged() {
    _restartBlink();
    _scheduleMeasure();
  }

  void _onFocusChanged() {
    if (widget.focusNode.hasFocus) {
      _restartBlink();
    } else {
      _blinkTimer?.cancel();
      _blinkTimer = null;
      _caretVisible = false;
    }
    _scheduleMeasure();
  }

  void _restartBlink() {
    _caretVisible = true;
    _blinkTimer?.cancel();
    _blinkTimer = Timer.periodic(_blinkPeriod, (_) {
      if (!mounted) {
        return;
      }
      setState(() => _caretVisible = !_caretVisible);
    });
    if (mounted) {
      setState(() {});
    }
  }

  void _scheduleMeasure() {
    if (_measureScheduled) {
      return;
    }
    _measureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureScheduled = false;
      if (!mounted) {
        return;
      }
      _measureCaret();
    });
  }

  void _measureCaret() {
    if (!widget.focusNode.hasFocus) {
      if (_caretTopLeft != null) {
        setState(() {
          _caretTopLeft = null;
          _caretHeight = 0;
        });
      }
      return;
    }

    final selection = widget.controller.selection;
    if (!selection.isValid || !selection.isCollapsed) {
      if (_caretTopLeft != null) {
        setState(() {
          _caretTopLeft = null;
          _caretHeight = 0;
        });
      }
      return;
    }

    final overlayBox =
        widget.overlayKey.currentContext?.findRenderObject() as RenderBox?;
    final slotContext = widget.slotKey.currentContext;
    if (overlayBox == null || !overlayBox.hasSize || slotContext == null) {
      return;
    }

    final plain = widget.controller.text;
    final paragraph = _findBodyParagraph(
      slotContext.findRenderObject(),
      plainText: plain,
    );
    if (paragraph == null) {
      // 无正文段落时清掉旧坐标，避免换块后光标仍停在上一块的 X。
      if (_caretTopLeft != null) {
        setState(() {
          _caretTopLeft = null;
          _caretHeight = 0;
        });
      }
      return;
    }

    final displayText = paragraph.text.toPlainText();
    // 空块占位「 」：逻辑 offset 0 对应显示首部。
    final displayOffset = plain.isEmpty
        ? 0
        : _plainOffsetToDisplayOffset(
            plainOffset: selection.extentOffset.clamp(0, plain.length),
            plainText: plain,
            displayText: displayText,
            displayMarkdown: widget.displayMarkdownOf(),
            resolveLinkLabel: widget.resolveLinkLabel,
          );

    const caretPrototype = Rect.fromLTWH(0, 0, _caretWidth, 1);
    final localCaret = paragraph.getOffsetForCaret(
      TextPosition(offset: displayOffset),
      caretPrototype,
    );
    final height = paragraph.getFullHeightForCaret(
      TextPosition(offset: displayOffset),
    );
    if (height <= 0) {
      return;
    }

    final global = paragraph.localToGlobal(localCaret);
    final topLeft = overlayBox.globalToLocal(global);
    if (_caretTopLeft != topLeft || _caretHeight != height) {
      setState(() {
        _caretTopLeft = topLeft;
        _caretHeight = height;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final topLeft = _caretTopLeft;
    if (!_caretVisible || topLeft == null || _caretHeight <= 0) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: topLeft.dx,
      top: topLeft.dy,
      child: IgnorePointer(
        child: Container(
          width: _caretWidth,
          height: _caretHeight,
          color: widget.cursorColor,
        ),
      ),
    );
  }
}

RenderParagraph? _findBodyParagraph(
  RenderObject? root, {
  required String plainText,
}) {
  if (root == null) {
    return null;
  }
  final paragraphs = <RenderParagraph>[];
  void visit(RenderObject node) {
    if (node is RenderParagraph) {
      paragraphs.add(node);
    }
    node.visitChildren(visit);
  }

  visit(root);
  if (paragraphs.isEmpty) {
    return null;
  }

  // 空块占位是透明空格「 」；勿误用列表「• 」前缀段落。
  if (plainText.isEmpty) {
    for (final paragraph in paragraphs) {
      final text = paragraph.text.toPlainText();
      if (text == ' ' || text == '\u200B' || text.isEmpty) {
        return paragraph;
      }
    }
    for (final paragraph in paragraphs) {
      final text = paragraph.text.toPlainText();
      if (!text.startsWith('•') && !RegExp(r'^\d+\.\s').hasMatch(text)) {
        return paragraph;
      }
    }
    return paragraphs.last;
  }

  for (final paragraph in paragraphs) {
    final text = paragraph.text.toPlainText();
    if (text == plainText) {
      return paragraph;
    }
  }

  // 列表块另有「•」/「1.」前缀段落，取最宽的正文段落。
  paragraphs.sort((a, b) => b.size.width.compareTo(a.size.width));
  return paragraphs.first;
}

int _plainOffsetToDisplayOffset({
  required int plainOffset,
  required String plainText,
  required String displayText,
  required String? displayMarkdown,
  String? Function(String href)? resolveLinkLabel,
}) {
  if (plainOffset >= plainText.length) {
    return displayText.length;
  }
  if (plainText == displayText || displayMarkdown == null) {
    return plainOffset.clamp(0, displayText.length);
  }

  final nodes = parseInlineMarkdown(displayMarkdown);
  var plainRemaining = plainOffset;
  var display = 0;
  for (final node in nodes) {
    final plainLen = node.plainText.length;
    final shown = switch (node) {
      LinkInline(:final label, :final href) => linkDisplayLabel(
          label: label,
          href: href,
          resolvedTitle: resolveLinkLabel?.call(href),
        ),
      _ => node.plainText,
    };
    if (plainRemaining <= plainLen) {
      if (shown.length == plainLen) {
        return display + plainRemaining;
      }
      if (plainRemaining <= 0) {
        return display;
      }
      if (plainRemaining >= plainLen) {
        return display + shown.length;
      }
      final ratio = plainRemaining / plainLen;
      return display + (ratio * shown.length).round().clamp(0, shown.length);
    }
    plainRemaining -= plainLen;
    display += shown.length;
  }
  return display.clamp(0, displayText.length);
}
