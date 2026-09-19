import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mind_recall/core/debug/cursor_debug_hud.dart';
import 'package:mind_recall/core/debug/ime_debug_hud.dart';

/// Debug 专用左上角信息列表：IME / 光标等 HUD 均为列表元素。
///
/// 仅应在 [kDebugMode] 且对应子开关开启时挂载；UI 刷新限频。
class DebugInfoOverlay extends StatefulWidget {
  const DebugInfoOverlay({
    super.key,
    required this.showImeHud,
    required this.showCursorHud,
  });

  final bool showImeHud;
  final bool showCursorHud;

  @override
  State<DebugInfoOverlay> createState() => _DebugInfoOverlayState();
}

class _DebugInfoOverlayState extends State<DebugInfoOverlay> {
  static const _uiMinInterval = Duration(milliseconds: 80);
  static const _sectionGap = 6.0;

  ImeDebugSnapshot _ime = ImeDebugSnapshot.empty;
  CursorDebugSnapshot _cursor = CursorDebugSnapshot.empty;
  DateTime? _lastUiAt;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      _ime = imeDebugHud.value;
      _cursor = cursorDebugHud.value;
      imeDebugHud.addListener(_onHudChanged);
      cursorDebugHud.addListener(_onHudChanged);
      _listening = true;
    }
  }

  @override
  void dispose() {
    if (_listening) {
      imeDebugHud.removeListener(_onHudChanged);
      cursorDebugHud.removeListener(_onHudChanged);
    }
    super.dispose();
  }

  void _onHudChanged() {
    if (!mounted) {
      return;
    }
    final now = DateTime.now();
    final lastAt = _lastUiAt;
    final nextIme = imeDebugHud.value;
    final nextCursor = cursorDebugHud.value;
    final urgent = nextIme.committedLogical != _ime.committedLogical ||
        nextIme.toolbarLogical != _ime.toolbarLogical ||
        nextIme.settleActive != _ime.settleActive ||
        nextIme.lastCommitReason != _ime.lastCommitReason ||
        nextIme.scope != _ime.scope ||
        nextCursor.mode != _cursor.mode ||
        nextCursor.focused != _cursor.focused ||
        nextCursor.blockIndex != _cursor.blockIndex ||
        nextCursor.blockType != _cursor.blockType ||
        nextCursor.selectionBase != _cursor.selectionBase ||
        nextCursor.selectionExtent != _cursor.selectionExtent ||
        nextCursor.overlayHitTestActive != _cursor.overlayHitTestActive ||
        nextCursor.overlayInView != _cursor.overlayInView ||
        nextCursor.imeSessionFocused != _cursor.imeSessionFocused ||
        nextCursor.editorFocused != _cursor.editorFocused ||
        nextCursor.languageFocused != _cursor.languageFocused ||
        nextCursor.sameBlockTapDiscarded != _cursor.sameBlockTapDiscarded;
    if (!urgent &&
        lastAt != null &&
        now.difference(lastAt) < _uiMinInterval) {
      return;
    }
    _lastUiAt = now;
    setState(() {
      _ime = nextIme;
      _cursor = nextCursor;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode || (!widget.showImeHud && !widget.showCursorHud)) {
      return const SizedBox.shrink();
    }

    final items = <Widget>[];
    if (widget.showImeHud) {
      items.addAll(
        _lineItems(
          formatImeDebugHudLines(_ime),
          Colors.white,
        ),
      );
    }
    if (widget.showImeHud && widget.showCursorHud) {
      items.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: _sectionGap),
          child: Divider(height: 1, thickness: 1, color: Colors.white24),
        ),
      );
    }
    if (widget.showCursorHud) {
      items.addAll(
        _lineItems(
          formatCursorDebugHudLines(_cursor),
          Colors.lightGreenAccent,
        ),
      );
    }

    final top = MediaQuery.paddingOf(context).top + 4;
    return Positioned(
      top: top,
      left: 8,
      child: IgnorePointer(
        child: Material(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: items,
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _lineItems(List<String> lines, Color color) {
    return [
      for (final line in lines)
        Text(
          line,
          style: TextStyle(
            color: color,
            fontSize: 11,
            height: 1.25,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
    ];
  }
}
