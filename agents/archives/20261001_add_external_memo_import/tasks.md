## 步骤 1：导入文本编码

- [x] 在 pubspec.yaml 的 dependencies 加入 enough_convert，版本交给 pub 解析，不手写猜测版本；
- [x] 在 lib/services/imported_text_codec.dart 新增 decodeImportedTextBytes：先 utf8.decode 且 allowMalformed 为 false，成功则去掉开头的 U+FEFF；失败则用 GbkCodec(allowInvalid: false)；再失败抛 FormatException，且此时尚未创建笔记文件；
- [x] 在 test/imported_text_codec_test.dart 覆盖普通 UTF-8、带 BOM 的 UTF-8、GBK 中文解码，以及非法字节抛错；

## 步骤 2：带标题的图片行

- [x] 在 lib/core/markdown/parser/md_syntax_patterns.dart 新增 parseStandaloneImageLine 与 formatStandaloneImageLine，只识别单独成行的 `![alt](destination)` 与双引号形式 `![alt](destination "title")`；
- [x] 在 lib/core/markdown/ast/md_block.dart 的 ImageBlock 增加可选 title，copyWithId 与 copyWithPlainText 保留 title，toMarkdown 改为调用 formatStandaloneImageLine，空标题不写引号；
- [x] 在 lib/core/markdown/parser/markdown_block_parser.dart 创建 ImageBlock 时改用 parseStandaloneImageLine，src 只保存路径；
- [x] 在 test/markdown_block_ast_test.dart 断言 `![说明](./a.png "标题")` 的 src 为 `./a.png`、title 为 `标题`，且 serializeMdBlocks 写回仍带该标题；无标题图片的往返结果保持不变；

## 步骤 3：拷贝图片并写入笔记

- [x] 在 lib/services/memo_image_service.dart 新增导入改写：本地路径相对源文件所在目录解析并拷入 `{memoId}_assets/`，同一次导入按源绝对路径去重；http 与 https 原样保留；文件不存在或单张拷贝失败则保留该行；改写使用 formatStandaloneImageLine；禁止用 _resolvePath 限制源图必须位于笔记目录内；
- [x] 在 lib/services/memo_storage_service.dart 新增 importExternalMemo：先 decodeImportedTextBytes，扩展名仅接受 .txt 与 .md 并写成小写，再用 allocateUniqueId 写入 relativeParent；禁止调用 createMemo 与 updateMemo；正文写入失败时删除已创建的 `{id}_assets` 和半成品文件；成功返回 _memoFromFile；
- [x] 在 test/memo_storage_service_test.dart 用临时目录断言：txt 仍为 .txt 且 id 不是原文件名、带标题的本地图进入 `{id}_assets` 且链接已改写、缺失图片的那一行保持不变、https 行不变、非法编码不会留下文件；

## 步骤 4：侧栏入口

- [x] 在 MemoWorkspaceStore、DiskMemoWorkspaceStore 以及 test/memo_workspace_controller_test.dart 的 _FakeStore 增加 importExternalMemo，磁盘实现接到 MemoStorageService.importExternalMemo；
- [x] 在 MemoWorkspaceController 新增 importExternalMemo：先 flushSave，用 currentRelativeDir 调用存储，再 applyMemoToEditors 与 refreshList，且不清除搜索；
- [x] 在 lib/features/memo/sidebar/memo_file_panel.dart 的 _CreateAction 增加导入项，菜单显示新的 l10n 文案，选中后调用新回调；
- [x] 在 lib/features/memo/editor/memo_editor_screen.dart 把该回调接到 _buildFilePanel；导入方法在 FilePicker 前后调用 _suspendEditorFocus 与 _resumeEditorFocus，单选且 allowedExtensions 仅为 txt 与 md，取消则返回；成功后按 _createNewMemo 同样打开并聚焦；编码失败显示 importEncodingUnsupported，其它失败显示已有 importFailed；
- [x] 在 lib/l10n/app_zh.arb 与 app_en.arb 增加 importDocument 与 importEncodingUnsupported，并同步 lib/l10n/app_localizations.dart、app_localizations_zh.dart、app_localizations_en.dart；
- [x] 在 README.md 写明侧栏「＋」可导入 txt 与 md（新 id、保留 txt 或 md、打开新篇、本地图拷入资源目录、缺图不阻断、UTF-8 优先否则 GBK），并在 file_picker 说明中补上导入文档；
