## 目标

打开输入框页时，光标不跨文档继承：新开已有文档默认无光标（点一下才有）；同篇开关文件栏仍恢复刚才的光标。用户收起输入法后无光标，长段正文可以上下拖。标题、实时、编辑三种输入面一并遵守。

## 方案

焦点会话仍挂在 `MemoEditorScreen` 的 `_titleFocusNode` / `EditInputSession` / `LiveInputSession` 上，不按文档新建 `FocusNode`。用「suspend 时记下的 memoId + 是否禁止恢复」决定关侧栏要不要 `_resumeEditorFocus`；换篇在 `_openMemo` 里主动丢掉三处焦点。用户收起 IME（inset 下落，`shouldCommitImeDismissImmediately` / 等价下落沿）时 unfocus，并禁止 `_onLiveFocusChanged` 宽限里再 `restoreFocus`。Live 活动块 Overlay 在失焦时不参与命中，手势交给 `ListView`；失焦的活动块列表槽可点以重新聚焦。搜索跳转只滚到目标、不 `requestFocus`；新建、插入图、`PROCESS_TEXT` 仍聚焦正文。

## 已决事项

- 新建文档光标仍落在正文（`_createNewMemo` 的 `_activeBodyFocus.requestFocus()` 不改到标题）
- 搜索跳转默认无光标；插入图要有光标；`PROCESS_TEXT`（系统选区「记录到笔记」）要有光标
- 长段难拖：用户收起键盘则 unfocus，且 Live Overlay 失焦时不命中；不要只藏光标、不要清掉 `_activeBlockId`
- 同篇开关文件栏（窄屏抽屉 / 现有 suspend→resume）：与现在一样恢复焦点
- 只对同篇恢复；换了文档不恢复（窄屏 resume 比对 suspend 时 memoId；宽屏 `_openMemo` 换 id 主动 unfocus）
- 点搜索结果关栏也不恢复（即使仍是同篇）
- 标题、实时、编辑一并

## 关注点

- 侧滑开抽屉门禁仍只认系统 `viewInsets`（2026-08-14）；禁止改回用 hasFocus/hadFocus 否决侧滑
- `_resumeEditorFocus` 决定不恢复时仍须把 `_editorFocusSuspended` 置回 false，且不得额外 unfocus（以免冲掉新建 / PROCESS_TEXT 已 `requestFocus` 的正文）
- `_onLiveFocusChanged` 在换块 `deferFocusBlur` / `layoutTransitionActive` 时仍可 `restoreFocus`；用户收起 IME 导致的失焦禁止再抢
- 判定「用户收起 IME」须用 inset **下落**（已有 `shouldCommitImeDismissImmediately` 或 viewInsets 从 >0.5 落到 ≤0.5），禁止「hasFocus 且 inset≈0」以免点选后键盘尚未升起就被 unfocus
- `_editorFocusSuspended` 为 true 时不要走「收 IME → unfocus」（侧栏路径已经 suspend）
- Live Overlay 是 `ListView` 上方的 `CompositedTransformFollower`，只 unfocus 不够；失焦必须 `IgnorePointer`（或不命中）
- 活动块列表槽目前无 `InkWell`；Overlay 忽略指针后，失焦活动块须能点选再 `_activateBlock` / `restoreFocus`
- `_pickAndInsertImage` 现在末尾只 `requestFocus` 编辑 session；实时模式下须聚焦 `_activeBodyFocus` 并 `restoreFocus`，禁止把焦点抢到不可见的 edit `FocusNode`
- 决策函数放 `mode_input_session.dart` 纯函数，禁令写进单测；不要把 memoId 比较只写在 Widget 里无法测
- README 功能概览与易踩坑第 28 条仍写「收起键盘后可侧滑」；须改成与「收键盘无光标」一致，侧滑门禁仍只认 inset

## 未决事项

- （无）
