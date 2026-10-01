import '../parser/md_syntax_patterns.dart';

/// 块级 Markdown AST，供实时 WYSIWYG 编辑使用。
sealed class MdBlock {
  const MdBlock({required this.id});

  final String id;

  /// 块的可编辑纯文本（不含 `#`、`-` 等块级前缀）。
  String get plainText;

  MdBlock copyWithPlainText(String text);

  /// 仅替换 [id]，其余字段不变。
  MdBlock copyWithId(String id);

  String toMarkdown();

  /// 实时是否用 TextField 编辑块体；`false` 为原子块（点选 + 删除，不挂 Overlay）。
  bool get supportsPlainEditing => true;

  MdBlock asHeading(int level) => HeadingBlock(
        id: id,
        level: level.clamp(1, 6),
        text: plainText,
      );

  MdBlock asParagraph() => ParagraphBlock(id: id, text: plainText);

  MdBlock asBulletItem() => BulletBlock(id: id, text: plainText);

  /// 转为未勾选的 GFM 任务项（`- [ ]`）。
  MdBlock asTaskItem() =>
      BulletBlock(id: id, text: plainText, checked: false);

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

  @override
  HeadingBlock copyWithId(String id) =>
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
  ParagraphBlock copyWithId(String id) => ParagraphBlock(
        id: id,
        text: text,
        continuesWithNext: continuesWithNext,
      );

  @override
  String toMarkdown() => text;
}

final class BulletBlock extends MdBlock {
  const BulletBlock({
    required super.id,
    required this.text,
    this.checked,
  });

  final String text;

  /// `null` 为普通无序列表；非 `null` 为 GFM 勾选列表。
  final bool? checked;

  bool get isTask => checked != null;

  @override
  String get plainText => text;

  @override
  BulletBlock copyWithPlainText(String text) =>
      BulletBlock(id: id, text: text, checked: checked);

  @override
  BulletBlock copyWithId(String id) =>
      BulletBlock(id: id, text: text, checked: checked);

  @override
  String toMarkdown() {
    if (checked == null) {
      return '- $text';
    }
    final mark = checked! ? 'x' : ' ';
    if (text.isEmpty) {
      return '- [$mark]';
    }
    return '- [$mark] $text';
  }
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
  OrderedBlock copyWithId(String id) =>
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
  QuoteBlock copyWithId(String id) => QuoteBlock(id: id, text: text);

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
  CodeBlock copyWithId(String id) =>
      CodeBlock(id: id, code: code, language: language);

  /// [language] 传入 `null` 可清空围栏语言。
  static const _languageUnset = Object();

  CodeBlock copyWith({
    String? code,
    Object? language = _languageUnset,
  }) {
    return CodeBlock(
      id: id,
      code: code ?? this.code,
      language: identical(language, _languageUnset)
          ? this.language
          : language as String?,
    );
  }

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
    this.title,
  });

  final String alt;
  final String src;

  /// 标准图片标题（`![alt](path "title")`）。空则写回时不带引号。界面不展示。
  final String? title;

  @override
  String get plainText => alt.isEmpty ? src : alt;

  @override
  bool get supportsPlainEditing => false;

  @override
  ImageBlock copyWithPlainText(String text) =>
      ImageBlock(id: id, alt: text, src: src, title: title);

  @override
  ImageBlock copyWithId(String id) =>
      ImageBlock(id: id, alt: alt, src: src, title: title);

  @override
  String toMarkdown() => formatStandaloneImageLine(
        alt: alt,
        destination: src,
        title: title,
      );
}

/// Markdown 分割线（thematic break）；无正文，实时按原子块交互。
final class ThematicBreakBlock extends MdBlock {
  const ThematicBreakBlock({required super.id});

  @override
  bool get supportsPlainEditing => false;

  @override
  String get plainText => '';

  @override
  ThematicBreakBlock copyWithPlainText(String text) => this;

  @override
  ThematicBreakBlock copyWithId(String id) => ThematicBreakBlock(id: id);

  @override
  String toMarkdown() => '---';
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
