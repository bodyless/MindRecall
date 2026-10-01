## 目标

从侧栏文件列表上方「＋」菜单单选导入一个外部 `.txt` 或 `.md`：拷贝到当前目录、分配新的时间戳 id、扩展名仍是 txt 或 md、以 UTF-8 保存，并打开这一篇。单独成行的本地图片拷进该笔记的 `{id}_assets/`；某张图失败不影响这篇文档导入。

## 方案

- 菜单新增「导入文档」。选文件前挂起编辑器焦点，用已有 `FilePicker` 单选 `txt`/`md`。取消则什么都不写。
- 读原始字节，不走 `readAsString`。`decodeImportedTextBytes`：严格 UTF-8 成功则去掉开头 U+FEFF；否则用 `enough_convert` 的 `GbkCodec(allowInvalid: false)`；再失败则提示且不创建文件。
- `MemoStorageService.importExternalMemo` 用 `allocateUniqueId` 写到 `currentRelativeDir` 下的 `{id}.txt` 或 `{id}.md`（扩展名小写）。不调用 `createMemo` / `updateMemo`。侧栏标题仍由现有 `_parseMemoContent` 在读取时决定。
- 单独成行的 `![说明](./a.png "标题")` 由 `parseStandaloneImageLine` 拆出路径与双引号标题。本地路径相对源文件所在目录解析，拷贝逻辑复用 `{id}_assets/` 与去重文件名；写回 `./{id}_assets/文件名`，非空标题仍留在括号里。`ImageBlock.title` 与 `toMarkdown` 必须记住标题，避免一进实时模式就被 `serializeMdBlocks` 拼回「路径加标题」的坏 src。
- `http` / `https` 不拷贝。图不存在或单张拷贝失败：保留该行原文。正文最终写入失败时删掉本次已创建的 `{id}_assets` 和半成品文件。
- 成功后走与新建文件相同的打开路径：`flushSave`、写入编辑器、`refreshList`、聚焦。不另做冷启动或外部 Intent。

## 已决事项

- 新分配 id，外部文件名不当 id。
- 保留 txt 或 md；应用内「新建文件」仍只创建 `.md`。写入时扩展名用小写，以便现有 `_memoExtensions` 能列出。
- 标题沿用 `_parseMemoContent`（第 2 行为空才把第 1 行当标题），导入不重排正文。
- 一次只选一个文件；成功后打开刚导入的那一篇。
- 编码：UTF-8 优先，否则 GBK，再失败则报错且不写入。保存结果一律是 UTF-8。
- 文内单独成行的本地图拷进 `{id}_assets/`。缺图或单张拷贝失败仍导入该文档，该行保持原链接。
- 支持 `![说明](./a.png "标题")`：拆出路径再拷，写回仍带双引号标题。不另做单引号标题、尖括号路径、段落中的行内图片；这些行拆不开就按拷贝失败保留原文。
- 不在界面上展示图片标题。

## 关注点

- 块间距看的是路径字段。`src` 若仍含 ` "标题"`，预览会找不到已拷好的文件。
- 展示用的 `MemoImageService._resolvePath` 会拒绝笔记目录之外的路径，不能用来解析导入源图。
- `createMemo` 会写成空的 `.md`。`updateMemo` 会按标题规则重写文件。导入都不要走这两条。
- 「＋」菜单的 `onSelected` 会先恢复焦点。系统选文件对话框必须再次 `_suspendEditorFocus`，不能只靠菜单打开时的那一次。
- 搜索进行中不额外退出搜索，与 `createNewMemo` 相同。
- 编码失败必须发生在分配 id 和创建资源目录之前。

## 未决事项

- （无）
