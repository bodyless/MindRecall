import 'dart:convert';

import 'package:enough_convert/enough_convert.dart';

/// UTF-8 BOM（U+FEFF）。导入保存前去掉，避免标题解析把 BOM 算进首行。
const _utf8Bom = '\uFEFF';

/// 将外部 txt/md 的原始字节解成字符串。
///
/// 先严格 UTF-8；失败再按 GBK（非法字节抛错）。两者都失败则抛 [FormatException]，
/// 调用方此时还不能创建笔记文件。
String decodeImportedTextBytes(List<int> bytes) {
  try {
    final text = utf8.decode(bytes, allowMalformed: false);
    if (text.startsWith(_utf8Bom)) {
      return text.substring(_utf8Bom.length);
    }
    return text;
  } on FormatException {
    try {
      return const GbkCodec(allowInvalid: false).decode(bytes);
    } on FormatException {
      throw const FormatException('imported text is neither UTF-8 nor GBK');
    }
  }
}
