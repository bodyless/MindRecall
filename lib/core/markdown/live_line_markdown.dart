import 'ast/md_block.dart';
import 'parser/markdown_block_parser.dart';
import 'parser/md_syntax_patterns.dart';

/// 去掉行首块级 Markdown 前缀，保留行内内容。
String stripBlockLinePrefix(String lineMarkdown) {
  final heading = MdSyntaxPatterns.headingLine.firstMatch(lineMarkdown);
  if (heading != null) {
    return heading.group(2) ?? '';
  }
  final task = MdSyntaxPatterns.taskLine.firstMatch(lineMarkdown);
  if (task != null) {
    return task.group(2) ?? '';
  }
  if (MdSyntaxPatterns.bulletLine.hasMatch(lineMarkdown)) {
    return lineMarkdown.replaceFirst(MdSyntaxPatterns.bulletLine, '');
  }
  final ordered = MdSyntaxPatterns.orderedLine.firstMatch(lineMarkdown);
  if (ordered != null) {
    return ordered.group(2) ?? '';
  }
  if (lineMarkdown.startsWith('> ')) {
    return lineMarkdown.substring(2);
  }
  if (lineMarkdown.startsWith('>')) {
    return lineMarkdown.replaceFirst(MdSyntaxPatterns.quotePrefix, '');
  }
  return lineMarkdown;
}

String applyBulletLineMarkdown(String lineMarkdown) =>
    '- ${stripBlockLinePrefix(lineMarkdown)}';

String applyTaskLineMarkdown(String lineMarkdown) {
  final body = stripBlockLinePrefix(lineMarkdown);
  return body.isEmpty ? '- [ ]' : '- [ ] $body';
}

String applyOrderedLineMarkdown(
  String lineMarkdown, {
  String marker = '1.',
}) =>
    '$marker ${stripBlockLinePrefix(lineMarkdown)}';

String applyHeadingLineMarkdown(String lineMarkdown, int level) {
  final safeLevel = level.clamp(1, 6);
  return '${'#' * safeLevel} ${stripBlockLinePrefix(lineMarkdown)}';
}

String applyQuoteLineMarkdown(String lineMarkdown) =>
    '> ${stripBlockLinePrefix(lineMarkdown)}';

String applyParagraphLineMarkdown(String lineMarkdown) =>
    stripBlockLinePrefix(lineMarkdown);

/// 由块类型与行内 markdown 拼出完整行级 markdown（数据层，不含 WYSIWYG 展示前缀）。
String lineMarkdownForBlock(MdBlock block, String inlineMarkdown) {
  return switch (block) {
    BulletBlock(:final checked) => switch (checked) {
        null => '- $inlineMarkdown',
        false =>
          inlineMarkdown.isEmpty ? '- [ ]' : '- [ ] $inlineMarkdown',
        true => inlineMarkdown.isEmpty ? '- [x]' : '- [x] $inlineMarkdown',
      },
    OrderedBlock() => '1. $inlineMarkdown',
    HeadingBlock(:final level) => '${'#' * level.clamp(1, 6)} $inlineMarkdown',
    QuoteBlock() => '> $inlineMarkdown',
    ParagraphBlock() => inlineMarkdown,
    _ => inlineMarkdown,
  };
}

/// 将单行 markdown 解析为块，并保留 [id]。
MdBlock reparseBlockFromLineMarkdown(
  MdBlock template, {
  required String lineMarkdown,
  String? id,
}) {
  final preserveId = id ?? template.id;
  final trimmed = lineMarkdown.trim();
  if (trimmed.isEmpty) {
    return ParagraphBlock(id: preserveId, text: '');
  }

  final parsed = parseMarkdownBlocks(lineMarkdown);
  if (parsed.isEmpty) {
    return ParagraphBlock(id: preserveId, text: lineMarkdown);
  }
  return assignBlockId(parsed.first, preserveId);
}

MdBlock assignBlockId(MdBlock block, String id) {
  return switch (block) {
    HeadingBlock(:final level, :final text) =>
      HeadingBlock(id: id, level: level, text: text),
    ParagraphBlock(:final text, :final continuesWithNext) => ParagraphBlock(
        id: id,
        text: text,
        continuesWithNext: continuesWithNext,
      ),
    BulletBlock(:final text, :final checked) =>
      BulletBlock(id: id, text: text, checked: checked),
    OrderedBlock(:final marker, :final text) =>
      OrderedBlock(id: id, marker: marker, text: text),
    QuoteBlock(:final text) => QuoteBlock(id: id, text: text),
    CodeBlock(:final language, :final code) =>
      CodeBlock(id: id, language: language, code: code),
    ImageBlock(:final alt, :final src) =>
      ImageBlock(id: id, alt: alt, src: src),
  };
}
