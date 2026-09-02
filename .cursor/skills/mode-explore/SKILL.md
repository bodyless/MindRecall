---
name: mode-explore
description: >-
  Read-only exploration mode for the codebase. Inspect files and talk with the
  user; never create, edit, or delete files. At the end, only suggest
  mode-patch (root cause already stated, no architectural risk) or
  mode-propose (the default). Use when the user names mode-explore, asks to
  explore first, or wants a read-only look before any implementation.
disable-model-invocation: true
---

# mode-explore

当前模式下，只允许读文件以及跟用户互动，绝对不允许修改文件（增删改都不行）。

本 Skill 一旦启用，在用户**明确退出**本模式之前持续生效。用户本轮要求改代码，也不构成退出。

## 允许

- 读仓库：`Read`、`Grep`、`Glob`
- 与用户互动：正常回复、澄清、`AskQuestion`
- 只读检索：`WebSearch`、`WebFetch`、`SearchConversations`、`FetchMcpResource`、`GetMcpTools`
- 只读 Shell（无副作用）：`git status` / `git log` / `git diff` / `git show`、列目录、看文件内容
- `Task` 仅限 `subagent_type: explore`，且 prompt 必须复述本模式的只读约束

## 禁止

以下一律不做，即使用户要求落地、或「先改一下再解释」：

- `Write`、`StrReplace`、`Delete`、`EditNotebook`、`GenerateImage`
- 新建 / 覆盖 / 删除 / 移动 / 重命名任何文件或目录
- 会改工作区或 git 状态的命令：`git add` / `commit` / `checkout` / `reset`、重定向写入、包安装、格式化落盘、测试脚本若会写文件
- `SwitchMode` 切到可写模式（如 Agent）来绕过本约束
- 派发可能改文件的子代理（`generalPurpose`、`shell`、`best-of-n-runner` 等）
- MCP / 浏览器操作用于改本地文件

## 出口（只建议）

边读边归类。默认建议标准流程 **mode-propose**。仅当合取前提都满足才建议 **mode-patch**：

- 本次交付已写出根因句（哪条路径、哪个函数/状态、为什么错或可优化）
- 按该根因修/优化无架构隐患

命中任一条则否决 patch，一律建议 propose：根因写不清或有竞争假说；未拍板的对外行为分叉；新模块/改边界/新进程外入口/多到达路径；跨层生命周期（壳层 Focus、Input Session、IME、存储格式）；推翻 `fixed_list` 或 README 已有 invariant。

「优化」同样走这扇门。吃不准算有隐患。不能 `SwitchMode`，不能代执行。用户 `@mode-patch` / `@mode-propose` 才算退出本模式。

## 用户要求修改时

1. **不要改文件**（本模式仍禁止任何增删改）
2. 用对话给出对应交接（见下方「交付」）
3. 明确提示：当前是 `mode-explore`；按出口规则建议 **mode-patch**（`@mode-patch`）或 **mode-propose**（`@mode-propose`），并写清归类依据

## 交付

用中文直接回答。先给结论，再补证据（路径、符号、行为）。标出不确定点。可建议下一跳，但不要执行任何写入。不要写 `schemes.md` / `tasks.md`。产品分叉只列出，不要在 explore 里选定。

**→ mode-propose（默认）**：另一会话可独立消费的事实：

- 现有同类模式的路径（同类通道、同类入口、同类初始化）
- 调用链：从已有入口到将改的函数
- 不确定点与**行为分叉**：读不到的符号、多条到达路径、两条以上都合理的做法

**→ mode-patch**：对话里的短方案（不落盘），须含：

- 现象
- 根因句
- 要改的文件与函数
- 回归点（测什么；Bug 则双写 `agents/fixed_list.md`）

