## 目标

实时模式在活动块已聚焦、IME 仍打开时，手指按在该块文字上也能上下拖动整篇列表，不必先点空白或先收键盘。单击一次即按落点出现光标，不要变成要点两下。选区仍走长按与水滴手柄。

## 方案

- 根因：活动块 Overlay 与 `CustomScrollView` 是 `Stack` 兄弟。聚焦时 Overlay 透明 `TextField` 先命中，列表进不了手势竞技场；`NeverScrollableScrollPhysics` 只禁止块内自滚，并不转发外层滚动。
- 在 Overlay **块高命中区**（现有 `Align`/`heightFactor: 1.0` 内、`IgnorePointer` 之内）为垂直拖增加识别器，用 `widget.scrollController.position.drag` 把 start/update/end/cancel 转发给列表，保留惯性。不 `unfocus`、不清 `_activeBlockId`、不把 Overlay 塞进列表槽。
- 外层只挂垂直拖回调，**禁止**再挂 `onTap` / `onPanUpdate`。单击仍走现有 `MdBlockEditorField` / `TextField`（Android 为抬手 `selectPosition`）。垂直拖超过阈值后本次点按作废，光标保持拖之前的位置。
- 失焦 Overlay 仍 `liveOverlayIgnoresPointers` → `IgnorePointer`，与 2026-08-29 一致。chromeless `scrollPhysics: NeverScrollableScrollPhysics()` 保留。活动槽 `InkWell` 不随焦点拆掉。

## 已决事项

- IME 开着、光标还在块里，也要能上下拖列表。
- 不收键盘、不 `unfocus`、不清 `_activeBlockId`、不把 Overlay 改成列表子节点。
- 单击一次即按落点设光标（沿用现有 `TextField` 单击路径）；禁止外层抢单击导致要点第二次。
- 按住上下拖 = 滚列表；选字走长按和水滴。拖动手势不把光标改到拖完后手指底下的字。

## 关注点

- Overlay 必须留在 `Stack` 里那一个持久 `MdBlockEditorField`（`live-active-editor`）；虚拟化列表会销毁槽位，塞进去会拆 IME。
- 垂直拖转发层必须包在 `IgnorePointer` **里面**、且只覆盖活动块内容（不要包满屏 `LayoutBuilder`），否则失焦可拖与点其它块会回退。
- 用户手指拖列表时不要调用 `_scrollActiveBlockIntoView`，否则会把活动块拽回视口，对抗用户滚动。
- 2026-08-29 / 2026-08-29 ANR：禁止靠清活动块换滚动；禁止随焦点拆 `InkWell`。
- 单测宿主默认可能是桌面 `TapAndPan`；用例须按 Android 手势（`debugDefaultTargetPlatformOverride = TargetPlatform.android` 并在 tearDown 清掉），才能断言「垂直拖给列表、单击仍落光标」。
- 桌面 `TapAndPan` 会和垂直拖抢竞技场：外层垂直拖在纵向超过 slop 后须 `accepted` 赢下，不要为此改架构。
- `position.drag` 的 `Drag` 须在 `dispose` / `onVerticalDragCancel` 里 cancel，避免控制器已分离仍回调。

## 未决事项

- （无）
