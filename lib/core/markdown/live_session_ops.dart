import 'ast/md_block.dart';
import 'ast/md_inline.dart';
import 'block_ops.dart';
import 'live_line_markdown.dart';
import 'md_block_chrome_metrics.dart';
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
  } else if (block is BulletBlock && block.checked != null) {
    // 勾选列表 Enter：新项固定未勾选，当前块 checked 不变。
    newBlock = reparseBlockFromLineMarkdown(
      block,
      lineMarkdown: applyTaskLineMarkdown(afterInline),
      id: idGenerator.next(),
    );
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

/// 正文是否视为空文档：仅一块且为无内容段落（不含空列表项）。
///
/// 此时实时模式展示灰色 hint，并让正文框空白区可点聚焦。
bool isEmptyDocumentBody(List<MdBlock> blocks) {
  if (blocks.length != 1) {
    return false;
  }
  final block = blocks.single;
  return block is ParagraphBlock && block.plainText.trim().isEmpty;
}

/// 列表层 [RenderParagraph] 是否已跟上活动 controller 的 plain。
///
/// 未跟上时按旧段落测光标会停在上一字后，直到父级 debounce 同步才动。
/// 空块占位是透明空格。
bool rendererParagraphMatchesCaretPlain({
  required String controllerPlain,
  required String paragraphPlain,
  required bool hasInlineFormatting,
}) {
  if (controllerPlain.isEmpty) {
    return paragraphPlain == MdBlockChromeMetrics.emptyBodyPlaceholder ||
        paragraphPlain == '\u200B' ||
        paragraphPlain.isEmpty;
  }
  if (hasInlineFormatting) {
    // 行内格式下 display ≠ plain，无法用字符串相等判断 stale。
    return true;
  }
  return paragraphPlain == controllerPlain;
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

/// 原子块下方插入空段落，供继续键入。
({List<MdBlock> blocks, String newActiveId}) ensureEditableBlockAfterAtomic({
  required List<MdBlock> blocks,
  required int atomicIndex,
  required MdBlockIdGenerator idGenerator,
}) {
  final next = List<MdBlock>.of(blocks);
  final paragraph = ParagraphBlock(id: idGenerator.next(), text: '');
  final insertAt = (atomicIndex + 1).clamp(0, next.length);
  next.insert(insertAt, paragraph);
  return (blocks: next, newActiveId: paragraph.id);
}

/// 在 [index] 处插入分割线：空段落则替换，否则插在后方；线后再插空段落并聚焦。
({List<MdBlock> blocks, String newActiveId}) insertThematicBreakAt({
  required List<MdBlock> blocks,
  required int index,
  required MdBlockIdGenerator idGenerator,
}) {
  final next = List<MdBlock>.of(blocks);
  if (next.isEmpty || index < 0 || index >= next.length) {
    next.add(ThematicBreakBlock(id: idGenerator.next()));
    return ensureEditableBlockAfterAtomic(
      blocks: next,
      atomicIndex: next.length - 1,
      idGenerator: idGenerator,
    );
  }

  final current = next[index];
  final int atomicIndex;
  if (current is ParagraphBlock && current.text.trim().isEmpty) {
    next[index] = ThematicBreakBlock(id: current.id);
    atomicIndex = index;
  } else {
    next.insert(index + 1, ThematicBreakBlock(id: idGenerator.next()));
    atomicIndex = index + 1;
  }
  return ensureEditableBlockAfterAtomic(
    blocks: next,
    atomicIndex: atomicIndex,
    idGenerator: idGenerator,
  );
}
