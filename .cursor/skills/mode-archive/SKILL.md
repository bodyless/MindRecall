---
name: mode-archive
description: >-
  Archive a finished propose by moving it from agents/proposes/ to
  agents/archives/. Use when the user names mode-archive, asks to archive a
  completed propose, or after mode-implement when they want the plan filed away.
disable-model-invocation: true
---

# mode-archive

将已经完成的目标归档。需要向用户询问 propose 名称，用户选择后，将 propose 文件从 `agents/proposes` 移动到 `agents/archives` 目录下（若无则新建之）。

## 工作步骤

1. 列出 `agents/proposes/*.md`（没有可归档文件则停止并说明）
2. **向用户询问 propose 名称**（展示文件名供选择）；用户未选定前不要移动
3. 确认 `agents/archives/` 存在，若无则新建之
4. 将所选文件从 `agents/proposes/<name>.md` **移动**到 `agents/archives/<name>.md`（保持原文件名与正文）
5. 若目标路径已有同名文件：先问用户是否覆盖，默认不覆盖

## 允许

- 新建 `agents/archives/`（仅当不存在时）
- 移动（等效于复制到 archives 后删除 proposes 中的源文件）所选 `.md`

## 禁止

- 未询问、未得到用户选择就移动
- 修改方案正文或改工程目录（`lib/`、`test/` 等）
- 一次归档用户未指定的多个文件（除非用户明确要求归档多个）

## 交付

用中文告知：归档了哪个 propose、新路径。`agents/proposes/` 中该文件应已不存在。
