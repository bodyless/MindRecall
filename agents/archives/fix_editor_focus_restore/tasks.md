## 步骤 1：焦点恢复与收 IME 纯函数

- [x] 在 `lib/features/memo/editor/mode_input_session.dart` 新增 `shouldRestoreEditorFocusAfterSuspend`：`restoreRequested` 为真、`suppressRestore` 为假、且 `suspendedMemoId` 非空并等于 `activeMemoId` 时才为真；
- [x] 在同文件新增 `shouldUnfocusOnImeUserDismiss`：`hasFocus` 为真、`editorFocusSuspended` / `layoutTransitionActive` / `deferFocusBlur` 均为假、且 `imeDismissed` 为真时才为真；
- [x] 在同文件新增 `liveOverlayIgnoresPointers`：`hasFocus` 为假时为真（失焦 Overlay 不参与命中）；
- [x] 在 `test/mode_input_session_test.dart` 覆盖：同篇恢复、换篇不恢复、`suppressRestore` 即使同篇也不恢复、`suspendedMemoId` 空不恢复；收 IME 仅在下落且未 suspend/未换块时 unfocus；点选后 inset 仍为 0 不 unfocus；`liveOverlayIgnoresPointers` 聚焦否；

## 步骤 2：同篇才 resume，换篇丢掉焦点

- [x] 在 `lib/features/memo/editor/memo_editor_screen.dart` 的 `_suspendEditorFocus` 增加记录：suspend 当时的 `_activeMemoId`，并把「禁止本次 resume」标志清为假；
- [x] 在同文件 `_resumeEditorFocus` 用 `shouldRestoreEditorFocusAfterSuspend` 决定是否 `requestFocus` / `LiveMarkdownEditor.restoreFocus`；条件不满足时仍结束 suspended 状态，不要再 unfocus；
- [x] 在同文件抽出「丢掉编辑焦点」：`_titleFocusNode`、`_editSession.focusNode`、`_liveSession.focusNode` 均 `unfocus`，`_liveSession.clearSessionFlags`，编辑 inset 走现有 `_clearImeInsets` / `resetKeyboardInsets`；
- [x] 在同文件 `_openMemo` 当 `id != _activeMemoId` 时，在写入新文档前后调用上述丢掉焦点（宽屏无抽屉也要执行）；不要在此处 `requestFocus`；
- [x] 在同文件 `_openSearchResult` 在开篇前将「禁止本次 resume」置真，并丢掉编辑焦点；即使 `id == _activeMemoId` 的早退路径也要丢掉焦点再 `_jumpToTarget`；
- [x] 在同文件 `_jumpToTarget` 正文分支去掉 `_activeBodyFocus.requestFocus()`，仍设置 `_contentController.selection` 并 `_scrollContentToLine`；
- [x] 确认 `_createNewMemo` 仍在 `_loadMemoIntoEditor` 之后 `_activeBodyFocus.requestFocus()`；`_onCapturedProcessText` 仍 `requestFocus`；
- [x] 在同文件 `_pickAndInsertImage` 插入成功后对 `_activeBodyFocus.requestFocus()`，实时模式再 `_liveEditorKey.currentState?.restoreFocus()`；删除或停止只聚焦 `_editSession.focusNode`；

## 步骤 3：用户收起 IME 则 unfocus

- [x] 在 `memo_editor_screen.dart` 增加宽屏也执行的 IME metrics 路径（不要复用 `_syncDrawerOpenDragGestureGate` 的 `isWide` 早退）：用 `View` 的 `viewInsets.bottom` 下落沿，或 `shouldCommitImeDismissImmediately`；`shouldUnfocusOnImeUserDismiss` 为真时丢掉标题与两套正文焦点并 `clearSessionFlags`；Live / `EditImeCoordinator` 不要再各自 `unfocus`；
- [x] 在 `memo_editor_screen.dart` 的 `_onLiveFocusChanged`：因用户收起 IME 导致的失焦不要走宽限内 `restoreFocus()`；换块 `deferFocusBlur` / `layoutTransitionActive` 的现有抢回保留；
- [x] 在 `test/mode_input_session_test.dart` 覆盖 `shouldUnfocusOnImeUserDismiss` 与 `shouldCommitImeDismissImmediately` 组合：suspend 中、换块中不 unfocus；inset 仍为 0 的聚焦不 unfocus；

## 步骤 4：Live Overlay 失焦不拦拖动手势

- [x] 在 `live_markdown_editor.dart` 活动块 `CompositedTransformFollower` Overlay 外包 `IgnorePointer`（或等价），`ignoring` 取 `liveOverlayIgnoresPointers(hasFocus: widget.focusNode.hasFocus)`；用 `FocusNode` 或已有 `_imeSessionFocused` 重建，不要为 inset 整树 `setState`；
- [x] 在同文件 `_buildBlockSlot`：活动且可编辑的块在 `liveOverlayIgnoresPointers` 为真时与非活动块一样可点（`onTapDown` + `_activateBlock`），以便点回光标；聚焦时保持现状（列表槽不抢 Overlay 的 TextField）；
- [x] 在同文件 `_RendererSyncedCaret` 维持现有「无焦点不画光标/水滴」；不要靠清 `_activeBlockId` 来解决拖动；
- [x] 在 `test/live_empty_body_hint_test.dart` 或 `test/live_block_tap_ops_test.dart` 能测的范围内覆盖：失焦时活动块仍可通过点选激活；不要破坏空正文 `SliverFillRemaining` 点击聚焦；

## 步骤 5：README、fixed_list 与门禁

- [x] 在 `README.md` 功能概览写明：打开已有文档默认无光标；同篇开关文件栏恢复光标；换篇不继承；用户收起输入法后无光标；侧滑门禁仍只认 IME inset；
- [x] 在 `README.md` 易踩坑第 28 条去掉「收起键盘后即使光标仍在也可侧滑」中「光标仍在」的过时表述，改为门禁只认 inset、收键盘会丢光标但仍可侧滑；
- [x] 在 `README.md` Agent 注意补一条：切文档须丢掉壳层 Focus，resume 须比对 suspend 时 memoId；搜索跳转禁止 `requestFocus`；
- [x] 在 `agents/fixed_list.md` 目录与清单顶部追加当日条目（打开已有文档无光标、换篇不恢复、收 IME 无光标、失焦 Overlay 不拦拖动）；
- [x] 按 `.cursor/rules/unit-testing.mdc` 跑 `scripts/run_unit_tests` 全量通过后再宣告完成；
