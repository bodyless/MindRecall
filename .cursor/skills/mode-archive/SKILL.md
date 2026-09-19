---
name: mode-archive
description: >-
  Archive a finished propose by moving it from agents/proposes/ to
  agents/archives/<YYYYMMDD>_<name>/. Use when the user names mode-archive,
  asks to archive a completed propose, or after mode-implement when they want
  the plan filed away.
disable-model-invocation: true
---

# mode-archive

将已经完成的目标归档。询问用户 propose 名称，选定后再移动。源在 `agents/proposes/`，目标在 `agents/archives/`（无则新建）。归档后的目录（或遗留文件）**必须**加当天日期前缀，不改内部文件名与正文。

## 命名

- 日期：归档执行当天的本地日历日，格式 `YYYYMMDD`（无连字符）
- 目录：`add_text_block` → `agents/archives/20260912_add_text_block/`
- 遗留文件：`add_text_block.md` → `agents/archives/20260912_add_text_block.md`
- `<name>` 保持 propose 原名；不要把日期写进 `schemes.md` / `tasks.md`

## 工作步骤

1. 列出可归档项（没有则停止并说明）：
   - 规范：`agents/proposes/<name>/`（含 `schemes.md` 与 `tasks.md`）
   - 遗留：`agents/proposes/<name>.md`
2. **向用户询问名称**（展示目录名或文件名）；未选定前不要移动
3. 确认 `agents/archives/` 存在，若无则新建
4. 取当天 `YYYYMMDD`，移动（保持内部文件名与正文）：
   - 目录：`agents/proposes/<name>/` → `agents/archives/<YYYYMMDD>_<name>/`
   - 遗留文件：`agents/proposes/<name>.md` → `agents/archives/<YYYYMMDD>_<name>.md`
5. 若目标路径已有同名目录或文件：先问是否覆盖，默认不覆盖

## 允许

- 新建 `agents/archives/`（仅当不存在时）
- 移动所选目录或遗留 `.md`（复制到 archives 后删除 proposes 中的源）

## 禁止

- 未询问、未得到用户选择就移动
- 目标名不加日期前缀，或改用带连字符/其它格式的日期
- 修改方案正文或改工程目录（`lib/`、`test/` 等）
- 一次归档用户未指定的多个项（除非用户明确要求归档多个）
- 只移动 `tasks.md` 而留下空目录，或拆散目录内文件
- 给 `agents/archives/` 里已有、无日期前缀的旧目录批量改名（除非用户明确要求；补前缀时用该目录的文件系统建立日期，不是当天）

## 交付

用中文告知：归档了哪个 propose、新路径（含日期前缀）。`agents/proposes/` 中该项应已不存在。
