/// 块级 Markdown AST，供实时 WYSIWYG 编辑使用。
sealed class MdBlock {
  const MdBlock({required this.id});

  final String id;

  /// 块的可编辑纯文本（不含 `#`、`-` 等块级前缀）。
  String get plainText;

  MdBlock copyWithPlainText(String text);

  String toMarkdown();

  MdBlock asHeading(int level) => HeadingBlock(
        id: id,
        level: level.clamp(1, 6),
        text: plainText,
      );

  MdBlock asParagraph() => ParagraphBlock(id: id, text: plainText);

  MdBlock asBulletItem() => BulletBlock(id: id, text: plainText);

  MdBlock asOrderedItem({String marker = '1.'}) =>
      OrderedBlock(id: id, marker: marker, text: plainText);

  MdBlock asQuote() => QuoteBlock(id: id, text: plainText);
}

final class HeadingBlock extends MdBlock {
  const HeadingBlock({
    required super.id,
    required this.level,
    required this.text,
  });

  final int level;
  final String text;

  @override
  String get plainText => text;

  @override
  HeadingBlock copyWithPlainText(String text) =>
      HeadingBlock(id: id, level: level, text: text);

  HeadingBlock copyWith({int? level, String? text}) => HeadingBlock(
        id: id,
        level: level ?? this.level,
        text: text ?? this.text,
      );

  @override
  String toMarkdown() => '${'#' * level.clamp(1, 6)} $text';
}

final class ParagraphBlock extends MdBlock {
  const ParagraphBlock({
    required super.id,
    required this.text,
    this.continuesWithNext = false,
  });

  final String text;

  /// 与紧随其后的 [ParagraphBlock] 属于同一段落内的换行（实时 Enter / 多行展开），
  /// 块间不额外留白，以匹配预览中的行距。
  final bool continuesWithNext;

  @override
  String get plainText => text;

  ParagraphBlock copyWith({
    String? text,
    bool? continuesWithNext,
  }) =>
      ParagraphBlock(
        id: id,
        text: text ?? this.text,
        continuesWithNext: continuesWithNext ?? this.continuesWithNext,
      );

  @override
  ParagraphBlock copyWithPlainText(String text) => copyWith(text: text);

  @override
  String toMarkdown() => text;
}

final class BulletBlock extends MdBlock {
  const BulletBlock({
    required super.id,
    required this.text,
  });

  final String text;

  @override
  String get plainText => text;

  @override
  BulletBlock copyWithPlainText(String text) => BulletBlock(id: id, text: text);

  @override
  String toMarkdown() => '- $text';
}

final class OrderedBlock extends MdBlock {
  const OrderedBlock({
    required super.id,
    required this.marker,
    required this.text,
  });

  final String marker;
  final String text;

  @override
  String get plainText => text;

  @override
  OrderedBlock copyWithPlainText(String text) =>
      OrderedBlock(id: id, marker: marker, text: text);

  @override
  String toMarkdown() => '$marker $text';
}

final class QuoteBlock extends MdBlock {
  const QuoteBlock({
    required super.id,
    required this.text,
  });

  final String text;

  @override
  String get plainText => text;

  @override
  QuoteBlock copyWithPlainText(String text) => QuoteBlock(id: id, text: text);

  @override
  String toMarkdown() => '> $text';
}

final class CodeBlock extends MdBlock {
  const CodeBlock({
    required super.id,
    required this.code,
    this.language,
  });

  final String code;
  final String? language;

  @override
  String get plainText => code;

  @override
  CodeBlock copyWithPlainText(String text) =>
      CodeBlock(id: id, code: text, language: language);

  @override
  String toMarkdown() {
    final lang = language ?? '';
    if (code.isEmpty) {
      return '```$lang\n```';
    }
    return '```$lang\n$code\n```';
  }
}

final class ImageBlock extends MdBlock {
  const ImageBlock({
    required super.id,
    required this.alt,
    required this.src,
  });

  final String alt;
  final String src;

  @override
  String get plainText => alt.isEmpty ? src : alt;

  @override
  ImageBlock copyWithPlainText(String text) =>
      ImageBlock(id: id, alt: text, src: src);

  @override
  String toMarkdown() => '![$alt]($src)';
}

/// 解析会话内生成 block id。
class MdBlockIdGenerator {
  MdBlockIdGenerator([this._counter = 0]);

  int _counter;

  String next() {
    _counter += 1;
    return 'md-b$_counter';
  }

  MdBlockIdGenerator fork() => MdBlockIdGenerator(_counter);
}

String serializeMdBlocks(List<MdBlock> blocks) {
  if (blocks.isEmpty) {
    return '';
  }
  return blocks.map((block) => block.toMarkdown()).join('\n');
}
