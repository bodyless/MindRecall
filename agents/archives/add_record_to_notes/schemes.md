## 目标

其它 Android App 选中文本后，系统选区菜单出现「记录到笔记」；点选后打开回念笔记，把选中文本存成一篇笔记并留在本 App 内展示。

验收：已安装本 App 的真机上，在系统浏览器或备忘录等使用系统选区菜单的 App 中选中非空文本，菜单含「记录到笔记」；冷启动与本 App 已在后台两种路径都能得到一篇正文为该文本的笔记；源 App 选中内容不被改写。

## 方案

- 用 `activity-alias` 指向现有 `MainActivity`，alias 的 `android:label` 为「记录到笔记」，注册 `ACTION_PROCESS_TEXT` + `text/plain`。启动器名称仍为「回念笔记」。
- Native 从 `Intent.EXTRA_PROCESS_TEXT` 取出文本，经 EventChannel 交给 Dart；不 `setResult`、不 `finish()`。
- Dart 等 `_initializeWorkspace` 结束后再消费：当前活动笔记标题与正文都为空则填入该篇，否则 `createNewMemo` 再写入正文；标题字段留空（列表预览走 `Memo.displayTitle` 的首行）；立刻 `flushSave`。
- 仅 Android。不接 `ACTION_SEND`、不做 iOS 分享扩展。不新增 pub 包。

## 已决事项

- 系统选区菜单中文名：「记录到笔记」；英文资源为 `Save to Notes`。
- 用 `activity-alias`（`.ProcessTextAlias`）注册，不改 `MainActivity` / 应用的显示名。
- 复用现有 `MainActivity`（保持 `singleTop`）；热启动走 `onNewIntent`，冷启动走 `configureFlutterEngine` 时的 `getIntent()`。
- 不把处理结果交还触发方：禁止 `setResult` 写回选区；禁止为「返回源 App」而 `finish()`。
- 空串或 trim 后为空：忽略，不建文件、不改当前笔记。
- 标题字段留空，正文为 trim 后的选中文本。
- 当前活动笔记标题与正文都为空（含冷启动自动新建的空篇）则复用该篇；否则先 flush 再新建。
- 必须等编辑器 `_initializeWorkspace` 完成后再订阅/消费，避免与「恢复上次文档 / 空库建空篇」抢跑。
- 确认方式：打开并展示该笔记；不另弹 SnackBar。
- 通道：新建 EventChannel `com.wishtech.mind_recall/process_text`；权限通道保持独立。
- 范围：仅 `PROCESS_TEXT`；微信等自绘选区菜单不在验收范围。

## 关注点

- Manifest 已有的 `<queries>` `PROCESS_TEXT` 是查询别人，保留；本功能靠 alias 上的 `intent-filter` 成为处理方。
- `MainActivity` 已 `exported="true"` 且 `configChanges` 含 orientation，旋转不重建 Activity；pending 用实例字段即可。
- 取出 extra 后立刻 `removeExtra`，避免同一 Intent 被读两次；进程在送达 Dart 前被杀属于极窄窗口，不做磁盘队列。
- 实时模式写入正文前先 `flushToParent()`；写入 `contentController` 后 Live 会走 `_onExternalControllerChanged` 重载 AST，仍须走 Screen 的 `_loadMemoIntoEditor` 重置历史与滚动。
- `createNewMemo` 已会 `flushSave` 当前脏文档；复用空篇时不要再 `createNewMemo`。
- EventChannel 的 listen 必须在 `_isInitializing == false` 之后；`dispose` 时取消订阅。
- 非 Android：`AndroidProcessText` 不订阅，行为与现在一致。

## 未决事项

（无）
