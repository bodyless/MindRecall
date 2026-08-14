import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/models/user_preferences.dart';
import 'package:mind_recall/services/user_preferences_service.dart';

import 'package:mind_recall/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UserPreferences', () {
    test('serializes theme, locale, font size and last opened memo', () {
      const prefs = UserPreferences(
        themeMode: ThemeMode.dark,
        localeCode: 'en',
        lastOpenedMemoId: '12345',
        fontSize: AppFontSize.large,
        debugToolsEnabled: true,
        debugShowFps: false,
        debugShowImeHud: true,
        debugShowCursorHud: false,
      );

      final restored = UserPreferences.fromJson(prefs.toJson());
      expect(restored.themeMode, ThemeMode.dark);
      expect(restored.localeCode, 'en');
      expect(restored.lastOpenedMemoId, '12345');
      expect(restored.fontSize, AppFontSize.large);
      expect(restored.debugToolsEnabled, isTrue);
      expect(restored.debugShowFps, isFalse);
      expect(restored.debugShowImeHud, isTrue);
      expect(restored.debugShowCursorHud, isFalse);
    });

    test('defaults to light theme, Chinese locale and medium font', () {
      final restored = UserPreferences.fromJson({});
      expect(restored.themeMode, ThemeMode.light);
      expect(restored.localeCode, 'zh');
      expect(restored.lastOpenedMemoId, isNull);
      expect(restored.fontSize, AppFontSize.medium);
      expect(restored.debugToolsEnabled, isFalse);
      expect(restored.debugShowFps, isTrue);
      expect(restored.debugShowImeHud, isTrue);
      expect(restored.debugShowCursorHud, isTrue);
    });
  });

  testWidgets('Memo workspace loads', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MindRecallApp(prefsService: UserPreferencesService()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('实时'), findsWidgets);
    expect(find.text('编辑'), findsWidgets);
  });
}
