import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mind_recall/core/debug/debug_fps_overlay.dart';
import 'package:mind_recall/core/debug/debug_info_overlay.dart';
import 'package:mind_recall/core/debug/debug_timeline.dart';
import 'package:mind_recall/core/ui/keyboard_stable_media_query.dart';
import 'package:mind_recall/core/ui/ime_height_cache.dart';
import 'package:mind_recall/l10n/app_localizations.dart';

import 'package:mind_recall/features/memo/editor/memo_editor_screen.dart';
import 'package:mind_recall/models/user_preferences.dart';
import 'services/ime_height_cache_store.dart';
import 'services/user_preferences_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefsService = UserPreferencesService();
  await debugTimelineAsync('App.prefsLoad', prefsService.load);
  final imeHeightCacheStore = ImeHeightCacheStore(cache: defaultImeHeightCache);
  await debugTimelineAsync(
    'App.imeHeightCacheLoad',
    imeHeightCacheStore.loadAndAttach,
  );

  runApp(MindRecallApp(prefsService: prefsService));
}

class MindRecallApp extends StatefulWidget {
  const MindRecallApp({
    super.key,
    required this.prefsService,
  });

  final UserPreferencesService prefsService;

  @override
  State<MindRecallApp> createState() => _MindRecallAppState();
}

class _MindRecallAppState extends State<MindRecallApp> {
  late ThemeMode _themeMode;
  late Locale _locale;
  late AppFontSize _fontSize;
  late bool _debugToolsEnabled;
  late bool _debugShowFps;
  late bool _debugShowImeHud;
  late bool _debugShowCursorHud;

  @override
  void initState() {
    super.initState();
    final prefs = widget.prefsService.preferences;
    _themeMode = prefs.themeMode;
    _locale = prefs.locale;
    _fontSize = prefs.fontSize;
    _debugToolsEnabled = prefs.debugToolsEnabled;
    _debugShowFps = prefs.debugShowFps;
    _debugShowImeHud = prefs.debugShowImeHud;
    _debugShowCursorHud = prefs.debugShowCursorHud;
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    await widget.prefsService.updateThemeMode(mode);
  }

  Future<void> _setLocale(Locale locale) async {
    setState(() => _locale = locale);
    await widget.prefsService.updateLocale(locale);
  }

  Future<void> _setFontSize(AppFontSize fontSize) async {
    setState(() => _fontSize = fontSize);
    await widget.prefsService.updateFontSize(fontSize);
  }

  Future<void> _setDebugToolsEnabled(bool enabled) async {
    setState(() => _debugToolsEnabled = enabled);
    await widget.prefsService.updateDebugToolsEnabled(enabled);
  }

  Future<void> _setDebugShowFps(bool enabled) async {
    setState(() => _debugShowFps = enabled);
    await widget.prefsService.updateDebugShowFps(enabled);
  }

  Future<void> _setDebugShowImeHud(bool enabled) async {
    setState(() => _debugShowImeHud = enabled);
    await widget.prefsService.updateDebugShowImeHud(enabled);
  }

  Future<void> _setDebugShowCursorHud(bool enabled) async {
    setState(() => _debugShowCursorHud = enabled);
    await widget.prefsService.updateDebugShowCursorHud(enabled);
  }

  @override
  Widget build(BuildContext context) {
    final showFps =
        kDebugMode && _debugToolsEnabled && _debugShowFps;
    final showImeHud =
        kDebugMode && _debugToolsEnabled && _debugShowImeHud;
    final showCursorHud =
        kDebugMode && _debugToolsEnabled && _debugShowCursorHud;

    return MaterialApp(
      title: 'Mind Recall',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,
      themeAnimationDuration: Duration.zero,
      locale: _locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) {
        // 禁止 MediaQuery.of：键盘 viewInsets 每帧会重建整棵子树。
        Widget content = KeyboardStableMediaQuery(
          textScale: _fontSize.scale,
          child: child ?? const SizedBox.shrink(),
        );
        if (showFps || showImeHud || showCursorHud) {
          content = Stack(
            fit: StackFit.expand,
            children: [
              content,
              if (showImeHud || showCursorHud)
                DebugInfoOverlay(
                  showImeHud: showImeHud,
                  showCursorHud: showCursorHud,
                ),
              if (showFps) const DebugFpsOverlay(),
            ],
          );
        }
        return content;
      },
      home: MemoEditorScreen(
        themeMode: _themeMode,
        localeCode: _locale.languageCode,
        onThemeChanged: (mode) => unawaited(_setThemeMode(mode)),
        onLocaleChanged: (locale) => unawaited(_setLocale(locale)),
        onFontSizeChanged: (size) => unawaited(_setFontSize(size)),
        onDebugToolsChanged: kDebugMode
            ? (enabled) => unawaited(_setDebugToolsEnabled(enabled))
            : null,
        onDebugShowFpsChanged: kDebugMode
            ? (enabled) => unawaited(_setDebugShowFps(enabled))
            : null,
        onDebugShowImeHudChanged: kDebugMode
            ? (enabled) => unawaited(_setDebugShowImeHud(enabled))
            : null,
        onDebugShowCursorHudChanged: kDebugMode
            ? (enabled) => unawaited(_setDebugShowCursorHud(enabled))
            : null,
        prefsService: widget.prefsService,
      ),
    );
  }
}
