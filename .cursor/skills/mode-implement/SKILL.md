---
name: mode-implement
description: >-
  Implement one closed plan from agents/proposes/<name>/ (schemes.md + tasks.md).
  Use when the user names mode-implement, or after mode-propose when the plan is
  ready. If 未决事项 is non-empty or the checklist is not closed, stop and return
  to mode-propose; do not invent product choices.
disable-model-invocation: true
---

# mode-implement

扫描 `agents/proposes/` 并落实**已闭合**的方案。允许修改工程目录。

每次默认只实现一个 propose，除非用户要求实现多个。

`tasks.md` 是执行闭包；`schemes.md` 的已决与关注点是只读约束。缺口打回 **mode-propose**，不在实现时扩大合同。

## 工作步骤

### 1. 扫描方案

列出：

- 规范：`agents/proposes/<name>/tasks.md`（方案名 = `<name>`）
- 遗留：`agents/proposes/*.md` 单文件（旧三栏目；能做则做，否则提示用 **mode-propose** 改成目录格式）

目录不存在或两者皆空：停止，提示先用 **mode-propose**。

- **多个且用户未指定**：问要实现哪一个，选定前不动手
- **仅一个**：实现它
- **用户点名**：只做指定的那一个

规范目录：先读 `schemes.md`。若「未决事项」不是「（无）」：**禁止动手**，列出未决，提示回 **mode-propose** 拍板。

### 2. 读合同（控制 token）

对规范目录，按这个顺序读，不要把 `schemes.md` 当小说重写一遍：

1. `schemes.md`：**目标**、**已决事项**、**关注点**（落实中不得推翻已决）
2. `schemes.md`：**方案**（只用来理解已选路径；不要从中长出任务里没有的行为）
3. `tasks.md`：全部步骤与勾选项

遗留单文件：读其三栏目，视「整体方案」为已决路径。

### 3. 动手前：接线 vs 缺口

对照仓库核对路径与符号。

- **接线**（可做）：已写任务要能编译、接到现有 API 所必需的局部符号（字段、import、空平台分支）。不改方案措辞。
- **缺口**（停手）：任务未点名、已决也未覆盖的产品选择；或新符号没有调用点；或 `tasks.md` 与「已决事项」冲突。列出缺口，提示 **mode-propose** 修订该目录。用户未确认前不要当已实现。

禁止用领域常识补合同外行为。用户若只要「先判断能不能做」，只做第 1–3 步并报告，不改工程。

### 4. 按步骤落实并勾选

- 按 `tasks.md` 的 **步骤 1、2、…** 顺序做；步内按勾选列表顺序
- 已勾选 `- [x]` 视为完成，从第一条 `- [ ]` 继续
- **每完成一项，立刻勾上**，不要等全部做完再勾
- 只改 `tasks.md` 的勾选状态；不要改任务措辞、步骤标题，也不要改 `schemes.md`
- 步骤中的文件与函数须先 `Read` 再改，不要臆造 API
- 遵守仓库规则：中文注释、具名常量、功能变更同步 `README.md`、Bug 则双写 `agents/fixed_list.md`、补/更新 `test/` 并用 `scripts/run_unit_tests` 全量跑通

遗留单文件：只改该 `.md` 里任务勾选。

### 5. 方案文件其它操作

- 除勾选外，不要删除、移动、拆并方案目录（归档用 **mode-archive**）
- 不要自己往 `tasks.md` / `schemes.md` 加条目；修订权在 **mode-propose**

## 禁止

- 未指定时一次实现两个及以上 propose
- 未询问就擅自挑选多个方案中的某一个
- 做完一项却不勾选，或把未完成项提前勾上
- 未决非空仍动手
- 把「方案」或「关注点」扩写成任务中不存在的产品行为
- 推翻「已决事项」另选一条路

## 交付

用中文说明：实现了哪个 propose、勾选了哪些步骤/任务、改了哪些工程文件、测试结果。因缺口或未决停手：只列问题，不改工程。完成后提示 **mode-archive**。
