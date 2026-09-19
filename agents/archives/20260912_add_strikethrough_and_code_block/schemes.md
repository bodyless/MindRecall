## 目标

支持 GFM 删除线 `~~…~~`（解析、渲染、实时/编辑工具栏、实时快捷键），并在工具栏增加围栏**代码块**入口（与行内代码并存）。实时活动代码块在正文或语言框有焦点时显示语言输入；点「正文」才能退出代码块。

验收：`~~x~~` 在预览/实时显示删除线；工具栏点删除线后源码为粗>斜>删除线顺序；`Ctrl/Meta+Shift+K` 实时切换删除线（须有选区）；工具栏「代码块」把当前块（实时）或选区/光标处（编辑）变成 ` ``` ` 围栏；代码块内除「正文」外格式按钮无效；语言写回开行 ` ```lang`；正文块整行以 ` ``` ` 开头自动变块。

## 方案

- 行内新增 `StrikeInline`（可嵌套子节点，对标 `ItalicInline`）与 `InlineStyle.strikethrough`。`parseInlineMarkdown` 增加 `~~.+?~~`（须用 `_isWrapped(..., '~~')`），单个 `~` 不认。渲染 `TextDecoration.lineThrough`，走现有 `MdInlineText`（预览/实时/Overlay 共用）。
- `applyInlineStyle`：删除线与粗/斜可叠加；点行内代码时与粗/斜一起清掉删除线。工具栏路径经 `_wrapStyledText` 规范为**由内到外**删除线 → 斜体 → 粗体（`Bold(Italic(Strike))`）。仅解析不强制改写 `~~**x**~~` 的 AST 形状。
- 实时：`applyStrikethrough()` → 现有 `_applyInlineStyle`；空选区与粗体一样直接 return。快捷键走 `_handleKeyEvent` 已有 `_isShortcutModifierPressed()`（Ctrl 或 Meta）+ `Shift` + `K`，不写 `Platform` 分支。IME `composing` 时忽略，与 B/I 相同。
- 工具栏：删除线放在斜体之后（`Icons.format_strikethrough`）；代码块放在引用之后（`Icons.terminal`，不得用已占用的 `Icons.code`）。文案：删除线「删除线」/`Strikethrough`；代码块「代码块」/`Code block`；行内保持「行内代码」/`Inline code`。
- 实时代码块：`applyCodeBlock()` 已是 `CodeBlock` 则 return；否则走 `_applyLineMarkdownTransform` + 新 `applyCodeBlockLineMarkdown`（`stripBlockLinePrefix` 后包围栏，只转当前块，与 H1 相同）。`applyParagraph()` 对 `CodeBlock` 特例：用 `code` 字段建 `ParagraphBlock`（禁止对 `toMarkdown()` 做行首 strip），含 `\n` 则按现有 live 规则拆成每行一段。活动块为 `CodeBlock` 时，H1/列表/引用/分割线/粗斜删除线/行内代码/链接/插图全部 no-op（静默，工具栏不变灰）。
- 自动变块：仅 `ParagraphBlock` 且整行 `lineText.startsWith('```')` 时 `applyBlockTrigger` 再 parse；H1/引用/列表不变；已是代码块时 ` ``` ` 当代码正文。
- 编辑模式：`MarkdownEditorHelper.insertCodeBlockFence`——有选区则选区原样进围栏正文；无选区在光标处插入空围栏（若当前不在行首则先换行），EOF 时闭合围栏后再多一个源码空行；光标落到围栏内空行。
- 语言框：活动 `CodeBlock` 槽位右上角单行 `TextField`（几何对标图片 × 的角落，但是输入框）。显示当且仅当**代码正文 `widget.focusNode` 或该块语言框**有焦点。`onChanged` 即时写 `language`（trim 空则 `null`），不禁止空格/反引号。语言框必须自有 `FocusNode`；获焦时禁止 `restoreFocus` 把焦点抢回正文，也禁止壳层 `_onLiveFocusChanged` 把会话结束掉。

## 已决事项

- 删除线与粗/斜平级可共存；粗/斜与行内代码互斥，删除线同样互斥（点代码清删除线）。
- 只认双波浪线 `~~…~~`。
- 两种源码都解析；工具栏序列化顺序粗体 > 斜体 > 删除线。
- 实时空选区点删除线无操作（与粗体一致）；标题不纳入 `supportsInlineFormatting`（与粗体一致）。
- 快捷键：实时 `Ctrl` 或 `Meta` + `Shift` + `K`；不写死仅 Control、不写 Platform 分支；不另做 PC 专用逻辑。
- 代码块与行内代码并存；行内按钮/文案不动。
- 删除线按钮在斜体后；代码块按钮在引用后。
- 实时转代码块只转当前活动块（与 H1 相同，不合并上下行）。
- 代码块内不解析 markdown；`**粗体**` 原样显示。
- 已是代码块再点「代码块」无反应；从标题/列表/引用/段落等可转入。
- 代码块内除「正文」外任何格式按钮失效（吞掉 markdown）；只有「正文」拆围栏退出。
- 正文退出接受怪缩进；实现必须走 `code` 字段。
- 编辑模式：有选区则吞选区为围栏正文；`abc|def` → `abc` / 空代码块 / `def`；EOF 再在围栏后加源码空行。
- 自动变块：仅正文块、整行以 ` ``` ` 开头。
- 语言框：正文或语言框有焦点才显示；不校验语言字符；`onChanged` 即时写回。
- 图标：删除线 `Icons.format_strikethrough`；代码块 `Icons.terminal`。
- 失效手感：静默 no-op，工具栏不强制变灰。
- 语言占位：`codeBlockLanguageHint`「语言」/`Language`。
- 不改 `agents/fixed_list.md`（功能而非 Bug）。

## 关注点

- `MdInline` 为 sealed：`splitMdInlineNode` / `_flattenSegments` / `_wrapStyledText` / `md_inline_renderer.dart` 的 `switch` 必须补 `StrikeInline`，否则编不过。
- 删除线 Overlay：透明 TextField 保持现有 `decoration: none`；划线只画在底层 `MdInlineText`。禁止用会改 glyph advance 的 `letterSpacing`（见 fixed_list 粗体/光标悬空）。
- `~~` 解析必须走 `_isWrapped`，避免短 token 误切（对标 `***` RangeError）。
- 代码块进出禁止复用「只 strip 行首再 parse 第一块」对付围栏：`CodeBlock.toMarkdown()` 是多行，`reparseBlockFromLineMarkdown` 只取 `parsed.first`，正文按钮会卡住或丢行。
- 活动 `CodeBlock` 时格式 no-op 要写在 `LiveMarkdownEditorState` 各 `apply*` / `insertThematicBreak`，以及壳层插图；不要只藏按钮。
- 语言框获焦会使 `LiveInputSession.focusNode` 失焦：`restoreFocus` 与 `memo_editor_screen._onLiveFocusChanged` 宽限期会抢回正文或结束会话。必须把「语言框有焦点」视为仍在该代码块会话内。
- 编辑模式 EOF 多出的是**源码空行**；`parseMarkdownBlocks` 本就会跳过空白行，切到实时不一定多出空段落块。不要为了对齐而去改块解析跳空行。
- 本仓库 l10n 为 arb + 手写 Dart，改 `app_zh.arb` / `app_en.arb` 时三份 `app_localizations*.dart` 一起改。
- `toolbarCode` 保持行内语义，新增 `toolbarCodeBlock` / `toolbarStrikethrough`，禁止把行内英文改成 `Code`。

## 未决事项

（无）
