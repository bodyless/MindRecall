import 'package:flutter/widgets.dart';

/// 比较两份 [MediaQueryData] 时忽略 [MediaQueryData.viewInsets]。
///
/// 本应用 `resizeToAvoidBottomInset: false` 且自行处理 IME 留白；键盘动画
/// 不应通过 Inherited MediaQuery 驱动整树重建。
bool mediaQueryDataEqualsIgnoringViewInsets(
  MediaQueryData a,
  MediaQueryData b,
) {
  return a.copyWith(viewInsets: EdgeInsets.zero) ==
      b.copyWith(viewInsets: EdgeInsets.zero);
}

/// 覆盖 textScaler，并向子树发布 **viewInsets=0** 的 MediaQuery。
///
/// 仅在尺寸/安全区/缩放等非键盘字段变化时 setState，避免 IME 动画每帧
/// 经 [MediaQuery.of] 重建 MaterialApp.builder 以下整棵子树。
class KeyboardStableMediaQuery extends StatefulWidget {
  const KeyboardStableMediaQuery({
    super.key,
    required this.textScale,
    required this.child,
  });

  final double textScale;
  final Widget child;

  @override
  State<KeyboardStableMediaQuery> createState() =>
      _KeyboardStableMediaQueryState();
}

class _KeyboardStableMediaQueryState extends State<KeyboardStableMediaQuery>
    with WidgetsBindingObserver {
  MediaQueryData? _data;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncFromView();
  }

  @override
  void didUpdateWidget(covariant KeyboardStableMediaQuery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.textScale != widget.textScale) {
      _syncFromView();
    }
  }

  @override
  void didChangeMetrics() {
    _syncFromView();
  }

  MediaQueryData _resolveData() {
    final fromView = MediaQueryData.fromView(View.of(context));
    return fromView.copyWith(
      textScaler: TextScaler.linear(widget.textScale),
      viewInsets: EdgeInsets.zero,
    );
  }

  void _syncFromView() {
    if (!mounted) {
      return;
    }
    final next = _resolveData();
    final prev = _data;
    if (prev != null && mediaQueryDataEqualsIgnoringViewInsets(prev, next)) {
      return;
    }
    setState(() => _data = next);
  }

  @override
  Widget build(BuildContext context) {
    final data = _data ?? _resolveData();
    return MediaQuery(
      data: data,
      child: widget.child,
    );
  }
}
