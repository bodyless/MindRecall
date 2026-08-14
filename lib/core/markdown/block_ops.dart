import 'ast/md_block.dart';
import 'ast/md_inline.dart';
import 'live_line_markdown.dart';
import 'md_block_chrome_metrics.dart';
import 'parser/markdown_block_parser.dart';

/// 实时模式的块编辑能力与 plain ↔ markdown 映射。
///
/// 行内语法（如 `**bold**`）存在 block 的 [text] 字段；
/// 活动 [TextField] 显示 [editableTextForBlock]（plain text）。

/// 块体是否支持粗体/斜体/代码等行内 Markdown。
bool supportsInlineFormatting(MdBlock block) {
  return switch (block) {
    ParagraphBlock() ||
    BulletBlock() ||
    OrderedBlock() ||
    QuoteBlock() =>
      true,
    _ => false,
  };
}

/// 块上存储的原始行内 markdown（不含 `#` 等块级前缀）。
String inlineMarkdownForBlock(MdBlock block) {
  return switch (block) {
    ParagraphBlock(:final text) ||
    BulletBlock(:final text) ||
    OrderedBlock(:final text) ||
    QuoteBlock(:final text) =>
      text,
    _ => block.plainText,
  };
}

/// 活动输入框显示的 plain text（已去掉行内标记）。
String editableTextForBlock(MdBlock block) {
  if (supportsInlineFormatting(block)) {
    return plainTextFromInlines(
      parseInlineMarkdown(inlineMarkdownForBlock(block)),
    );
  }
  return block.plainText;
}

/// 解析后的行内 AST 是否含非纯文本节点（粗体/斜体/代码）。
bool hasRenderedInlineFormatting(MdBlock block) {
  if (!supportsInlineFormatting(block)) {
    return false;
  }
  final markdown = inlineMarkdownForBlock(block);
  if (markdown.isEmpty) {
    return false;
  }
  final nodes = parseInlineMarkdown(markdown);
  return nodes.any((node) => node is! TextInline);
}

/// 更新支持行内格式的块上的 markdown 文本。
MdBlock copyBlockInlineMarkdown(MdBlock block, String markdown) {
  return switch (block) {
    ParagraphBlock() => block.copyWith(text: markdown),
    BulletBlock() => block.copyWithPlainText(markdown),
    OrderedBlock() => block.copyWithPlainText(markdown),
    QuoteBlock() => block.copyWithPlainText(markdown),
    _ => block,
  };
}

String stripInlineMarkdownSyntax(String input) {
  return plainTextFromInlines(parseInlineMarkdown(input));
}

bool supportsMultilineEditing(MdBlock block) {
  return block is ParagraphBlock || block is CodeBlock;
}

bool isSingleLineBlock(MdBlock block) {
  return switch (block) {
    HeadingBlock() || BulletBlock() || OrderedBlock() || QuoteBlock() => true,
    _ => false,
  };
}

/// 将含 `\n` 的 [ParagraphBlock] 拆成每视觉行一块。
///
/// 实时模式按行编辑；若不拆分，编辑模式的多行段落会被整块 H2/列表误伤。
List<MdBlock> expandMultilineParagraphsForLive(
  List<MdBlock> blocks,
  MdBlockIdGenerator idGenerator,
) {
  final expanded = <MdBlock>[];
  for (final block in blocks) {
    if (block is! ParagraphBlock || !block.text.contains('\n')) {
      expanded.add(block);
      continue;
    }
    final lines = block.text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      expanded.add(
        ParagraphBlock(
          id: i == 0 ? block.id : idGenerator.next(),
          text: lines[i],
          continuesWithNext: i < lines.length - 1,
        ),
      );
    }
  }
  return expanded;
}

/// 将多行 [ParagraphBlock] 拆成每行一块。
///
/// 返回拆分结果及 [plainOffset] 所在行索引；首行保留 [block.id]。
({List<ParagraphBlock> blocks, int activeLineIndex})
    splitMultilineParagraphAtPlainOffset({
  required ParagraphBlock block,
  required int plainOffset,
  required MdBlockIdGenerator idGenerator,
}) {
  final plainText = editableTextForBlock(block);
  final plainLines = plainText.split('\n');
  if (plainLines.length <= 1) {
    return (blocks: [block], activeLineIndex: 0);
  }

  final activeLineIndex = lineIndexAtPlainOffset(plainText, plainOffset);
  final markdownLines = _splitParagraphMarkdownLines(block);
  final resolvedLines =
      markdownLines.length == plainLines.length ? markdownLines : plainLines;

  final blocks = <ParagraphBlock>[
    for (var i = 0; i < resolvedLines.length; i++)
      ParagraphBlock(
        id: i == 0 ? block.id : idGenerator.next(),
        text: resolvedLines[i],
        continuesWithNext: i < resolvedLines.length - 1,
      ),
  ];
  return (blocks: blocks, activeLineIndex: activeLineIndex);
}

List<String> _splitParagraphMarkdownLines(ParagraphBlock block) {
  final markdown = block.text;
  if (!markdown.contains('\n')) {
    return [markdown];
  }
  return markdown.split('\n');
}

/// [plainOffset] 在 [plainText.split('\n')] 中所在的行索引。
int lineIndexAtPlainOffset(String plainText, int plainOffset) {
  final clamped = plainOffset.clamp(0, plainText.length);
  final before = plainText.substring(0, clamped);
  return before.split('\n').length - 1;
}

/// 有序列表连续段的起始索引。
int orderedRunStart(List<MdBlock> blocks, int index) {
  var start = index.clamp(0, blocks.isEmpty ? 0 : blocks.length - 1);
  while (start > 0 && blocks[start - 1] is OrderedBlock) {
    start--;
  }
  return start;
}

/// 从 [start] 起为连续 [OrderedBlock] 重排 1. 2. 3. …
void renumberOrderedBlocksFrom(List<MdBlock> blocks, int start) {
  var number = 1;
  for (var i = start; i < blocks.length; i++) {
    final block = blocks[i];
    if (block is! OrderedBlock) {
      break;
    }
    blocks[i] = OrderedBlock(
      id: block.id,
      marker: '$number.',
      text: block.text,
    );
    number++;
  }
}

/// 删除下标 [removedAtIndex] 的块后，对剩余有序列表连续段重编号。
void renumberOrderedBlocksAfterRemoval(List<MdBlock> blocks, int removedAtIndex) {
  if (blocks.isEmpty) {
    return;
  }
  final probe = removedAtIndex.clamp(0, blocks.length - 1);
  final start = orderedRunStart(blocks, probe);
  if (blocks[start] is OrderedBlock) {
    renumberOrderedBlocksFrom(blocks, start);
  }
}

/// 删除 [index] 处的块；若删空则插入一个空段落，保证编辑器始终有至少一块。
///
/// 返回删除后应激活的块下标（优先原位置后继，否则前一块）。
({List<MdBlock> blocks, int activeIndex}) removeBlockAt(
  List<MdBlock> blocks, {
  required int index,
  required MdBlockIdGenerator idGenerator,
}) {
  if (index < 0 || index >= blocks.length) {
    return (blocks: List<MdBlock>.of(blocks), activeIndex: 0);
  }
  final next = List<MdBlock>.of(blocks)..removeAt(index);
  renumberOrderedBlocksAfterRemoval(next, index);
  if (next.isEmpty) {
    next.add(ParagraphBlock(id: idGenerator.next(), text: ''));
  }
  final activeIndex = index.clamp(0, next.length - 1);
  return (blocks: next, activeIndex: activeIndex);
}

/// 将预览/其它来源粘贴文本规范为可解析的 Markdown（如 `•  ` → `- `）。
String normalizePastedMarkdown(String raw) {
  const bulletPrefix = MdBlockChromeMetrics.bulletPrefix;
  final normalized = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  return normalized.split('\n').map((line) {
    if (line.startsWith(bulletPrefix)) {
      return '- ${line.substring(bulletPrefix.length)}';
    }
    if (line.startsWith('• ')) {
      return '- ${line.substring(2)}';
    }
    if (line.startsWith('•')) {
      return '- ${line.substring(1).trimLeft()}';
    }
    return line;
  }).join('\n');
}

/// 在活动块选区处粘贴多行 Markdown，拆成多个块插入。
///
/// [beforePlain] / [afterPlain] 为粘贴前活动块 plain 在选区两侧的文本。
({List<MdBlock> blocks, int activeIndex}) pasteMarkdownIntoBlocks({
  required List<MdBlock> blocks,
  required int activeIndex,
  required MdBlock activeBlock,
  required String beforePlain,
  required String afterPlain,
  required String pastedMarkdown,
  required MdBlockIdGenerator idGenerator,
}) {
  final normalized = normalizePastedMarkdown(pastedMarkdown);
  if (normalized.trim().isEmpty) {
    return (
      blocks: List<MdBlock>.of(blocks),
      activeIndex: activeIndex.clamp(0, blocks.isEmpty ? 0 : blocks.length - 1),
    );
  }

  var pasted = expandMultilineParagraphsForLive(
    parseMarkdownBlocks(normalized, idGenerator: idGenerator),
    idGenerator,
  );
  if (pasted.isEmpty) {
    pasted = [
      for (final line in normalized.split('\n'))
        ParagraphBlock(id: idGenerator.next(), text: line),
    ];
  }

  final result = List<MdBlock>.of(blocks);
  if (activeIndex < 0 || activeIndex >= result.length) {
    result.addAll(pasted);
    return (blocks: result, activeIndex: result.length - 1);
  }

  // 空块整段替换为粘贴结果。
  if (beforePlain.isEmpty && afterPlain.isEmpty) {
    final withIds = <MdBlock>[
      assignBlockId(pasted.first, activeBlock.id),
      ...pasted.skip(1),
    ];
    result.replaceRange(activeIndex, activeIndex + 1, withIds);
    _renumberAround(result, activeIndex);
    return (
      blocks: result,
      activeIndex: (activeIndex + withIds.length - 1).clamp(0, result.length - 1),
    );
  }

  final insert = <MdBlock>[];
  if (beforePlain.isNotEmpty) {
    insert.add(_retainActivePrefix(activeBlock, beforePlain));
    insert.addAll(pasted);
  } else {
    insert.add(assignBlockId(pasted.first, activeBlock.id));
    insert.addAll(pasted.skip(1));
  }
  if (afterPlain.isNotEmpty) {
    insert.add(ParagraphBlock(id: idGenerator.next(), text: afterPlain));
  }

  result.replaceRange(activeIndex, activeIndex + 1, insert);
  _renumberAround(result, activeIndex);
  final focusIndex = afterPlain.isNotEmpty
      ? activeIndex + insert.length - 2
      : activeIndex + insert.length - 1;
  return (
    blocks: result,
    activeIndex: focusIndex.clamp(0, result.length - 1),
  );
}

void _renumberAround(List<MdBlock> blocks, int index) {
  if (blocks.isEmpty) {
    return;
  }
  final start = orderedRunStart(blocks, index.clamp(0, blocks.length - 1));
  if (blocks[start] is OrderedBlock) {
    renumberOrderedBlocksFrom(blocks, start);
  }
}

/// 保留活动块类型，写入光标前 plain（含行内格式时走 applyPlainTextChange）。
MdBlock _retainActivePrefix(MdBlock activeBlock, String beforePlain) {
  if (supportsInlineFormatting(activeBlock)) {
    final markdown = applyPlainTextChange(
      markdown: inlineMarkdownForBlock(activeBlock),
      previousPlain: editableTextForBlock(activeBlock),
      newPlain: beforePlain,
    );
    return copyBlockInlineMarkdown(activeBlock, markdown);
  }
  if (activeBlock is HeadingBlock) {
    return HeadingBlock(
      id: activeBlock.id,
      level: activeBlock.level,
      text: beforePlain,
    );
  }
  return activeBlock.copyWithPlainText(beforePlain);
}
