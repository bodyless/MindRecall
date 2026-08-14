import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ast/md_block.dart';
import '../block_ops.dart';
import '../renderer/markdown_image_resolver.dart';
import '../renderer/md_block_chrome.dart';
import '../renderer/md_block_renderer.dart';
import '../renderer/md_block_styles.dart';
import '../renderer/md_inline_renderer.dart';

/// 实时模式活动块的 [TextField]，可选 styled 透明叠加层。
///
/// 块内存储行内 markdown（如 `**bold**`），输入框显示 plain text；
/// 有格式时用透明 [TextField] 叠在 [MdInlineText] 上实现 WYSIWYG。
class MdBlockEditorField extends StatefulWidget {
  const MdBlockEditorField({
    super.key,
    required this.block,
    required this.controller,
    required this.focusNode,
    required this.onSplitBlockAt,
    this.onPasteMarkdown,
    this.resolveLocalImage,
    this.onLinkTap,
    this.resolveLinkLabel,
    this.chromeless = false,
  });

  final MdBlock block;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<int> onSplitBlockAt;

  /// 粘贴含换行的 Markdown 时回调（已规范化前的原始插入串）。
  final ValueChanged<String>? onPasteMarkdown;
  final MarkdownImageResolver? resolveLocalImage;
  final ValueChanged<String>? onLinkTap;
  final String? Function(String href)? resolveLinkLabel;

  /// 实时 Overlay 模式：不重复渲染列表/引用等块级装饰，仅保留与渲染层对齐的输入框。
  final bool chromeless;

  @override
  State<MdBlockEditorField> createState() => _MdBlockEditorFieldState();
}

class _MdBlockEditorFieldState extends State<MdBlockEditorField> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        return _MdBlockEditorFieldBody(
          block: widget.block,
          controller: widget.controller,
          focusNode: widget.focusNode,
          onSplitBlockAt: widget.onSplitBlockAt,
          onPasteMarkdown: widget.onPasteMarkdown,
          resolveLocalImage: widget.resolveLocalImage,
          onLinkTap: widget.onLinkTap,
          resolveLinkLabel: widget.resolveLinkLabel,
          chromeless: widget.chromeless,
        );
      },
    );
  }
}

class _MdBlockEditorFieldBody extends StatelessWidget {
  const _MdBlockEditorFieldBody({
    required this.block,
    required this.controller,
    required this.focusNode,
    required this.onSplitBlockAt,
    this.onPasteMarkdown,
    this.resolveLocalImage,
    this.onLinkTap,
    this.resolveLinkLabel,
    this.chromeless = false,
  });

  final MdBlock block;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<int> onSplitBlockAt;
  final ValueChanged<String>? onPasteMarkdown;
  final MarkdownImageResolver? resolveLocalImage;
  final ValueChanged<String>? onLinkTap;
  final String? Function(String href)? resolveLinkLabel;
  final bool chromeless;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cursorColor = theme.colorScheme.primary;
    final singleLine = isSingleLineBlock(block);
    final splitOnEnter = block is ParagraphBlock;

    InputDecoration decoration({String? hint, TextStyle? hintStyle}) {
      return InputDecoration(
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        filled: false,
        fillColor: Colors.transparent,
        isDense: true,
        contentPadding: EdgeInsets.zero,
        hintText: hint,
        hintStyle: hintStyle,
      );
    }

    InputDecoration overlayDecoration(InputDecoration base) {
      return base.copyWith(
        filled: false,
        fillColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        hintStyle: base.hintStyle?.copyWith(color: Colors.transparent),
      );
    }

    Widget field({
      required TextStyle? style,
      InputDecoration? fieldDecoration,
      Widget? styledOverlay,
      bool styledEditing = false,
    }) {
      final resolvedStyle =
          style ?? theme.textTheme.bodyLarge ?? const TextStyle();
      final strutStyle = MdBlockStyles.strutFor(resolvedStyle);
      final expectedPlain = supportsInlineFormatting(block)
          ? editableTextForBlock(block)
          : controller.text;
      final overlayReady = styledEditing &&
          styledOverlay != null &&
          expectedPlain.isNotEmpty &&
          controller.text == expectedPlain;

      final textField = TextField(
        controller: controller,
        focusNode: focusNode,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        showCursor: true,
        cursorColor: cursorColor,
        minLines: 1,
        strutStyle: strutStyle,
        scrollPadding: EdgeInsets.zero,
        style: overlayReady
            ? resolvedStyle.copyWith(
                color: Colors.transparent,
                decoration: TextDecoration.none,
                decorationColor: Colors.transparent,
              )
            : resolvedStyle,
        decoration: overlayReady
            ? overlayDecoration(fieldDecoration ?? decoration())
            : fieldDecoration,
        inputFormatters: [
          // 标题/列表/引用：Enter 在下方插入段落；段落：Enter 在光标处拆块。
          // 含换行的粘贴走 onPasteMarkdown，避免被 Enter 逻辑吞掉。
          if (singleLine || splitOnEnter)
            _NewBlockEnterFormatter(
              onSplitBlockAt: onSplitBlockAt,
              onPasteMarkdown: onPasteMarkdown,
            ),
        ],
      );

      final compactFieldTheme = theme.copyWith(
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          contentPadding: EdgeInsets.zero,
          isDense: true,
          filled: false,
          fillColor: Colors.transparent,
        ),
      );

      final themedField = Theme(
        data: compactFieldTheme,
        child: textField,
      );

      // 始终用 Stack 包裹，避免有/无行内格式切换时 TextField 重挂载失焦。
      return Stack(
        alignment: Alignment.topLeft,
        children: [
          SizedBox(
            width: double.infinity,
            child: IgnorePointer(
              child: overlayReady
                  ? styledOverlay as Widget
                  : const SizedBox.shrink(),
            ),
          ),
          themedField,
        ],
      );
    }

    final expectedPlain = supportsInlineFormatting(block)
        ? editableTextForBlock(block)
        : controller.text;
    final styledEditing = hasRenderedInlineFormatting(block) &&
        expectedPlain.isNotEmpty &&
        controller.text == expectedPlain;
    final styledOverlay =
        styledEditing ? _inlinePreviewForBlock(block, theme) : null;

    if (chromeless) {
      return _buildChromelessField(
        theme: theme,
        cursorColor: cursorColor,
        singleLine: singleLine,
        splitOnEnter: splitOnEnter,
      );
    }

    return switch (block) {
      HeadingBlock(:final level) => field(
          style: MdBlockStyles.headingStyle(theme, level),
          styledEditing: styledEditing,
          styledOverlay: styledOverlay,
          fieldDecoration: decoration(
            hint: '标题',
            hintStyle: MdBlockStyles.headingStyle(theme, level)?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ),
        ),
      BulletBlock() || OrderedBlock() => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MdBlockChrome.buildPrefix(
              block,
              theme.textTheme.bodyLarge,
              visible: true,
            ),
            Expanded(
              child: field(
                style: theme.textTheme.bodyLarge,
                styledEditing: styledEditing,
                styledOverlay: styledOverlay,
              ),
            ),
          ],
        ),
      QuoteBlock() => DecoratedBox(
          decoration: MdBlockStyles.quoteDecoration(theme),
          child: Padding(
            padding: MdBlockChrome.quoteBodyPadding(),
            child: field(
              style: MdBlockStyles.quoteTextStyle(theme),
              styledEditing: styledEditing,
              styledOverlay: styledOverlay,
            ),
          ),
        ),
      CodeBlock() => Container(
          width: double.infinity,
          padding: MdBlockChrome.codeBlockPadding(),
          decoration: MdBlockStyles.codeBlockDecoration(theme),
          child: field(
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
            ),
          ),
        ),
      ImageBlock() => MdBlockRenderer(
          block: block,
          resolveLocalImage: resolveLocalImage,
        ),
      ParagraphBlock() => field(
          style: theme.textTheme.bodyLarge,
          styledEditing: styledEditing,
          styledOverlay: styledOverlay,
          fieldDecoration: decoration(
            hint: '开始输入…',
            hintStyle: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ),
        ),
    };
  }

  Widget _buildChromelessField({
    required ThemeData theme,
    required Color cursorColor,
    required bool singleLine,
    required bool splitOnEnter,
  }) {
    final textStyle = switch (block) {
      HeadingBlock(:final level) => MdBlockStyles.headingStyle(theme, level),
      QuoteBlock() => MdBlockStyles.quoteTextStyle(theme),
      CodeBlock() =>
        theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
      _ => theme.textTheme.bodyLarge,
    };
    final resolvedStyle =
        textStyle ?? theme.textTheme.bodyLarge ?? const TextStyle();
    final strutStyle = MdBlockStyles.strutFor(resolvedStyle);

    // 列表层已绘制正文；此处只放透明 TextField + 与渲染层等宽的不可见前缀占位。
    // 列表层已绘制正文；系统光标按 TextField 度量会与 MdInlineText 错位，
    // 由 Live 层按渲染层实测位置绘制光标（showCursor: false）。
    final textField = TextField(
      controller: controller,
      focusNode: focusNode,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      showCursor: false,
      cursorColor: cursorColor,
      minLines: 1,
      strutStyle: strutStyle,
      scrollPadding: EdgeInsets.zero,
      scrollPhysics: const NeverScrollableScrollPhysics(),
      style: resolvedStyle.copyWith(
        color: Colors.transparent,
        decoration: TextDecoration.none,
        decorationColor: Colors.transparent,
      ),
      decoration: const InputDecoration(
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
        isCollapsed: true,
      ),
      inputFormatters: [
        if (singleLine || splitOnEnter)
          _NewBlockEnterFormatter(
            onSplitBlockAt: onSplitBlockAt,
            onPasteMarkdown: onPasteMarkdown,
          ),
      ],
    );

    final compactFieldTheme = theme.copyWith(
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        contentPadding: EdgeInsets.zero,
        isDense: true,
        filled: false,
        fillColor: Colors.transparent,
      ),
    );

    final input = Theme(data: compactFieldTheme, child: textField);

    // 前缀占位：始终用 Row + Expanded 包住 TextField，避免列表↔标题等换型时
    // TextField 重挂载导致焦点/IME 被系统收起。几何须与 [MdBlockChrome] / 渲染层一致。
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MdBlockChrome.buildPrefix(
          block,
          theme.textTheme.bodyLarge,
          visible: false,
        ),
        Expanded(
          child: Padding(
            padding: MdBlockChrome.chromelessBodyPadding(block),
            child: input,
          ),
        ),
      ],
    );
  }

  Widget _inlinePreviewForBlock(MdBlock block, ThemeData theme) {
    return switch (block) {
      HeadingBlock(:final level, :final text) => MdInlineText(
          markdown: text,
          style: MdBlockStyles.headingStyle(theme, level),
          onLinkTap: onLinkTap,
          resolveLinkLabel: resolveLinkLabel,
        ),
      BulletBlock(:final text) ||
      OrderedBlock(:final text) ||
      ParagraphBlock(:final text) =>
        MdInlineText(
          markdown: text,
          style: theme.textTheme.bodyLarge,
          onLinkTap: onLinkTap,
          resolveLinkLabel: resolveLinkLabel,
        ),
      QuoteBlock(:final text) => MdInlineText(
          markdown: text,
          style: MdBlockStyles.quoteTextStyle(theme),
          onLinkTap: onLinkTap,
          resolveLinkLabel: resolveLinkLabel,
        ),
      _ => MdBlockRenderer(
          block: block,
          resolveLocalImage: resolveLocalImage,
          onLinkTap: onLinkTap,
          resolveLinkLabel: resolveLinkLabel,
        ),
    };
  }
}

class _NewBlockEnterFormatter extends TextInputFormatter {
  const _NewBlockEnterFormatter({
    required this.onSplitBlockAt,
    this.onPasteMarkdown,
  });

  final ValueChanged<int> onSplitBlockAt;
  final ValueChanged<String>? onPasteMarkdown;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.text.contains('\n')) {
      return newValue;
    }

    final inserted = _insertedText(oldValue, newValue);
    // 多行粘贴：插入串含换行且不只是单次 Enter。
    // 注意：单独的 `\n` 也 contains('\n')，若误走粘贴则段落 Enter 失效
    // （列表等单行块由 Focus.onKeyEvent 处理，故仍正常）。
    if (isMultilinePasteInsertion(inserted) && onPasteMarkdown != null) {
      final pasted = inserted!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onPasteMarkdown!(pasted);
      });
      return oldValue;
    }

    // 单次 Enter：在旧光标处拆块。
    final cursor = oldValue.selection.start.clamp(0, oldValue.text.length);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onSplitBlockAt(cursor);
    });
    return oldValue;
  }
}

/// 插入串是否应视为「粘贴含换行」而非单次 Enter。
///
/// 单独的 `\n` / `\r\n` / `\r` 是 Enter；带其它字符或多行才是粘贴。
bool isMultilinePasteInsertion(String? inserted) {
  if (inserted == null ||
      (!inserted.contains('\n') && !inserted.contains('\r'))) {
    return false;
  }
  final normalized =
      inserted.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  return normalized != '\n';
}

/// 从 old→new 推断插入的文本；无法可靠推断时返回 null。
String? _insertedText(TextEditingValue oldValue, TextEditingValue newValue) {
  final oldText = oldValue.text;
  final newText = newValue.text;
  if (newText.length <= oldText.length) {
    return null;
  }
  final oldSel = oldValue.selection;
  if (!oldSel.isValid) {
    return null;
  }
  final start = oldSel.start.clamp(0, oldText.length);
  final end = oldSel.end.clamp(0, oldText.length);
  final replacedLength = end - start;
  final insertedLength = newText.length - oldText.length + replacedLength;
  if (insertedLength <= 0) {
    return null;
  }
  final insertStart = start;
  final insertEnd = insertStart + insertedLength;
  if (insertEnd > newText.length) {
    return null;
  }
  // 校验：去掉插入段后应等于把选区删掉后的 old。
  final before = oldText.substring(0, start);
  final after = oldText.substring(end);
  final withoutInsert =
      newText.substring(0, insertStart) + newText.substring(insertEnd);
  if (withoutInsert != before + after) {
    // 回退：若整段变长且前缀/后缀匹配，取中间。
    if (newText.startsWith(before) && newText.endsWith(after)) {
      return newText.substring(
        before.length,
        newText.length - after.length,
      );
    }
    return null;
  }
  return newText.substring(insertStart, insertEnd);
}
