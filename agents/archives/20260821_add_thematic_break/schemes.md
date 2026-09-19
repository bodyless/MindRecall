## 目标

Markdown 分割线（thematic break）在编辑 / 实时 / 预览三种模式可见、可插入、可序列化回 `.md`。实时里图片与分割线同属「不能当段落编辑」的原子块，不再靠点名 `ImageBlock`。

验收：源码或工具栏产生的 `---` / `***` / `___` 单独成行时，预览与实时画成横线而非字面短横；存盘为 `---`；实时点选横线或图片后右上角 × 可删、不挂 TextField；空段落键入整行 `---` 会变成线并在下方继续打字。

## 方案

- 在 `MdBlock` 增加 `supportsPlainEditing`（默认 `true`）与 `copyWithId`；`assignBlockId` 改为转发 `copyWithId`。`ImageBlock`、`ThematicBreakBlock` 覆写 `supportsPlainEditing => false`。
- Live 与 renderer 所有「像图片一样」的判断改为 `!block.supportsPlainEditing`（或不挂 Overlay 时用 `supportsPlainEditing`）。`CodeBlock` 仍可编辑正文，不算原子块。
- 新增 `ThematicBreakBlock`：`plainText` 为空、`copyWithPlainText` 忽略入参、`toMarkdown()` 恒为 `---`。
- 解析认整行 trim 意义下「行首最多 3 空格 + 连续 ≥3 个同字符 `-`/`*`/`_`」；不认 `- - -`；不做 setext；段落吞行遇到该行必须打断。
- 实时：`applyBlockTrigger` 认同一正则；转成原子块后在下方插入空段落并聚焦该段落。工具栏（编辑 + 实时）插入分割线：当前为空段落则替换为线，否则在下方插入线；线后再保证有一空段落并聚焦。
- 预览 / 实时非活动块走 `MdBlockRenderer` 画 `Divider`；活动原子块复用图片槽位（点选 + ×，无 Overlay）。
- 预览选区镜像放不可见 `---`，复制才能还原。原子块上点 H1/列表等换型保持现状，本次不修。

## 已决事项

- 抽出原子块协议 `supportsPlainEditing`，先收编 `ImageBlock` 再加分割线。
- 新块类型名为 `ThematicBreakBlock`。
- 语法：整行 ≥3 个同字符 `-` / `*` / `_`，行首最多 3 空格；不认中间有空格的 `- - -` / `* * *`。
- 不做 setext：`Foo\n---` 为段落 `Foo` + 分割线，不是 H2。
- 无空行时也打断段落吞行：`hello\n---\nworld` 三块。
- 读入 `***` / `___` 后存盘统一 `---`。
- 实时整行键入匹配则转块，并在下方插入空段落再聚焦，避免光标停在不能打字的块上。
- 编辑与实时工具栏都提供插入分割线；有正文时不毁掉当前行。
- 实时交互与图片相同：无 Overlay、点选、× 删除；删除按钮几何复用现有图片常量。
- 用 `copyWithId` 收掉 `assignBlockId` 的手写全类型拷贝。
- 不处理「选中原子块再点 H1/列表」的怪转换。

## 关注点

- 必须先改协议并替换 `is ImageBlock` 特例，再引入 `ThematicBreakBlock`，否则 live 里会再抄一套图片 if。
- `ThematicBreakBlock.plainText` 恒为空；`MdBlockRenderer` 空 chrome 条件必须改为「空且 `supportsPlainEditing`」，不能只靠 `is! ImageBlock`。
- `_onActiveFieldChanged` 在 trigger 得到原子块后，禁止再按 `plainText` 去 `_updateActiveController`；应插入/聚焦下方空段落。
- `MdBlock` 为 sealed：renderer / editor field 非 chromeless switch / preview 镜像 / debug 标签必须补新分支，否则编不过。
- 段落吞行 `break` 与主循环识别必须共用 `MdSyntaxPatterns` 的同一正则，禁止只改一处。
- 禁止把 `CodeBlock` 标成原子块。
- 本仓库 l10n 为 arb + 手写 Dart，三份 `app_localizations*.dart` 须与 arb 一起改。
- 不改 `agents/fixed_list.md`（功能而非 Bug）。

## 未决事项

（无）
