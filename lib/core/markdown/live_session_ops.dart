import 'ast/md_block.dart';
import 'ast/md_inline.dart';
import 'block_ops.dart';
import 'live_line_markdown.dart';
import 'parser/markdown_block_parser.dart';

/// 实时模式会话级纯函数：加载 / 拆块 / 单行 Enter，不依赖 Widget。
///
/// [LiveMarkdownEditorState] 只负责焦点、Overlay、滚动与 setState。

/// 从 Markdown 源码准备实时 AST，并解析应激活的块 id。
({List<MdBlock> blocks, String activeBlockId}) prepareLiveBlocksFromMarkdown(
  String markdown, {
  required MdBlockIdGenerator idGenerator,
  String? preferredActiveId,
  bool preferLastBlock = false,
}) {
  var blocks = parseMarkdownBlocks(markdown, idGenerator: idGenerator);
  blocks = expandMultilineParagraphsForLive(blocks, idGenerator);
  if (blocks.isEmpty) {
    blocks = [ParagraphBlock(id: idGenerator.next(), text: '')];
  }
  final activeBlockId = preferLastBlock
      ? blocks.last.id
      : (preferredActiveId != null &&
              blocks.any((block) => block.id == preferredActiveId)
          ? preferredActiveId!
          : blocks.first.id);
  return (blocks: blocks, activeBlockId: activeBlockId);
}

/// 将活动输入 plain 映射为块内行内 markdown（含格式时走 applyPlainTextChange）。
String resolvedInlineMarkdownForEdit(MdBlock block, String plainText) {
  if (!supportsInlineFormatting(block)) {
    return plainText;
  }
  final markdown = inlineMarkdownForBlock(block);
  final storedPlain = editableTextForBlock(block);
  if (plainText == storedPlain) {
    return markdown;
  }
  return applyPlainTextChange(
    markdown: markdown,
    previousPlain: storedPlain,
    newPlain: plainText,
  );
}

/// 段落拆分后：前半块标记 [ParagraphBlock.continuesWithNext]。
MdBlock paragraphAfterSplit(MdBlock block, String markdown) {
  final updated = copyBlockInlineMarkdown(block, markdown);
  if (updated is ParagraphBlock) {
    return updated.copyWith(continuesWithNext: true);
  }
  return updated;
}

/// 多行块（段落）在 plain 光标处拆成两块。
({List<MdBlock> blocks, String newActiveId}) splitMultilineBlockAt({
  required List<MdBlock> blocks,
  required int index,
  required String resolvedMarkdownBeforeEdit,
  required int plainCursor,
  required MdBlockIdGenerator idGenerator,
}) {
  final next = List<MdBlock>.of(blocks);
  final split = splitInlineMarkdown(resolvedMarkdownBeforeEdit, plainCursor);
  next[index] = paragraphAfterSplit(next[index], split.before);
  final newBlock = ParagraphBlock(
    id: idGenerator.next(),
    text: split.after,
  );
  next.insert(index + 1, newBlock);
  return (blocks: next, newActiveId: newBlock.id);
}

/// 单行块（标题/列表/引用）Enter：保留光标前内容，下方插入新块。
({List<MdBlock> blocks, String newActiveId}) insertBlockBelowSingleLine({
  required List<MdBlock> blocks,
  required int index,
  required String beforePlain,
  required String afterPlain,
  required MdBlockIdGenerator idGenerator,
}) {
  final next = List<MdBlock>.of(blocks);
  final block = next[index];
  final beforeInline = resolvedInlineMarkdownForEdit(block, beforePlain);
  final afterInline = resolvedInlineMarkdownForEdit(block, afterPlain);

  next[index] = reparseBlockFromLineMarkdown(
    block,
    lineMarkdown: lineMarkdownForBlock(block, beforeInline),
  );

  final MdBlock newBlock;
  if (block is HeadingBlock) {
    newBlock = ParagraphBlock(id: idGenerator.next(), text: afterPlain);
  } else {
    newBlock = reparseBlockFromLineMarkdown(
      block,
      lineMarkdown: lineMarkdownForBlock(block, afterInline),
      id: idGenerator.next(),
    );
  }
  next.insert(index + 1, newBlock);
  if (block is OrderedBlock || newBlock is OrderedBlock) {
    renumberOrderedBlocksFrom(next, orderedRunStart(next, index + 1));
  }
  return (blocks: next, newActiveId: newBlock.id);
}

/// 用 plain 写回活动块（提交/失焦时）。
MdBlock commitPlainToBlock(MdBlock block, String plainText) {
  final normalized =
      supportsInlineFormatting(block) ? plainText : plainText.split('\n').first;
  final updatedMarkdown = resolvedInlineMarkdownForEdit(block, normalized);
  if (updatedMarkdown == inlineMarkdownForBlock(block)) {
    return block;
  }
  return copyBlockInlineMarkdown(block, updatedMarkdown);
}

/// 仅段落块可携带 [ParagraphBlock.continuesWithNext]。
MdBlock copyWithContinuesWithNext(
  MdBlock block, {
  required bool continuesWithNext,
}) {
  if (block is ParagraphBlock) {
    return block.copyWith(continuesWithNext: continuesWithNext);
  }
  return block;
}
