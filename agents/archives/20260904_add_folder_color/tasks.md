## 步骤 1：模型与 fileconf 合并读写

- [x] 在 `lib/models/memo_folder.dart` 的 `MemoFolder` 增加可选字段 `colorHex`（`String?`，默认 `null` 表示无自定义色），现有构造调用保持可编译；
- [x] 在同文件为 `MemoFolder` 增加静态 `parseColorHex`：入参 trim 后仅接受 `#` + 6 位十六进制（大小写均可），合法则返回 `#` + 6 位大写，否则返回 `null`（含 `#RGB`、带 alpha、非字符串语义的调用方传入）；
- [x] 在同文件增加静态 `formatColorHex`：把 r/g/b（0–255）格式化为 `#RRGGBB` 大写；
- [x] 在 `lib/services/memo_storage_service.dart` 增加 conf 键常量 `color`（与现有 `_fileConfDisplayNameKey` 并列）；
- [x] 在 `MemoStorageService` 把读 conf 收成一次解析：不存在 / `jsonDecode` 失败 / 结果非 Map 则视为空 Map，不抛给调用方；从 Map 取显示名（逻辑与今日 `readFolderDisplayName` 相同）和 `color`（经 `MemoFolder.parseColorHex`）；
- [x] 在 `MemoStorageService.folderFromDirectory` 用上述一次解析同时填 `displayName` 与 `colorHex`；
- [x] 在 `MemoStorageService` 增加合并写：读出 Map（失败则空 Map），按调用方更新或删除指定键，保留未知键，再 `JsonEncoder.withIndent('  ')` 写回 `{id}.fileconf`；
- [x] 把现有 `writeFolderDisplayName` 改为只更新 `displayName` 键并走合并写，禁止再整文件覆盖成单键对象；
- [x] 在 `MemoStorageService` 增加按文件夹 id 写入/清除颜色：合法 hex 则写入归一化 `#RRGGBB`；`null` 则删除 `color` 键；找不到目录则失败；
- [x] 在 `test/` 新增或扩展用例覆盖：`parseColorHex` / `formatColorHex` 的合法与非法；设色后 `renameFolder` 仍保留 `color`；清除后键消失且 `displayName` 仍在；未知键在改显示名或改颜色后仍在；缺 conf / 坏 JSON / 非法 `color` 不抛错且视为无色；`createFolder` 写出的 conf 无 `color` 键；

## 步骤 2：工作区 API

- [x] 在 `lib/features/memo/editor/memo_workspace_controller.dart` 的 `MemoWorkspaceStore` 增加 `updateFolderColor({required String id, String? colorHex})`；
- [x] 在同文件 `DiskMemoWorkspaceStore` 把该方法转到 `MemoStorageService` 对应写入；
- [x] 在 `MemoWorkspaceController` 增加 `updateFolderColor`：调用 store 后 `_reloadDirEntries` 并 `notifyListeners`，不改当前目录与活动篇；
- [x] 在 `test/memo_workspace_controller_test.dart` 的 `_FakeStore` 实现 `updateFolderColor`，并让 `renameFolder` / `moveFolder` / 其它重建 `MemoFolder(` 的路径抄上 `colorHex`；
- [x] 在 `test/memo_workspace_controller_test.dart` 覆盖：更新颜色后当前层该文件夹 `colorHex` 已变、当前目录与活动篇不变；清除后为 `null`；

## 步骤 3：RGB 控件与设色对话框

- [x] 在 `lib/l10n/app_zh.arb` 与 `lib/l10n/app_en.arb` 增加「设置颜色」「清除颜色」、对话框标题、设置失败（带 error 占位）；不要复用搜索框 `clear`；改完后生成 l10n；
- [x] 新增 `lib/shared/widgets/rgb_color_picker.dart`：仅 RGB 三条 0–255 `Slider` 与当前通道值，入参为 `Color value` 与 `ValueChanged<Color> onChanged`，不读 fileconf、不负责确认/清除；
- [x] 新增 `lib/features/memo/editor/widgets/folder_color_dialog.dart`：`AlertDialog` 对标 `FolderNameDialog`（取消 / 确定走已有 `l10n.cancel` / `l10n.confirm`）；内容含色块预览、「清除颜色」按钮、嵌入 `RgbColorPicker`；
- [x] 在 `FolderColorDialog` 用独立结果类型区分取消与确认：`showDialog` 返回 `null` 表示取消；确认时 `colorHex == null` 表示清除，非 null 为归一化 `#RRGGBB`；
- [x] 在 `FolderColorDialog` 实现草稿：`initialColorHex` 合法则草稿与滑条为该色；否则草稿为空、滑条初值为 `#808080`；点「清除颜色」只清空草稿、不立刻 pop；拖滑条把草稿设为当前 RGB；确定才 `pop` 结果；

## 步骤 4：侧栏菜单、色条与 Screen 接线

- [x] 在 `lib/features/memo/sidebar/memo_file_panel.dart` 的 `_MemoFileAction` 增加 `setColor`；
- [x] 在同文件 `_entryMenuItems` 仅当 `entry.isFolder` 时，在「移动到」与「删除」之间加入「设置颜色」（图标+文案行，对标现有菜单项）；文件菜单不加此项；
- [x] 在 `MemoFilePanel` 增加 `onSetFolderColor`，`_handleEntryAction` 在文件夹分支调用它，文件分支忽略 `setColor`；长按 `showMenu` 与 `PopupMenuButton` 继续共用 `_entryMenuItems` / `_handleEntryAction`；
- [x] 在 `_MemoListItem` 增加可选条颜色；仅当非 null 时在 `Stack` **第一个** child 画左侧通高色条（宽度用命名常量 4.0）；不要改 `_tilePadding`、图标色、标题/副标题样式、选中 `Material` 色、置顶三角的位置与颜色；置顶三角保持为 Stack 后画；
- [x] 在 `_buildMemoList` 对文件夹把 `entry.folder!.colorHex` 解析为条颜色传入 `_MemoListItem`，文件与无色文件夹传 null；`_buildSearchResults` 不改；
- [x] 在 `lib/features/memo/editor/memo_editor_screen.dart` 的 `_buildFilePanel` 接上 `onSetFolderColor`；新增流程：按 id 从 `_workspace.dirEntries` 取文件夹、`_suspendEditorFocus`、`showDialog` 打开 `FolderColorDialog`（传入当前 `colorHex`）、`_resumeEditorFocus`、结果非 null 再调 `_workspace.updateFolderColor`，失败 `_showMessage` 设置失败；不要为此成功路径弹已设置类 Snackbar；

## 步骤 5：README 与门禁

- [x] 在 `README.md` 功能概览写明：文件夹可设色（长按与 `⋮` 同一菜单）、色条在行左侧、颜色写入 `{id}.fileconf` 的 `color`；目录结构补上 `folder_color_dialog.dart` 与 `rgb_color_picker.dart`；
- [x] 跑 `scripts/run_unit_tests` 全量通过后再宣告完成；
