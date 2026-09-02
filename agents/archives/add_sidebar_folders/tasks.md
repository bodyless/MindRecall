## 步骤 1：存储根迁到 documents 并迁移旧文件

- [x] 在 `lib/services/memo_storage_service.dart` 将 `memosDirectory()` 改为 `MindRecall/documents/`（常量名语义明确，如 `documentsFolderName`），不存在则创建；
- [x] 在 `MemoStorageService` 新增一次性迁移：把 `MindRecall/` 根上的 `.md` / `.txt` 及同级 `{id}_assets` 移入 `documents/`，跳过 `trash/` 与已存在的 `documents/`；已在 `documents/` 内的不重复搬；
- [x] 将 `_fileForId` 改为在 `documents/` 树内按 id 查找笔记文件（含嵌套），找不到再回退到 `documents/{id}.md`；
- [x] 将 `createMemo` 改为在指定相对父目录（默认 `documents/` 根）写入 `{id}.md`，id 与已有文件/文件夹冲突则换新时间戳；
- [x] 在 `lib/services/memo_image_service.dart` 的 `assetsDirectory` / `copyAndBuildMarkdown` / `deleteAssets` 改为相对该笔记 `.md` 所在目录创建/删除 `{id}_assets`，不再写 `MindRecall/` 根；
- [x] 保持 `_resolvePath` 拒绝 `memoDir` 外路径；`test/memo_image_service_test.dart` 的「rejects paths outside」不得改语义；
- [x] 在 `test/memo_storage_service_test.dart` 覆盖：迁移根文件、`createMemo` 写入当前相对目录、嵌套路径 `_fileForId` 能 load；

## 步骤 2：文件夹条目、conf、当前层列举与排序

- [x] 新增侧栏条目模型（文件 / 文件夹），文件夹含 id、磁盘路径、显示名、`createdAt`；文件仍用 `Memo`；
- [x] 约定 conf 为目录内 `{id}.fileconf`，内容含显示名；缺失则显示名为磁盘 basename；搜索与侧栏列举均排除该后缀；
- [x] 在 `MemoStorageService` 新增创建文件夹：生成唯一时间戳目录、写入初始 conf（显示名=用户输入，trim 后为空则失败）；
- [x] 在 `MemoStorageService` 新增重命名文件夹显示名（只写 conf）；删除文件夹整棵交给回收站接口，不在本步直接 `delete`；
- [x] 将 `listMemos` 扩展为全库递归列出所有笔记（供搜索/链接），另增「列出当前相对目录一层」：文件夹 + 笔记文件，排除 `*_assets` 与 conf；
- [x] 替换 `sortMemosWithPins` 的侧栏用法为四段排序：置顶文件夹（后置顶靠前）→ 置顶文件（后置顶靠前）→ 未置顶文件夹（`createdAt`）→ 未置顶文件（`updatedAt`）；
- [x] 在 `test/memo_storage_service_test.dart` 覆盖：一层列举、排除资产/conf、无 conf 回退显示名、四段排序；

## 步骤 3：工作区当前目录与全库索引

- [x] 扩展 `lib/features/memo/editor/memo_workspace_controller.dart` 的 `MemoWorkspaceStore`：`createMemo` 带相对父目录；增补全库列出、当前层列出、创建/重命名/删除文件夹；
- [x] 更新 `DiskMemoWorkspaceStore` 与 `test/memo_workspace_controller_test.dart` 的 `_FakeStore` 以匹配新接口；
- [x] 在 `MemoWorkspaceController` 同时持有全库笔记列表与当前层条目；`runSearch` 只对全库调用 `MemoSearchService.searchMemos`；
- [x] 新增进入文件夹 / 返回上级：只改当前相对路径并刷新当前层，不调用 `openMemo`、不改 `activeMemoId`；根目录返回为 no-op；
- [x] 将 `createNewMemo` 改为把文件建在当前相对目录；`openMemo` 与从搜索打开在成功加载后把当前目录设为该文件父目录并刷新当前层；
- [x] 将 `performSave` / `refreshList` / `deleteMemo` 改为维护全库索引与当前层，禁止把其它目录文件显示进当前层；
- [x] 若删除的文件或文件夹包含 `activeMemoId`：沿用现 `deleteMemo` 的 wasActive 语义（由 Screen 打开剩余篇或新建）；
- [x] 在 `test/memo_workspace_controller_test.dart` 覆盖：当前层过滤、进入/返回不改活动篇、新建落在当前目录、搜索命中子目录文件、打开搜索结果后当前目录为该文件父目录；

## 步骤 4：会话缓存（当前目录与文件夹置顶）

- [x] 在 `lib/services/session_cache_service.dart` 的 `SessionCache` 增加当前相对目录、以及与 `pinnedMemoIds` 分离的文件夹置顶有序列表（后置顶插到最前）；
- [x] 扩展 `MemoPinStore` / `SessionMemoPinStore`：读写当前目录、切换文件夹置顶；冷启动仍读 `lastOpenedMemoId`；
- [x] 在 `MemoWorkspaceController.loadPinsAndList` 中：先跑 documents 迁移与全库索引；恢复上次打开文档后把当前目录设为该文件父目录并回写 session；该文件不存在时才用已持久化的当前目录（非法路径则回 `documents/` 根）；
- [x] 进入/返回文件夹时持久化当前相对路径；
- [x] 补充或新建 `test/` 下 session 解析用例：缺字段时当前目录视为根、置顶列表兼容旧 JSON 仅含 `pinnedMemoIds`；

## 步骤 5：回收站 manifest 与整棵文件夹

- [x] 在 `lib/services/memo_trash_service.dart` 增加 `trash/manifest.json`：按 id 记录 kind（文件/文件夹）与相对 `documents/` 的原父路径；同 id 覆盖；恢复成功后删除对应条；
- [x] 将单文件 `moveToTrash` / `restore` 的目标从存储根改为 `documents/` 树：进站平放到 `trash/{id}.md`（及同级 `{id}_assets`），恢复时父目录存在则回原父目录，否则 `documents/` 根；
- [x] 新增文件夹进站：整目录 `rename` 到 `trash/{folderId}/`（含嵌套、conf、同级 assets），并写 manifest；空文件夹也进站；
- [x] 新增文件夹恢复：整棵移回 manifest 父路径，父目录不存在则放到 `documents/` 根；与已存在同 id 目标的冲突按现文件恢复（先删目标再移入）；
- [x] 将 `listTrash` 改为列出 trash 根上的笔记文件与文件夹条目（不要把文件夹内部的 md 当成独立可选项）；文件夹显示名读其 conf 或 id；
- [x] 扩展 `TrashItem` 以区分文件/文件夹，供 `trash_restore_dialog.dart` 勾选恢复；`MemoWorkspaceController.restoreTrash` 恢复后刷新全库与当前层；
- [x] 在 `test/` 新增或扩展回收站测试：文件回原父目录、父目录缺失回根、文件夹整棵进站与恢复、manifest 覆盖与恢复后移除；

## 步骤 6：侧栏 UI 与 Screen 接线

- [x] 在 `lib/l10n/app_zh.arb` 与 `lib/l10n/app_en.arb` 增加：新建文件、新建文件夹、文件夹名输入框、返回上级、删除文件夹确认等文案，并生成 l10n；
- [x] 将 `lib/features/memo/sidebar/memo_file_panel.dart` 标题栏 `Icons.add` 的 `IconButton` 改为弹出菜单（与文件行 `PopupMenuButton` 同风格）：新建文件走原 `onCreateMemo`，新建文件夹走新回调；`isSaving` 时禁用；
- [x] 在文件列表上方增加「返回上级」：非根且非搜索结果时显示，点击只导航目录；根目录与搜索列表不渲染该按钮；
- [x] 将 `_buildMemoList` 改为渲染当前层文件夹+文件；文件夹使用不同于 `Icons.description` 且不同于「在资源管理器中显示」的 folder icon；点文件夹进入、点文件仍 `onMemoSelected`；活动篇仅在当前层且 id 匹配时高亮；
- [x] 文件夹长按与三点菜单复用现有 `showMenu` / `PopupMenuButton` 样式，项仅为置顶、重命名、删除；文件菜单仍含可选 reveal；
- [x] 新建/重命名文件夹用 Dialog（结构可仿 `RenameMemoDialog`）：确认且显示名非空才调用 store；取消不建目录；
- [x] 在 `lib/features/memo/editor/memo_editor_screen.dart` 的 `_buildFilePanel` 接上：当前层条目、进入/返回、建文件夹、重命名/删除/置顶文件夹；删除文件夹前确认；删除树含当前篇时走现 `_deleteMemo` 之后的切篇逻辑；
- [x] `_createNewMemo` 保持关抽屉、聚焦正文；`LinkInsertDialog` 继续传入全库 `memos` 而非当前层；
- [x] 新建/文件夹菜单打开时调用已有 `onBeforeSystemOverlay` / `onAfterSystemOverlay`；
- [x] 在 `lib/features/memo/sidebar/memo_file_panel_logic.dart` 抽出可单测的：是否显示返回上级、当前层排序、是否高亮；并更新 `test/memo_file_panel_logic_test.dart`；

## 步骤 7：文档与门禁

- [x] 更新 `README.md` 功能概览与目录结构：`documents/`、侧栏当前目录、文件夹 conf、全库搜索、session 当前目录与文件夹置顶、回收站 manifest、图片与 md 同级；
- [x] 按 `.cursor/rules/unit-testing.mdc` 执行 `.\scripts\run_unit_tests.ps1`（或对应 sh），失败则改到全绿后再交付；
