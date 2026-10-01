import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:mind_recall/core/debug/cursor_debug_hud.dart';
import 'package:mind_recall/core/debug/debug_timeline.dart';
import 'package:mind_recall/core/debug/ime_debug_hud.dart';
import 'package:mind_recall/core/debug/ime_timeline.dart';
import 'package:mind_recall/core/debug/live_editor_timeline.dart';
import 'package:mind_recall/core/markdown/markdown.dart';
import 'package:mind_recall/app_layout_constants.dart';
import 'package:mind_recall/core/ui/ime_height_cache.dart';
import 'package:mind_recall/core/ui/ime_metrics_observer.dart';
import 'package:mind_recall/l10n/app_localizations.dart';
import 'package:mind_recall/features/memo/editor/mode_input_session.dart';

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
    this.imeHeightCache,
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

  /// IME 高度缓存；未传则用进程内 [defaultImeHeightCache]。
  final ImeHeightCache? imeHeightCache;

  /// 空正文点击填充层，便于单测点空白区聚焦。
  @visibleForTesting
  static const emptyBodyFillKey = ValueKey<String>('live-empty-body-fill');

  /// 最后一块为代码块时的文末空白点击层，点后插入并聚焦空段落。
  @visibleForTesting
  static const trailingAfterCodeFillKey = ValueKey<String>(
    'live-trailing-after-code-fill',
  );

  /// 渲染层同步的折叠水滴手柄，便于单测断言仍可见且跟光标。
  @visibleForTesting
  static const collapsedCaretHandleKey = ValueKey<String>(
    'live-collapsed-caret-handle',
  );

  /// 聚焦 Overlay 上转发垂直拖到外层列表的命中层，便于单测拖动。
  @visibleForTesting
  static const overlayListScrollKey = ValueKey<String>(
    'live-overlay-list-scroll',
  );

  /// 代码块右上角语言框，便于单测点到「python」等文字而非空白。
  @visibleForTesting
  static const codeLanguageFieldKey = ValueKey<String>(
    'live-code-language-field',
  );

  @override
  State<LiveMarkdownEditor> createState() => LiveMarkdownEditorState();
}

class LiveMarkdownEditorState extends State<LiveMarkdownEditor> {
  static const _activeEditorKey = ValueKey<String>('live-active-editor');
  static const _activeFocusKey = ValueKey<String>('live-active-focus');
  static const _syncToParentDebounce = Duration(milliseconds: 120);
  static const _scrollIntoViewDuration = Duration(milliseconds: 250);

  final _activeFieldController = TextEditingController();
  final _idGenerator = MdBlockIdGenerator();
  final _activeOverlayLink = LayerLink();
  final _contentStackKey = GlobalKey();
  final _overlayStackKey = GlobalKey();
  final Map<String, GlobalKey> _blockSlotKeys = {};

  /// 代码块语言框；获焦时不得把正文 Focus 抢回去。
  final _languageFocusNode = FocusNode(debugLabel: 'live-code-language');
  final _languageController = TextEditingController();
  bool _reconcileLiveInputFocusScheduled = false;

  List<MdBlock> _blocks = [];
  String? _activeBlockId;
  bool _syncingToParent = false;
  bool _programmaticFieldUpdate = false;
  bool _splitInProgress = false;

  /// 块首删除合并进行中，避免 KeyEvent 与 IME 清空连打两次。
  bool _blockStartMergeInProgress = false;
  bool _pendingImeBlockStartMerge = false;
  bool _layoutTransitionActive = false;
  Timer? _saveTimer;
  String? _capturedPlainText;
  TextSelection? _capturedSelection;
  String? _lastExpandedText;
  TextSelection? _lastExpandedSelection;
  bool _activeOverlayInView = true;

  /// 同块 InkWell 激活时是否丢掉了落点（仅 debug HUD / 日志）。
  bool _sameBlockTapDiscarded = false;

  /// 聚焦 Overlay 垂直拖交给外层 [ScrollPosition.drag]；取消/销毁时须 cancel。
  Drag? _overlayListScrollDrag;

  /// 非活动块 InkWell 的 onTapDown 全局坐标；激活时映射为落点 caret。
  Offset? _pendingActivateTapGlobal;

  /// IME 滚入每帧最多调度一次。
  bool _keyboardScrollScheduled = false;

  /// 最近一次滚入调度原因（ensureVisible 埋点用）。
  String? _pendingScrollReason;

  /// 活动块槽位高度基线；软换行变高时对比后决定是否 nudge。
  double? _lastActiveSlotHeight;

  /// 软换行 nudge 每帧最多调度一次。
  bool _contentWrapNudgeScheduled = false;

  /// 折叠水滴显示代数：点选/激活时 +1，caret 据此重新显示。
  int _collapsedHandleRevealTick = 0;

  /// 键盘 metrics 收稳后最终对齐留白并滚入一次。
  Timer? _keyboardSettleTimer;

  /// 无缓存时 120ms nudge 防抖；有新 settle 则重武装。
  Timer? _nudgeDebounceTimer;

  /// 缓存偏高时等真实 inset 静默后再降低。
  Timer? _cacheDownCorrectTimer;

  /// 本次打开已按缓存高度提交 spacer，避免 297 假停把 348 收回。
  bool _appliedCacheThisOpen = false;
  bool _firstBuildTraced = false;

  /// 已提交的键盘遮挡高度；经 ValueNotifier 驱动尾部 spacer，避免整树 setState。
  late final ValueNotifier<double> _keyboardBottomInset;
  late final bool _ownsKeyboardBottomInset;

  /// 与 inset 合并驱动 spacer；聚焦不再 setState 整棵块树。
  final ValueNotifier<bool> _imeSessionFocused = ValueNotifier<bool>(false);
  double _pendingKeyboardInset = 0;

  /// 启动当前 settle 计时器时的 pending；小变化不重置计时。
  double _imeSettleArmedPending = 0;

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
    _languageFocusNode.addListener(_onLanguageFocusChanged);
    widget.scrollController.addListener(_onScrollForOverlayVisibility);
    _imeSessionFocused.value = widget.focusNode.hasFocus;
    _loadFromMarkdown(widget.controller.text, preferLastBlock: true);
  }

  late final ImeMetricsObserver _keyboardMetricsObserver = ImeMetricsObserver(
    _onKeyboardMetricsChanged,
  );

  void _commitKeyboardInset(double logical, {String? reason}) {
    final previous = _keyboardBottomInset.value;
    final changed = previous != logical;
    if (changed) {
      _keyboardBottomInset.value = logical;
      imeTimelineCommit(
        ImeTimelineScope.live,
        pendingLogical: _pendingKeyboardInset,
        committedLogical: logical,
        reason: reason,
      );
      _traceVisualShift(
        phase: 'spacerCommit',
        reason: reason,
        applied: true,
        delta: logical - previous,
      );
    }
    // 收起：工具栏与正文同拍隐藏。
    if (logical <= 0) {
      _setToolbarKeyboardInset(0);
      _appliedCacheThisOpen = false;
      _cancelNudgeDebounceTimer();
      _cancelCacheDownCorrectTimer();
    }
  }

  void _setToolbarKeyboardInset(double logical, {String? reason}) {
    final toolbar = widget.toolbarKeyboardInset;
    if (toolbar == null || toolbar.value == logical) {
      return;
    }
    final previous = toolbar.value;
    toolbar.value = logical;
    _traceVisualShift(
      phase: 'toolbarInset',
      reason: logical <= 0 ? 'hide' : (reason ?? 'reveal'),
      applied: true,
      delta: logical - previous,
    );
  }

  double get _toolbarInsetLogical => widget.toolbarKeyboardInset?.value ?? 0;

  /// 与正文 nudge 同拍显栏；已显示则仅在 raise/correct 时改高度。
  void _syncToolbarWithCommitted({required String reason}) {
    final target = _keyboardBottomInset.value;
    if (!shouldSyncImeToolbarInset(
      targetLogical: target,
      toolbarLogical: _toolbarInsetLogical,
    )) {
      return;
    }
    _setToolbarKeyboardInset(target, reason: reason);
    imeTimelineCommit(
      ImeTimelineScope.toolbar,
      pendingLogical: _pendingKeyboardInset,
      committedLogical: target,
      reason: reason,
    );
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
      settleActive:
          (_keyboardSettleTimer?.isActive ?? false) ||
          (_nudgeDebounceTimer?.isActive ?? false) ||
          (_cacheDownCorrectTimer?.isActive ?? false),
      focused: focused,
      lastCommitReason: lastCommitReason,
    );
  }

  /// 可见上移埋点：spacer / ensureVisible / nudge / 工具栏各打一条，便于对照两次跳动。
  void _traceVisualShift({
    required String phase,
    String? reason,
    double? offsetBefore,
    double? offsetAfter,
    double? delta,
    double? obscuredBottom,
    bool? applied,
  }) {
    imeTimelineVisualShift(
      ImeTimelineScope.live,
      phase: phase,
      reason: reason,
      offsetBefore: offsetBefore,
      offsetAfter: offsetAfter,
      delta: delta,
      pendingLogical: _pendingKeyboardInset,
      committedLogical: _keyboardBottomInset.value,
      toolbarLogical: _toolbarInsetLogical,
      obscuredBottom: obscuredBottom,
      applied: applied,
    );
  }

  /// 空文档点正文框空白区：聚焦已有空段落（勿新建块）。
  void _onEmptyBodyAreaTap() {
    if (!isEmptyDocumentBody(_blocks)) {
      return;
    }
    final id = _blocks.first.id;
    if (_activeBlockId == id) {
      restoreFocus();
      return;
    }
    _activateBlock(id);
  }

  /// 点代码块下方文末空白：插入空段落并聚焦。
  void _onTrailingAfterCodeTap() {
    if (_blocks.isEmpty || _blocks.last is! CodeBlock) {
      return;
    }
    _commitActiveBlock();
    if (_blocks.isEmpty || _blocks.last is! CodeBlock) {
      return;
    }
    final continued = ensureEditableBlockAfterAtomic(
      blocks: _blocks,
      atomicIndex: _blocks.length - 1,
      idGenerator: _idGenerator,
    );
    syncParagraphFlowFlags(continued.blocks);
    _blocks = continued.blocks;
    _syncToParent();
    _switchToActiveBlock(
      blockId: continued.newActiveId,
      selection: const TextSelection.collapsed(offset: 0),
      forceFocus: true,
    );
  }

  /// settle 后单次上推（工具栏已在 commit 同拍显示，不再延后显栏）。
  void _scheduleSettleNudge({String? reason}) {
    if (_keyboardScrollScheduled) {
      return;
    }
    _keyboardScrollScheduled = true;
    imeTimelineScroll(ImeTimelineScope.live, reason: reason ?? 'settle');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _keyboardScrollScheduled = false;
      if (!mounted || !widget.focusNode.hasFocus) {
        return;
      }
      // settle 路径只用 nudge，避免 ensureVisible 再造一拍。
      _nudgeActiveBlockAboveIme(reason: reason ?? 'settle');
    });
  }

  ImeHeightCache get _imeHeightCache =>
      widget.imeHeightCache ?? defaultImeHeightCache;

  String get _imeHeightCacheKey => imeHeightCacheKeyForView(View.of(context));

  void _cancelNudgeDebounceTimer() {
    _nudgeDebounceTimer?.cancel();
    _nudgeDebounceTimer = null;
  }

  void _cancelCacheDownCorrectTimer() {
    _cacheDownCorrectTimer?.cancel();
    _cacheDownCorrectTimer = null;
  }

  void _storeCommittedImeHeight() {
    final logical = _keyboardBottomInset.value;
    if (logical <= 0.5) {
      return;
    }
    _imeHeightCache.store(_imeHeightCacheKey, logical);
  }

  void _armDebouncedNudge() {
    _cancelNudgeDebounceTimer();
    _nudgeDebounceTimer = Timer(kImeNudgeDebounceDelay, () {
      if (!mounted || !widget.focusNode.hasFocus) {
        return;
      }
      _syncToolbarWithCommitted(reason: 'settleDebounced');
      _nudgeActiveBlockAboveIme(reason: 'settleDebounced');
      _storeCommittedImeHeight();
    });
  }

  double? _activeSlotHeight() {
    final id = _activeBlockId;
    if (id == null) {
      return null;
    }
    final context = _blockSlotKeys[id]?.currentContext;
    final box = context?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return null;
    }
    return box.size.height;
  }

  void _snapshotActiveSlotHeight() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _lastActiveSlotHeight = _activeSlotHeight();
    });
  }

  /// 同一活动块因软换行变高时，检查是否还需上浮避开键盘。
  void _scheduleNudgeOnContentWrap() {
    if (_contentWrapNudgeScheduled) {
      return;
    }
    _contentWrapNudgeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _contentWrapNudgeScheduled = false;
      if (!mounted) {
        return;
      }
      final height = _activeSlotHeight();
      if (height == null) {
        return;
      }
      final imeOpen =
          _keyboardBottomInset.value > 0 || _pendingKeyboardInset > 0;
      if (imeOpen &&
          widget.focusNode.hasFocus &&
          shouldNudgeImeAfterContentWrap(
            previousSlotHeight: _lastActiveSlotHeight,
            nextSlotHeight: height,
          )) {
        _nudgeActiveBlockAboveIme(reason: 'contentWrap');
      }
      _lastActiveSlotHeight = height;
    });
  }

  void _revealCollapsedCaretHandle() {
    _collapsedHandleRevealTick++;
    if (mounted) {
      setState(() {});
    }
  }

  void _syncImeCacheDownCorrectTimer() {
    if (!shouldArmImeCacheDownCorrect(
      appliedCacheThisOpen: _appliedCacheThisOpen,
      pendingLogical: _pendingKeyboardInset,
      committedLogical: _keyboardBottomInset.value,
    )) {
      _cancelCacheDownCorrectTimer();
      return;
    }
    _cacheDownCorrectTimer?.cancel();
    _cacheDownCorrectTimer = Timer(kImeNudgeDebounceDelay, () {
      if (!mounted || !widget.focusNode.hasFocus) {
        return;
      }
      if (!shouldArmImeCacheDownCorrect(
        appliedCacheThisOpen: _appliedCacheThisOpen,
        pendingLogical: _pendingKeyboardInset,
        committedLogical: _keyboardBottomInset.value,
      )) {
        return;
      }
      final next = _pendingKeyboardInset;
      _commitKeyboardInset(next, reason: 'correctCacheDown');
      _imeHeightCache.store(_imeHeightCacheKey, next);
      _syncToolbarWithCommitted(reason: 'correctCacheDown');
      _publishImeDebugHud(
        burstMs: 0,
        focused: true,
        lastCommitReason: 'correctCacheDown',
      );
      if (next > 0) {
        _scheduleSettleNudge(reason: 'correctCacheDown');
      }
    });
  }

  void _applyImeSettleDecision(
    ImeSettleDecision decision, {
    required int settleBurstMs,
  }) {
    if (decision.markCacheApplied) {
      _appliedCacheThisOpen = true;
    }
    if (decision.commitLogical != null) {
      _commitKeyboardInset(decision.commitLogical!, reason: decision.reason);
    }
    if (decision.storeCacheLogical != null) {
      _imeHeightCache.store(_imeHeightCacheKey, decision.storeCacheLogical!);
    }
    _publishImeDebugHud(
      burstMs: settleBurstMs,
      focused: true,
      lastCommitReason: decision.reason ?? 'settle',
    );
    switch (decision.nudge) {
      case ImeSettleNudgeMode.immediate:
        _cancelNudgeDebounceTimer();
        _syncToolbarWithCommitted(reason: decision.reason ?? 'applyCache');
        _scheduleSettleNudge(reason: decision.reason);
      case ImeSettleNudgeMode.debounce:
        _armDebouncedNudge();
      case ImeSettleNudgeMode.none:
        break;
    }
    _syncImeCacheDownCorrectTimer();
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
      final decision = resolveImeSettleDecision(
        pendingLogical: _pendingKeyboardInset,
        committedLogical: _keyboardBottomInset.value,
        cachedLogical: _imeHeightCache.lookup(_imeHeightCacheKey),
        appliedCacheThisOpen: _appliedCacheThisOpen,
      );
      imeTimelineSettle(
        ImeTimelineScope.live,
        pendingLogical: _pendingKeyboardInset,
        committedLogical: _keyboardBottomInset.value,
        burstMs: settleBurstMs,
        settleResetCount: _imeSettleResetCount,
        willCommit: decision.shouldCommit,
      );
      if (!decision.shouldCommit && decision.nudge == ImeSettleNudgeMode.none) {
        return;
      }
      _applyImeSettleDecision(decision, settleBurstMs: settleBurstMs);
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
    final previousPending = _pendingKeyboardInset;
    _pendingKeyboardInset = _liveOverlayHitTestActive ? inset : 0;
    final burstOriginMs = _imeBurstStartMs ?? nowMs;
    final burstMs = nowMs - burstOriginMs;

    if (!_liveOverlayHitTestActive) {
      _keyboardSettleTimer?.cancel();
      _cancelNudgeDebounceTimer();
      _cancelCacheDownCorrectTimer();
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
      appliedCacheThisOpen: _appliedCacheThisOpen,
      previousPendingLogical: previousPending,
    )) {
      _keyboardSettleTimer?.cancel();
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

    final restart =
        !hadActiveSettle ||
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
    _syncImeCacheDownCorrectTimer();

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
      if (!_languageFocusNode.hasFocus) {
        _scrollActiveBlockIntoView(reason: 'stabilizeFocus');
      }
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
    final canFocus = widget.focusNode.canRequestFocus;
    final hadFocus = widget.focusNode.hasFocus;
    _traceLiveTap(
      phase: 'restoreFocus',
      canFocus: canFocus,
      hasFocus: hadFocus,
    );
    if (!mounted || !canFocus) {
      return;
    }
    if (_languageFocusNode.hasFocus) {
      return;
    }
    widget.focusNode.requestFocus();
    _traceLiveTap(
      phase: 'restoreFocus.after',
      canFocus: widget.focusNode.canRequestFocus,
      hasFocus: widget.focusNode.hasFocus,
    );
  }

  /// Debug：Overlay / 槽点击与焦点恢复。
  void _traceLiveTap({
    required String phase,
    String? path,
    String? pending,
    bool? canFocus,
    bool? hasFocus,
  }) {
    if (!kDebugMode) {
      return;
    }
    final overlayHit = _liveOverlayHitTestActive;
    final overlayInView = _activeOverlayInView;
    final imeF = _imeSessionFocused.value;
    final edF = widget.focusNode.hasFocus;
    final langF = _languageFocusNode.hasFocus;
    debugTimelineInstant(
      'Live.$phase',
      arguments: liveTapDebugFields(
        phase: phase,
        overlayHit: overlayHit,
        overlayInView: overlayInView,
        imeSessionFocused: imeF,
        editorFocused: edF,
        languageFocused: langF,
        sameBlockTapDiscarded: _sameBlockTapDiscarded,
        path: path,
        pending: pending,
        canFocus: canFocus,
        hasFocus: hasFocus,
      ),
    );
    debugPrint(
      formatLiveTapDebugLog(
        phase: phase,
        overlayHit: overlayHit,
        overlayInView: overlayInView,
        imeSessionFocused: imeF,
        editorFocused: edF,
        languageFocused: langF,
        sameBlockTapDiscarded: _sameBlockTapDiscarded,
        path: path,
        pending: pending,
        canFocus: canFocus,
        hasFocus: hasFocus,
      ),
    );
  }

  /// 正文或语言框任一获焦，都视为仍在实时输入。
  bool get _isLiveEditorInputFocused =>
      widget.focusNode.hasFocus || _languageFocusNode.hasFocus;

  /// Overlay 是否继续吃点击；含「正文刚失焦、语言框尚未获焦」的同一帧。
  bool get _liveOverlayHitTestActive =>
      _imeSessionFocused.value || _isLiveEditorInputFocused;

  void _onEditorFocusChanged() {
    if (!mounted) {
      return;
    }
    if (!widget.focusNode.hasFocus) {
      // 焦点可能正交给语言框；等本帧结束再判定是否离开输入。
      _scheduleReconcileLiveInputFocus();
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

  void _onLanguageFocusChanged() {
    if (!mounted) {
      return;
    }
    if (_languageFocusNode.hasFocus) {
      _imeSessionFocused.value = true;
      _publishLiveCursorDebugHud();
      return;
    }
    _scheduleReconcileLiveInputFocus();
  }

  void _scheduleReconcileLiveInputFocus() {
    if (_reconcileLiveInputFocusScheduled) {
      return;
    }
    _reconcileLiveInputFocusScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reconcileLiveInputFocusScheduled = false;
      if (!mounted) {
        return;
      }
      if (_isLiveEditorInputFocused) {
        _imeSessionFocused.value = true;
        return;
      }
      _keyboardSettleTimer?.cancel();
      _cancelNudgeDebounceTimer();
      _cancelCacheDownCorrectTimer();
      _pendingKeyboardInset = 0;
      _imeSessionFocused.value = false;
      _publishLiveCursorDebugHud();
    });
  }

  void _scheduleScrollActiveIntoView({String? reason}) {
    if (_keyboardScrollScheduled) {
      return;
    }
    _keyboardScrollScheduled = true;
    _pendingScrollReason = reason;
    imeTimelineScroll(ImeTimelineScope.live, reason: reason);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _keyboardScrollScheduled = false;
      if (mounted && widget.focusNode.hasFocus) {
        _scrollActiveBlockIntoView(reason: _pendingScrollReason);
      }
    });
  }

  static const _estimatedBlockExtent = 40.0;

  /// 聚焦时底部留白 = 键盘 + 工具栏 + 间隙；键盘高度在 metrics 收稳后写入 notifier。
  double get _focusedBottomScrollPadding => liveListImeSpacerHeight(
    keyboardInset: _keyboardBottomInset.value,
    focused: _liveOverlayHitTestActive,
  );

  /// 将活动块滚入可视区域（考虑键盘与底部工具栏遮挡）。
  void _scrollActiveBlockIntoView({String? reason}) {
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
            _scrollActiveBlockIntoView(reason: reason);
          }
        });
        return;
      }

      // 不经 MediaQuery.viewInsets，避免误订阅导致键盘动画期整树重建。
      final keyboardOpen = _keyboardBottomInset.value > 0;
      // 键盘弹出时用瞬时滚动，避免光标（Overlay）先上移而正文仍在动画中。
      // alignment 偏上：把活动块留在未被键盘/工具栏遮住的可视区。
      final useInstant = keyboardOpen || _layoutTransitionActive;
      final offsetBefore = controller.offset;
      Scrollable.ensureVisible(
        slotContext,
        alignment: keyboardOpen ? 0.12 : 0.35,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
        duration: useInstant ? Duration.zero : _scrollIntoViewDuration,
        curve: Curves.easeOut,
      );
      final offsetAfter = controller.hasClients
          ? controller.offset
          : offsetBefore;
      _traceVisualShift(
        phase: 'ensureVisible',
        reason: reason,
        offsetBefore: offsetBefore,
        offsetAfter: offsetAfter,
        delta: offsetAfter - offsetBefore,
        applied: (offsetAfter - offsetBefore).abs() > 0.5,
      );
      // ensureVisible 按完整 viewport 计算，不知底部键盘/工具栏；帧后再上推。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _nudgeActiveBlockAboveIme(reason: reason ?? 'afterEnsureVisible');
        }
      });
    });
  }

  /// 若活动块底边仍落在键盘/工具栏遮挡区内，继续上滚。
  void _nudgeActiveBlockAboveIme({String? reason}) {
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
    final stackBottom = stackBox
        .localToGlobal(Offset(0, stackBox.size.height))
        .dy;
    final delta = scrollDeltaToClearIme(
      caretOrBlockGlobalBottom: slotBottom,
      viewportGlobalBottom: stackBottom,
      obscuredBottom: obscured,
    );
    if (delta <= 0) {
      _traceVisualShift(
        phase: 'nudge',
        reason: reason,
        offsetBefore: controller.offset,
        offsetAfter: controller.offset,
        delta: 0,
        obscuredBottom: obscured,
        applied: false,
      );
      return;
    }
    final offsetBefore = controller.offset;
    controller.jumpTo(
      (controller.offset + delta).clamp(
        controller.position.minScrollExtent,
        controller.position.maxScrollExtent,
      ),
    );
    _traceVisualShift(
      phase: 'nudge',
      reason: reason,
      offsetBefore: offsetBefore,
      offsetAfter: controller.offset,
      delta: delta,
      obscuredBottom: obscured,
      applied: true,
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
    final focused = _isLiveEditorInputFocused;
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
          overlayHitTestActive: _liveOverlayHitTestActive,
          overlayInView: _activeOverlayInView,
          imeSessionFocused: _imeSessionFocused.value,
          editorFocused: widget.focusNode.hasFocus,
          languageFocused: _languageFocusNode.hasFocus,
          sameBlockTapDiscarded: _sameBlockTapDiscarded,
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
        overlayHitTestActive: _liveOverlayHitTestActive,
        overlayInView: _activeOverlayInView,
        imeSessionFocused: _imeSessionFocused.value,
        editorFocused: widget.focusNode.hasFocus,
        languageFocused: _languageFocusNode.hasFocus,
        sameBlockTapDiscarded: _sameBlockTapDiscarded,
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
      _lastActiveSlotHeight = null;
      _updateActiveController(editableTextForBlock(block), selection);
      _syncLanguageFieldFromActive();
      _publishLiveCursorDebugHud();
      if (mounted) {
        setState(() {});
      }
      // 换块类型时 TextField 周边布局曾会重挂载；force 可把 IME 拉回。
      _stabilizeInputFocus(
        force: forceFocus || notifyParent,
        notifyParent: notifyParent,
      );
      _snapshotActiveSlotHeight();
    });
  }

  void _restoreFocusAfterBlockChange({bool force = false}) {
    if (!mounted || !widget.focusNode.canRequestFocus) {
      return;
    }
    if (_languageFocusNode.hasFocus) {
      return;
    }
    if (!force && widget.focusNode.hasFocus) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.focusNode.canRequestFocus) {
        return;
      }
      if (_languageFocusNode.hasFocus) {
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
    _cancelNudgeDebounceTimer();
    _cancelCacheDownCorrectTimer();
    _overlayListScrollDrag?.cancel();
    _overlayListScrollDrag = null;
    widget.focusNode.removeListener(_onEditorFocusChanged);
    _languageFocusNode.removeListener(_onLanguageFocusChanged);
    widget.scrollController.removeListener(_onScrollForOverlayVisibility);
    flushToParent();
    _activeFieldController.removeListener(_onActiveFieldChanged);
    widget.controller.removeListener(_onExternalControllerChanged);
    _activeFieldController.dispose();
    _languageFocusNode.dispose();
    _languageController.dispose();
    if (_ownsKeyboardBottomInset) {
      _keyboardBottomInset.dispose();
    }
    _imeSessionFocused.dispose();
    super.dispose();
  }

  void _onScrollForOverlayVisibility() {
    _updateActiveOverlayVisibility();
  }

  /// 将 Overlay 上的垂直拖转发给外层列表；不丢焦点、不改活动块。
  void _onOverlayVerticalDragStart(DragStartDetails details) {
    _overlayListScrollDrag?.cancel();
    _overlayListScrollDrag = null;
    final controller = widget.scrollController;
    if (!controller.hasClients) {
      return;
    }
    _overlayListScrollDrag = controller.position.drag(details, () {
      _overlayListScrollDrag = null;
    });
  }

  void _onOverlayVerticalDragUpdate(DragUpdateDetails details) {
    _overlayListScrollDrag?.update(details);
  }

  void _onOverlayVerticalDragEnd(DragEndDetails details) {
    _overlayListScrollDrag?.end(details);
    _overlayListScrollDrag = null;
  }

  void _onOverlayVerticalDragCancel() {
    _overlayListScrollDrag?.cancel();
    _overlayListScrollDrag = null;
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

  bool get swallowsMarkdownToolbar => _activeBlock is CodeBlock;

  bool get isCodeLanguageFieldFocused => _languageFocusNode.hasFocus;

  void _syncLanguageFieldFromActive() {
    final block = _activeBlock;
    if (block is CodeBlock) {
      final next = block.language ?? '';
      if (_languageController.text != next) {
        _languageController.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        );
      }
      return;
    }
    if (_languageFocusNode.hasFocus) {
      _languageFocusNode.unfocus();
    }
    if (_languageController.text.isNotEmpty) {
      _languageController.clear();
    }
  }

  void _onCodeLanguageChanged(String value) {
    final index = _activeBlockId == null ? -1 : _indexOf(_activeBlockId!);
    if (index < 0) {
      return;
    }
    final block = _blocks[index];
    if (block is! CodeBlock) {
      return;
    }
    final trimmed = value.trim();
    final nextLang = trimmed.isEmpty ? null : trimmed;
    if (block.language == nextLang) {
      return;
    }
    _blocks[index] = block.copyWith(language: nextLang);
    _syncToParentDeferred();
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
    debugTimelineSync('Live.loadFromMarkdown', () {
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
      _lastActiveSlotHeight = null;
      // 换文档/重载后先显示 Overlay；帧末再按真实视口校正。
      _activeOverlayInView = true;
      _pruneBlockSlotKeys();
      _syncActiveFieldFromBlock();
      _syncLanguageFieldFromActive();
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
        _snapshotActiveSlotHeight();
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
    }, arguments: {'chars': '${markdown.length}'});
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
    final newSelection = start == end
        ? TextSelection.collapsed(
            offset: start,
            affinity: start >= text.length && text.isNotEmpty
                ? TextAffinity.upstream
                : selection.affinity,
          )
        : TextSelection(baseOffset: start, extentOffset: end);
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
    final textChanged = text != editableTextForBlock(previous);
    if (textChanged) {
      _scheduleNudgeOnContentWrap();
    }

    final triggered = applyBlockTrigger(block, text);
    if (triggered != null) {
      block = triggered;
      final markdownChanged =
          inlineMarkdownForBlock(block) != inlineMarkdownForBlock(previous);
      final typeChanged = block.runtimeType != previous.runtimeType;
      _blocks[index] = block;
      if (!block.supportsPlainEditing) {
        final continued = ensureEditableBlockAfterAtomic(
          blocks: _blocks,
          atomicIndex: index,
          idGenerator: _idGenerator,
        );
        _blocks = continued.blocks;
        syncParagraphFlowFlags(_blocks);
        renumberOrderedBlocksAround(_blocks, index);
        _scheduleSyncToParent();
        if (mounted) {
          _markLayoutTransition();
          setState(() {});
        }
        _switchToActiveBlock(
          blockId: continued.newActiveId,
          selection: const TextSelection.collapsed(offset: 0),
          forceFocus: true,
        );
        return;
      }
      if (typeChanged) {
        syncParagraphFlowFlags(_blocks);
        renumberOrderedBlocksAround(_blocks, index);
      }
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
      _syncLanguageFieldFromActive();
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
      final normalized = isSingleLineBlock(block)
          ? text.split('\n').first
          : text;
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

    final markdownChanged =
        inlineMarkdownForBlock(block) != inlineMarkdownForBlock(previous);
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
        final discarded = _pendingActivateTapGlobal != null;
        _pendingActivateTapGlobal = null;
        _sameBlockTapDiscarded = true;
        _traceLiveTap(
          phase: 'activateBlock',
          path: 'sameId',
          pending: discarded ? 'discarded' : 'none',
        );
        _publishLiveCursorDebugHud();
        // 勿在 InkWell onTap 同步 requestFocus / setState，避免手势分发中改树。
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _activeBlockId != blockId) {
            return;
          }
          restoreFocus();
          _revealCollapsedCaretHandle();
        });
        return;
      }
      final pending = _pendingActivateTapGlobal == null ? 'none' : 'used';
      _sameBlockTapDiscarded = false;
      _traceLiveTap(
        phase: 'activateBlock',
        path: 'switch',
        pending: pending,
      );
      debugTimelineSync('Live.commitActive', _commitActiveBlock);
      _clearInlineActionCache();
      final nextIndex = _indexOf(blockId);
      if (nextIndex < 0) {
        _pendingActivateTapGlobal = null;
        return;
      }
      final previousId = _activeBlockId;
      final previousIndex = previousId == null ? -1 : _indexOf(previousId);
      final typeChanged =
          previousIndex >= 0 &&
          _blocks[previousIndex].runtimeType != _blocks[nextIndex].runtimeType;
      final nextBlock = _blocks[nextIndex];
      final text = editableTextForBlock(nextBlock);
      final caretOffset =
          _consumeActivateTapPlainOffset(block: nextBlock, plainText: text) ??
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
      _revealCollapsedCaretHandle();
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
    if (global == null || !block.supportsPlainEditing) {
      return null;
    }
    final slotContext = _slotKeyFor(block.id).currentContext;
    if (slotContext == null) {
      return null;
    }
    final displayMarkdown = supportsInlineFormatting(block)
        ? inlineMarkdownForBlock(block)
        : null;
    return plainOffsetAtGlobalTap(
      slotRoot: slotContext.findRenderObject(),
      globalPosition: global,
      plainText: plainText,
      findBodyParagraph: findLiveBodyParagraph,
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
      // 原子块无 plain 编辑内容，无需 commit 文本。
      if (_blocks[index].supportsPlainEditing) {
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
      forceFocus: next.supportsPlainEditing,
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

  /// IME 在块首把整块清空：拒绝该次编辑，帧后再合并，避免与 KeyEvent 双打。
  bool _onImeClearAtBlockStart() {
    if (_blockStartMergeInProgress) {
      return true;
    }
    _blockStartMergeInProgress = true;
    _pendingImeBlockStartMerge = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pendingImeBlockStartMerge) {
        return;
      }
      _pendingImeBlockStartMerge = false;
      _blockStartMergeInProgress = false;
      _handleBackspaceAtBlockStart();
    });
    return true;
  }

  void _armBlockStartMergeLock() {
    _blockStartMergeInProgress = true;
    _pendingImeBlockStartMerge = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _blockStartMergeInProgress = false;
      });
    });
  }

  void _handleBackspaceAtBlockStart() {
    if (_blockStartMergeInProgress) {
      return;
    }
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
          _armBlockStartMergeLock();
          _blocks[index] = ParagraphBlock(id: block.id, text: '');
          renumberOrderedBlocksAround(_blocks, index);
          setState(() => _syncActiveFieldFromBlock());
          _syncToParentDeferred();
        }
        return;
      }
      if (isSingleLineBlock(block)) {
        _armBlockStartMergeLock();
        _blocks[index] = reparseBlockFromLineMarkdown(
          block,
          lineMarkdown: applyParagraphLineMarkdown(block.toMarkdown()),
        );
        renumberOrderedBlocksAround(_blocks, index);
        setState(() => _syncActiveFieldFromBlock());
        _syncToParentDeferred();
        return;
      }
      return;
    }

    final result = mergeCurrentBlockIntoPrevious(
      blocks: _blocks,
      currentIndex: index,
      currentPlain: text,
    );
    if (!result.handled) {
      return;
    }
    _armBlockStartMergeLock();
    _blocks = result.blocks;
    _syncToParentDeferred();
    _switchToActiveBlock(
      blockId: result.activeId,
      selection: TextSelection.collapsed(offset: result.caretOffset),
    );
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
      if (key == LogicalKeyboardKey.keyK && keyboard.isShiftPressed) {
        applyStrikethrough();
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
    if (swallowsMarkdownToolbar) {
      return;
    }
    _applyLineMarkdownTransform(
      (line) => applyHeadingLineMarkdown(line, level),
    );
  }

  void applyBulletList() {
    if (swallowsMarkdownToolbar) {
      return;
    }
    _applyLineMarkdownTransform(applyBulletLineMarkdown);
  }

  void applyTaskList() {
    if (swallowsMarkdownToolbar) {
      return;
    }
    _applyLineMarkdownTransform(applyTaskLineMarkdown);
  }

  void applyOrderedList() {
    if (swallowsMarkdownToolbar) {
      return;
    }
    _applyLineMarkdownTransform(applyOrderedLineMarkdown);
  }

  void applyQuote() {
    if (swallowsMarkdownToolbar) {
      return;
    }
    _applyLineMarkdownTransform(applyQuoteLineMarkdown);
  }

  void applyParagraph() {
    final active = _activeBlock;
    if (active is CodeBlock) {
      _applyParagraphFromCodeBlock(active);
      return;
    }
    _applyLineMarkdownTransform(applyParagraphLineMarkdown);
  }

  void applyCodeBlock() {
    if (swallowsMarkdownToolbar) {
      return;
    }
    _applyLineMarkdownTransform(applyCodeBlockLineMarkdown);
  }

  /// 代码块点「正文」：用 [CodeBlock.code] 变段落，不走围栏 toMarkdown strip。
  void _applyParagraphFromCodeBlock(CodeBlock block) {
    _commitActiveBlock();
    final index = _indexOf(block.id);
    if (index < 0) {
      return;
    }
    final current = _blocks[index];
    if (current is! CodeBlock) {
      return;
    }

    final paragraph = ParagraphBlock(id: current.id, text: current.code);
    var next = List<MdBlock>.of(_blocks);
    if (current.code.contains('\n')) {
      final expanded = expandMultilineParagraphsForLive(
        [paragraph],
        _idGenerator,
      );
      next.replaceRange(index, index + 1, expanded);
      syncParagraphFlowFlags(next);
      _blocks = next;
      final focus = expanded.first;
      final plain = editableTextForBlock(focus);
      _syncToParentDeferred();
      _switchToActiveBlock(
        blockId: focus.id,
        selection: TextSelection.collapsed(
          offset: 0.clamp(0, plain.length),
        ),
        forceFocus: true,
      );
      return;
    }

    next[index] = paragraph;
    syncParagraphFlowFlags(next);
    _blocks = next;
    final plain = editableTextForBlock(paragraph);
    _syncToParentDeferred();
    _switchToActiveBlock(
      blockId: paragraph.id,
      selection: TextSelection.collapsed(
        offset: plain.length.clamp(0, plain.length),
      ),
      forceFocus: true,
    );
  }

  /// 在活动块处插入分割线，并聚焦线后的空段落。
  void insertThematicBreak() {
    if (swallowsMarkdownToolbar) {
      return;
    }
    _commitActiveBlock();
    final activeId = _activeBlockId;
    if (activeId == null) {
      return;
    }
    final index = _indexOf(activeId);
    if (index < 0) {
      return;
    }
    final result = insertThematicBreakAt(
      blocks: _blocks,
      index: index,
      idGenerator: _idGenerator,
    );
    _blocks = result.blocks;
    _syncToParent();
    if (mounted) {
      _markLayoutTransition();
      setState(() {});
    }
    _switchToActiveBlock(
      blockId: result.newActiveId,
      selection: const TextSelection.collapsed(offset: 0),
      forceFocus: true,
    );
  }

  void applyBold() {
    if (swallowsMarkdownToolbar) {
      return;
    }
    _applyInlineStyle(InlineStyle.bold);
  }

  void applyItalic() {
    if (swallowsMarkdownToolbar) {
      return;
    }
    _applyInlineStyle(InlineStyle.italic);
  }

  void applyStrikethrough() {
    if (swallowsMarkdownToolbar) {
      return;
    }
    _applyInlineStyle(InlineStyle.strikethrough);
  }

  void applyInlineCode() {
    if (swallowsMarkdownToolbar) {
      return;
    }
    _applyInlineStyle(InlineStyle.code);
  }

  /// 在选区包裹或于光标处插入 Markdown 链接。
  void applyLink({required String url, String? displayText}) {
    final activeId = _activeBlockId;
    if (activeId == null) {
      return;
    }
    if (swallowsMarkdownToolbar) {
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
    final markdownSource = blockPlain == plainText ? blockMarkdown : plainText;
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
    final markdownSource = blockPlain == plainText ? blockMarkdown : plainText;

    final inlines = parseInlineMarkdown(markdownSource);
    final updated = applyInlineStyle(inlines, selStart, selEnd, style);
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
    final fromLabel = _activeBlock == null
        ? '?'
        : mdBlockDebugTypeLabel(_activeBlock!);
    debugTimelineSync('Live.applyBlockType', () {
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
      final taskChromeChanged =
          block is BulletBlock &&
          reparsed is BulletBlock &&
          (block.checked == null) != (reparsed.checked == null);
      // H1/H2/H3 同属 HeadingBlock，runtimeType 不变，但字号在列表槽
      // headingStyle(level)。须 setState 刷新；不要并进 layoutChanged，
      // 否则会 _markLayoutTransition + forceFocus，误走 IME 布局过渡。
      final headingLevelChanged =
          block is HeadingBlock &&
          reparsed is HeadingBlock &&
          block.level != reparsed.level;
      final layoutChanged = typeChanged || taskChromeChanged;
      final oldPlain = editableTextForBlock(block);
      final newPlain = editableTextForBlock(reparsed);
      _blocks[index] = reparsed;
      paragraphFlowAfterHeadingToBody(
        blocks: _blocks,
        index: index,
        before: block,
      );
      if (layoutChanged) {
        syncParagraphFlowFlags(_blocks);
      }
      renumberOrderedBlocksAround(_blocks, index);
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
      final didSetState =
          mounted &&
          (layoutChanged || headingLevelChanged || reparsed is OrderedBlock);
      debugTimelineInstant(
        'Live.applyBlockType',
        arguments: liveApplyBlockTypeArgs(
          from: fromLabel,
          to: mdBlockDebugTypeLabel(reparsed),
          layoutChanged: layoutChanged,
          didSetState: didSetState,
        ),
      );
      if (!layoutChanged && !didSetState) {
        debugTimelineInstant(
          'Live.applyBlockType.skipSetState',
          arguments: liveApplyBlockTypeArgs(
            from: fromLabel,
            to: mdBlockDebugTypeLabel(reparsed),
            layoutChanged: layoutChanged,
            didSetState: didSetState,
          ),
        );
      }
      if (didSetState) {
        if (layoutChanged) {
          _markLayoutTransition();
        }
        setState(() {});
      }
      _syncToParentDeferred();
      _stabilizeInputFocus(force: layoutChanged);
    });
  }

  /// 点击勾选前缀：只翻转 checked，不换活动块、不改选区、不收 IME。
  void toggleTaskChecked(String blockId) {
    final index = _indexOf(blockId);
    if (index < 0) {
      return;
    }
    final updated = toggleBulletTaskChecked(_blocks[index]);
    if (identical(updated, _blocks[index])) {
      return;
    }
    _blocks[index] = updated;
    if (mounted) {
      setState(() {});
    }
    _scheduleSyncToParent();
  }

  Widget _buildBlockSlot(
    MdBlock block, {
    MdBlock? previous,
    MdBlock? next,
    required bool isActive,
  }) {
    Widget buildRenderer(MdBlock displayBlock) {
      return Padding(
        padding: MdBlockStyles.slotPaddingFor(
          displayBlock,
          previous: previous,
          next: next,
        ),
        child: MdBlockRenderer(
          block: displayBlock,
          memoFilePath: widget.memoFilePath,
          resolveLocalImage: widget.resolveLocalImage,
          onLinkTap: widget.onLinkTap,
          resolveLinkLabel: widget.resolveLinkLabel,
          onTaskToggle:
              displayBlock is BulletBlock && displayBlock.checked != null
              ? () => toggleTaskChecked(block.id)
              : null,
          emptyBodyHint: isEmptyDocumentBody(_blocks)
              ? AppLocalizations.of(context).emptyBodyHint
              : null,
        ),
      );
    }

    // 原子块：点击选中后右上角显示 ×，不走透明 TextField Overlay。
    if (!block.supportsPlainEditing) {
      final imageBody = Stack(
        clipBehavior: Clip.none,
        children: [
          buildRenderer(block),
          if (isActive)
            MdBlockStyles.positionAtomicDeleteButton(
              block: block,
              button: MdBlockStyles.buildAtomicDeleteButton(
                onPressed: () => _deleteBlockById(block.id),
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

    // 活动块列表槽始终可点：禁止随焦点拆掉 InkWell（onTap 里 requestFocus
    // 会同步重建，手势目标消失，Android 上易 ANR）。聚焦时 Overlay 在上层吃点击。
    Widget wrapTappable(Widget child) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTapDown: (details) {
            _pendingActivateTapGlobal = details.globalPosition;
          },
          onTap: () {
            _traceLiveTap(phase: 'slot.inkTap');
            _activateBlock(block.id);
          },
          borderRadius: BorderRadius.circular(4),
          child: child,
        ),
      );
    }

    final renderer = isActive
        ? ListenableBuilder(
            listenable: _activeFieldController,
            builder: (context, _) =>
                buildRenderer(_displayBlockForActiveField(block)),
          )
        : buildRenderer(block);
    final content = wrapTappable(renderer);

    // 每块始终挂 key；活动块同时作为 Overlay 的 LayerLink 锚点。
    final keyed = KeyedSubtree(
      key: _slotKeyFor(block.id),
      child: RepaintBoundary(child: content),
    );
    if (isActive) {
      return CompositedTransformTarget(link: _activeOverlayLink, child: keyed);
    }
    return keyed;
  }

  Widget _buildCodeLanguageField(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Material(
      elevation: 2,
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: MdBlockStyles.codeLanguageFieldWidth,
        child: TextField(
          key: LiveMarkdownEditor.codeLanguageFieldKey,
          controller: _languageController,
          focusNode: _languageFocusNode,
          maxLines: 1,
          // Overlay 不在列表内；默认 scrollPadding 会 ensureVisible 把文档滚走。
          scrollPadding: EdgeInsets.zero,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: MdBlockStyles.codeLanguageFieldFontSize,
            fontFamily: 'monospace',
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: l10n.codeBlockLanguageHint,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: MdBlockStyles.codeLanguageFieldHorizontalPadding,
              vertical: MdBlockStyles.codeLanguageFieldVerticalPadding,
            ),
          ),
          onChanged: _onCodeLanguageChanged,
        ),
      ),
    );
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
    final activeIndex = activeId == null
        ? -1
        : _blocks.indexWhere((b) => b.id == activeId);
    // Overlay 单独用 LayoutBuilder 只算宽度；锚点已在 padding 内，勿再加左缩进。
    // IME 留白放尾部 spacer（ValueNotifier），避免改 padding / setState 重建全部块槽。
    // 空文档用 SliverFillRemaining 吃掉正文框剩余空白，点空白才能聚焦（Overlay 仅一行高）。
    const listPadding = EdgeInsets.fromLTRB(
      MdBlockStyles.editorBodyHorizontalPadding,
      MdBlockStyles.editorBodyTopPadding,
      MdBlockStyles.editorBodyHorizontalPadding,
      kEditorBodyBottomPadding,
    );
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final emptyBody = isEmptyDocumentBody(_blocks);

    return Stack(
      key: _contentStackKey,
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        CustomScrollView(
          controller: widget.scrollController,
          cacheExtent: 1600,
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                listPadding.left,
                listPadding.top,
                listPadding.right,
                0,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, i) {
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: MdBlockStyles.bottomSpacingFor(
                        _blocks[i],
                        next: i + 1 < _blocks.length ? _blocks[i + 1] : null,
                      ),
                    ),
                    child: _buildBlockSlot(
                      _blocks[i],
                      previous: i > 0 ? _blocks[i - 1] : null,
                      next: i + 1 < _blocks.length ? _blocks[i + 1] : null,
                      isActive: _blocks[i].id == activeId,
                    ),
                  );
                }, childCount: _blocks.length),
              ),
            ),
            if (emptyBody)
              SliverFillRemaining(
                hasScrollBody: false,
                child: GestureDetector(
                  key: LiveMarkdownEditor.emptyBodyFillKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: _onEmptyBodyAreaTap,
                ),
              ),
            if (liveShowsTrailingAfterCodeFill(_blocks))
              SliverFillRemaining(
                hasScrollBody: false,
                child: GestureDetector(
                  key: LiveMarkdownEditor.trailingAfterCodeFillKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: _onTrailingAfterCodeTap,
                ),
              ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                listPadding.left,
                0,
                listPadding.right,
                listPadding.bottom + bottomSafe,
              ),
              sliver: SliverToBoxAdapter(
                child: ListenableBuilder(
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
                ),
              ),
            ),
          ],
        ),
        if (activeBlock != null && activeBlock.supportsPlainEditing)
          LayoutBuilder(
            builder: (context, constraints) {
              // 锚点已在 ListView content 区内，宽度与 list children 约束一致。
              final overlayWidth =
                  (constraints.maxWidth - listPadding.horizontal).clamp(
                    0.0,
                    double.infinity,
                  );
              return ListenableBuilder(
                listenable: Listenable.merge([
                  widget.focusNode,
                  _languageFocusNode,
                  _imeSessionFocused,
                ]),
                builder: (context, _) {
                  return IgnorePointer(
                    ignoring: liveOverlayIgnoresPointers(
                      hasFocus: _liveOverlayHitTestActive,
                    ),
                    child: CompositedTransformFollower(
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
                                    next:
                                        activeIndex >= 0 &&
                                            activeIndex + 1 < _blocks.length
                                        ? _blocks[activeIndex + 1]
                                        : null,
                                  ),
                                  // 只转发垂直拖给外层列表；禁止 onTap/onPan，以免单击被抢走。
                                  child: GestureDetector(
                                    key: LiveMarkdownEditor.overlayListScrollKey,
                                    onVerticalDragStart:
                                        _onOverlayVerticalDragStart,
                                    onVerticalDragUpdate:
                                        _onOverlayVerticalDragUpdate,
                                    onVerticalDragEnd: _onOverlayVerticalDragEnd,
                                    onVerticalDragCancel:
                                        _onOverlayVerticalDragCancel,
                                    child: Listener(
                                      onPointerDown: (_) {
                                        _traceLiveTap(phase: 'overlay.pointer');
                                        _revealCollapsedCaretHandle();
                                      },
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
                                          resolveLocalImage:
                                              widget.resolveLocalImage,
                                          onLinkTap: widget.onLinkTap,
                                          resolveLinkLabel:
                                              widget.resolveLinkLabel,
                                          onTaskToggle:
                                              activeBlock is BulletBlock &&
                                                  activeBlock.checked != null
                                              ? () => toggleTaskChecked(
                                                  activeBlock.id,
                                                )
                                              : null,
                                          chromeless: true,
                                          onTap: _revealCollapsedCaretHandle,
                                          onImeClearAtBlockStart:
                                              _onImeClearAtBlockStart,
                                        ),
                                      ),
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
                                  cursorColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  resolveLinkLabel: widget.resolveLinkLabel,
                                  handleRevealTick: _collapsedHandleRevealTick,
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
                                if (activeBlock is CodeBlock &&
                                    _liveOverlayHitTestActive)
                                  MdBlockStyles.positionCodeLanguageField(
                                    field: _buildCodeLanguageField(context),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
      ],
    );
  }
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
    required this.handleRevealTick,
    this.resolveLinkLabel,
  });

  final GlobalKey slotKey;
  final GlobalKey overlayKey;
  final TextEditingController controller;
  final FocusNode focusNode;
  final Color cursorColor;
  final String? Function() displayMarkdownOf;
  final String? Function(String href)? resolveLinkLabel;
  final int handleRevealTick;

  @override
  State<_RendererSyncedCaret> createState() => _RendererSyncedCaretState();
}

class _RendererSyncedCaretState extends State<_RendererSyncedCaret> {
  static const _caretWidth = kTextCaretWidth;
  static const _blinkPeriod = Duration(milliseconds: 500);
  static const _maxMeasureRetries = 8;

  Timer? _blinkTimer;
  bool _caretVisible = true;
  bool _handleVisible = true;
  String? _lastPlain;
  Offset? _caretTopLeft;
  double _caretHeight = 0;
  bool _measureScheduled = false;
  int _measureRetries = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextOrSelectionChanged);
    widget.focusNode.addListener(_onFocusChanged);
    _lastPlain = widget.controller.text;
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
    if (oldWidget.handleRevealTick != widget.handleRevealTick) {
      _handleVisible = liveCollapsedHandleVisibleAfterEdit(
        visible: _handleVisible,
        textChanged: false,
        revealFromUserTap: true,
      );
      _measureRetries = 0;
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
    final nextPlain = widget.controller.text;
    final textChanged = _lastPlain != null && nextPlain != _lastPlain;
    _lastPlain = nextPlain;
    _handleVisible = liveCollapsedHandleVisibleAfterEdit(
      visible: _handleVisible,
      textChanged: textChanged,
      revealFromUserTap: false,
    );
    _measureRetries = 0;
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

  void _retryMeasure() {
    if (_measureRetries >= _maxMeasureRetries) {
      return;
    }
    _measureRetries++;
    _scheduleMeasure();
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
      _retryMeasure();
      return;
    }

    final plain = widget.controller.text;
    final paragraph = findLiveBodyParagraph(
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
      _retryMeasure();
      return;
    }

    final displayText = paragraph.text.toPlainText();
    final displayMarkdown = widget.displayMarkdownOf();
    if (!rendererParagraphMatchesCaretPlain(
      controllerPlain: plain,
      paragraphPlain: displayText,
      hasInlineFormatting: displayMarkdown != null,
    )) {
      // 列表层尚未跟上本次输入；再等一帧，勿用旧段落把光标钉在上一字后。
      _retryMeasure();
      return;
    }
    _measureRetries = 0;

    // 空块占位「 」：逻辑 offset 0 对应显示首部。
    final displayOffset = plain.isEmpty
        ? 0
        : plainOffsetToDisplayOffset(
            plainOffset: selection.extentOffset.clamp(0, plain.length),
            plainText: plain,
            displayText: displayText,
            displayMarkdown: displayMarkdown,
            resolveLinkLabel: widget.resolveLinkLabel,
          );

    const caretPrototype = Rect.fromLTWH(0, 0, _caretWidth, 1);
    final caretPosition = caretTextPositionForDisplay(
      displayOffset: displayOffset,
      displayLength: displayText.length,
      affinity: selection.affinity,
    );
    final localCaret = paragraph.getOffsetForCaret(
      caretPosition,
      caretPrototype,
    );
    var height = paragraph.getFullHeightForCaret(caretPosition);
    if (height <= 0) {
      height = paragraph.getFullHeightForCaret(
        TextPosition(offset: caretPosition.offset),
      );
    }
    if (height <= 0) {
      _retryMeasure();
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
    if (topLeft == null || _caretHeight <= 0) {
      return const SizedBox.shrink();
    }

    final handleTopLeft = liveCollapsedCaretHandleTopLeft(
      caretTopLeft: topLeft,
      caretWidth: _caretWidth,
      caretHeight: _caretHeight,
    );

    return Positioned.fill(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (_caretVisible)
            Positioned(
              left: topLeft.dx,
              top: topLeft.dy,
              child: IgnorePointer(
                child: Container(
                  width: _caretWidth,
                  height: _caretHeight,
                  color: widget.cursorColor,
                ),
              ),
            ),
          if (_handleVisible)
            Positioned(
              left: handleTopLeft.dx,
              top: handleTopLeft.dy,
              child: GestureDetector(
                key: LiveMarkdownEditor.collapsedCaretHandleKey,
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.focusNode.requestFocus(),
                child: Transform.rotate(
                  angle: math.pi / 4,
                  child: CustomPaint(
                    size: const Size(
                      kLiveCollapsedCaretHandleSize,
                      kLiveCollapsedCaretHandleSize,
                    ),
                    painter: _LiveCaretDropHandlePainter(
                      color: widget.cursorColor,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Material 折叠水滴：圆 + 左上角方块，旋转 45° 后尖端朝上。
class _LiveCaretDropHandlePainter extends CustomPainter {
  const _LiveCaretDropHandlePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final radius = size.width / 2.0;
    final path = Path()
      ..addOval(Rect.fromCircle(center: Offset(radius, radius), radius: radius))
      ..addRect(Rect.fromLTWH(0, 0, radius, radius));
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LiveCaretDropHandlePainter oldDelegate) {
    return color != oldDelegate.color;
  }
}
