## 步骤 1：代码块多行提交

- [x] 在 `lib/core/markdown/live_session_ops.dart` 的 `commitPlainToBlock` 中，将截取第一行的条件改为 `isSingleLineBlock(block)`，非单行块（含 `CodeBlock`）保留完整 `plainText`；
- [x] 在 `test/live_session_ops_test.dart` 的 `commitPlainToBlock` 组新增用例：多行 `CodeBlock` 提交后 `code` 含全部换行，单行 `HeadingBlock` 提交仍只留第一行；

## 步骤 2：空代码块深色框

- [x] 在 `lib/core/markdown/renderer/md_block_renderer.dart` 的 `_emptyBlockChrome` 中，将 `CodeBlock` 分支改为与有内容分支同类的全宽 `Container`（`codeBlockPadding` + `codeBlockDecoration` + 占位正文）；
- [x] 在 `test/live_image_delete_and_empty_chrome_test.dart` 的 empty chrome 组新增用例：空 `CodeBlock` 渲染带 `MdBlockStyles.codeBlockDecoration` 的底色容器，且仍无「…」占位；

## 步骤 3：中间插入行距

- [x] 在 `lib/core/markdown/live_session_ops.dart` 的 `splitMultilineBlockAt` 中，新建 `ParagraphBlock` 时把被拆块原有的 `continuesWithNext` 赋给新块（左半段仍走 `paragraphAfterSplit`）；
- [x] 在 `test/live_session_ops_test.dart` 的 `splitMultilineBlockAt` 组新增用例：三行正文且前两行 `continuesWithNext` 为 true 时，在第一行末拆入新行后，新块对原第二行仍为 `continuesWithNext: true`；

## 步骤 4：点代码块下方空白续写

- [x] 在 `lib/core/markdown/live_session_ops.dart` 中于 `isEmptyDocumentBody` 旁新增 `liveShowsTrailingAfterCodeFill`：非空文档且 `_blocks.last is CodeBlock` 时为 true；
- [x] 在 `test/live_session_ops_test.dart` 新增对 `liveShowsTrailingAfterCodeFill` 的用例（最后一块代码为 true；最后一块段落/空文档为 false）；
- [x] 在 `lib/features/memo/editor/live/live_markdown_editor.dart` 为文末代码填空新增独立 `ValueKey`（如 `trailingAfterCodeFillKey`），与 `emptyBodyFillKey` 分开；
- [x] 在 `LiveMarkdownEditorState.build` 的 sliver 列表中，当 `liveShowsTrailingAfterCodeFill(_blocks)` 时挂 `SliverFillRemaining`（`hasScrollBody: false`），点击回调新方法 `_onTrailingAfterCodeTap`；空文档填空与 hint 条件保持 `isEmptyDocumentBody`；
- [x] 在 `_onTrailingAfterCodeTap` 中：若最后一块不是 `CodeBlock` 则 return；否则 `_commitActiveBlock`，对最后一块下标调用已有 `ensureEditableBlockAfterAtomic`，`syncParagraphFlowFlags`，写回 `_blocks` 并 `_syncToParent`，再 `_switchToActiveBlock` 聚焦新空段落（offset 0、`forceFocus: true`）；
- [x] 在 `test/live_empty_body_hint_test.dart`（或同目录新 widget 测试）新增：源码为围栏代码且为最后一块时能点到 `trailingAfterCodeFillKey`，点后块列表末尾为空段落且 focus 落到该段；已有正文非代码时该 key 不出现；空文档仍只有 `emptyBodyFillKey`；

## 步骤 5：标题切换 Timeline

- [x] 在 `lib/core/debug/` 新增纯函数（可放新文件 `live_editor_timeline.dart` 或并入现有 debug 文件）组装 `Live.applyBlockType` 的 arguments：`from`、`to`、`layoutChanged`、`didSetState`；
- [x] 在对应 `test/` 单测中覆盖该 arguments 纯函数；
- [x] 在 `lib/features/memo/editor/live/live_markdown_editor.dart` 的 `_applyLineMarkdownTransform` 中用 `debugTimelineSync('Live.applyBlockType', …)` 包住变换；`layoutChanged == false` 且未 `setState` 时再 `debugTimelineInstant('Live.applyBlockType.skipSetState')`；
- [x] 在 `lib/features/memo/editor/memo_editor_screen.dart` 的 `_onLiveInputStabilizing` 中，当因已聚焦且已 defer 而跳过 `setState` 时 `debugTimelineInstant('Editor.toolbarStabilize.skip')`，现有 `Editor.toolbarStabilize` 包住的 `setState` 保持不变；
- [x] 本步骤禁止修改 `_applyLineMarkdownTransform` 的 `layoutChanged` 判定，禁止为 H1/H2/H3 补 `setState` 或改 800ms defer；

## 步骤 6：列表点击定位 HUD 与 LOG

- [x] 在 `lib/core/debug/cursor_debug_hud.dart` 的 `CursorDebugSnapshot` 增加 overlay 命中、overlay 在视口、IME 会话焦点、正文焦点、语言框焦点、同块丢落点字段，并更新 `==` / `hashCode` 与默认值（Edit 模式可保持 false/空）；
- [x] 在 `formatCursorDebugHudLines` 增加一行展示上述字段；在 `test/cursor_debug_hud_test.dart` 补格式化断言；
- [x] 在 `lib/core/debug/` 增加 `formatLiveTapDebugLog` 纯函数（固定前缀 `[LiveTap]`，字段与 HUD 一致），并在 `test/` 覆盖其输出；
- [x] 在 `LiveMarkdownEditorState._publishLiveCursorDebugHud` 写入新 HUD 字段（`_liveOverlayHitTestActive`、`_activeOverlayInView`、`_imeSessionFocused`、`widget.focusNode.hasFocus`、`_languageFocusNode.hasFocus`）；
- [x] 在 Overlay 现有 `Listener.onPointerDown`、槽 `wrapTappable` 的 `InkWell.onTap`、`_activateBlock`（区分 sameId / switch、pendingTap 使用或丢弃）、`restoreFocus`（`canRequestFocus` 与调用前后 `hasFocus`）于 `kDebugMode` 下调用 `debugTimelineInstant` 与 `debugPrint(formatLiveTapDebugLog(…))`；
- [x] 在 `lib/core/debug/debug_info_overlay.dart` 的 HUD 紧急刷新条件中纳入新光标字段，避免 overlay 命中变化被 80ms 限频吃掉；
- [x] 本步骤禁止修改 `liveOverlayIgnoresPointers`、禁止修改同块 `_activateBlock` 丢弃 `_pendingActivateTapGlobal` 的产品逻辑、禁止改 `_updateActiveOverlayVisibility` 判定；

## 步骤 7：文档、台账与门禁

- [x] 在 `README.md` 功能/数据流中写明：实时代码块提交保留多行；空代码块也有深色框；最后一块为代码块时可点文末空白续写；正文中间 Enter 新行继承段内行距；
- [x] 在 `README.md` 性能 Timeline / 光标 HUD 说明中补 `Live.applyBlockType`、`Live.applyBlockType.skipSetState`、`Editor.toolbarStabilize.skip` 及 Cursor HUD overlay 行、`[LiveTap]` 日志用途；
- [x] 在 `agents/fixed_list.md` 目录与清单顶部各追加四条（当天日期）：代码块多行失焦只留第一行；空代码块无深色框；文末代码块下方无法续写；中间插入正文行距变大；
- [x] 跑通 `.\scripts\run_unit_tests.ps1`，非 0 则继续改到 PASSED；
