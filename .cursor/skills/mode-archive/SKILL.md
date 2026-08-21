---
name: mode-archive
description: >-
  Archive a finished propose by moving it from agents/proposes/ to
  agents/archives/. Use when the user names mode-archive, asks to archive a
  completed propose, or after mode-implement when they want the plan filed away.
disable-model-invocation: true
---

# mode-archive

将已经完成的目标归档。询问用户 propose 名称，选定后再移动。源在 `agents/proposes/`，目标在 `agents/archives/`（无则新建）。

## 工作步骤

1. 列出可归档项（没有则停止并说明）：
   - 规范：`agents/proposes/<name>/`（含 `schemes.md` 与 `tasks.md`）
   - 遗留：`agents/proposes/<name>.md`
2. **向用户询问名称**（展示目录名或文件名）；未选定前不要移动
3. 确认 `agents/archives/` 存在，若无则新建
4. 移动（保持内部文件名与正文）：
   - 目录：`agents/proposes/<name>/` → `agents/archives/<name>/`
   - 遗留文件：`agents/proposes/<name>.md` → `agents/archives/<name>.md`
5. 若目标路径已有同名目录或文件：先问是否覆盖，默认不覆盖

## 允许

- 新建 `agents/archives/`（仅当不存在时）
- 移动所选目录或遗留 `.md`（复制到 archives 后删除 proposes 中的源）

## 禁止

- 未询问、未得到用户选择就移动
- 修改方案正文或改工程目录（`lib/`、`test/` 等）
- 一次归档用户未指定的多个项（除非用户明确要求归档多个）
- 只移动 `tasks.md` 而留下空目录，或拆散目录内文件

## 交付

用中文告知：归档了哪个 propose、新路径。`agents/proposes/` 中该项应已不存在。
