import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mind_recall/app_layout_constants.dart';
import 'package:mind_recall/core/debug/ime_debug_hud.dart';
import 'package:mind_recall/core/debug/ime_timeline.dart';
import 'package:mind_recall/core/ui/ime_height_cache.dart';
import 'package:mind_recall/features/memo/editor/mode_input_session.dart';

/// 编辑模式 IME settle / nudge / 工具栏同拍；决策只走已有 `resolveImeSettleDecision`。
class EditImeCoordinator {
  EditImeCoordinator({
    required this.session,
    required this.contentController,
    required this.contentFieldKey,
    required this.isMounted,
    required this.isEditMode,
    required this.isSuspended,
    required this.isDrawerOpen,
    required this.layoutWidth,
    required this.rebuild,
  });

  final EditInputSession session;
  final TextEditingController contentController;
  final GlobalKey contentFieldKey;
  final bool Function() isMounted;
  final bool Function() isEditMode;
  final bool Function() isSuspended;
  final bool Function() isDrawerOpen;
  final double Function() layoutWidth;
  final void Function(VoidCallback fn) rebuild;

  /// 窄屏正文 settled 键盘高度（Live spacer / 与滚入同步）。
  final ValueNotifier<double> keyboardBottomInset = ValueNotifier<double>(0);

  /// 窄屏工具栏贴齐高度；与正文 nudge 同拍写入。
  final ValueNotifier<double> toolbarKeyboardInset = ValueNotifier<double>(0);

  Timer? _settleTimer;
  Timer? _nudgeDebounceTimer;
  Timer? _cacheDownCorrectTimer;
  bool _appliedCacheThisOpen = false;
  bool _scrollScheduled = false;
  int? _burstStartMs;
  int _settleResetCount = 0;
  double _settleArmedPending = 0;

  bool get _editFocused =>
      isMounted() && isEditMode() && session.focusNode.hasFocus;

  bool get settleActive =>
      (_settleTimer?.isActive ?? false) ||
      (_nudgeDebounceTimer?.isActive ?? false) ||
      (_cacheDownCorrectTimer?.isActive ?? false);

  int get settleResetCount => _settleResetCount;

  void dispose() {
    _settleTimer?.cancel();
    _nudgeDebounceTimer?.cancel();
    _cacheDownCorrectTimer?.cancel();
    keyboardBottomInset.dispose();
    toolbarKeyboardInset.dispose();
  }

  void setKeyboardBottomInset(double logical) {
    if (keyboardBottomInset.value == logical) {
      return;
    }
    keyboardBottomInset.value = logical;
  }

  void setToolbarKeyboardInset(double logical) {
    if (toolbarKeyboardInset.value == logical) {
      return;
    }
    toolbarKeyboardInset.value = logical;
  }

  /// 与正文 nudge 同拍显栏；已显示则仅在 raise/correct 时改高度。
  void syncToolbarWithCommitted({required String reason}) {
    final target = session.keyboardBottomInset;
    if (!shouldSyncImeToolbarInset(
      targetLogical: target,
      toolbarLogical: toolbarKeyboardInset.value,
    )) {
      return;
    }
    final previous = toolbarKeyboardInset.value;
    setToolbarKeyboardInset(target);
    imeTimelineCommit(
      ImeTimelineScope.toolbar,
      pendingLogical: session.pendingKeyboardInset,
      committedLogical: target,
      reason: reason,
    );
    imeTimelineVisualShift(
      ImeTimelineScope.edit,
      phase: 'toolbarInset',
      reason: reason,
      applied: true,
      delta: target - previous,
      pendingLogical: session.pendingKeyboardInset,
      committedLogical: session.keyboardBottomInset,
      toolbarLogical: target,
    );
  }

  /// 收起/切模式：正文留白与工具栏同拍清零。
  void clearInsets() {
    _nudgeDebounceTimer?.cancel();
    _nudgeDebounceTimer = null;
    _cacheDownCorrectTimer?.cancel();
    _cacheDownCorrectTimer = null;
    _appliedCacheThisOpen = false;
    setKeyboardBottomInset(0);
    setToolbarKeyboardInset(0);
  }

  void cancelSettleTimer() {
    _settleTimer?.cancel();
  }

  void publishDebugHud({
    required int burstMs,
    required bool focused,
    String? lastCommitReason,
  }) {
    publishImeDebugHud(
      scope: ImeTimelineScope.edit,
      pendingLogical: session.pendingKeyboardInset,
      committedLogical: session.keyboardBottomInset,
      toolbarLogical: toolbarKeyboardInset.value,
      burstMs: burstMs,
      settleResetCount: _settleResetCount,
      settleActive: settleActive,
      focused: focused,
      lastCommitReason: lastCommitReason,
    );
  }

  void armSettleTimer({
    required int burstOriginMs,
    required String cacheKey,
  }) {
    _settleTimer?.cancel();
    _settleArmedPending = session.pendingKeyboardInset;
    _settleTimer = Timer(kImeInsetSettleDelay, () {
      if (!_editFocused || isSuspended() || isDrawerOpen()) {
        return;
      }
      final settleBurstMs =
          DateTime.now().millisecondsSinceEpoch - burstOriginMs;
      final decision = resolveImeSettleDecision(
        pendingLogical: session.pendingKeyboardInset,
        committedLogical: session.keyboardBottomInset,
        cachedLogical: defaultImeHeightCache.lookup(cacheKey),
        appliedCacheThisOpen: _appliedCacheThisOpen,
      );
      imeTimelineSettle(
        ImeTimelineScope.edit,
        pendingLogical: session.pendingKeyboardInset,
        committedLogical: session.keyboardBottomInset,
        burstMs: settleBurstMs,
        settleResetCount: _settleResetCount,
        willCommit: decision.shouldCommit,
      );
      if (!decision.shouldCommit &&
          decision.nudge == ImeSettleNudgeMode.none) {
        return;
      }
      applySettleDecision(
        decision,
        settleBurstMs: settleBurstMs,
        cacheKey: cacheKey,
      );
    });
  }

  void commitKeyboardInset(double logical, {String? reason}) {
    final previous = session.keyboardBottomInset;
    if (previous != logical) {
      rebuild(() => session.keyboardBottomInset = logical);
      setKeyboardBottomInset(logical);
      imeTimelineCommit(
        ImeTimelineScope.edit,
        pendingLogical: session.pendingKeyboardInset,
        committedLogical: logical,
        reason: reason,
      );
      imeTimelineVisualShift(
        ImeTimelineScope.edit,
        phase: 'spacerCommit',
        reason: reason,
        applied: true,
        delta: logical - previous,
        pendingLogical: session.pendingKeyboardInset,
        committedLogical: logical,
        toolbarLogical: toolbarKeyboardInset.value,
      );
    } else {
      setKeyboardBottomInset(logical);
    }
    if (logical <= 0) {
      _appliedCacheThisOpen = false;
      _cancelNudgeDebounceTimer();
      _cancelCacheDownCorrectTimer();
    }
  }

  void _cancelNudgeDebounceTimer() {
    _nudgeDebounceTimer?.cancel();
    _nudgeDebounceTimer = null;
  }

  void _cancelCacheDownCorrectTimer() {
    _cacheDownCorrectTimer?.cancel();
    _cacheDownCorrectTimer = null;
  }

  void armDebouncedNudge({required String cacheKey}) {
    _cancelNudgeDebounceTimer();
    _nudgeDebounceTimer = Timer(kImeNudgeDebounceDelay, () {
      if (!_editFocused) {
        return;
      }
      syncToolbarWithCommitted(reason: 'settleDebounced');
      nudgeCaretAboveIme(reason: 'settleDebounced');
      defaultImeHeightCache.store(cacheKey, session.keyboardBottomInset);
    });
  }

  void syncCacheDownCorrectTimer({required String cacheKey}) {
    if (!shouldArmImeCacheDownCorrect(
      appliedCacheThisOpen: _appliedCacheThisOpen,
      pendingLogical: session.pendingKeyboardInset,
      committedLogical: session.keyboardBottomInset,
    )) {
      _cancelCacheDownCorrectTimer();
      return;
    }
    _cacheDownCorrectTimer?.cancel();
    _cacheDownCorrectTimer = Timer(kImeNudgeDebounceDelay, () {
      if (!_editFocused) {
        return;
      }
      if (!shouldArmImeCacheDownCorrect(
        appliedCacheThisOpen: _appliedCacheThisOpen,
        pendingLogical: session.pendingKeyboardInset,
        committedLogical: session.keyboardBottomInset,
      )) {
        return;
      }
      final next = session.pendingKeyboardInset;
      commitKeyboardInset(next, reason: 'correctCacheDown');
      defaultImeHeightCache.store(cacheKey, next);
      syncToolbarWithCommitted(reason: 'correctCacheDown');
      publishDebugHud(
        burstMs: 0,
        focused: true,
        lastCommitReason: 'correctCacheDown',
      );
      if (next > 0) {
        scheduleSettleNudge(reason: 'correctCacheDown');
      }
    });
  }

  void applySettleDecision(
    ImeSettleDecision decision, {
    required int settleBurstMs,
    required String cacheKey,
  }) {
    if (decision.markCacheApplied) {
      _appliedCacheThisOpen = true;
    }
    if (decision.commitLogical != null) {
      commitKeyboardInset(
        decision.commitLogical!,
        reason: decision.reason,
      );
    }
    if (decision.storeCacheLogical != null) {
      defaultImeHeightCache.store(cacheKey, decision.storeCacheLogical!);
    }
    publishDebugHud(
      burstMs: settleBurstMs,
      focused: true,
      lastCommitReason: decision.reason ?? 'settle',
    );
    switch (decision.nudge) {
      case ImeSettleNudgeMode.immediate:
        _cancelNudgeDebounceTimer();
        syncToolbarWithCommitted(reason: decision.reason ?? 'applyCache');
        scheduleSettleNudge(reason: decision.reason);
      case ImeSettleNudgeMode.debounce:
        armDebouncedNudge(cacheKey: cacheKey);
      case ImeSettleNudgeMode.none:
        break;
    }
    syncCacheDownCorrectTimer(cacheKey: cacheKey);
  }

  /// 编辑 settle：padding 布局后单次上推（工具栏已同拍显示）。
  void scheduleSettleNudge({String? reason}) {
    if (_scrollScheduled) {
      return;
    }
    _scrollScheduled = true;
    imeTimelineScroll(ImeTimelineScope.edit, reason: reason ?? 'settle');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;
      if (!_editFocused) {
        return;
      }
      nudgeCaretAboveIme(reason: reason ?? 'settle');
    });
  }

  void onKeyboardMetricsChanged({required String cacheKey, required double inset}) {
    if (!isMounted() || !isEditMode()) {
      return;
    }
    if (isSuspended() || isDrawerOpen()) {
      return;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final hadActiveSettle = _settleTimer?.isActive ?? false;
    if (!hadActiveSettle) {
      _burstStartMs = nowMs;
      _settleResetCount = 0;
    }
    final previousPending = session.pendingKeyboardInset;
    session.pendingKeyboardInset = session.focusNode.hasFocus ? inset : 0;
    final burstOriginMs = _burstStartMs ?? nowMs;
    final burstMs = nowMs - burstOriginMs;

    if (!session.focusNode.hasFocus) {
      _settleTimer?.cancel();
      var clearedForUnfocus = false;
      if (session.keyboardBottomInset != 0 ||
          keyboardBottomInset.value != 0 ||
          toolbarKeyboardInset.value != 0) {
        clearInsets();
        rebuild(session.resetKeyboardInsets);
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
        pendingLogical: session.pendingKeyboardInset,
        committedLogical: session.keyboardBottomInset,
        burstMs: burstMs,
        settleResetCount: _settleResetCount,
        focused: false,
      );
      publishDebugHud(
        burstMs: burstMs,
        focused: false,
        lastCommitReason: clearedForUnfocus ? 'unfocused' : null,
      );
      return;
    }

    if (shouldCommitImeDismissImmediately(
      pendingLogical: session.pendingKeyboardInset,
      committedLogical: session.keyboardBottomInset,
      appliedCacheThisOpen: _appliedCacheThisOpen,
      previousPendingLogical: previousPending,
    )) {
      _settleTimer?.cancel();
      clearInsets();
      rebuild(() => session.keyboardBottomInset = 0);
      imeTimelineCommit(
        ImeTimelineScope.edit,
        pendingLogical: session.pendingKeyboardInset,
        committedLogical: 0,
        reason: 'dismissImmediate',
      );
      imeTimelineMetrics(
        ImeTimelineScope.edit,
        pendingLogical: session.pendingKeyboardInset,
        committedLogical: 0,
        burstMs: burstMs,
        settleResetCount: _settleResetCount,
        focused: true,
      );
      publishDebugHud(
        burstMs: burstMs,
        focused: true,
        lastCommitReason: 'dismissImmediate',
      );
      return;
    }

    final restart = !hadActiveSettle ||
        shouldRestartImeSettleTimer(
          pendingLogical: session.pendingKeyboardInset,
          armedPendingLogical: _settleArmedPending,
        );
    if (restart) {
      if (hadActiveSettle) {
        _settleResetCount++;
      }
      armSettleTimer(burstOriginMs: burstOriginMs, cacheKey: cacheKey);
    }
    syncCacheDownCorrectTimer(cacheKey: cacheKey);

    imeTimelineMetrics(
      ImeTimelineScope.edit,
      pendingLogical: session.pendingKeyboardInset,
      committedLogical: session.keyboardBottomInset,
      burstMs: burstMs,
      settleResetCount: _settleResetCount,
      focused: true,
    );
    publishDebugHud(burstMs: burstMs, focused: true);
  }

  void scheduleScrollCaretAboveIme({String? reason}) {
    if (_scrollScheduled) {
      return;
    }
    _scrollScheduled = true;
    imeTimelineScroll(ImeTimelineScope.edit, reason: reason);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;
      if (!_editFocused) {
        return;
      }
      scrollCaretAboveIme();
    });
  }

  /// 编辑模式：将光标滚出键盘/底部工具栏遮挡区（对齐实时模式 ensureVisible + nudge）。
  void scrollCaretAboveIme() {
    if (!_editFocused) {
      return;
    }
    final selection = contentController.selection;
    if (!selection.isValid) {
      return;
    }
    final editable = findEditableTextState();
    if (editable == null) {
      return;
    }
    final controller = session.scrollController;
    final offsetBefore = controller.hasClients ? controller.offset : null;
    editable.bringIntoView(selection.extent);
    final offsetAfter = controller.hasClients ? controller.offset : offsetBefore;
    imeTimelineVisualShift(
      ImeTimelineScope.edit,
      phase: 'bringIntoView',
      offsetBefore: offsetBefore,
      offsetAfter: offsetAfter,
      delta: offsetBefore != null && offsetAfter != null
          ? offsetAfter - offsetBefore
          : null,
      applied: offsetBefore != null &&
          offsetAfter != null &&
          (offsetAfter - offsetBefore).abs() > 0.5,
      pendingLogical: session.pendingKeyboardInset,
      committedLogical: session.keyboardBottomInset,
      toolbarLogical: toolbarKeyboardInset.value,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isMounted()) {
        nudgeCaretAboveIme(reason: 'afterBringIntoView');
      }
    });
  }

  /// 从焦点或 TextField 子树定位 [EditableTextState]。
  EditableTextState? findEditableTextState() {
    final fromFocus = session.focusNode.context
        ?.findAncestorStateOfType<EditableTextState>();
    if (fromFocus != null) {
      return fromFocus;
    }
    final root = contentFieldKey.currentContext;
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
  void nudgeCaretAboveIme({String? reason}) {
    if (!_editFocused) {
      return;
    }
    final controller = session.scrollController;
    if (!controller.hasClients) {
      return;
    }
    final editable = findEditableTextState();
    final fieldContext = contentFieldKey.currentContext;
    if (editable == null || fieldContext == null) {
      return;
    }
    final selection = contentController.selection;
    if (!selection.isValid) {
      return;
    }

    final isWide = layoutWidth() >= kWideLayoutBreakpoint;
    final spacer = editImeBottomSpacerHeight(
      keyboardInset: session.keyboardBottomInset,
      focused: true,
      includeToolbar: !isWide,
    );
    if (spacer > 0) {
      imeTimelineVisualShift(
        ImeTimelineScope.edit,
        phase: 'nudge',
        reason: reason,
        applied: false,
        pendingLogical: session.pendingKeyboardInset,
        committedLogical: session.keyboardBottomInset,
        toolbarLogical: toolbarKeyboardInset.value,
      );
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
      imeTimelineVisualShift(
        ImeTimelineScope.edit,
        phase: 'nudge',
        reason: reason,
        offsetBefore: controller.offset,
        offsetAfter: controller.offset,
        delta: 0,
        applied: false,
        pendingLogical: session.pendingKeyboardInset,
        committedLogical: session.keyboardBottomInset,
        toolbarLogical: toolbarKeyboardInset.value,
      );
      return;
    }
    final nextOffset = (controller.offset + delta).clamp(
      controller.position.minScrollExtent,
      controller.position.maxScrollExtent,
    );
    if ((nextOffset - controller.offset).abs() < 0.5) {
      imeTimelineVisualShift(
        ImeTimelineScope.edit,
        phase: 'nudge',
        reason: reason,
        offsetBefore: controller.offset,
        offsetAfter: controller.offset,
        delta: delta,
        applied: false,
        pendingLogical: session.pendingKeyboardInset,
        committedLogical: session.keyboardBottomInset,
        toolbarLogical: toolbarKeyboardInset.value,
      );
      return;
    }
    final offsetBefore = controller.offset;
    controller.jumpTo(nextOffset);
    imeTimelineVisualShift(
      ImeTimelineScope.edit,
      phase: 'nudge',
      reason: reason,
      offsetBefore: offsetBefore,
      offsetAfter: controller.offset,
      delta: delta,
      applied: true,
      pendingLogical: session.pendingKeyboardInset,
      committedLogical: session.keyboardBottomInset,
      toolbarLogical: toolbarKeyboardInset.value,
    );
  }
}
