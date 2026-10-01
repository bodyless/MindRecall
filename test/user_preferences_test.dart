import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/models/user_preferences.dart';

void main() {
  test('copyWith can clear last opened memo id', () {
    const prefs = UserPreferences(
      themeMode: ThemeMode.light,
      localeCode: 'zh',
      lastOpenedMemoId: '123',
    );

    final cleared = prefs.copyWith(clearLastOpenedMemoId: true);
    expect(cleared.lastOpenedMemoId, isNull);
    expect(cleared.themeMode, ThemeMode.light);
    expect(cleared.localeCode, 'zh');
  });

  test('serializes debug master and sub switches', () {
    const prefs = UserPreferences(
      themeMode: ThemeMode.dark,
      localeCode: 'en',
      debugToolsEnabled: true,
      debugShowFps: false,
      debugShowImeHud: true,
      debugShowCursorHud: false,
    );
    final restored = UserPreferences.fromJson(prefs.toJson());
    expect(restored.debugToolsEnabled, isTrue);
    expect(restored.debugShowFps, isFalse);
    expect(restored.debugShowImeHud, isTrue);
    expect(restored.debugShowCursorHud, isFalse);
  });

  test('serializes file list sort and defaults when missing', () {
    const prefs = UserPreferences(
      themeMode: ThemeMode.light,
      localeCode: 'zh',
      fileListSort: FileListSort.name,
    );
    final restored = UserPreferences.fromJson(prefs.toJson());
    expect(restored.fileListSort, FileListSort.name);

    final missing = UserPreferences.fromJson({
      'themeMode': 'light',
      'localeCode': 'zh',
    });
    expect(missing.fileListSort, FileListSort.modifiedTime);

    final unknown = UserPreferences.fromJson({
      'themeMode': 'light',
      'localeCode': 'zh',
      'fileListSort': 'size',
    });
    expect(unknown.fileListSort, FileListSort.modifiedTime);
  });

  test('missing debug sub switch keys default to true', () {
    final restored = UserPreferences.fromJson({
      'themeMode': 'light',
      'localeCode': 'zh',
      'debugToolsEnabled': true,
    });
    expect(restored.debugShowFps, isTrue);
    expect(restored.debugShowImeHud, isTrue);
    expect(restored.debugShowCursorHud, isTrue);
  });
}
