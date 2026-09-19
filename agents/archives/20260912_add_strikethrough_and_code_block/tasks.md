## 步骤 1：行内 AST 与解析

- [x] 在 `lib/core/markdown/ast/md_inline.dart` 新增 `StrikeInline`（`children`、`plainText` 拼接、`toMarkdown()` 为 `~~${children.map(toMarkdown).join()}~~`），文件头注释补上删除线；
- [x] 在 `lib/core/markdown/ast/md_inline.dart` 的 `InlineStyle` 增加 `strikethrough`；
- [x] 在 `parseInlineMarkdown` 的正则 alternation 中加入 `~~.+?~~`，并在 `**`/`__` 分支之后、行内代码与单 `*` 斜体之前用 `_isWrapped(token, '~~')` 解析为 `StrikeInline(parseInlineMarkdown(inner))`；
- [x] 在 `splitMdInlineNode` 为 `StrikeInline` 按子节点拆分，对标 `ItalicInline`；
- [x] 在 `_flattenSegments` 的 `walk` 为 `StrikeInline` 并入 `InlineStyle.strikethrough`；
- [x] 在 `applyInlineStyle` 里当 `style == InlineStyle.code` 时除 bold/italic 外同时 `remove(InlineStyle.strikethrough)`；
- [x] 在 `_wrapStyledText` 于非 code 时按删除线 → 斜体 → 粗体依次包裹（代码仍为叶子 `CodeInline` 并独占）；

## 步骤 2：行内渲染

- [x] 在 `lib/core/markdown/renderer/md_inline_renderer.dart` 的 `_spanFor` 为 `StrikeInline` 合并 `TextDecoration.lineThrough`（`decorationColor` 跟当前文字色），子节点走现有 `_styledSpan`；禁止加 `letterSpacing`；

## 步骤 3：删除线工具栏、快捷键、文案

- [x] 在 `lib/l10n/app_zh.arb` 与 `app_en.arb` 于 `toolbarItalic` 后新增 `toolbarStrikethrough`（「删除线」/`Strikethrough`），于 `toolbarQuote` 后新增 `toolbarCodeBlock`（「代码块」/`Code block`），并新增 `codeBlockLanguageHint`（「语言」/`Language`）；`toolbarCode` 保持「行内代码」/`Inline code`；
- [x] 在 `lib/l10n/app_localizations.dart`、`app_localizations_zh.dart`、`app_localizations_en.dart` 同步上述三个 getter；
- [x] 在 `lib/features/memo/editor/widgets/markdown_toolbar.dart` 的 `MarkdownToolbar` 于斜体按钮之后增加删除线按钮（`Icons.format_strikethrough`），调用 `MarkdownEditorHelper.wrapSelection(left: '~~', right: '~~')`；
- [x] 在同文件 `LiveMarkdownToolbar` 增加可选 `onStrikethrough`，于斜体之后、行内代码之前插入按钮，`onPrepare` 与粗/斜相同（`onPrepareToolbarAction` + `onPrepareInlineAction`）；
- [x] 在 `lib/features/memo/editor/live/live_markdown_editor.dart` 新增 `applyStrikethrough() => _applyInlineStyle(InlineStyle.strikethrough)`；
- [x] 在 `LiveMarkdownEditorState._handleKeyEvent` 的修饰键分支中：当 `_isShortcutModifierPressed()` 且 `HardwareKeyboard.instance.isShiftPressed` 且 `key == LogicalKeyboardKey.keyK` 时调用 `applyStrikethrough()` 并 `handled`；不写 `Platform` 判断；
- [x] 在 `lib/features/memo/editor/memo_editor_screen.dart` 的 `_buildMarkdownToolbar` 将实时 `onStrikethrough` 接到 `liveState?.applyStrikethrough()`；

## 步骤 4：实时代码块换入、退出、吞格式

- [x] 在 `lib/core/markdown/live_line_markdown.dart` 新增 `applyCodeBlockLineMarkdown`：对 `stripBlockLinePrefix(lineMarkdown)` 包成 ` ```\n$body\n``` `（body 空则为 ` ```\n``` `）；
- [x] 在 `lib/core/markdown/ast/md_block.dart` 为 `CodeBlock` 新增 `copyWith({String? code, String? language})`，允许把 `language` 写成 `null`（空语言）；
- [x] 在 `lib/core/markdown/block_ops.dart` 新增 `bool swallowsMarkdownToolbar(MdBlock block) => block is CodeBlock`；
- [x] 在 `LiveMarkdownEditorState` 新增公开 `bool get swallowsMarkdownToolbar`（读当前 `_activeBlock`）与 `applyCodeBlock()`：若已是 `CodeBlock` 则 return，否则 `_applyLineMarkdownTransform(applyCodeBlockLineMarkdown)`；
- [x] 在 `applyHeading` / `applyBulletList` / `applyTaskList` / `applyOrderedList` / `applyQuote` / `insertThematicBreak` / `applyBold` / `applyItalic` / `applyInlineCode` / `applyStrikethrough` / `applyLink` 开头若 `swallowsMarkdownToolbar` 则 return；
- [x] 在 `applyParagraph` 开头若当前为 `CodeBlock`：用 `code` 构造同 `id` 的 `ParagraphBlock` 写回 `_blocks`，若 `code` 含 `\n` 则对该块做 `expandMultilineParagraphsForLive`（或等价拆行）并 `syncParagraphFlowFlags`，聚焦保留原 id 的那一段、选区 clamp 到新 plain，然后 `_syncToParentDeferred` / `_stabilizeInputFocus`；非代码块仍走现有 `_applyLineMarkdownTransform(applyParagraphLineMarkdown)`；
- [x] 在 `memo_editor_screen.dart` 的 `_pickAndInsertImage` 于实时模式若 `liveState?.swallowsMarkdownToolbar == true` 则直接 return；
- [x] 在 `LiveMarkdownToolbar` 增加 `onCodeBlock`，于引用按钮之后、分割线之前插入 `Icons.terminal` 按钮（`onPrepare` 仅 `onPrepareToolbarAction`，与引用相同）；
- [x] 在 `MarkdownToolbar` 于引用按钮之后插入同一图标的代码块按钮，调用 `MarkdownEditorHelper.insertCodeBlockFence`；
- [x] 在 `_buildMarkdownToolbar` 将实时 `onCodeBlock` 接到 `liveState?.applyCodeBlock()`；

## 步骤 5：编辑模式围栏插入与自动变块

- [x] 在 `lib/features/memo/editor/plain_text/markdown_editor_helper.dart` 新增 `insertCodeBlockFence`：选区非折叠则把选中文本原样包进 ` ```\n…\n``` `，光标放在围栏内正文末；折叠则若前缀非空且不以 `\n` 结尾先插入换行，再插入空围栏 ` ```\n\n``` `，若光标在全文末尾再多一个 `\n`，光标放在围栏内空行；
- [x] 在 `lib/core/markdown/parser/markdown_block_parser.dart` 的 `applyBlockTrigger` 中：当 `block is ParagraphBlock` 且 `lineText.startsWith('```')` 时 `return reparseBlockFromLineMarkdown(block, lineMarkdown: lineText)`；该条件不要套用到标题/引用/列表；不要把围栏触发并进现有 `matchesTrigger` 让非段落也变块；

## 步骤 6：语言框与焦点

- [x] 在 `lib/core/markdown/renderer/md_block_styles.dart`（或块 chrome 常量处）为语言框抽出宽度/字号/内缩命名常量，角落定位对标 `positionAtomicDeleteButton` 的右上内缩，不得 magic number；
- [x] 在 `LiveMarkdownEditorState` 增加 `_languageFocusNode` 与 `_languageController`，于 `dispose` 释放；切到非 `CodeBlock` 或切块时 `unfocus` 语言框并按新块 `language` 同步 controller（非代码块则清空）；
- [x] 在 `_buildBlockSlot` 当 `block is CodeBlock` 且（`widget.focusNode.hasFocus && isActive` 或 `_languageFocusNode.hasFocus` 且该槽为活动代码块）时于 `Stack` 叠单行语言 `TextField`：`hint` 为 `codeBlockLanguageHint`，`onChanged` 把 trim 后空串写成 `language: null` 否则写回当前 `CodeBlock.copyWith(language: …)` 并 `_syncToParentDeferred`；
- [x] 在 `restoreFocus` 开头若 `_languageFocusNode.hasFocus` 则直接 return；
- [x] 在 `memo_editor_screen.dart` 的 `_onLiveFocusChanged` 失焦宽限期：若 `liveState` 语言框有焦点（新增公开 `bool get isCodeLanguageFieldFocused`）则保持 `_liveSession.hadFocus`、禁止 `restoreFocus`、禁止随后结束实时输入会话；

## 步骤 7：测试与 README

- [x] 在 `test/md_inline_test.dart` 补：解析 `~~x~~`；单个 `~` 仍为文本；`**~~x~~**` 与 `~~**x**~~` 都能解析且可叠粗+删除线；`applyInlineStyle` 删除线；粗+斜+删除线序列化为 `***~~x~~***`；点 `InlineStyle.code` 清掉删除线；
- [x] 在 `test/md_inline_test.dart` 或现有 inline render 组补 `MdInlineText` 删除线 `TextDecoration.lineThrough`；
- [x] 在 `test/live_block_ops_test.dart` 补 `applyCodeBlockLineMarkdown`（剥 `# ` / `- ` / `>` 再围栏）与 `applyBlockTrigger`：段落 ` ``` ` / ` ```dart` 变为 `CodeBlock`（后者带 language），标题/列表行 ` ``` ` 不变块；
- [x] 在 `test/markdown_block_ast_test.dart` 或 `live_block_ops_test.dart` 补：`CodeBlock` 经正文路径变成 `ParagraphBlock` 且 `text == code`（含多行）；
- [x] 在 `test/markdown_editor_helper_test.dart` 补 `insertCodeBlockFence`：选区包裹；`abc|def` 切成 `abc` + 空围栏 + `def`；全文末尾多一个空行；空文档不先插多余空行；
- [x] 在 `test/markdown_editor_helper_test.dart` 补 `wrapSelection` 删除线 `~~`（可与现有 bold wrap 同组）；
- [x] 更新 `README.md`：功能概览工具栏（删除线、代码块与行内代码区分）；行内 AST 表加 `StrikeInline` / `~~`；`LiveMarkdownEditor` API 表加 `applyStrikethrough` / `applyCodeBlock`；写明代码块吞格式、语言框显隐、正文才退出；
- [x] 跑通 `.\scripts\run_unit_tests.ps1`，失败则改到 PASSED，不得未绿交付；
