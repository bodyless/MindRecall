---
name: mode-propose
description: >-
  Summarize mode-explore context into an implementable plan markdown file under
  agents/proposes/. Use when the user names mode-propose, asks to turn
  exploration into a plan, or after mode-explore when they want changes written
  down for later implementation.
disable-model-invocation: true
---

# mode-propose

将 mode-explore 中的上下文总结为即将可以被落实的方案。

允许修改的文件局限在 `agents/proposes` 目录内部。禁止改工程目录（`lib/`、`test/`、`README.md` 等产品与测试文件）。

## 工作步骤

### 1. 收集上下文

- 整理本会话中 mode-explore 的结论、用户意图、涉及路径与符号
- 缺口用 `Read` / `Grep` / `Glob` 补全，使每一步能落到真实文件与函数（或明确的新增点）
- 函数名、路径不要臆造；读不到则先问用户，再写文件

### 2. 新建方案文件

在根目录的 `agents/proposes` 目录下（若无则新建之），根据上下文新建一个 `.md` 文件（命名自取，使用下划线命名法，例如 `add_slide_bar_button`，要求命名的第一个词语一定是动词（add, fix, update 等））。

约束：

- 路径：`agents/proposes/<name>.md`
- `<name>`：小写 + 下划线；**首词必须是动词**（`add`、`fix`、`update`、`remove`、`rename`、`move` 等）
- 同名已存在则换更具体的动词短语，不要覆盖已有方案

### 3. 写入方案（三栏目）

文件整体拆分为 3 个栏目，格式如下：

```
## 目标

<一句话简述要达成什么>

## 整体方案

<一两句简述怎么做>

## 任务

- [ ] 在A文件中的F1函数中新增变量V1；
- [ ] 在B文件的F2函数中读取变量V1；
```

要求：

- 栏目名固定为 `目标`、`整体方案`、`任务`，不要增删栏目或改名
- **目标**、**整体方案**：简述即可，不要长文
- **任务**：勾选列表；新建时全部为 `- [ ]`（未完成）
- 任务每一项一句，以中文分号 `；` 结尾
- 写清：**哪个文件**、**哪个函数/位置**、**做什么**（新增 / 读取 / 修改 / 删除何物）
- 按落实顺序排列，后者可以依赖前者已引入的符号
- 不要标题以外的前言、代码块或其它章节

## 禁止

- 修改 `agents/proposes/` 以外的任何文件
- 按方案去改工程目录（`lib/`、`test/`、`README.md`、`agents/fixed_list.md` 等）
- 往「目标 / 整体方案」里写长文，或用论述/伪代码替代「任务」勾选列表

## 用户要求修改工程目录时

若用户要求修改工程目录，则提示让用户使用技能 **mode-implement**（`@mode-implement`）。本模式不落地产品代码。

## 交付

用中文告知：方案路径、文件名、任务条数。需要落实工程改动时，提示使用 **mode-implement**。
