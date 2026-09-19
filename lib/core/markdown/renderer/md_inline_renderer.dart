import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../ast/md_inline.dart';
import 'md_block_styles.dart';

/// 将 [MdInline] 节点渲染为带样式的 rich text。
class MdInlineText extends StatelessWidget {
  const MdInlineText({
    super.key,
    required String markdown,
    this.style,
    this.onLinkTap,
    this.resolveLinkLabel,
  })  : _markdown = markdown,
        _inlines = null;

  const MdInlineText.fromNodes({
    super.key,
    required List<MdInline> inlines,
    this.style,
    this.onLinkTap,
    this.resolveLinkLabel,
  })  : _markdown = null,
        _inlines = inlines;

  final String? _markdown;
  final List<MdInline>? _inlines;
  final TextStyle? style;

  /// 点击链接时回调（网页或本地文档）。
  final ValueChanged<String>? onLinkTap;

  /// 将本地链接 href 解析为文档标题；仅当 markdown 标签仍是路径/href 时用于展示。
  final String? Function(String href)? resolveLinkLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inherited = DefaultTextStyle.of(context).style;
    final base = inherited.merge(style ?? theme.textTheme.bodyLarge);
    final inlines = _inlines ?? parseInlineMarkdown(_markdown ?? '');

    return Text.rich(
      TextSpan(
        style: base,
        children: _InlineSpanBuilder(
          base: base,
          theme: theme,
          onLinkTap: onLinkTap,
          resolveLinkLabel: resolveLinkLabel,
        ).build(inlines),
      ),
      strutStyle: MdBlockStyles.strutFor(base),
    );
  }
}

class _InlineSpanBuilder {
  const _InlineSpanBuilder({
    required this.base,
    required this.theme,
    this.onLinkTap,
    this.resolveLinkLabel,
  });

  final TextStyle base;
  final ThemeData theme;
  final ValueChanged<String>? onLinkTap;
  final String? Function(String href)? resolveLinkLabel;

  List<InlineSpan> build(List<MdInline> inlines) {
    final spans = <InlineSpan>[];
    for (final inline in inlines) {
      spans.add(_spanFor(inline, base));
    }
    if (spans.isEmpty) {
      spans.add(const TextSpan(text: ''));
    }
    return spans;
  }

  InlineSpan _spanFor(MdInline inline, TextStyle current) {
    switch (inline) {
      case TextInline(:final text):
        return TextSpan(text: text, style: current);
      case BoldInline(:final children):
        // 中文字体粗体偏弱：用字重 + 极轻描边增强；不加 letterSpacing，
        // 否则与透明 TextField 的字形宽度不一致，光标会看起来「悬」在字后空白处。
        final boldColor = theme.colorScheme.onSurface;
        final boldStyle = current.merge(
          TextStyle(
            fontWeight: FontWeight.w800,
            color: boldColor,
            height: current.height,
            shadows: [
              Shadow(
                color: boldColor.withValues(alpha: 0.22),
                offset: const Offset(0.3, 0),
                blurRadius: 0,
              ),
              Shadow(
                color: boldColor.withValues(alpha: 0.18),
                offset: const Offset(-0.15, 0),
                blurRadius: 0,
              ),
            ],
          ),
        );
        return _styledSpan(children, boldStyle);
      case ItalicInline(:final children):
        final italicStyle = current.merge(
          const TextStyle(fontStyle: FontStyle.italic),
        );
        return _styledSpan(children, italicStyle);
      case StrikeInline(:final children):
        final strikeStyle = current.merge(
          TextStyle(
            decoration: TextDecoration.lineThrough,
            decorationColor: current.color,
          ),
        );
        return _styledSpan(children, strikeStyle);
      case CodeInline(:final text):
        return TextSpan(
          text: text,
          style: current.merge(
            TextStyle(
              fontFamily: 'monospace',
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        );
      case LinkInline(:final label, :final href):
        final display = linkDisplayLabel(
          label: label,
          href: href,
          resolvedTitle: resolveLinkLabel?.call(href),
        );
        final linkStyle = current.merge(
          TextStyle(
            color: theme.colorScheme.primary,
            decoration: TextDecoration.underline,
            decorationColor: theme.colorScheme.primary,
          ),
        );
        final handler = onLinkTap;
        if (handler == null) {
          return TextSpan(text: display, style: linkStyle);
        }
        return TextSpan(
          text: display,
          style: linkStyle,
          recognizer: TapGestureRecognizer()..onTap = () => handler(href),
        );
    }
  }

  InlineSpan _styledSpan(List<MdInline> children, TextStyle style) {
    if (_isPlainChildren(children)) {
      return TextSpan(
        text: plainTextFromInlines(children),
        style: style,
      );
    }

    return TextSpan(
      style: style,
      children: [
        for (final child in children) _spanFor(child, style),
      ],
    );
  }

  bool _isPlainChildren(List<MdInline> children) {
    return children.every((child) => child is TextInline);
  }
}
