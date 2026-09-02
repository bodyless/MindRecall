import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/models/memo_folder.dart';

void main() {
  group('MemoFolder.parseColorHex', () {
    test('合法 #RRGGBB 归一成大写', () {
      expect(MemoFolder.parseColorHex('#aabbcc'), '#AABBCC');
      expect(MemoFolder.parseColorHex('  #A1B2C3  '), '#A1B2C3');
    });

    test('非法值返回 null', () {
      expect(MemoFolder.parseColorHex(null), isNull);
      expect(MemoFolder.parseColorHex(123), isNull);
      expect(MemoFolder.parseColorHex(''), isNull);
      expect(MemoFolder.parseColorHex('red'), isNull);
      expect(MemoFolder.parseColorHex('#RGB'), isNull);
      expect(MemoFolder.parseColorHex('#AABBCCDD'), isNull);
      expect(MemoFolder.parseColorHex('AABBCC'), isNull);
    });
  });

  test('formatColorHex 输出 #RRGGBB 大写', () {
    expect(
      MemoFolder.formatColorHex(r: 10, g: 16, b: 255),
      '#0A10FF',
    );
    expect(
      MemoFolder.formatColorHex(r: 0, g: 0, b: 0),
      '#000000',
    );
  });
}
