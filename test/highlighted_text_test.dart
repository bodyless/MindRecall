import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/shared/widgets/highlighted_text.dart';

void main() {
  testWidgets('HighlightedText highlights multiple keywords', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HighlightedText(
            text: 'Flutter search and Dart keywords',
            keywords: const ['Flutter', 'Dart'],
            caseSensitive: false,
          ),
        ),
      ),
    );

    expect(find.textContaining('Flutter'), findsOneWidget);
    expect(find.textContaining('Dart'), findsOneWidget);
  });

  test('splitKeywords splits on whitespace', () {
    expect(
      HighlightedText.splitKeywords('foo bar  baz'),
      ['foo', 'bar', 'baz'],
    );
  });
}
