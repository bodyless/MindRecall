## 步骤 1：注册系统菜单项

- [x] 新建 `android/app/src/main/res/values/strings.xml`，加入 `process_text_label` 值为 `记录到笔记`；
- [x] 新建 `android/app/src/main/res/values-en/strings.xml`，加入同名 `process_text_label` 值为 `Save to Notes`；
- [x] 在 `android/app/src/main/AndroidManifest.xml` 的 `MainActivity` 之后增加 `activity-alias`，`android:name` 为 `.ProcessTextAlias`，`android:targetActivity` 为 `.MainActivity`，`android:exported` 为 `true`，`android:label` 为 `@string/process_text_label`；
- [x] 该 alias 的 `intent-filter` 含 `android.intent.action.PROCESS_TEXT`、`android.intent.category.DEFAULT`、`data android:mimeType="text/plain"`；
- [x] 不修改 `application` / `MainActivity` 的 `android:label`，不修改现有 `<queries>` 块；

## 步骤 2：Native 取出选区并推给 Dart

- [x] 在 `android/app/src/main/java/com/wishtech/mind_recall/MainActivity.java` 增加 EventChannel，名称为 `com.wishtech.mind_recall/process_text`，在现有 `configureFlutterEngine` 里与存储 `MethodChannel` 一并注册；
- [x] 在 `MainActivity` 增加 pending 文本字段与 `EventChannel.EventSink` 字段，实现 `StreamHandler`：`onListen` 保存 sink 并把 pending 非空时 `success` 后清空 pending，`onCancel` 将 sink 置空；
- [x] 在 `MainActivity` 增加 `offerProcessTextFrom(Intent)`：用 `Intent.EXTRA_PROCESS_TEXT` 取 `CharSequence`，trim 后为空则 return；否则写入 pending、对该 Intent `removeExtra`，若 sink 非空则立刻 `success` 并清空 pending；
- [x] 在 `configureFlutterEngine` 末尾调用 `offerProcessTextFrom(getIntent())`（冷启动）；
- [x] 覆盖 `onNewIntent`：先 `super.onNewIntent`，再 `setIntent(intent)`，再 `offerProcessTextFrom(intent)`（热启动、`singleTop` 复用实例）；
- [x] `offerProcessTextFrom` 与 `onNewIntent` 均不得 `setResult`、不得 `finish()`；

## 步骤 3：Dart 通道与纯函数

- [x] 新建 `lib/services/process_text_capture.dart`，提供顶层函数 `normalizeCapturedProcessText(String? raw)`：null 或 trim 后为空返回 null，否则返回 trim 后的字符串；
- [x] 同文件提供顶层函数 `shouldReuseEmptyActiveMemo`，参数为当前标题与正文，两者 trim 后都为空则返回 true；
- [x] 新建 `lib/services/android_process_text.dart`，用 EventChannel `com.wishtech.mind_recall/process_text` 暴露 `Stream<String> events()`；非 Android 返回空 Stream，且不建立订阅；

## 步骤 4：工作区写入笔记

- [x] 在 `lib/features/memo/editor/memo_workspace_controller.dart` 的 `MemoWorkspaceController` 增加 `captureTextAsMemo(String text)`：入参视为已 normalize；若 `shouldReuseEmptyActiveMemo` 对当前 `titleController` / `contentController` 为 true 且 `activeMemoId != null` 则不调用 `createNewMemo`，否则调用现有 `createNewMemo`；
- [x] `captureTextAsMemo` 将 `contentController.text` 设为入参、标题保持空字符串，然后 `flushSave`，返回当前活动 `Memo`（必要时用 `memoById` / `loadMemo`）；
- [x] 复用空篇时禁止再 `createMemo`，以免冷启动空库留下第二篇空笔记；

## 步骤 5：编辑器在初始化之后消费

- [x] 在 `lib/features/memo/editor/memo_editor_screen.dart` 的 `_MemoEditorScreenState` 增加 EventChannel 订阅字段，以及串行锁（`Future` 链或 bool）防止两条文本并行各建一篇交错保存；
- [x] 在 `_initializeWorkspace` 的 `finally` 里、`_isInitializing = false` 之后调用订阅方法（仅此时开始 `AndroidProcessText.events()` listen）；
- [x] 订阅回调：`normalizeCapturedProcessText` 为 null 则忽略；否则 `_suppressAutoSave` 为 true，若当前为实时模式则先 `LiveMarkdownEditorState.flushToParent()`，再 `await _workspace.captureTextAsMemo`，成功后 `_loadMemoIntoEditor`、请求正文焦点、`_closeDrawerIfNeeded`，`finally` 恢复 `_suppressAutoSave`；
- [x] 在 `dispose` 中取消该订阅；
- [x] 不在 `main.dart` / `MindRecallApp` 提前订阅，避免工作区未就绪时丢事件或抢跑；

## 步骤 6：测试与文档

- [x] 新建 `test/process_text_capture_test.dart`，覆盖 `normalizeCapturedProcessText` 对 null、空白、首尾空白文本的行为，以及 `shouldReuseEmptyActiveMemo` 的空/非空标题或正文；
- [x] 在 `test/memo_workspace_controller_test.dart` 增加用例：活动笔记为空时 `captureTextAsMemo` 不新增 store 条目只更新正文；已有非空活动笔记时会 `createMemo` 并保存正文、标题为空；
- [x] 在 `README.md`「功能概览」增加一条 Android 选区菜单「记录到笔记」的说明（冷/热启动、不改写源 App 文本）；
- [x] 在 `README.md` 目录结构的 `services/` 下列出 `process_text_capture.dart` 与 `android_process_text.dart`；
- [x] 执行 `.\scripts\run_unit_tests.ps1`，非 0 退出则改到通过；
