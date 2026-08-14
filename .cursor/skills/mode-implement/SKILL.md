---
name: mode-implement
description: >-
  Implement one plan from agents/proposes/ by modifying project files. Use when
  the user names mode-implement, asks to implement a propose, or after
  mode-propose when they want the plan applied to the codebase.
disable-model-invocation: true
---

# mode-implement

扫描 `agents/proposes` 目录下的内容，并进行功能实现。允许修改工程目录下的文件。

每次默认只实现一个 propose，除非用户要求实现多个。

## 工作步骤

### 1. 扫描方案

- 列出 `agents/proposes/*.md`（目录不存在或为空则停止，提示先用 **mode-propose**）
- **多个方案且用户未指定**：向用户询问实现哪个具体的 propose，得到选择后再动手
- **仅一个方案**：实现该文件
- **用户点名或多个**：按其指定的文件实现；未要求多个时仍只做第一个/指定的那一个

### 2. 按「任务」落实并勾选

- 通读所选 `.md` 的 **任务** 勾选列表，按顺序改工程目录（`lib/`、`test/`、`README.md`、`agents/fixed_list.md` 等，以方案步骤与项目规范为准）
- 已勾选 `- [x]` 的视为已完成，从第一条 `- [ ]` 继续
- **每完成一项，就勾选上**：立刻把该行 `- [ ]` 改为 `- [x]`，不要等全部做完再勾
- 只改「任务」中的勾选状态，不要改写「目标」「整体方案」或任务措辞
- 步骤中的文件与函数须先 `Read` 再改，不要臆造 API
- 遵守仓库规则：中文注释、具名常量、功能变更同步 `README.md`、Bug 则双写 `agents/fixed_list.md`、补/更新 `test/` 并用 `scripts/run_unit_tests` 全量跑通

### 3. 方案文件其它操作

- 除勾选「任务」外，不要删除或移动方案文件（归档用 **mode-archive**）

## 禁止

- 在用户未指定多个时，一次实现两个及以上 propose
- 未询问就擅自挑选多个方案中的某一个以外的文件（多个且未指定时必须先问）
- 做完一项却不勾选，或把未完成项提前勾上

## 交付

用中文说明：实现了哪个 propose、勾选了哪些任务、改了哪些工程文件、测试结果。完成后提示可用 **mode-archive** 将该方案归档。
