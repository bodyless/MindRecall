import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String pubspec;
  late String editor;
  late String patchSkill;
  late String implementSkill;

  setUpAll(() {
    pubspec = File('pubspec.yaml').readAsStringSync();
    editor = File('lib/features/memo/editor/memo_editor_screen.dart')
        .readAsStringSync();
    patchSkill = File('.cursor/skills/mode-patch/SKILL.md').readAsStringSync();
    implementSkill =
        File('.cursor/skills/mode-implement/SKILL.md').readAsStringSync();
  });

  test('pubspec 顶层 version 为 大.小.迭代 且不含 +', () {
    String? value;
    for (final line in pubspec.split('\n')) {
      final trimmed = line.trimRight();
      if (trimmed.startsWith('#')) {
        continue;
      }
      final match = RegExp(r'^version:\s*(.+)$').firstMatch(trimmed);
      if (match != null) {
        value = match.group(1)!.trim();
        break;
      }
    }
    expect(value, isNotNull);
    expect(value!.contains('+'), isFalse);
    expect(RegExp(r'^\d+\.\d+\.\d+$').hasMatch(value), isTrue);
  });

  test('_loadAppVersionLabel 只赋 info.version，不拼接 buildNumber', () {
    expect(editor.contains('_appVersionLabel = info.version'), isTrue);
    expect(editor.contains(r'${info.version}+${info.buildNumber}'), isFalse);
    expect(editor.contains('buildNumber'), isFalse);
  });

  test('mode-patch 成功交付后迭代 +1', () {
    expect(patchSkill.contains('迭代 +1'), isTrue);
  });

  test('mode-implement 全部勾完后小版本 +1、迭代置 0', () {
    expect(implementSkill.contains('小版本 +1、迭代置 0'), isTrue);
  });
}
