## 步骤 1：偏好

- [x] 在 lib/models/user_preferences.dart 新增枚举 FileListSort，值为 modifiedTime 与 name，存储字符串与枚举名相同，无法识别时视为 modifiedTime；
- [x] 在 UserPreferences 增加 fileListSort，defaults、fromJson、toJson、copyWith 都带上，缺 fileListSort 时为 modifiedTime；
- [x] 在 lib/services/user_preferences_service.dart 新增 updateFileListSort，经 save 写回；
- [x] 在 test/user_preferences_test.dart 断言 fileListSort 往返序列化，以及 json 缺少该字段时恢复为 modifiedTime；

## 步骤 2：比较

- [x] 在 lib/services/memo_storage_service.dart 新增 compareDirEntryByVisibleName：文件夹用 displayName，文件用 displayTitle(untitledLabel)，只做 String.compareTo，完全相同返回 0，禁止再比 id 或时间；
- [x] 在 sortDirEntries 增加 fileListSort（默认 modifiedTime）和 untitledLabel；modifiedTime 保持文件夹 createdAt 降序再比 id 降序、文件走 _compareByUpdatedAtDesc；name 时非置顶两段改用 compareDirEntryByVisibleName；返回顺序仍是置顶文件夹、置顶文件、非置顶文件夹、非置顶文件；
- [x] 在 lib/features/memo/sidebar/memo_file_panel_logic.dart 的 sortMemoDirEntries 把 fileListSort 与 untitledLabel 传给 sortDirEntries；
- [x] 在 test/memo_storage_service_test.dart 覆盖名称序：A 在 Z 前、Z 在 a 前、App 在 Apple 前、英文字母排在更高码元的汉字前；相同可见文本且 id 不同时 compareDirEntryByVisibleName 返回 0；四段与置顶顺序仍在；标题为空时比的是 displayTitle（含传入的无标题文案，以及正文第一行长于 kMemoTitlePreviewMaxLength 时的截断串）；
- [x] 保持 test/memo_storage_service_test.dart 里现有 sortDirEntries 时间序测试在默认参数下通过；
- [x] 不修改 MemoSearchService.searchMemos、sortMemosStable、sortMemosWithPins、sortMemoFolderTree，使它们不读取 fileListSort；

## 步骤 3：当前列表

- [x] 在 MemoWorkspaceController 增加 fileListSort，默认 modifiedTime；新增 resortDirEntries，用当前 fileListSort 与已有 untitledLabel 对 dirEntries 调用 sortDirEntries 并 notifyListeners，且不调用 listDirEntries、不调用 runSearch；
- [x] 在 MemoWorkspaceController 新增 setFileListSort：写入 fileListSort 后调用 resortDirEntries；
- [x] 在 _reloadDirEntries、togglePin、toggleFolderPin 的 sortDirEntries 调用传入 fileListSort 与 untitledLabel；
- [x] 在 lib/features/memo/editor/memo_editor_screen.dart 的 _initializeWorkspace 中，于 loadPinsAndList 之前把 prefsService.preferences.fileListSort 写入控制器，并把 untitledLabel 设为 lookupAppLocalizations(preferences.locale).untitled；
- [x] 在 test/memo_workspace_controller_test.dart 断言 setFileListSort(name) 后当前 dirEntries 的条目集合不变、非置顶段按可见名称排列、置顶段仍在各自段的前面；

## 步骤 4：设置与说明

- [x] 在 lib/l10n/app_zh.arb 与 app_en.arb 增加 settingsFileSort（文件排序 / File sort）、fileSortModifiedTime（修改时间 / Modified time）、fileSortName（名称 / Name），并同步 lib/l10n/app_localizations.dart、app_localizations_zh.dart、app_localizations_en.dart；
- [x] 在 lib/shared/widgets/settings_panel.dart 的字体 SegmentedButton 下方，用 _sectionItemGap 与 _labelGap 增加「文件排序」和 SegmentedButton<FileListSort>，showSelectedIcon 为 false，style 为 _segmentStyle，选中值读 preferences.fileListSort，变更调用 onFileListSortChanged；
- [x] 在 _openSettings 里接上 onFileListSortChanged：直接调用 prefsService.updateFileListSort，使 save 在 setSheetState 之前写好内存偏好，再调用 _workspace.setFileListSort，然后 setSheetState；
- [x] 在 _openSettings 的 onLocaleChanged 中，把 _workspace.untitledLabel 更新为 lookupAppLocalizations 对新语言的 untitled，再调用 resortDirEntries；
- [x] 在 test/settings_panel_test.dart 断言界面上有「文件排序」「修改时间」「名称」；
- [x] 在 README.md 的格式说明中写上文件排序（修改时间 / 名称，默认修改时间）；侧栏顺序改为：默认仍是置顶文件夹、置顶文件、文件夹按建立时间、文件按最后修改时间降序；选名称时非置顶两段改为可见名称的码元升序，整段相同不再区分；搜索与移动目录树不使用该设置；

## 步骤 5：门禁

- [x] 运行 .\scripts\run_unit_tests.ps1，失败则继续改到通过为止；
