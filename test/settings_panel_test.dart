import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/l10n/app_localizations.dart';
import 'package:mind_recall/models/user_preferences.dart';
import 'package:mind_recall/services/user_preferences_service.dart';
import 'package:mind_recall/shared/widgets/settings_panel.dart';

class _FakePrefsService extends UserPreferencesService {
  _FakePrefsService(this._prefs);

  UserPreferences _prefs;

  @override
  UserPreferences get preferences => _prefs;

  @override
  Future<void> save(UserPreferences preferences) async {
    _prefs = preferences;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(Widget child) {
    return MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }

  testWidgets('groups controls into Format Data and Debug sections',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        SettingsPanel(
          prefsService: UserPreferencesService(),
          onThemeModeChanged: (_) {},
          onLocaleChanged: (_) {},
          onFontSizeChanged: (_) {},
          onDebugToolsChanged: (_) {},
          onDebugShowFpsChanged: (_) {},
          onDebugShowImeHudChanged: (_) {},
          onDebugShowCursorHudChanged: (_) {},
          onExportData: () {},
          onImportData: () {},
          onEmptyTrash: () {},
          onRestoreFromTrash: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('格式'), findsOneWidget);
    expect(find.text('数据'), findsOneWidget);
    expect(kDebugMode, isTrue);
    expect(find.text('调试'), findsOneWidget);
    expect(find.text('启用调试'), findsOneWidget);
    // 总开关默认关：子开关隐藏。
    expect(find.text('显示帧率'), findsNothing);
    expect(find.text('显示IME状态'), findsNothing);
    expect(find.text('显示光标状态'), findsNothing);
  });

  testWidgets('shows debug sub switches only when master enabled',
      (tester) async {
    final prefs = _FakePrefsService(
      const UserPreferences(
        themeMode: ThemeMode.light,
        localeCode: 'zh',
        debugToolsEnabled: true,
      ),
    );

    await tester.pumpWidget(
      wrap(
        SettingsPanel(
          prefsService: prefs,
          onThemeModeChanged: (_) {},
          onLocaleChanged: (_) {},
          onFontSizeChanged: (_) {},
          onDebugToolsChanged: (_) {},
          onDebugShowFpsChanged: (_) {},
          onDebugShowImeHudChanged: (_) {},
          onDebugShowCursorHudChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('显示帧率'), findsOneWidget);
    expect(find.text('显示IME状态'), findsOneWidget);
    expect(find.text('显示光标状态'), findsOneWidget);
  });
}
