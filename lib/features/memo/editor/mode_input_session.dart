import 'package:flutter/material.dart';

/// 编辑模式私有输入基础设施（Focus / Scroll / IME 键盘高度）。
///
/// 与 [LiveInputSession] 分离，避免失焦宽限与滚动位置串台。
final class EditInputSession {
  EditInputSession();

  final FocusNode focusNode = FocusNode(debugLabel: 'edit-body');
  final ScrollController scrollController = ScrollController();

  /// 由 metrics 即时写入的键盘底 inset（逻辑像素；跟随动画，勿 trailing debounce）。
  double keyboardBottomInset = 0;
  double pendingKeyboardInset = 0;

  /// 用于避免选区未变时重复触发 IME 上推。
  TextSelection? lastSelectionForIme;

  void resetKeyboardInsets() {
    keyboardBottomInset = 0;
    pendingKeyboardInset = 0;
  }

  void dispose() {
    focusNode.dispose();
    scrollController.dispose();
  }
}

/// 实时模式私有输入基础设施（Focus / Scroll / 工具栏 session 标志）。
///
/// 换块短暂失焦宽限只作用于此 session，不影响编辑模式。
final class LiveInputSession {
  LiveInputSession();

  final FocusNode focusNode = FocusNode(debugLabel: 'live-body');
  final ScrollController scrollController = ScrollController();

  /// 曾聚焦过正文（用于窄屏工具栏在短暂失焦时保持显示）。
  bool hadFocus = false;

  /// 换块/拆行等导致短暂失焦时，推迟把「会话结束」算进工具栏。
  bool deferFocusBlur = false;

  /// 窄屏工具栏是否视为「输入会话中」（不含 layoutTransition，由壳层并入）。
  bool get inputSessionActive => hadFocus || deferFocusBlur;

  void clearSessionFlags() {
    hadFocus = false;
    deferFocusBlur = false;
  }

  void dispose() {
    focusNode.dispose();
    scrollController.dispose();
  }
}
