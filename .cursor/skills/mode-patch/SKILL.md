---
name: mode-patch
description: >-
  Apply mode-explore's short plan to engineering files without writing
  agents/proposes/. Use when the user names mode-patch, or after mode-explore
  recommends it because the root cause is already stated and the change has no
  architectural risk. If the root cause is missing or a product/architecture
  fork appears, stop and return to mode-explore or mode-propose.
disable-model-invocation: true
---

# mode-patch

按 **mode-explore** 交付的短方案改工程（局部修复或优化）。不写 `agents/proposes/`，不归档。

根因必须来自上一跳 explore；本模式不补根因、不拍板产品分叉。

## 动手前

核对上一跳 explore 交付是否同时满足：

- 已写出根因句（哪条路径、哪个函数/状态、为什么错或可优化）
- explore **建议了** `@mode-patch`（因按该根因落地无架构隐患）

任一不满足（用户直接启用本模式、根因缺失或仍是假说、explore 建议的是 propose）：**禁止动手**。说明缺什么，提示回到 **mode-explore** 或走标准流程 **mode-propose**。

核对短方案点名的路径与符号；读不到则先问用户，不要臆造。

发现短方案未覆盖的对外行为分叉，或将触及架构隐患（新模块/改边界/新进程外入口/多到达路径；跨层生命周期：Focus、Input Session、IME、存储格式；推翻 `fixed_list` / README invariant）：**停手**，列出问题，提示 **mode-propose**。用户未确认前不要当已实现。

## 按短方案落实

- 只改短方案写明的文件/函数；编译与接到现有 API 所需的局部符号（字段、import）可做
- 不要扩大范围，不要用领域常识补短方案外的行为
- 遵守仓库规则：中文注释、具名常量、功能变更同步 `README.md`、Bug 则双写 `agents/fixed_list.md`、补/更新 `test/` 并用 `scripts/run_unit_tests` 全量跑通
- 成功交付后的版本升版见「交付」：即使短方案未点名 `pubspec.yaml` 也要改顶层 `version:` 的迭代位

## 禁止

- 写入、修订或扫描 `agents/proposes/`；不要 **mode-archive**
- 自己补根因或另选修复路径后再开写
- 在本模式里替用户拍板产品选择
- `SwitchMode` 绕过停手条件继续改工程

## 交付

用中文说明：按哪份 explore 短方案、改了哪些工程文件、测试结果、`fixed_list` / `README` 是否已同步。因根因缺失、分叉或架构面停手：只列问题，不改工程。

门禁通过并宣告成功后：读取 `pubspec.yaml` 顶层 `version: 大.小.迭代`（三个非负整数、无 `+`），将迭代 +1 写回该行；短方案未点名 `pubspec.yaml` 也要改这一行。停手或测试未过则不改；不改大版本与小版本。升版只动 `pubspec.yaml` 顶层 `version:`，不改依赖版本、不添加 `+buildNumber`、不为 `versionCode` 做推导。
