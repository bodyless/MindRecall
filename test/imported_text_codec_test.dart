import 'dart:convert';

import 'package:enough_convert/enough_convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/services/imported_text_codec.dart';

void main() {
  group('decodeImportedTextBytes', () {
    test('普通 UTF-8 原样返回', () {
      expect(decodeImportedTextBytes(utf8.encode('你好')), '你好');
    });

    test('带 BOM 的 UTF-8 去掉 U+FEFF', () {
      final bytes = utf8.encode('\uFEFF标题');
      expect(decodeImportedTextBytes(bytes), '标题');
    });

    test('GBK 中文解码为 Unicode', () {
      final bytes = const GbkCodec().encode('中文标题');
      expect(decodeImportedTextBytes(bytes), '中文标题');
    });

    test('非法字节抛 FormatException', () {
      expect(
        () => decodeImportedTextBytes([0xFF, 0xFE]),
        throwsFormatException,
      );
    });
  });
}
