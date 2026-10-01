## 目标

设置「格式」中增加「文件排序」，可选「修改时间」与「名称」，默认「修改时间」。变更后立刻按该方式重排当前目录的侧栏列表，并在之后进入目录、返回上级、切换置顶时继续使用该方式。

## 方案

- 偏好写入 `user_preferences.json`。`UserPreferences.fileListSort` 缺字段或无法识别时为 `FileListSort.modifiedTime`。`UserPreferencesService.updateFileListSort` 经现有 `save` 写盘。
- 设置面板在字体 `SegmentedButton` 下方增加同样式的 `SegmentedButton<FileListSort>`。文案：`settingsFileSort` 为「文件排序」/ `File sort`，`fileSortModifiedTime` 为「修改时间」/ `Modified time`，`fileSortName` 为「名称」/ `Name`。
- `MemoStorageService.sortDirEntries` 增加 `fileListSort` 与 `untitledLabel`。四段仍是置顶文件夹、置顶文件、非置顶文件夹、非置顶文件。`modifiedTime` 保持现在的比较。`name` 只替换非置顶两段：`compareDirEntryByVisibleName` 对文件夹用 `displayName`，对文件用 `displayTitle(untitledLabel)`，按 `String.compareTo` 升序；返回 0 时不再比 id 或时间。
- `MemoWorkspaceController` 记住 `fileListSort`，重排时使用已有的 `untitledLabel`。`setFileListSort` 只重排内存中的 `dirEntries` 并 `notifyListeners`，不读磁盘、不重跑搜索。`_reloadDirEntries`、`togglePin`、`toggleFolderPin` 传入同一对参数。
- `_initializeWorkspace` 在 `loadPinsAndList` 之前，从 `prefsService.preferences` 写入排序方式，并把 `untitledLabel` 设为 `lookupAppLocalizations(preferences.locale).untitled`。冷启动与导入备份后的再次初始化都走这里。
- 设置里改排序：先 `updateFileListSort`，再 `setFileListSort`，再刷新设置底栏。改语言：更新 `untitledLabel` 为新语言的 `untitled`，再 `resortDirEntries`。

## 已决事项

- 「修改时间」就是当前行为：非置顶文件夹按 `createdAt` 新到旧，相同再比 id 降序；非置顶文件按 `updatedAt` 新到旧，相同再比数字 id 降序。不把文件夹改成按 `updatedAt` 排。
- 「名称」比侧栏标题那一行的字符串：文件夹 `displayName`，文件 `Memo.displayTitle(当前语言的无标题)`。标题为空且正文第一行超过 `kMemoTitlePreviewMaxLength` 时，比的就是 `displayTitle` 已截断的那串。不按控件宽度裁出来的绘制文本排。
- 码元升序，当前字符相同则继续比后面的字符。大写 `A–Z` 在小写 `a–z` 前，其它字符按同一套码元顺序。
- 两行可见文本整段相同则比较结果为 0，不再用 id 或其它字段区分先后。
- 四段结构与置顶先后保持不变；名称与修改时间平级，只作用在非置顶两段内部。
- 只影响当前文件列表。搜索结果、`sortMemosStable`、`sortMemosWithPins`、移动目录树 `sortMemoFolderTree` 不读这个设置。
- 语言会改变「无标题」的字，名称模式下切换语言后重排当前列表。

## 关注点

- 排序方式必须在 `loadPinsAndList` 之前写入控制器，否则第一次列表会先按时间排。导入备份会再次进入 `_initializeWorkspace`，用当时的 `preferences`，不要依赖可能尚未重建的 `widget.localeCode`。
- `updateFileListSort` 要在 `setSheetState` 之前执行到 `save` 写好内存偏好；设置底栏读的是 `preferences`，不是 `MaterialApp` 的状态。
- 进目录、返回上级、置顶如果仍调用不带 `fileListSort` 的排序，会退回修改时间。
- 名称比较禁止再比 id。单测只断言相同可见文本的比较结果为 0，不要断言两条相同名称谁在前。
- `untitledLabel` 已存在，搜索在用。名称排序复用它，不要再加一份无标题文案。

## 未决事项

- （无）
