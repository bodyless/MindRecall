import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/user_preferences.dart';

class UserPreferencesService {
  UserPreferencesService({Directory? documentsDirectory})
      : _documentsDirectory = documentsDirectory;

  static const fileName = 'user_preferences.json';

  final Directory? _documentsDirectory;
  UserPreferences _preferences = UserPreferences.defaults();

  UserPreferences get preferences => _preferences;

  /// 偏好文件绝对路径（导出 / 导入用）。
  Future<File> preferencesFile() => _preferencesFile();

  Future<UserPreferences> load() async {
    try {
      final file = await _preferencesFile();
      if (!await file.exists()) {
        _preferences = UserPreferences.defaults();
        return _preferences;
      }

      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        _preferences = UserPreferences.defaults();
        return _preferences;
      }

      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) {
        _preferences = UserPreferences.defaults();
        return _preferences;
      }

      _preferences = UserPreferences.fromJson(json);
      return _preferences;
    } catch (_) {
      _preferences = UserPreferences.defaults();
      return _preferences;
    }
  }

  Future<void> save(UserPreferences preferences) async {
    _preferences = preferences;
    final file = await _preferencesFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(preferences.toJson()),
    );
  }

  Future<void> updateThemeMode(ThemeMode themeMode) {
    return save(_preferences.copyWith(themeMode: themeMode));
  }

  Future<void> updateLocale(Locale locale) {
    return save(_preferences.copyWith(localeCode: locale.languageCode));
  }

  Future<void> updateLastOpenedMemoId(String? memoId) {
    if (memoId == null) {
      return save(_preferences.copyWith(clearLastOpenedMemoId: true));
    }
    return save(_preferences.copyWith(lastOpenedMemoId: memoId));
  }

  Future<void> updateFontSize(AppFontSize fontSize) {
    return save(_preferences.copyWith(fontSize: fontSize));
  }

  Future<void> updateDebugToolsEnabled(bool enabled) {
    return save(_preferences.copyWith(debugToolsEnabled: enabled));
  }

  Future<void> updateDebugShowFps(bool enabled) {
    return save(_preferences.copyWith(debugShowFps: enabled));
  }

  Future<void> updateDebugShowImeHud(bool enabled) {
    return save(_preferences.copyWith(debugShowImeHud: enabled));
  }

  Future<void> updateDebugShowCursorHud(bool enabled) {
    return save(_preferences.copyWith(debugShowCursorHud: enabled));
  }

  Future<File> _preferencesFile() async {
    final appDir =
        _documentsDirectory ?? await getApplicationDocumentsDirectory();
    return File(p.join(appDir.path, fileName));
  }
}
