## 步骤 1：Overlay 垂直拖转发给列表

- [x] 在 `lib/features/memo/editor/live/live_markdown_editor.dart` 的 `LiveMarkdownEditor` 上新增 `@visibleForTesting` 的 `ValueKey`（如 `overlayListScrollKey`），供单测拖活动块 Overlay；
- [x] 在 `LiveMarkdownEditorState` 增加字段保存 `ScrollPosition.drag` 返回的 `Drag`，并在 `dispose` 里若仍存在则 `cancel` 后置空；
- [x] 在 `LiveMarkdownEditorState` 新增垂直拖 start/update/end/cancel：`hasClients` 时对 `widget.scrollController.position` 调用 `drag` / `update` / `end` / `cancel`；**禁止**在这些回调里 `unfocus`、清 `_activeBlockId`、调用 `_scrollActiveBlockIntoView`；
- [x] 在 `LiveMarkdownEditor.build` 活动块 Overlay 中，于现有 `IgnorePointer`（`liveOverlayIgnoresPointers`）之内、包住现有 `Listener`+`Focus`+`MdBlockEditorField` 的那一层，增加只处理垂直拖的检测器（`onVerticalDragStart`/`Update`/`End`/`Cancel` 接到上一步），并挂上 `overlayListScrollKey`；**禁止**在该检测器上挂 `onTap`、`onPanUpdate` 或其它会抢走单击的回调；
- [x] 确认该检测器不要包住满屏 `LayoutBuilder` / `CompositedTransformFollower` 的整页约束，只留在 `Align(heightFactor: 1.0)` 的活动块内容上；
- [x] 不要把 Overlay `TextField` 挪进 `SliverList` 槽位；不要改 `liveOverlayIgnoresPointers` 的失焦为 true 语义；不要改 chromeless `MdBlockEditorField` 的 `NeverScrollableScrollPhysics`；不要随焦点拆活动槽 `InkWell`；

## 步骤 2：回归测试

- [x] 新增 `test/live_overlay_scroll_test.dart`：用与 `test/live_empty_body_hint_test.dart` 相同的 `MaterialApp`+`LiveMarkdownEditor` 泵入方式；`setUp`/`tearDown` 将 `debugDefaultTargetPlatformOverride` 设为 `TargetPlatform.android` 并恢复；
- [x] 在该文件写用例：视口矮、正文为一块足够长的段落（或等价铺满），`keyboardBottomInset` 为大于 0 的 `ValueNotifier` 模拟 IME，`focusNode.requestFocus` 后在 `overlayListScrollKey`（或活动 `TextField`）上 `tester.drag` 垂直超过 slop，断言 `scrollController.offset` 改变且 `focusNode.hasFocus` 仍为 true；
- [x] 在该文件写用例：同一聚焦 Overlay 上 `tester.tap` **一次** 后 `pump`，断言 `focusNode.hasFocus` 为 true 且活动 `TextField` 的选区已落到点击附近（不要先 tap 一次再 tap 一次才落点）；
- [x] 在 `test/mode_input_session_test.dart` 的 `liveOverlayIgnoresPointers` 组保持失焦 true、聚焦 false 的现有断言，不要改语义；

## 步骤 3：文档与台账

- [x] 在 `README.md`「其他 UX」中把「用户收起输入法后无光标（长段可上下拖）」改为：收 IME 仍丢光标；**聚焦且 IME 仍开时，在活动块文字上垂直拖即可滚列表**，单击一次落光标；
- [x] 在 `README.md`「Agent 注意」实时 Overlay 那条或第 33 条补一句：聚焦 Overlay 须把垂直拖转发给外层 `CustomScrollView`，禁止靠 `unfocus`/清 `_activeBlockId` 换滚动，禁止外层 `onTap` 抢走单击；
- [x] 在 `README.md` 目录结构 `test/` 下增加 `live_overlay_scroll_test.dart`；
- [x] 在 `agents/fixed_list.md` 的「## 目录」最上方增加一行：`2026-09-06 — 实时聚焦有 IME 时无法拖列表`；
- [x] 在 `agents/fixed_list.md` 的「## 清单」最上方追加同标题条目：现象（铺满且光标在块内无法拖）、根因（Overlay 与列表是 Stack 兄弟，聚焦 TextField 独食命中）、修复要点（垂直拖转发 `position.drag`；不 unfocus；外层禁止 onTap；失焦仍 IgnorePointer）、相关文件与测试名；
- [x] 运行 `scripts/run_unit_tests`（Windows 为 `.\scripts\run_unit_tests.ps1`）至通过；
