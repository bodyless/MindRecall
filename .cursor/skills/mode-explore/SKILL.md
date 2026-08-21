---
name: mode-explore
description: >-
  Read-only exploration mode for the codebase. Inspect files and talk with the
  user; never create, edit, or delete files. Use when the user names
  mode-explore, asks to explore first, or wants a read-only look before any
  implementation.
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

## 用户要求修改时

若用户尝试修改时，提示用户使用 mode-propose 技能。

1. **不要改文件**（本模式仍禁止任何增删改）
2. 用对话给出：已读结论、建议改动要点、涉及路径（见下方「交接」）
3. 明确提示：当前是 `mode-explore`；要把探索结果写成可落实方案，请使用 **mode-propose**（`@mode-propose`）

## 交付

用中文直接回答。先给结论，再补证据（路径、符号、行为）。标出不确定点。可给下一步建议，但不要执行任何写入。

面向下一模式时，只交**另一会话可独立消费**的事实，不要写 `schemes.md` / `tasks.md`（那是 **mode-propose** 的合同）：

- 现有同类模式的路径（同类通道、同类入口、同类初始化）
- 调用链：从已有入口到将改的函数
- 不确定点与**行为分叉**：读不到的符号、多条到达路径、两条以上都合理的做法——标出来交给 propose 问用户，不要在 explore 里擅自选定

