/// 实时块类型切换 / 点击定位的 Timeline 与 log 纯函数（仅 debug 调用方使用）。

/// `Live.applyBlockType` 的 Timeline arguments。
Map<String, String> liveApplyBlockTypeArgs({
  required String from,
  required String to,
  required bool layoutChanged,
  required bool didSetState,
}) {
  return <String, String>{
    'from': from,
    'to': to,
    'layoutChanged': '$layoutChanged',
    'didSetState': '$didSetState',
  };
}

/// Overlay / 槽点击诊断字段；与屏上 Cursor HUD overlay 行一致。
Map<String, String> liveTapDebugFields({
  required String phase,
  required bool overlayHit,
  required bool overlayInView,
  required bool imeSessionFocused,
  required bool editorFocused,
  required bool languageFocused,
  required bool sameBlockTapDiscarded,
  String? path,
  String? pending,
  bool? canFocus,
  bool? hasFocus,
}) {
  return <String, String>{
    'phase': phase,
    'ovHit': overlayHit ? '1' : '0',
    'ovView': overlayInView ? '1' : '0',
    'imeF': imeSessionFocused ? '1' : '0',
    'edF': editorFocused ? '1' : '0',
    'langF': languageFocused ? '1' : '0',
    'sameTap': sameBlockTapDiscarded ? '1' : '0',
    if (path != null) 'path': path,
    if (pending != null) 'pending': pending,
    if (canFocus != null) 'canFocus': canFocus ? '1' : '0',
    if (hasFocus != null) 'hasFocus': hasFocus ? '1' : '0',
  };
}

/// 拼 `[LiveTap]` 一行，供 logcat 与单测。
String formatLiveTapDebugLog({
  required String phase,
  required bool overlayHit,
  required bool overlayInView,
  required bool imeSessionFocused,
  required bool editorFocused,
  required bool languageFocused,
  required bool sameBlockTapDiscarded,
  String? path,
  String? pending,
  bool? canFocus,
  bool? hasFocus,
}) {
  final fields = liveTapDebugFields(
    phase: phase,
    overlayHit: overlayHit,
    overlayInView: overlayInView,
    imeSessionFocused: imeSessionFocused,
    editorFocused: editorFocused,
    languageFocused: languageFocused,
    sameBlockTapDiscarded: sameBlockTapDiscarded,
    path: path,
    pending: pending,
    canFocus: canFocus,
    hasFocus: hasFocus,
  );
  final pairs = fields.entries.map((e) => '${e.key}=${e.value}').join(' ');
  return '[LiveTap] $pairs';
}
