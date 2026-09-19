## 步骤 1：磁盘移动与文件夹树

- [x] 在 `lib/models/memo_folder.dart` 新增文件夹树节点类型（根节点 `relativeDir` 为空、`folderId` 为空；子节点带 id、显示名、相对 `documents/` 路径、子列表）；
- [x] 在 `lib/services/memo_fs_constants.dart` 的 `MemoFs` 新增判断：某相对路径是否等于或位于另一文件夹相对路径之下（用于剔除自身与子孙）；
- [x] 在 `lib/services/memo_storage_service.dart` 新增 `listFolderTree`：从 `documents/` 递归只收文件夹（排除 `*_assets`），显示名走现有 `readFolderDisplayName`，根节点代表 `documents/` 根；
- [x] 在 `MemoStorageService` 新增 `moveMemo`：按 id 找到 `.md`/`.txt`，`rename` 到 `resolveRelativeDir(docs, destRelativeDir)` 下同名文件，并把同级 `{id}_assets/` 一并 `rename`；源已在目标则抛错；目标已存在同名则抛错不覆盖；返回搬后的 `Memo`（新 `filePath`）；
- [x] 在 `MemoStorageService` 新增 `moveFolder`：按 id 找到目录，拒绝目标相对路径为自己或子孙，将整目录 `rename` 到目标下的 `{id}/`；目标已存在同名则抛错不覆盖；
- [x] 在 `test/memo_storage_service_test.dart` 覆盖：文件连 assets 搬到子目录后 `loadMemo` 与图片目录新路径；文件夹整棵搬迁；拒绝文件夹搬进自身子孙；目标已存在同 id 失败；

## 步骤 2：选目录纯逻辑

- [x] 在 `lib/features/memo/sidebar/memo_file_panel_logic.dart` 新增：按置顶列表对树每一层排序（置顶文件夹顺序与侧栏相同，其余按 `createdAt` 新→旧）；
- [x] 在同文件新增：移动文件夹时从树中去掉自身及子孙节点（根永远保留）；
- [x] 在同文件新增：确认是否可点（所选 `relativeDir` 与源父相对路径不同才为真）；
- [x] 在 `test/memo_file_panel_logic_test.dart` 覆盖：剔除自身与子孙、源父目录时确认禁用、选其它目录确认启用、根作为目标、每一层置顶排序；

## 步骤 3：工作区搬迁且不切文档

- [x] 在 `lib/models/memo.dart` 的 `copyWith` 增加可选 `filePath`，供测试与内存更新使用；
- [x] 在 `MemoWorkspaceStore` / `DiskMemoWorkspaceStore` 增加 `listFolderTree`、`moveMemo`、`moveFolder` 并转给 `MemoStorageService`；
- [x] 在 `test/memo_workspace_controller_test.dart` 的 `_FakeStore` 实现上述三方法（内存改 `filePath` / `directoryPath`，文件夹搬迁时同步其子文件与子文件夹路径）；
- [x] 在 `MemoWorkspaceController` 新增 `moveMemo`：先 `flushSave`，再 store 移动，再 `listMemos` + `_reloadDirEntries`；不改 `currentRelativeDir`、不改 `activeMemoId`、不调用 `applyMemoToEditors` / `openMemo`；
- [x] 在 `MemoWorkspaceController` 新增 `moveFolder`：同样先 `flushSave`，store 移动后刷新全库与当前层；不改当前目录与活动篇；若活动篇位于被搬文件夹内，仅通过新的 `listMemos` 更新其 `filePath`；
- [x] 在 `test/memo_workspace_controller_test.dart` 覆盖：搬文件后当前目录不变、活动篇 id 不变、该篇 `filePath` 已更新、当前层不再出现该文件；搬文件夹后活动篇仍打开且路径已更新、当前目录不变；

## 步骤 4：菜单、选目录对话框与 Screen

- [x] 在 `lib/l10n/app_zh.arb` 与 `lib/l10n/app_en.arb` 增加「移动到」、对话框标题、「根目录」、已移动、移动失败；改完后生成 l10n；
- [x] 新增 `lib/features/memo/editor/widgets/move_to_folder_dialog.dart`：`AlertDialog` 列出根 + 文件夹树；行点击选中；有子节点才显示展开箭头且只切换展开；根默认展开、其它默认折叠；当前源父目录可被选中但确认禁用；无新建入口；确认返回所选 `relativeDir`；
- [x] 在 `lib/features/memo/sidebar/memo_file_panel.dart` 的 `_MemoFileAction` 增加 `move`；`_entryMenuItems` 在重命名与删除之间加入「移动到」（文件与文件夹都有）；搜索列表 `_buildSearchResults` 不改；
- [x] 在 `MemoFilePanel` 增加 `onMoveMemo` / `onMoveFolder`，`_handleEntryAction` 按文件/文件夹分别回调；
- [x] 在 `lib/features/memo/editor/memo_editor_screen.dart` 的 `_buildFilePanel` 接上移动回调；新增移动流程：取源父相对路径、拉树、若是文件夹则剔除自身子孙、`showDialog` 打开 `MoveToFolderDialog`、确认后调 workspace 对应 `moveMemo`/`moveFolder`，成功 `_showMessage` 已移动，失败 `_showMessage` 移动失败；
- [x] 移动流程中不要 `openMemo`、不要改编辑器 controller；可与重命名一样用 `_suppressAutoSave` 包住搬迁调用；

## 步骤 5：README 与门禁

- [x] 在 `README.md` 功能概览写明侧栏可将文件/文件夹移动到已有目录（含根），搜索不做移动；目录结构补上 `move_to_folder_dialog.dart`；
- [x] 跑 `scripts/run_unit_tests` 全量通过后再宣告完成；
