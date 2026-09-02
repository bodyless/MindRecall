import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/models/user_preferences.dart';
import 'package:mind_recall/services/user_preferences_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:mind_recall/main.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);

  final Directory root;

  @override
  Future<String?> getApplicationSupportPath() async => root.path;

  @override
  Future<String?> getApplicationDocumentsPath() async => root.path;

  @override
  Future<String?> getDownloadsPath() async => root.path;

  @override
  Future<String?> getTemporaryPath() async => root.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;

  setUpAll(() async {
    tempRoot = await Directory.systemTemp.createTemp('mind_recall_widget_');
    PathProviderPlatform.instance = _FakePathProvider(tempRoot);
  });

  tearDownAll(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

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
    PathProviderPlatform.instance = _FakePathProvider(tempRoot);
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MindRecallApp(prefsService: UserPreferencesService()),
    );
    await tester.pump();
    const ioStep = Duration(milliseconds: 50);
    const ioLimit = Duration(seconds: 2);
    var waited = Duration.zero;
    while (find.text('实时').evaluate().isEmpty && waited < ioLimit) {
      await tester.runAsync(() => Future<void>.delayed(ioStep));
      await tester.pump();
      waited += ioStep;
    }

    expect(find.text('实时'), findsWidgets);
    expect(find.text('编辑'), findsWidgets);
  });
}
