## 目标

侧栏当前目录列表中，用户可为**文件夹**自定义颜色：长按与行尾 `⋮` 同一菜单增加「设置颜色」；面板内可调 RGB、可「清除颜色」（均为草稿），确认后写入该目录 `{id}.fileconf`；列表行最左侧出现色条，其余行样式不变。无自定义色时与现在一致。文件行、搜索结果、「移动到」树不设色。

## 方案

`{id}.fileconf` 视为文件夹多项配置 JSON。键 `displayName` 仍为显示名；新增键 `color`，值为 `"#RRGGBB"`（写入时归一成 `#` + 6 位大写十六进制）。缺键、非法值、坏 JSON 均视为无自定义色，不向用户抛错。任何字段的写入都是「读出 Map → 改目标键 → 保留未知键 → pretty-print 写回」，禁止再整文件覆盖成只剩 `displayName`。清除颜色 = 从 Map 删除 `color` 再写回。

侧栏只对文件夹、且仅当 `color` 合法时，在 `_MemoListItem` 的 `Stack` **最底层**贴左侧画通高色条；`_tilePadding`、图标色、标题/时间样式、选中底、置顶三角都不改。置顶三角仍后画，压在色条左上角。无色文件夹不加占位条。

菜单只改共用的 `_entryMenuItems`：文件夹在「移动到」与「删除」之间增加「设置颜色」。弹出 `AlertDialog`（对标 `FolderNameDialog`）：内容为色块预览、「清除颜色」、独立 `RgbColorPicker`（三条 0–255 RGB 滑条 + 当前值，不引新包）；actions 为取消 / 确定。打开时：已有合法色则草稿为该色；无色则草稿为「已清除」，滑条停在中灰 `#808080`，确定不写色，直到用户拖滑条。点「清除颜色」只把草稿置空，滑条 RGB 保留，便于再拖。取消或点遮罩 = 不写盘。确定后按草稿写盘并刷新当前层列表；成功不 Snackbar，失败 Snackbar。弹窗前后走现有 `_suspendEditorFocus` / `_resumeEditorFocus`。

`RgbColorPicker` 只收 `Color` / `ValueChanged<Color>`，对话框不把滑条内联进去，便于以后整块替换选色控件。hex 只在存储边界与 `MemoFolder.colorHex` 转换。

## 已决事项

- 只支持文件夹；文件、搜索、「移动到」对话框不上色
- 长按与 `⋮` 同一菜单，不拆分；仅文件夹出现「设置颜色」
- 列表只在行最左侧加色条，不改已有图标/文字/选中/置顶样式；辨识度落地后真机再看
- 选色用最简单的 RGB 滑条，抽成可替换控件；不新增依赖
- 「清除颜色」与滑条改色都是草稿，只有确定才写盘；取消丢草稿
- 无自定义色打开面板：草稿为已清除，确定保持无色；滑条初值 `#808080`，用户拖动后草稿才变为该 RGB
- 有自定义色打开：草稿与滑条均为该色
- 存储格式 `"#RRGGBB"`，JSON 键 `color`；清除则删键
- fileconf 是多项配置：读写必须合并，重命名不得丢掉 `color` 或其它未知键
- 一般不手改 conf；坏数据只当无色/无显示名回退，不为兼容做额外扫盘
- 成功不弹 Snackbar（列表色条即反馈）；写盘失败再提示
- 备份 / 移动 / 回收站整目录带走 conf，本迭代不改那些服务的颜色逻辑

## 关注点

- `writeFolderDisplayName` 今日整文件写成只含 `displayName`，必须改为走合并写；否则设色后一重命名颜色丢失
- `folderFromDirectory` 已读一次 conf 取显示名；颜色必须同一次解析取出，禁止为颜色再读一遍文件
- `MemoFolder` 与 hex 编解码不要 import Flutter `Color`；测试里所有 `MemoFolder(` 手写构造把 `colorHex` 做成可选默认 `null`
- `_FakeStore` 里凡 `MemoFolder(` 重建（尤其 `renameFolder` / `moveFolder`）必须抄上 `colorHex`，否则工作区测会假绿
- 色条叠在 `Stack` 底层、贴左通高；置顶三角 18×18 仍最后画；无色不占宽，避免和文件行错位
- 色条宽度用命名常量（4.0），不要改 `MemoFilePanel._tilePadding`
- `showDialog` 的 `null` 是取消；确认清除必须用结果类型里 `colorHex == null` 区分
- 搜索列表 `_buildSearchResults`、`MoveToFolderDialog` 本迭代零改动
- `MemoFolderTreeNode` / `listFolderTree` 不带颜色
- 回收站 `memo_trash_service` 继续只读 `displayName` 当标题即可
- arb 不要复用搜索框的 `clear`；「设置颜色 / 清除颜色」用新 key；改 arb 后生成 l10n
- README 功能概览与目录结构要写色条、fileconf `color`、新 widget 路径

## 未决事项

- （无）
