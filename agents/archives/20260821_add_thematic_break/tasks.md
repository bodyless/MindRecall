## 步骤 1：原子块协议与 copyWithId

- [x] 在 `lib/core/markdown/ast/md_block.dart` 的 `MdBlock` 上新增 `bool get supportsPlainEditing => true` 与抽象 `MdBlock copyWithId(String id)`；
- [x] 在 `lib/core/markdown/ast/md_block.dart` 为现有子类 `HeadingBlock`、`ParagraphBlock`、`BulletBlock`、`OrderedBlock`、`QuoteBlock`、`CodeBlock`、`ImageBlock` 实现 `copyWithId`（复制全部字段、只换 `id`）；
- [x] 在 `lib/core/markdown/ast/md_block.dart` 的 `ImageBlock` 覆写 `supportsPlainEditing => false`；
- [x] 在 `lib/core/markdown/live_line_markdown.dart` 把 `assignBlockId` 改为 `return block.copyWithId(id)`，删除按类型手写构造的 `switch`；

## 步骤 2：图片特例改走协议

- [x] 在 `lib/core/markdown/renderer/md_block_renderer.dart` 的 `build` 把空 chrome 条件从 `plainText.trim().isEmpty && block is! ImageBlock` 改为 `plainText.trim().isEmpty && block.supportsPlainEditing`；
- [x] 在 `lib/features/memo/editor/live/live_markdown_editor.dart` 的 `_consumeActivateTapPlainOffset` 把 `block is ImageBlock` 改为 `!block.supportsPlainEditing`；
- [x] 在 `lib/features/memo/editor/live/live_markdown_editor.dart` 的 `_deleteBlockById` 把「无 plain 则跳过 commit」与 `forceFocus: next is! ImageBlock` 改为按 `supportsPlainEditing` 判断；
- [x] 在 `lib/features/memo/editor/live/live_markdown_editor.dart` 的 `_buildBlockSlot` 把 `if (block is ImageBlock)` 槽位（点选 + 右上角 ×、不挂 Overlay）改为 `if (!block.supportsPlainEditing)`，删除按钮常量仍用现有 `_imageDeleteButtonInset` 等；
- [x] 在 `lib/features/memo/editor/live/live_markdown_editor.dart` 的 `build` 里 Overlay 条件从 `activeBlock is! ImageBlock` 改为 `activeBlock.supportsPlainEditing`；

## 步骤 3：分割线 AST 与解析

- [x] 在 `lib/core/markdown/ast/md_block.dart` 新增 `ThematicBreakBlock`：`plainText` 为空、`supportsPlainEditing => false`、`copyWithPlainText` 忽略入参返回 `this`、`copyWithId` 只换 id、`toMarkdown()` 返回 `---`；
- [x] 在 `lib/core/markdown/parser/md_syntax_patterns.dart` 新增 `thematicBreakLine`，匹配行首最多 3 空格 + 连续 ≥3 个同字符 `-` 或 `*` 或 `_` + 行尾空白，不匹配中间夹空格的写法；
- [x] 在 `lib/core/markdown/parser/markdown_block_parser.dart` 的 `parseMarkdownBlocks` 主循环中，于图片识别之后、任务/列表之前：若 `thematicBreakLine` 匹配则添加 `ThematicBreakBlock` 并 `continue`；
- [x] 在 `lib/core/markdown/parser/markdown_block_parser.dart` 的段落吞行 `break` 条件中加入 `MdSyntaxPatterns.thematicBreakLine.hasMatch(next)`，与主循环共用同一正则；
- [x] 在 `lib/core/markdown/parser/markdown_block_parser.dart` 的 `applyBlockTrigger` 的 `matchesTrigger` 中加入 `MdSyntaxPatterns.thematicBreakLine.hasMatch(lineText)`；
- [x] 在 `lib/core/markdown/live_line_markdown.dart` 的 `lineMarkdownForBlock` 为 `ThematicBreakBlock` 返回 `---`；

## 步骤 4：渲染、编辑框、预览镜像、debug

- [x] 在 `lib/core/markdown/renderer/md_block_styles.dart` 抽出分割线厚度等命名常量（禁止 magic number），供 renderer 使用；
- [x] 在 `lib/core/markdown/renderer/md_block_renderer.dart` 的块 `switch` 为 `ThematicBreakBlock` 渲染一条 `Divider`（颜色走 `onSurfaceVariant`，宽度贴正文）；
- [x] 在 `lib/core/markdown/editor/md_block_editor_field.dart` 非 chromeless 的 `switch` 将 `ThematicBreakBlock` 与 `ImageBlock` 一样交给 `MdBlockRenderer`；
- [x] 在 `lib/core/markdown/preview/md_blocks_preview.dart` 的 `_selectionMirrorForBlock` 为 `ThematicBreakBlock` 提供与线同高的镜像，并包含不可见文本 `---` 以便复制还原；
- [x] 在 `lib/core/debug/cursor_debug_hud.dart` 的 `mdBlockDebugTypeLabel` 为 `ThematicBreakBlock` 返回 `hr`；

## 步骤 5：实时转块、工具栏插入、文案

- [x] 在 `lib/core/markdown/live_session_ops.dart` 新增纯函数 `ensureEditableBlockAfterAtomic`：给定原子块下标，在其下方插入空 `ParagraphBlock` 并返回新列表与该段落 id；
- [x] 在 `lib/core/markdown/live_session_ops.dart` 新增纯函数 `insertThematicBreakAt`：当前块为空 `ParagraphBlock` 则替换为 `ThematicBreakBlock`（保留 id），否则在当前块后插入新 `ThematicBreakBlock`；随后调用 `ensureEditableBlockAfterAtomic`；
- [x] 在 `lib/features/memo/editor/live/live_markdown_editor.dart` 的 `_onActiveFieldChanged` 中，当 `applyBlockTrigger` 返回 `!supportsPlainEditing` 的块时：写入 `_blocks` 后调用 `ensureEditableBlockAfterAtomic`，`_switchToActiveBlock` 聚焦新空段落（`forceFocus: true`），禁止再对该原子块 `_updateActiveController`；
- [x] 在 `lib/features/memo/editor/live/live_markdown_editor.dart` 新增公开方法 `insertThematicBreak`：先 `_commitActiveBlock`，再 `insertThematicBreakAt` 写回 `_blocks`，聚焦返回的空段落并 `_syncToParent`；
- [x] 在 `lib/features/memo/editor/plain_text/markdown_editor_helper.dart` 新增 `insertThematicBreak`：经现有 `insertAtCursor` 插入 `\n---\n`；
- [x] 在 `lib/l10n/app_zh.arb` 与 `lib/l10n/app_en.arb` 新增 `toolbarThematicBreak`（中文「分割线」/ 英文 `Divider`）；
- [x] 在 `lib/l10n/app_localizations.dart`、`app_localizations_zh.dart`、`app_localizations_en.dart` 同步新增 `toolbarThematicBreak` getter；
- [x] 在 `lib/features/memo/editor/widgets/markdown_toolbar.dart` 的 `MarkdownToolbar` 于引用按钮之后增加分割线按钮（图标 `Icons.horizontal_rule`），调用 `MarkdownEditorHelper.insertThematicBreak`；
- [x] 在 `lib/features/memo/editor/widgets/markdown_toolbar.dart` 的 `LiveMarkdownToolbar` 增加 `onInsertThematicBreak` 及对应按钮（放在引用与正文之间）；
- [x] 在 `lib/features/memo/editor/memo_editor_screen.dart` 的 `_buildMarkdownToolbar` 将实时 `onInsertThematicBreak` 接到 `liveState?.insertThematicBreak()`；

## 步骤 6：测试与 README

- [x] 在 `test/markdown_block_ast_test.dart` 补解析：`---` / `***` / `___` / 行首 3 空格 + `---` 为 `ThematicBreakBlock`；`***` 往返存盘为 `---`；`- - -` 仍为 `BulletBlock`；`Foo\n---` 为段落 + 分割线而非 H2；`hello\n---\nworld` 为三块；
- [x] 在 `test/markdown_block_ast_test.dart` 补 `applyBlockTrigger`：段落键入 `---` 得到 `ThematicBreakBlock`；
- [x] 在 `test/live_session_ops_test.dart` 补 `ensureEditableBlockAfterAtomic` 与 `insertThematicBreakAt`（空段落替换、有正文则插在后方、焦点为线后空段落）；
- [x] 在 `test/live_image_delete_and_empty_chrome_test.dart` 或新 `test/thematic_break_render_test.dart` 补 `MdBlockRenderer`：`ThematicBreakBlock` 能找到 `Divider`，且空 `plainText` 不走空段落 hint/省略号；
- [x] 在 `test/live_paste_markdown_test.dart` 补粘贴含 `---` 的源码会拆出 `ThematicBreakBlock`；
- [x] 在 `test/markdown_editor_helper_test.dart` 补 `insertThematicBreak` 在光标处插入 `\n---\n`；
- [x] 在 `test/cursor_debug_hud_test.dart` 补 `ThematicBreakBlock` 的 `mdBlockDebugTypeLabel` 为 `hr`；
- [x] 在 `test/live_block_ops_test.dart` 或 `test/markdown_block_ast_test.dart` 断言 `ImageBlock` 与 `ThematicBreakBlock` 的 `supportsPlainEditing` 为 false、段落/标题/代码为 true；
- [x] 更新 `README.md` 功能概览工具栏两条（编辑/实时均含分割线）、块级 AST 表增加 `ThematicBreakBlock`，并写明 `supportsPlainEditing` 为原子块协议；
- [x] 跑通 `.\scripts\run_unit_tests.ps1`，失败则改到 PASSED，不得未绿交付；
