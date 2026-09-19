# 已修复 Bug 清单（fixed_list）

> **用途**：记录已修复的回归风险点。  
> **读法（省 token）**：修 Bug 前**先读下方「目录」**；仅对标题相似/关联的条目再读「清单」正文。  
> **写法**：新条目同时追加到**目录顶部**与**清单顶部**（时间倒序）。细则见 `.cursor/rules/fixed-bugs.mdc`。

---

## 目录

- 2026-09-19 — 实时 H1/H2/H3 互切字号滞后
- 2026-09-13 — 代码块多行失焦只留第一行
- 2026-09-13 — 空代码块无深色框
- 2026-09-13 — 文末代码块下方无法续写
- 2026-09-13 — 中间插入正文行距变大
- 2026-09-12 — 标题与删除线共存渲染且光标错位
- 2026-09-12 — 代码块语言框点文字无效且列表跳顶
- 2026-09-06 — 实时聚焦有 IME 时无法拖列表
- 2026-09-02 — 打开含网络图文档 HandshakeException / ANR
- 2026-09-02 — 正文转列表行距错；实时比预览疏
- 2026-08-30 — 冷启动侧栏未应用 session 置顶
- 2026-08-29 — 收键盘后点击正文 ANR
- 2026-08-29 — 切篇不继承光标；收键盘后可拖长段
- 2026-08-28 — 侧栏文件夹图标与名称上下不对齐
- 2026-08-22 — 导入空备份清空本地文档
- 2026-08-22 — 有序项换型后后续序号未重计
- 2026-08-22 — 块首删除合并未保持上方格式
- 2026-08-22 — 勾选框在小/大字号与正文错位
- 2026-08-21 — flutter install 找不到 app-release.apk
- 2026-08-21 — 导入备份后图片丢失
- 2026-08-21 — Android 导入备份 Permission denied
- 2026-08-21 — 水滴打字后隐藏；编辑模式偏 1–2px
- 2026-08-21 — 同一块连续打字软换行不上浮
- 2026-08-21 — 列表块行尾水滴手柄与光标错位
- 2026-08-18 — 原子块删除钮：贴图偏高、贴线偏低、圆内 X 偏
- 2026-08-16 — PROCESS_TEXT 嵌进源 App 导致黑屏卡住
- 2026-08-15 — 实时输入时光标滞后约 100ms
- 2026-08-15 — 有序列表序号相对无序/勾选偏左
- 2026-08-15 — 空正文框点击无光标；空文档灰色提示
- 2026-08-14 — 窄屏半屏侧滑；门禁只认 IME inset；跨块点击落点
- 2026-08-08 — Debug 屏上光标状态 HUD
- 2026-08-08 — 设置面板拆为格式/数据/调试三大类
- 2026-08-08 — Debug 屏上 IME HUD（pending/committed/toolbar）
- 2026-08-06 — 侧栏文件按 updatedAt 排序；段落 Enter 误走粘贴
- 2026-08-02 — Android IME：开关卡顿、跳动与留白（整合）
- 2026-08-01 — 实时模式反复开侧栏偶现文件列表空白
- 2026-08-01 — 编辑/实时拆分 Focus·Scroll·输入 session
- 2026-08-01 — 编辑模式仅 scrollPadding 仍被键盘挡（缺底部可滚留白）
- 2026-07-31 — 编辑模式长文点击底部被键盘遮挡
- 2026-07-31 — P0：块 chrome 几何与 Live 会话纯函数抽离
- 2026-07-31 — 标题 Enter 后光标 X 未更新 / 空文档无光标
- 2026-07-31 — 预览复制列表无法粘贴到实时模式
- 2026-07-31 — 预览全选选区与文字错位
- 2026-07-30 — 实时模式无法删除图片
- 2026-07-30 — 列表↔标题等换块类型时 IME 收起
- 2026-07-30 — 新建空块显示「…」占位
- 2026-07-29 — 实时模式活动块光标「悬」在字后空白处
- 既有 — 实时模式 plain 覆盖导致丢粗体
- 既有 — splitBlockAt 直接 substring plain
- 既有 — Android 行内工具栏抢焦点
- 既有 — 透明叠加编辑行「消失」
- 既有 — 切离实时模式未 flush
- 既有 — Enter 拆块路径重复或遗漏
- 既有 — 多行段落进实时未展开
- 既有 — 按 block.id 重建活动 TextField 导致失焦
- 既有 — 粗体渲染无 fontWeight
- 既有 — 插入链接对话框抢回 IME
- 既有 — 行内 `***` 解析 RangeError
- 既有 — 活动块滚出可视区光标漂顶

---

## 条目格式

```markdown
### YYYY-MM-DD — 简短标题
- **现象**：用户可见的错误行为
- **根因**：一句话
- **修复要点**：关键约束 / 不可再犯的写法
- **相关**：可选（文件、测试名）
```

目录对应一行：`- YYYY-MM-DD — 简短标题`（与上列 `###` 标题一致）。

---

## 清单

### 2026-09-19 — 实时 H1/H2/H3 互切字号滞后
- **现象**：实时模式工具栏在 H1 / H2 / H3 之间切换时，标题字号有时要停约一秒才变
- **根因**：`_applyLineMarkdownTransform` 的 `layoutChanged` 只看 `runtimeType`；三级标题都是 `HeadingBlock`，Live 不 `setState`，列表槽 `headingStyle(level)` 要等到自动保存等其它重建才刷新
- **修复要点**：同属 `HeadingBlock` 但 `level` 不同时必须 `setState`。**禁止**把换级算进 `layoutChanged`（会 `_markLayoutTransition` + `_stabilizeInputFocus(force: true)`，误走 IME 布局过渡）。有序编号刷新已是「`setState` 但不算 layoutChanged」
- **相关**：`live_markdown_editor.dart`、`test/live_heading_level_test.dart`

### 2026-09-13 — 代码块多行失焦只留第一行
- **现象**：实时模式代码块输入多行，光标点到块外或切模式后只剩第一行
- **根因**：`commitPlainToBlock` 用 `!supportsInlineFormatting` 当单行，把 `CodeBlock` 的 plain `split('\n').first`
- **修复要点**：只对 `isSingleLineBlock` 截第一行；代码块提交必须保留完整换行。失焦 / `_activateBlock` / `flushToParent` 都走此函数，禁止另写截行通道
- **相关**：`live_session_ops.dart`、`test/live_session_ops_test.dart`

### 2026-09-13 — 空代码块无深色框
- **现象**：实时转成空代码块时语言框出现，但没有深色代码底，打字后才出现
- **根因**：`_emptyBlockChrome` 的 `CodeBlock` 只有 padding，没有 `codeBlockDecoration`；实时 Overlay 是 chromeless，底色只能靠列表槽
- **修复要点**：空代码块 chrome 必须与有内容分支同样全宽 Container + `codeBlockDecoration`。禁止只在 Overlay 再画一套底
- **相关**：`md_block_renderer.dart`、`test/live_image_delete_and_empty_chrome_test.dart`

### 2026-09-13 — 文末代码块下方无法续写
- **现象**：代码块是最后一块时，写完无法继续写正文；Enter 只在块内换行
- **根因**：空文档 `SliverFillRemaining` 仅 `isEmptyDocumentBody`；代码块不拆块，文末没有可点段落
- **修复要点**：最后一块为 `CodeBlock` 时用独立 key 的文末 fill；点击先 `_commitActiveBlock` 再 `ensureEditableBlockAfterAtomic` 聚焦空段落。禁止改代码块内 Enter 拆块，禁止与空文档 fill 混用 key
- **相关**：`live_markdown_editor.dart`、`live_session_ops.dart`、`test/live_empty_body_hint_test.dart`

### 2026-09-13 — 中间插入正文行距变大
- **现象**：已有多行正文时在中间 Enter 再写，新行与后面原行间距偏大；切模式再回来才正常
- **根因**：`splitMultilineBlockAt` 只给左半段打 `continuesWithNext`，新块默认 false，`bottomSpacingFor` 走 `blockGap`
- **修复要点**：新块须继承被拆块原有的 `continuesWithNext`。禁止把 `syncParagraphFlowFlags` 改成给所有相邻段落 SET flag
- **相关**：`live_session_ops.dart`、`test/live_session_ops_test.dart`

### 2026-09-12 — 标题与删除线共存渲染且光标错位
- **现象**：`## ~~测试~~` 同时呈标题样式和删除线；实时模式点进标题内部折叠光标隐藏或偏移，全选看起来正常
- **根因**：标题不在 `supportsInlineFormatting`，Overlay 透明 `TextField` 含 `~~`；列表层 `MdInlineText` 却解析删除线，段落 plain 与 controller 不一致，`rendererParagraphMatchesCaretPlain` 失败就清掉自定义光标
- **修复要点**：标题展示/编辑必须 `headingVisualPlain`（剥行内标记的纯文本 + 标题样式），**禁止**对 `HeadingBlock` 走 `MdInlineText`。转标题时 `applyHeadingLineMarkdown` / 编辑模式 `applyHeading` 同样剥标记。折叠光标按渲染层测量，字符串须与 Overlay plain 一致
- **相关**：`md_block_renderer.dart`、`block_ops.dart`、`live_line_markdown.dart`、`test/live_block_ops_test.dart`、`test/md_block_renderer_test.dart`

### 2026-09-12 — 代码块语言框点文字无效且列表跳顶
- **现象**：实时模式代码块右上角语言框（如 `python`）点在文字上无效，只能点空白；一点空白文档立刻滚到顶部，代码块滚出视野
- **根因**：语言框挂在列表槽，活动块 Overlay 透明 `TextField` 盖住文字命中；点到空白才落到槽内语言框。正文失焦同一帧语言框尚未获焦，Overlay `IgnorePointer`、IME spacer 被清掉，列表跳顶；语言框默认 `scrollPadding` 还会 `ensureVisible`
- **修复要点**：语言框必须叠在 Overlay 透明 `TextField` **之上**，不要放列表槽。正文/语言框任一获焦（含交接那一帧的 `_imeSessionFocused`）都视为仍在输入，禁止立刻 `IgnorePointer` 或拆 spacer。语言框 `scrollPadding: EdgeInsets.zero`。父屏失焦宽限须等本帧结束再看语言框焦点，禁止抢回正文 Focus
- **相关**：`live_markdown_editor.dart`、`memo_editor_screen.dart`、`test/live_code_language_field_test.dart`

### 2026-09-06 — 实时聚焦有 IME 时无法拖列表
- **现象**：实时模式文本铺满且光标已在某块内时，无法在文字上上下拖列表，只能点到空白才滚；编辑模式无此问题。IME 开着时同样拖不动。
- **根因**：活动块 Overlay 与 `CustomScrollView` 是 `Stack` 兄弟。聚焦时透明 `TextField` 独食命中；`NeverScrollableScrollPhysics` 只禁止块内自滚，不把垂直拖交给外层列表。
- **修复要点**：聚焦 Overlay 块高命中区用垂直拖转发 `ScrollPosition.drag`，不 `unfocus`、不清 `_activeBlockId`。外层**禁止** `onTap`/`onPan` 抢走单击。失焦仍 `IgnorePointer`。**禁止**把 Overlay 塞进列表槽当拖动方案。
- **相关**：`live_markdown_editor.dart`、`test/live_overlay_scroll_test.dart`

### 2026-09-02 — 打开含网络图文档 HandshakeException / ANR
- **现象**：打开文档后 debug 崩并断连，控制台 `HandshakeException: Connection terminated during handshake`；MIUI 上伴随 ANR / signal 3
- **根因**：正文里的 `http(s)` 图用裸 `Image.network`，TLS 握手失败会经 Image 报到 `FlutterError`。侧栏 `ListTile.onTap` 里同步 `_dropEditorFocus()`（unfocus + setState）会拆掉正在处理手势的列表行
- **修复要点**：网络/本地图必须带 `errorBuilder`，失败只显示 alt/src。换篇丢焦点须等出手势回调（`Duration.zero`）再 `unfocus`/`setState`。**禁止**在侧栏 onTap 同步拆焦点树
- **相关**：`md_block_renderer.dart`、`memo_editor_screen.dart`、`test/live_image_delete_and_empty_chrome_test.dart`

### 2026-09-02 — 正文转列表行距错；实时比预览疏
- **现象**：正文换行后立刻改成列表，列表项之间行距宽、正文与列表之间反而窄（像段内换行）；切到其它模式再回来才恢复。同样内容在实时模式比预览更疏（如分割线）。
- **根因**：Enter 给前一段打了 `continuesWithNext`，改块类型时没清；`bottomSpacingFor` / `slotPaddingFor` 只看该 flag。实时每块还有 2px 上下 slot padding、顶边距 12（预览 8）。
- **修复要点**：换型后走 `syncParagraphFlowFlags`；间距函数必须看下一块类型，过期 flow 不能当段内行距。连续列表用 `listItemGap`。实时垂直 slot padding 为 0，顶边距与预览共用 `editorBodyTopPadding`。**禁止**只信 `continuesWithNext` 而不看邻居块类型。
- **相关**：`md_block_styles.dart`、`live_session_ops.dart`、`live_markdown_editor.dart`、`md_blocks_preview.dart`、`test/live_block_ops_test.dart`、`test/live_session_ops_test.dart`

### 2026-08-30 — 冷启动侧栏未应用 session 置顶
- **现象**：打开 App 后本应置顶的文件/文件夹有时不置顶；再手动置顶另一项后，原先的置顶状态又全部回来
- **根因**：`SessionMemoPinStore.load` 给 `session_cache` 读盘加了 300ms timeout；超时后 `loadPinsAndList` 把工作区置顶清成空列表去排序，但底层 cache 仍会加载成功，之后任意一次 toggle 用完整列表重排
- **修复要点**：启动必须等 session 置顶读完再画侧栏，**禁止**用短 timeout 放弃置顶。读失败时仍以 pin store 当前内存为准，**禁止** catch 后写死空列表（会把已读到的置顶丢掉）
- **相关**：`memo_workspace_controller.dart`、`test/memo_workspace_controller_test.dart`、`test/widget_test.dart`

### 2026-08-29 — 收键盘后点击正文 ANR
- **现象**：收起输入法后再点正文，进程被杀（MIUI ANR / signal 3），debug 断连
- **根因**：失焦时列表槽才挂 `InkWell`，`onTap` 里同步 `requestFocus` 让 `ListenableBuilder` 当场拆掉正在处理手势的 `InkWell`；IME `didChangeMetrics` 里同步 `unfocus`/`setState` 与收键盘动画叠在一起
- **修复要点**：活动块列表槽**始终** `InkWell`，聚焦后由上层 Overlay 吃点击，禁止随焦点换树。同块激活把 `restoreFocus` 放到帧末。收 IME 同一轮只丢一次焦点，且 `unfocus` 放在 post-frame。**禁止**在手势回调里同步拆掉命中目标
- **相关**：`live_markdown_editor.dart`、`memo_editor_screen.dart`、`test/live_empty_body_hint_test.dart`

### 2026-08-29 — 切篇不继承光标；收键盘后可拖长段
- **现象**：打开已有文档会带上上一篇的光标；收起输入法后光标仍在，长段很难上下拖
- **根因**：Focus 挂在壳层 session 上，换篇只换文本；`_resumeEditorFocus` 不认 memoId；IME 收起不清焦点；Live Overlay 叠在 ListView 上仍命中
- **修复要点**：resume 只对 suspend 时同一 `memoId` 且未被搜索跳转禁止。换篇 `_dropEditorFocus`。用户收 IME 用 inset 下落 unfocus，禁止「hasFocus 且 inset≈0」。失焦 Overlay `IgnorePointer`，活动块列表槽可点回。**禁止**清 `_activeBlockId` 当拖动方案；**禁止**用 hasFocus 否决侧滑
- **相关**：`mode_input_session.dart`、`memo_editor_screen.dart`、`live_markdown_editor.dart`、`test/mode_input_session_test.dart`、`test/live_empty_body_hint_test.dart`

### 2026-08-28 — 侧栏文件夹图标与名称上下不对齐
- **现象**：侧栏文件夹图标相对文件夹名偏上/偏下，文件行正常
- **根因**：文件夹副标题写成空字符串但仍渲染 `SizedBox(2)` + `Text('')`，行高仍是两行；`Row` 把图标按两行垂直居中，看起来没和名称对齐
- **修复要点**：文件夹用目录 `stat.modified` 当 `updatedAt`，第二行与文件同一套时间格式。空副标题必须不占位（不要留空 `Text`）。**禁止**用空字符串「隐藏」副标题却仍走两行布局
- **相关**：`memo_folder.dart`、`memo_file_panel.dart`、`memo_file_panel_logic.dart`、`test/memo_file_panel_logic_test.dart`、`test/memo_storage_service_test.dart`

### 2026-08-22 — 导入空备份清空本地文档
- **现象**：导入空文件列表会把应用里已有文档全部清掉
- **根因**：`importFromDirectory` 无条件 `_clearDirectoryContents`，再拷备份；空备份拷 0 个文件后本地已空
- **修复要点**：导入确认必须二选一「合并 / 覆盖」，**默认合并**。合并按文件名拷贝（同名覆盖、新名添加），禁止先清空。覆盖才清空再写入。**禁止**导入默认走清空
- **相关**：`data_backup_service.dart`、`import_backup_dialog.dart`、`test/data_backup_service_test.dart`、`test/import_backup_dialog_test.dart`

### 2026-08-22 — 有序项换型后后续序号未重计
- **现象**：有序列表 `1.` `2.` 时把第 1 项改成无序/正文，第 2 项仍显示 `2.`，应为 `1.`
- **根因**：工具栏换型只在新块是 `OrderedBlock` 时 `renumberOrderedBlocksFrom`；有序改为其它类型不重编号
- **修复要点**：换型后走 `renumberOrderedBlocksAround`：切断连续段则后段从 `1.` 起，接上两段则整段重排。**禁止**只判断「当前块变成了有序」
- **相关**：`block_ops.dart`、`live_markdown_editor.dart`、`test/live_block_ops_test.dart`

### 2026-08-22 — 块首删除合并未保持上方格式
- **现象**：标题上方有空行时，光标点在标题最前端再按 IME 删除，标题上移；有时退化为正文，有时多出空行
- **根因**：块首 Backspace 把文本接到上一块时，`copyBlockInlineMarkdown` 不写标题/代码（原样返回），当前块仍被删掉导致丢字/空标题残留；IME 清空与 KeyEvent 还会连打两次
- **修复要点**：块首删除统一走 `mergeCurrentBlockIntoPrevious`：上一块须 `supportsPlainEditing`，文本接到其末尾并**保留上一块类型**，再删当前块。原子块上删除无效。`copyBlockInlineMarkdown` 必须覆盖 Heading/Code。IME 整块清空用 formatter 拒绝并与 KeyEvent 互斥，禁止两路各合一次
- **相关**：`live_session_ops.dart`、`block_ops.dart`、`live_markdown_editor.dart`、`md_block_editor_field.dart`、`test/live_session_ops_test.dart`

### 2026-08-22 — 勾选框在小/大字号与正文错位
- **现象**：字体「小」或「大」时勾选图标相对后续正文略微上下错位；无序/有序列表前缀正常
- **根因**：勾选前缀槽高按未缩放 `fontSize * height` 计算，图标 size 固定 18；正文与 `•`/`1.` 是 Text，会跟 MediaQuery `textScaler` 缩放
- **修复要点**：勾选槽高与图标 size 必须乘 `MediaQuery.textScalerOf`。禁止按裸 `TextStyle.fontSize` 当行高。无序/有序是 Text 不必手写缩放
- **相关**：`md_block_chrome.dart`、`test/md_block_chrome_test.dart`

### 2026-08-21 — flutter install 找不到 app-release.apk
- **现象**：自定义 APK 名为 `mind_recall_<version>_<debug/release>.apk` 后，`flutter install` 仍访问 `build/app/outputs/flutter-apk/app-release.apk` 并失败
- **根因**：Flutter CLI / gradle 插件写死产物名为 `app-<mode>.apk`。改 `outputFileName` 后插件未必再复制该别名，flutter-apk 目录只剩自定义名
- **修复要点**：assemble 后同时写出分发名和 `app-<buildType>.apk`。**禁止**只改 Gradle 输出名而不保留 Flutter CLI 别名
- **相关**：`android/app/build.gradle.kts`、`test/android_apk_output_name_test.dart`

### 2026-08-21 — 导入备份后图片丢失
- **现象**：备份导入后文档在，`{id}_assets/` 里的图片空白
- **根因**：备份设计含图片；但 Android `Directory.list` 常列不出媒体子目录/png。仅拷 `.md` 也会显示成功
- **修复要点**：Android 用 Java `File.listFiles` 递归复制；导入后再按 Markdown `![](./{id}_assets/…)` **点名补拷**。API 33+ 还须 `READ_MEDIA_IMAGES`（不能只靠所有文件访问）。**禁止**假设 dart:io 列举公共目录一定能看到 png
- **相关**：`data_backup_service.dart`、`MainActivity.java`、`test/data_backup_service_test.dart`

### 2026-08-21 — Android 导入备份 Permission denied
- **现象**：release 重装后从 `Download/文档备份/.../user_preferences.json` 导入，`PathAccessException` / `errno = 13`
- **根因**：Android 11+ 分区存储。`File.copy` 读不了公共目录里「非本安装创建」的文件；manifest 只声明了 maxSdk 32 的 `READ_EXTERNAL_STORAGE`，API 33+ 等于没权限。卸 debug 再装 release 会丢掉文件归属
- **修复要点**：API 30+ 须 `MANAGE_EXTERNAL_STORAGE` 并在导入/导出前打开系统授权页等到结果。复制用 `copyFileReplacing`（先删目标，copy 失败再读写字节）。**禁止**在 Android 11+ 只靠 `READ_EXTERNAL_STORAGE` 去 `File.copy` Downloads 里的备份
- **相关**：`MainActivity.java`、`android_storage_permission.dart`、`data_backup_service.dart`、`test/data_backup_service_test.dart`

### 2026-08-21 — 水滴打字后隐藏；编辑模式偏 1–2px
- **现象**：实时模式点选后水滴一直跟着打字；编辑模式水滴比光标提前约 1–2px
- **根因**：实时自绘水滴未对齐编辑模式「keyboard 隐藏 / tap 再显示」。系统折叠手柄 endpoint 在光标左缘，2px 光标条的视觉中线在 +1px，看起来手柄提前
- **修复要点**：实时文本变化隐藏水滴，点选/激活再显示（`liveCollapsedHandleVisibleAfterEdit`）。编辑/标题 `selectionControls` 用 `alignedCollapsedHandleAnchor`（锚点 x − `kTextCaretWidth/2`）。**禁止**折叠水滴贴光标左缘；**禁止**打字时仍画折叠水滴
- **相关**：`live_markdown_editor.dart`、`md_block_editor_field.dart`、`memo_editor_screen.dart`、`live_block_tap_ops.dart`、`test/live_caret_handle_test.dart`

### 2026-08-21 — 同一块连续打字软换行不上浮
- **现象**：点击块后上浮正确；但在同一输入框连续打字、中途不再点击/锁框，软换行后光标会被输入法盖住
- **根因**：`_scheduleScrollActiveIntoView` 只在激活/聚焦/IME settle 时调度；`_onActiveFieldChanged` 不检查槽位变高
- **修复要点**：文本变化后帧末对比活动槽高度，`shouldNudgeImeAfterContentWrap` 为真则 `_nudgeActiveBlockAboveIme`。**禁止**只在点击块或锁起输入框时上浮；软换行必须再检查。勿用 `ensureVisible` 跟每次按键（跳动）
- **相关**：`live_markdown_editor.dart`、`app_layout_constants.dart`、`test/ime_scroll_padding_test.dart`、`test/live_caret_handle_test.dart`

### 2026-08-21 — 列表块行尾水滴手柄与光标错位
- **现象**：点击列表块后光标下方出现 Android 水滴手柄；同一块文字变多并移到行尾后，手柄偏到光标右侧。不必现，仅部分文档、仅列表块
- **根因**：① 系统折叠手柄按透明 TextField 度量，与渲染层自定义光标不是同一套几何（列表更窄、软换行后文末 affinity 把自定义光标送到下一行行首）；② `_findBodyParagraph` 只在空块时跳过 `•`/`1.` 前缀
- **修复要点**：chromeless `showCursor: false` 时**系统**折叠手柄必须关掉（`ChromelessTextSelectionControls`）；可见水滴按渲染层光标自绘（`liveCollapsedCaretHandleTopLeft`）。文末测光标用 `TextAffinity.upstream`；`findLiveBodyParagraph` **始终**跳过列表 chrome 前缀。**禁止**再让系统水滴跟自定义光标各测各的，也**禁止**关掉系统手柄后不补用户可见水滴
- **相关**：`md_block_editor_field.dart`、`live_block_tap_ops.dart`、`live_markdown_editor.dart`、`test/live_block_tap_ops_test.dart`、`test/live_caret_handle_test.dart`

### 2026-08-18 — 原子块删除钮：贴图偏高、贴线偏低、圆内 X 偏
- **现象**：实时选中图片时 × 高出画面顶边；选中分割线时黑圆相对横线偏下；圆对准后叉仍偏在圆内
- **根因**：图片与分割线共用 `Positioned(top: 4)`，未计入图片上下留白、也未按分割线槽高垂直居中；圆内用裸 `Icon` + `Padding`，图标字体 descent 把叉画出几何中心
- **修复要点**：定位走 `MdBlockStyles.positionAtomicDeleteButton`（图片 `top` = 槽位 padding + `imageContentVerticalPadding` + inset；分割线 `top/bottom: 0` + `Center`）。钮体走 `buildAtomicDeleteButton`：固定正方形 + `Center` + `Text`（`height: 1`、`forceStrutHeight`）。叉相对圆心用 `atomicDeleteIconOpticalOffset` 微调。**禁止**图片/分割线再写死同一 `top`，也**禁止**裸 `Icon` 外包 `Padding` 当圆钮
- **相关**：`md_block_styles.dart`、`live_markdown_editor.dart`、`test/md_block_chrome_test.dart`

### 2026-08-16 — PROCESS_TEXT 嵌进源 App 导致黑屏卡住
- **现象**：其它 App 选中文本点「记录到笔记」后，笔记 App 打不开，源 App 黑屏卡住
- **根因**：`activity-alias` 把 Flutter `MainActivity` 直接当作 `PROCESS_TEXT` 处理方；系统在**调用方任务栈**里 `startActivityForResult`，主界面既不 `finish` 也不回到自己的 task，源 App 一直等结果
- **修复要点**：必须用独立 `ProcessTextActivity`（`Theme.NoDisplay`，非 Flutter）接收选区，`FLAG_ACTIVITY_NEW_TASK|CLEAR_TOP|SINGLE_TOP` 打开 `MainActivity`，立刻 `setResult(CANCELED)` + `finish()`。**禁止**再把 `PROCESS_TEXT` alias/intent-filter 挂到 `MainActivity`
- **相关**：`ProcessTextActivity.java`、`AndroidManifest.xml`、`test/android_process_text_manifest_test.dart`

### 2026-08-15 — 实时输入时光标滞后约 100ms
- **现象**：打几个字后，光标要过约 100ms 才跟到新字后面
- **根因**：自定义光标按列表层 `RenderParagraph` 测；controller 已更新但列表尚未 layout 时若测一次就停，会钉在旧坐标，直到 `_syncToParent` 的 120ms debounce 触发重建
- **修复要点**：段落 plain 未跟上 controller 时**再等一帧**测量（有重试上限）；**禁止**把 `_syncToParentDebounce` 当光标刷新；勿为赶速度改回 chromeless `showCursor: true`（会「悬」在字后空白）
- **相关**：`live_markdown_editor.dart`（`_RendererSyncedCaret`）、`live_session_ops.dart`（`rendererParagraphMatchesCaretPlain`）、`test/live_session_ops_test.dart`

### 2026-08-15 — 有序列表序号相对无序/勾选偏左
- **现象**：`1. 2. 3.` 看起来比 `•` / 勾选图标更靠左，后两者像有缩进
- **根因**：有序前缀是随字宽的 `1. `，无序是 `•  `，勾选是固定 `taskPrefixWidth`（24）；三者槽宽不一致
- **修复要点**：无序/有序/勾选共用 `MdBlockChromeMetrics.listPrefixSlotWidth`；有序在槽内**右对齐**。勿只改 renderer 而漏 chromeless Overlay
- **相关**：`md_block_chrome_metrics.dart`、`md_block_chrome.dart`、`test/md_block_chrome_test.dart`

### 2026-08-15 — 空正文框点击无光标；空文档灰色提示
- **现象**：新建文档输入标题后，点正文框空白不出光标（须标题回车或刚好点到第一行）
- **根因**：实时 Overlay 按内容收缩高度（避免盖住下方块），空段落只有一行；ListView 空白区吞点击且无 InkWell
- **修复要点**：`isEmptyDocumentBody`（仅单空段落）时：① 灰色 hint「点击此处输入文本」（`MdBlockChrome.hintStyle`，与标题「无标题」同透明度）；② `SliverFillRemaining` 吃剩余空白并 `requestFocus`。hint **叠在**透明空格上，勿替换占位、勿恢复「…」
- **相关**：`live_markdown_editor.dart`、`md_block_renderer.dart`、`test/live_empty_body_hint_test.dart`

### 2026-08-14 — 窄屏半屏侧滑；门禁只认 IME inset；跨块点击落点
- **现象**：① 左边缘仅约 48px，难侧滑；② 聚焦时侧滑会与 IME 下落叠动画；③ 若用「失焦才允许侧滑」，Android 收起键盘后常仍保留焦点/光标，侧滑继续被禁；④ 跨块点击 caret 落块末
- **根因**：① 边缘宽写死 48；② Scaffold 在进度>0.5 才 `onDrawerChanged` 才 unfocus；③ 焦点 ≠ IME 可见；④ `_activateBlock` 写死块末
- **修复要点（方案 A）**：`drawerEdgeDragWidthFor` 半屏+安全区；`drawerOpenDragGestureEnabled` **只认**系统 `viewInsets`（≤0.5 允许），勿用 hasFocus/hadFocus；父屏 metrics 观察者仅在「可否侧滑」布尔翻转时 setState；菜单仍 `_openMobileDrawer` 串行；非活动块 `plainOffsetAtGlobalTap`。光标可与 IME 解耦，勿再为侧滑强制藏光标
- **相关**：`memo_file_panel_logic.dart`、`memo_editor_screen.dart`、`live_markdown_editor.dart`、`live_block_tap_ops.dart`、`test/memo_file_panel_logic_test.dart`、`test/live_block_tap_ops_test.dart`

### 2026-08-08 — Debug 屏上光标状态 HUD
- **现象**：排查光标/块问题时只能靠猜测或打断点，无屏上实时状态
- **根因**：调试叠层仅有 FPS / IME，缺光标与块上下文
- **修复要点**：总开关下增加「显示光标状态」；Live/Edit 经 `publishCursorDebugHud` 更新；与 IME 共用左上角 `DebugInfoOverlay` 列表（各为列表段）；HUD 含模式、选区、块类型与序号、前后文；叠层限频；release / 未开调试勿挂载
- **相关**：`cursor_debug_hud.dart`、`debug_info_overlay.dart`、`live_markdown_editor.dart`、`memo_editor_screen.dart`、`settings_panel.dart`、`test/cursor_debug_hud_test.dart`

### 2026-08-08 — 设置面板拆为格式/数据/调试三大类
- **现象**：设置项平铺，语言/主题/备份/调试挤在一起，层次不清；调试说明冗长且无法单独开关 FPS / IME / 光标 HUD
- **根因**：无大类分区；调试仅单一总开关
- **修复要点**：UI 按 **格式** / **数据** / **调试** 分区；调试为总开关「启用调试」，开启后显示子开关「显示帧率」「显示IME状态」「显示光标状态」（关闭总开关则隐藏子项）；叠层挂载须 `总开关 && 对应子开关`；旧偏好缺子键时子开关默认 true
- **相关**：`settings_panel.dart`、`user_preferences.dart`、`main.dart`、`app_zh.arb`、`app_en.arb`、`test/settings_panel_test.dart`

### 2026-08-08 — Debug 屏上 IME HUD（pending/committed/toolbar）
- **现象**：工具栏/正文 IME 延迟只能靠 DevTools Timeline 对照，真机难判断是 metrics 尾抖还是 commit 未写 toolbar
- **根因**：已有 `Ime.*` Timeline，缺屏上实时快照
- **修复要点**：设置「启用调试」后挂 `DebugInfoOverlay`（左上角列表，IME/光标为列表段）；Live/Edit metrics·settle·dismiss 经 `publishImeDebugHud` 更新全局快照；读 `p/c/t` 与 `rst`/`burst` 判断尾抖；勿在 release 或未开调试时挂叠层；叠层 UI 须限频，勿每帧 setState
- **相关**：`ime_debug_hud.dart`、`debug_info_overlay.dart`、`live_markdown_editor.dart`、`memo_editor_screen.dart`、`main.dart`、`test/ime_debug_hud_test.dart`

### 2026-08-06 — 侧栏文件按 updatedAt 排序；段落 Enter 误走粘贴
- **现象**：① 实时模式正文段落按 Enter 不换块，列表 Enter 仍可新建 `•`；② 左侧文件列表像按创建时间排，非最后修改时间
- **根因**：① `_NewBlockEnterFormatter` 把单独插入的 `\n` 也当成「含换行粘贴」（`contains('\n')`），段落只靠 formatter、列表走 `onKeyEvent` 故列表仍正常；② `sortMemosStable` / `sortMemosWithPins` 按文件 id（创建时间戳）排，未用 `Memo.updatedAt`
- **修复要点**：仅「非单次 Enter」的换行插入才走粘贴（`isMultilinePasteInsertion`）；侧栏非置顶项按 `updatedAt` 降序，勿再按 id/创建冒充修改时间
- **相关**：`md_block_editor_field.dart`、`memo_storage_service.dart`、`test/live_enter_format_test.dart`、`test/memo_storage_service_test.dart`

### 2026-08-02 — Android IME：开关卡顿、跳动与留白（整合）
- **现象**（同一问题链，曾拆成十余条）：反复呼出/收起键盘掉帧；与侧栏互开更卡；动画中正文/工具栏一截一截跳，或动画结束后顿一下再动；工具栏显隐落后/二次刷新；编辑与实时底端留白不一致、末行像被底遮罩挡住
- **根因**：`resizeToAvoidBottomInset: false` 下自管 IME 时，多层写法叠在一起——`MediaQuery.viewInsets` 打脏整树；Live 为 inset `setState` 重建块列表；动画中步进提交或每帧重置 settle；工具栏与正文各自 settle；编辑把大块 IME 塞进 `contentPadding` 变成视口底遮罩
- **修复要点**（终态约束；下列中间方案**禁止回潮**：trailing debounce 跟手、`shouldCommitImeInsetStepped` 驱动 UI、工具栏动画中步进/提前显栏、builder 里 `MediaQuery.of`、为 inset 整树 `setState`、大块 IME 进 `contentPadding`）
  1. **MediaQuery**：`KeyboardStableMediaQuery` 发布 `viewInsets=0`；IME 高度只走 `View` / session metrics；禁止 `viewInsetsOf` 回退
  2. **Live 留白**：`ValueNotifier` + ListView **尾部 spacer**（`liveListImeSpacerHeight`）；聚焦只改 notifier
  3. **Settle-only（正文）**：动画中不改留白；仅 `|pending-armed|≥kImeSettleRestartMinDelta(8)` 重启 `kImeInsetSettleDelay(48ms)`；回调读**最新** pending；收起 `dismissImmediate` 立刻清正文 inset
  4. **窄屏工具栏**：与正文 **nudge 同拍**一次性写入 toolbar inset（有缓存=`applyCache` 当拍；无缓存=`settleDebounced`）。栏贴齐键盘顶（`imeToolbarBottomPadding`，**禁止**再叠 `kEditorPagePadding`）。已显示后禁止分帧爬升；仅 `raiseCache` / `correctCacheDown` 可改高度。收起立刻清零。勿动画中步进显栏 / 勿跟手提前显栏 / 勿再单独用 120ms pending 静止窗显栏
  5. **编辑留白**：`contentPadding` 仅 `kEditorBodyBottomPadding + safe`；IME 用 `editImeBottomSpacerHeight`（仅 `keyboardInset>0`）做 Column 底 spacer；有 spacer 时 nudge 勿再按满高 obscured 上推
  6. **侧栏**：suspend 时立刻 snap 清 inset 并忽略 metrics；开抽屉等 IME 上限宜短（约 180ms）
  7. **排查**：debug Timeline `Ime.Live.*` / `Ime.Edit.*`（`burstMs` / `settleResetCount` / `visualShift`）
  8. **二次上推**：无缓存时 spacer 仍 settle-only，nudge+工具栏用 `kImeNudgeDebounceDelay`(120ms) 防抖后写入 `ImeHeightCache`；有缓存时首次 settle 提交 `max(pending, cache)` 并立即 nudge+显栏（`applyCache`）。套用缓存后**禁止**把 `pending < committed` 当成收起。缓存偏高才在静默后 `correctCacheDown`。高度按视口分桶持久化到应用 support 目录 `ime_height_cache.json`（启动 `App.imeHeightCacheLoad`；**不要**写入 `user_preferences.json` / 备份）。真实高度变化时 `raiseCache` / `correctCacheDown` 改写缓存。勿为跟手动画步进 spacer。
- **未决**（仍属本条）：编辑末行底遮罩体感未完全消除——继续对照上列约束排查
- **相关**：`keyboard_stable_media_query.dart`、`ime_timeline.dart`、`ime_height_cache.dart`、`ime_height_cache_store.dart`、`app_layout_constants.dart`、`live_markdown_editor.dart`、`memo_editor_screen.dart`、`main.dart`、`test/ime_scroll_padding_test.dart`、`test/keyboard_stable_media_query_test.dart`、`test/ime_timeline_test.dart`、`test/ime_height_cache_test.dart`、`test/ime_height_cache_store_test.dart`
- **历史子题**（已并入，勿再单独追加同质条目）：实时反复呼键盘卡顿；MediaQuery 整树重建；侧栏互开卡顿；动画结束顿一下；settle-only；收起立刻藏栏；settle 重置阈值；Timeline；工具栏/正文同帧与同拍；先滚再显栏；底距对齐；编辑 contentPadding→spacer；工具栏同拍 settle 分帧爬升；工具栏静止后一次性显栏

### 2026-08-01 — 实时模式反复开侧栏偶现文件列表空白
- **现象**：光标在实时模式时反复打开左侧栏/抽屉，偶现文件列表空白或像「暂无文件」
- **根因**：① 固定 300ms 等 IME，慢机上抽屉在 viewInsets 未收完时打开；② 搜索防抖清空前仍显示搜索空结果；③ 宽屏侧栏用 Timer 揭示，取消后可能卡住不挂载面板；④ 文件 ListView 占用 PrimaryScrollController，残留 offset 滚到空白区
- **修复要点**：开抽屉须轮询至 inset≈0（或超时）且 `MediaQuery.removeViewInsets(removeBottom)`；搜索 UI 以 query 非空为准并在清空时立刻退出搜索态；宽屏揭示用 `AnimatedContainer.onEnd`（`SidebarRevealState`）；文件/搜索 ListView 设 `primary: false`
- **相关**：`memo_file_panel_logic.dart`、`memo_editor_screen.dart`、`memo_file_panel.dart`、`test/memo_file_panel_logic_test.dart`

### 2026-08-01 — 编辑/实时拆分 Focus·Scroll·输入 session
- **现象**（风险）：编辑与实时共用 `_contentFocusNode` / `_contentScrollController` / `_contentHadFocus`，实时失焦宽限与滚动会污染编辑 IME
- **根因**：壳层把模式私有输入基础设施当成跨模式总线
- **修复要点**：`EditInputSession` + `LiveInputSession` 各持 Focus/Scroll；live 的 `hadFocus`/`deferFocusBlur` 与 edit 的键盘 inset 互不共享；切模式须 unfocus 离开方并 `clearSessionFlags`/`resetKeyboardInsets`
- **相关**：`mode_input_session.dart`、`memo_editor_screen.dart`、`test/mode_input_session_test.dart`

### 2026-08-01 — 编辑模式仅 scrollPadding 仍被键盘挡（缺底部可滚留白）
- **现象**：编辑模式点击下方文字，光标仍被输入法挡住（上次「bringIntoView + nudge」未真正生效）
- **根因**：`resizeToAvoidBottomInset: false` 下只设 `scrollPadding` 不增大 `maxScrollExtent`；文末无法再上滚
- **修复要点**：须有可滚/可承托的 IME 留白（实时尾部 spacer；编辑见 **2026-08-02 整合条** 的 Column spacer）。**勿**再把大块 IME 塞进 `contentPadding`
- **相关**：`memo_editor_screen.dart`、`app_layout_constants.dart`、`test/ime_scroll_padding_test.dart`

### 2026-07-31 — 编辑模式长文点击底部被键盘遮挡
- **现象**：编辑模式大量文本时，点击下方文字后光标落在键盘/工具栏后方
- **根因**：`resizeToAvoidBottomInset: false` 时 TextField 视口含键盘下方区域；仅设 `scrollPadding` 不会像实时模式那样主动上推
- **修复要点**：焦点/选区/键盘 metrics 变化时 `bringIntoView` + `scrollDeltaToClearIme`；留白结构以 **2026-08-02 整合条** 为准
- **相关**：`memo_editor_screen.dart`、`app_layout_constants.dart`、`test/ime_scroll_padding_test.dart`

### 2026-07-31 — P0：块 chrome 几何与 Live 会话纯函数抽离
- **现象**（风险）：renderer / chromeless / 预览选区前缀宽度易漂移；`LiveMarkdownEditorState` 内嵌 AST 逻辑难单测
- **根因**：magic `•  `/`12` 多处复制；加载/拆块写在 StatefulWidget 内
- **修复要点**：`MdBlockChromeMetrics` + `MdBlockChrome` 为唯一 chrome 源；`live_session_ops.dart` 承载加载/拆块/单行 Enter；State 只做 UI
- **相关**：`test/md_block_chrome_test.dart`、`test/live_session_ops_test.dart`

### 2026-07-31 — 标题 Enter 后光标 X 未更新 / 空文档无光标
- **现象**：H1 换行后光标仍在「问题」下方；新建空文档看不到光标
- **根因**：空块 chrome 只有 `SizedBox` 无 `RenderParagraph`；自定义光标测量失败时未清除旧坐标
- **修复要点**：空块用透明空格保留段落；空 plain 优先匹配占位段落；测量失败须清空 stale caret
- **相关**：`md_block_renderer.dart`、`live_markdown_editor.dart`（`_RendererSyncedCaret`）

### 2026-07-31 — 预览复制列表无法粘贴到实时模式
- **现象**：预览复制多行列表后，实时模式粘贴无效
- **根因**：`_NewBlockEnterFormatter` 遇 `\n` 一律当 Enter 并丢弃粘贴
- **修复要点**：多行插入走 `pasteMarkdownAtCaret` → `pasteMarkdownIntoBlocks`；`•` 规范为 `-`
- **相关**：`md_block_editor_field.dart`、`block_ops.dart`、`test/live_paste_markdown_test.dart`

### 2026-07-31 — 预览全选选区与文字错位
- **现象**：预览全选后高亮/光标与渲染文字不对齐
- **根因**：选区几何来自透明 `toMarkdown()` 文本（含 `- `/`## `），与渲染层 `•`/标题样式不一致
- **修复要点**：选区镜像与渲染同结构；复制时再转 Markdown（`visualSelectionToMarkdown`）
- **相关**：`md_blocks_preview.dart`

### 2026-07-30 — 实时模式无法删除图片
- **现象**：插入图片后在实时模式无法删除
- **根因**：图片块无删除交互，且活动 Overlay TextField 盖住图片
- **修复要点**：点击图片选中后右上角显示 ×；图片活动时不挂透明 TextField Overlay；删除走 `removeBlockAt`
- **相关**：`live_markdown_editor.dart`、`block_ops.dart`、`test/live_image_delete_and_empty_chrome_test.dart`

### 2026-07-30 — 列表↔标题等换块类型时 IME 收起
- **现象**：光标在列表再点标题（或其它不同类型块）时输入法隐藏
- **根因**：chromeless 层列表用 `Row+Expanded`、标题用裸 `TextField`，换型导致 TextField 重挂载失焦
- **修复要点**：chromeless **始终** `Row + prefix + Expanded(TextField)`；换不同类型块时 `forceFocus` 拉回焦点
- **相关**：`md_block_editor_field.dart`、`live_markdown_editor.dart`

### 2026-07-30 — 新建空块显示「…」占位
- **现象**：新建空块前方出现「…」
- **根因**：`MdBlockRenderer._emptyBlockChrome` 用省略号占位
- **修复要点**：空块只保留行高 `SizedBox`，不渲染「…」；编辑态靠光标即可
- **相关**：`md_block_renderer.dart`

### 2026-07-29 — 实时模式活动块光标「悬」在字后空白处
- **现象**：点击块后光标在逻辑末尾，但视觉上离最后一个字还有一段空白；退格仍直接删最后实字符
- **根因**：列表 `MdInlineText` 与上层透明 `TextField` 字形宽度不一致；粗体曾使用 `letterSpacing` 进一步拉宽渲染宽度
- **修复要点**：chromeless 层 `showCursor: false`，按渲染层 `RenderParagraph` 实测位置画光标；粗体勿加会改变 advance 的 `letterSpacing`
- **相关**：`live_markdown_editor.dart`（`_RendererSyncedCaret`）、`md_inline_renderer.dart`、`md_block_editor_field.dart`

### 既有 — 实时模式 plain 覆盖导致丢粗体
- **现象**：预览/实时丢失 `**粗体**`
- **根因**：用纯文本 `copyWithPlainText` 覆盖含行内 markdown 的 block
- **修复要点**：显示用 `editableTextForBlock`；写回用 `applyPlainTextChange` / `copyBlockInlineMarkdown`
- **相关**：`block_ops.dart`、`md_inline.dart`

### 既有 — splitBlockAt 直接 substring plain
- **现象**：块中拆分后行内格式错乱或丢失
- **根因**：按 plain 偏移直接切字符串
- **修复要点**：必须 `splitInlineMarkdown`（或等价按 AST 拆分）
- **相关**：`live_markdown_editor.dart`、`md_inline.dart`

### 既有 — Android 行内工具栏抢焦点
- **现象**：点 B/I 后面板或选区异常、IME 跳动
- **根因**：工具栏可抢焦点
- **修复要点**：`captureForInlineAction` + 按钮 `canRequestFocus: false`
- **相关**：实时工具栏 / `memo_editor_screen.dart`

### 既有 — 透明叠加编辑行「消失」
- **现象**：有格式时活动行看起来空白
- **根因**：`InputDecoration` 不透明填充盖住下层渲染
- **修复要点**：`filled: false` / 透明 `fillColor`，与透明 text style 配套
- **相关**：`md_block_editor_field.dart`

### 既有 — 切离实时模式未 flush
- **现象**：切编辑/预览后内容丢失或过期
- **根因**：块 AST 未写回 parent controller
- **修复要点**：切离前 `flushToParent()`
- **相关**：`LiveMarkdownEditor` / `memo_editor_screen.dart`

### 既有 — Enter 拆块路径重复或遗漏
- **现象**：标题/列表 Enter 无新段，或段落被拆两次
- **根因**：formatter 与 `Focus.onKeyEvent` 职责不清
- **修复要点**：段落走 `_NewBlockEnterFormatter`；单行块可另由 onKeyEvent → `_insertEmptyBlockBelow`；勿对段落重复处理
- **相关**：`md_block_editor_field.dart`、`live_markdown_editor.dart`

### 既有 — 多行段落进实时未展开
- **现象**：H2/列表等块级操作作用到整段多行
- **根因**：含 `\n` 的段落未拆成每行一块
- **修复要点**：进入实时前 `expandMultilineParagraphsForLive`；块级样式只作用于当前块
- **相关**：`live_line_markdown.dart` / live editor

### 既有 — 按 block.id 重建活动 TextField 导致失焦
- **现象**：换块或类型切换后 Android 键盘收起、焦点丢失
- **根因**：活动 TextField 随 id 销毁重建
- **修复要点**：Stack 内**唯一持久** Overlay `MdBlockEditorField`（固定 key），换块只改 controller 内容
- **相关**：`live_markdown_editor.dart`

### 既有 — 粗体渲染无 fontWeight
- **现象**：粗体看起来不够粗或与正文难区分
- **根因**：`TextSpan` 未设 `fontWeight`
- **修复要点**：`BoldInline` 必须设置字重（中文可辅以极轻 shadow，勿用会改宽度的 letterSpacing）
- **相关**：`md_inline_renderer.dart`、`test/md_inline_test.dart`

### 既有 — 插入链接对话框抢回 IME
- **现象**：弹链接面板时键盘/焦点被编辑器抢回
- **根因**：未暂停编辑器焦点
- **修复要点**：对话框前 `_suspendEditorFocus()`
- **相关**：`memo_editor_screen.dart`

### 既有 — 行内 `***` 解析 RangeError
- **现象**：输入或解析 `***` 崩溃
- **根因**：`*.+?*` 匹配后未校验包裹长度就 `substring`
- **修复要点**：`_isWrapped` 校验长度后再切片
- **相关**：`md_inline.dart`、`test/md_inline_test.dart`

### 既有 — 活动块滚出可视区光标漂顶
- **现象**：滚动后光标出现在屏幕顶部
- **根因**：Follower 在锚点不可见时仍显示
- **修复要点**：滚出可视区隐藏 Follower；外层 `Clip.hardEdge`
- **相关**：`live_markdown_editor.dart`
