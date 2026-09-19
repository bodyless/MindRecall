## 目标

实时模式修掉四条必现：代码块多行失焦只剩第一行；空代码块无深色框；代码块在文末时点下方空白无法续写正文；正文中间插入一行后行距变大（切模式才恢复）。H1/H2/H3 偶发卡约一秒、无序列表偶现点中间无光标：本方案只加 debug Timeline / 屏上 HUD / `[LiveTap]` 日志，不改标题换级策略、不改 Overlay 命中。验收：多行代码失焦与切模式后源码仍含全部行；空代码块有与有内容时同类的深色底；最后一块为代码块时点文末空白会聚焦其后空段落；中间 Enter 插入后与后续正文行距为段内间距；debug 下标题变换与列表点击能在 DevTools / HUD / logcat 对上事件。

## 方案

- 多行提交：`commitPlainToBlock` 与活动输入对齐，仅 `isSingleLineBlock` 才 `split('\n').first`；`CodeBlock` 整段 plain 写回 `code`。失焦、`_activateBlock`、`flushToParent` 共用此函数，不再另开通道。
- 空代码块外观：`MdBlockRenderer._emptyBlockChrome` 的 `CodeBlock` 分支补上与有内容分支相同的 `codeBlockDecoration` + `codeBlockPadding`（全宽 Container）。实时 Overlay 仍 chromeless，底色只来自列表槽。
- 文末续写：仅当最后一块是 `CodeBlock` 时，用与空文档同类的 `SliverFillRemaining` 承接代码块下方剩余空白。点击后 `ensureEditableBlockAfterAtomic` 在该代码块后插入空段落并聚焦。代码块内 Enter 仍不拆块。下一块已是段落时点到该段走现有 `_activateBlock`。空文档点空白仍走 `_onEmptyBodyAreaTap`（不新建）。
- 中间行距：`splitMultilineBlockAt` 插入的新段落继承被拆块原有的 `continuesWithNext`（左半段仍由 `paragraphAfterSplit` 标 true）。不把 `syncParagraphFlowFlags` 改成给所有相邻段落补 flag。
- 标题 Timeline：用现有 `debugTimelineSync` / `debugTimelineInstant`（仅 `kDebugMode`）包住 `_applyLineMarkdownTransform`；记录 from/to、`layoutChanged`、是否 `setState`。父屏 `_onLiveInputStabilizing` 在跳过整页 `setState` 时打 instant。不在本方案里给 H1↔H2↔H3 补 `setState` 或改 800ms defer。
- 列表点击定位：扩展光标 HUD 快照（Overlay 是否吃点击、是否在视口、正文/语言/IME 会话焦点、是否同块丢落点）；Overlay `onPointerDown` 与槽 `InkWell.onTap`、`_activateBlock`、`restoreFocus` 打 Timeline instant + `[LiveTap]` `debugPrint`。不改 `liveOverlayIgnoresPointers`、不改同块丢坐标逻辑。

## 已决事项

- 问题 3：点代码块下方空白 → 新建或聚焦下一段；不采用转代码时自动补段，也不改代码块内 Enter 拆块。
- 问题 3 范围：只在**最后一块是代码块**时出现文末可点空白；不要抢代码块本体或语言框。
- 问题 5：先当性能问题打 Timeline；本方案只埋点，不修漏刷/IME 策略。
- 问题 6：先定位（HUD + Timeline + LOG）；本方案只埋点，不改 Overlay 命中。
- 问题 1 / 2 / 4 按 explore 根因直接修。
- 埋点仅 `kDebugMode`；profile/release 零开销。`[LiveTap]` 只打 pointer/tap/activate/restoreFocus，不每帧打印。

## 关注点

- `commitPlainToBlock` 禁止继续用 `!supportsInlineFormatting` 当「单行」：标题要截行，代码块不要。
- 空代码 chrome 须与有内容 `CodeBlock` 装饰一致；禁止只加 padding 不加 `codeBlockDecoration`。实时 Overlay 保持 `chromeless: true`，不要在 Overlay 再画一套底。
- 文末 `SliverFillRemaining` 与空文档填充分开 key / 回调，避免已有正文测试误伤；空文档 hint 仍仅 `isEmptyDocumentBody`。
- 点击文末须先 `_commitActiveBlock` 再插段，避免未提交的多行代码被截断（与问题 1 同一提交函数）。
- 中间拆段只改 `splitMultilineBlockAt` 新块的 `continuesWithNext`；禁止扩大 `syncParagraphFlowFlags` 去给所有相邻段落 SET flag（空段序列化成 `\n\n` 的语义会变）。
- 标题/点击埋点不得顺手给 H1 换级加 `setState`、不得改 `IgnorePointer` / Offstage / 同块激活丢坐标。
- Bug 修复（问题 1–4）须双写 `agents/fixed_list.md` 目录+正文；5/6 埋点不进 fixed_list。用户可见行为与 debug 事件名同步 `README.md`。
- 收尾跑 `.\scripts\run_unit_tests.ps1`。

## 未决事项

（无）
