import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/features/memo/editor/widgets/memo_markdown_preview.dart';
import 'package:mind_recall/l10n/app_localizations.dart';
import 'package:mind_recall/theme/app_theme.dart';

const _longPreviewParagraphCount = 40;
const _previewViewport = Size(800, 400);

String _longPreviewMarkdown() {
  return List.generate(
    _longPreviewParagraphCount,
    (index) => '段落 $index 用于预览滚动',
  ).join('\n\n');
}

Future<void> _pumpPreview(
  WidgetTester tester, {
  required TargetPlatform platform,
}) async {
  await tester.binding.setSurfaceSize(_previewViewport);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light.copyWith(platform: platform),
      home: Scaffold(body: MemoMarkdownPreview(content: _longPreviewMarkdown())),
    ),
  );
  await tester.pump();
}

void main() {

  testWidgets('windows wheel scrolls preview without scrollbar error', (
    tester,
  ) async {
    await _pumpPreview(tester, platform: TargetPlatform.windows);

    final scrollbar = tester.widget<Scrollbar>(find.byType(Scrollbar));
    final list = tester.widget<ListView>(find.byType(ListView));
    expect(scrollbar.controller, isNotNull);
    expect(list.controller, same(scrollbar.controller));

    final center = tester.getCenter(find.byType(ListView));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: center);
    await gesture.moveTo(center);
    await tester.sendEventToBinding(
      PointerScrollEvent(position: center, scrollDelta: const Offset(0, 120)),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;
    expect(position.pixels, greaterThan(0));
  });

  testWidgets('android preview keeps primary scroll controller unset', (
    tester,
  ) async {
    await _pumpPreview(tester, platform: TargetPlatform.android);

    expect(tester.widget<Scrollbar>(find.byType(Scrollbar)).controller, isNull);
    expect(tester.widget<ListView>(find.byType(ListView)).controller, isNull);

    await tester.drag(find.byType(ListView), const Offset(0, -240));
    await tester.pump();

    expect(tester.takeException(), isNull);
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;
    expect(position.pixels, greaterThan(0));
  });
}
