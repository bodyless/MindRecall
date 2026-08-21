import '../ast/md_block.dart';
import '../live_line_markdown.dart';
import 'md_syntax_patterns.dart';

/// 将 Markdown 源码解析为 [MdBlock] AST 列表。
List<MdBlock> parseMarkdownBlocks(
  String text, {
  MdBlockIdGenerator? idGenerator,
}) {
  final ids = idGenerator ?? MdBlockIdGenerator();
  if (text.isEmpty) {
    return [ParagraphBlock(id: ids.next(), text: '')];
  }

  final lines = text.split('\n');
  final blocks = <MdBlock>[];
  var index = 0;

  while (index < lines.length) {
    final line = lines[index];

    if (line.trim().isEmpty) {
      index++;
      continue;
    }

    if (line.startsWith('```')) {
      final language = line.length > 3 ? line.substring(3).trim() : '';
      final buffer = <String>[];
      index++;
      while (index < lines.length && !lines[index].startsWith('```')) {
        buffer.add(lines[index]);
        index++;
      }
      if (index < lines.length) {
        index++;
      }
      blocks.add(
        CodeBlock(
          id: ids.next(),
          language: language.isEmpty ? null : language,
          code: buffer.join('\n'),
        ),
      );
      continue;
    }

    final headingMatch = MdSyntaxPatterns.headingLine.firstMatch(line);
    if (headingMatch != null) {
      blocks.add(
        HeadingBlock(
          id: ids.next(),
          level: headingMatch.group(1)!.length,
          text: headingMatch.group(2) ?? '',
        ),
      );
      index++;
      continue;
    }

    if (MdSyntaxPatterns.imageLine.hasMatch(line.trim())) {
      final match = MdSyntaxPatterns.imageLine.firstMatch(line.trim())!;
      blocks.add(
        ImageBlock(
          id: ids.next(),
          alt: match.group(1) ?? '',
          src: match.group(2) ?? '',
        ),
      );
      index++;
      continue;
    }

    if (MdSyntaxPatterns.thematicBreakLine.hasMatch(line)) {
      blocks.add(ThematicBreakBlock(id: ids.next()));
      index++;
      continue;
    }

    final taskMatch = MdSyntaxPatterns.taskLine.firstMatch(line);
    if (taskMatch != null) {
      blocks.add(
        BulletBlock(
          id: ids.next(),
          text: taskMatch.group(2) ?? '',
          checked: MdSyntaxPatterns.taskMarkerIsChecked(taskMatch.group(1)!),
        ),
      );
      index++;
      continue;
    }

    if (MdSyntaxPatterns.bulletLine.hasMatch(line)) {
      blocks.add(
        BulletBlock(
          id: ids.next(),
          text: line.replaceFirst(MdSyntaxPatterns.bulletLine, ''),
        ),
      );
      index++;
      continue;
    }

    final orderedMatch = MdSyntaxPatterns.orderedLine.firstMatch(line);
    if (orderedMatch != null) {
      blocks.add(
        OrderedBlock(
          id: ids.next(),
          marker: orderedMatch.group(1)!,
          text: orderedMatch.group(2) ?? '',
        ),
      );
      index++;
      continue;
    }

    if (line.startsWith('>')) {
      blocks.add(
        QuoteBlock(
          id: ids.next(),
          text: line.replaceFirst(MdSyntaxPatterns.quotePrefix, ''),
        ),
      );
      index++;
      continue;
    }

    final buffer = <String>[line];
    index++;
    while (index < lines.length) {
      final next = lines[index];
      if (next.trim().isEmpty ||
          next.startsWith('#') ||
          next.startsWith('>') ||
          next.startsWith('```') ||
          MdSyntaxPatterns.imageLine.hasMatch(next.trim()) ||
          MdSyntaxPatterns.thematicBreakLine.hasMatch(next) ||
          MdSyntaxPatterns.bulletLine.hasMatch(next) ||
          RegExp(r'^\d+\.\s+').hasMatch(next)) {
        break;
      }
      buffer.add(next);
      index++;
    }
    blocks.add(
      ParagraphBlock(
        id: ids.next(),
        text: buffer.join('\n'),
      ),
    );
  }

  if (blocks.isEmpty) {
    blocks.add(ParagraphBlock(id: ids.next(), text: ''));
  }
  return blocks;
}

/// 识别行首轻量块触发语法（如输入 `# `、`- ` 转对应块类型）。
///
/// 通过「行 markdown → 解析」与工具栏块操作共用同一套解析逻辑。
MdBlock? applyBlockTrigger(MdBlock block, String lineText) {
  // 普通无序列表行首再输入 `[ ]` / `[x]` 时，补回 `- ` 再解析为勾选块。
  if (block is BulletBlock &&
      block.checked == null &&
      MdSyntaxPatterns.taskBodyMarker.hasMatch(lineText)) {
    return reparseBlockFromLineMarkdown(
      block,
      lineMarkdown: '- $lineText',
    );
  }
  final matchesTrigger = MdSyntaxPatterns.headingLine.hasMatch(lineText) ||
      MdSyntaxPatterns.bulletTrigger.hasMatch(lineText) ||
      MdSyntaxPatterns.orderedLine.hasMatch(lineText) ||
      MdSyntaxPatterns.thematicBreakLine.hasMatch(lineText) ||
      lineText.startsWith('> ');
  if (!matchesTrigger) {
    return null;
  }
  return reparseBlockFromLineMarkdown(block, lineMarkdown: lineText);
}
