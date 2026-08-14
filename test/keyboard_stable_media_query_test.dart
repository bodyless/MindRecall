import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/core/ui/keyboard_stable_media_query.dart';

void main() {
  group('mediaQueryDataEqualsIgnoringViewInsets', () {
    test('true when only viewInsets differ', () {
      const base = MediaQueryData(
        size: Size(390, 844),
        devicePixelRatio: 2.75,
        padding: EdgeInsets.only(top: 47, bottom: 34),
        viewPadding: EdgeInsets.only(top: 47, bottom: 34),
      );
      final withKeyboard = base.copyWith(
        viewInsets: const EdgeInsets.only(bottom: 300),
      );
      expect(
        mediaQueryDataEqualsIgnoringViewInsets(base, withKeyboard),
        isTrue,
      );
    });

    test('false when size changes', () {
      const a = MediaQueryData(size: Size(390, 844));
      const b = MediaQueryData(size: Size(390, 600));
      expect(mediaQueryDataEqualsIgnoringViewInsets(a, b), isFalse);
    });

    test('false when textScaler changes', () {
      const a = MediaQueryData(size: Size(390, 844));
      final b = a.copyWith(textScaler: const TextScaler.linear(1.2));
      expect(mediaQueryDataEqualsIgnoringViewInsets(a, b), isFalse);
    });
  });
}
