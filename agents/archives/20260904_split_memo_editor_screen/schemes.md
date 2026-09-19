## 目标

把 `memo_editor_screen.dart` 里低风险私有 Widget 与中风险工作区/编辑 IME 拆出，壳层只保留三模式切换与焦点/抽屉协调。

## 方案

先原样搬家 Dialog、贴键盘工具栏、共用 `ImeMetricsObserver`；再抽 `MemoWorkspaceController` 接管列表/保存/搜索/备份回收站；最后抽 `EditImeCoordinator` 复用已有 settle 决策。不拆 `_buildEditorContent`、`_suspendEditorFocus` 与 `LiveMarkdownEditor` 内部 IME。

## 已决事项

- （无）

## 关注点

- （无）

## 未决事项

- （无）
