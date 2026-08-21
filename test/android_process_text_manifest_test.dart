import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String manifest;
  late String trampoline;

  setUpAll(() {
    manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    trampoline = File(
      'android/app/src/main/java/com/wishtech/mind_recall/ProcessTextActivity.java',
    ).readAsStringSync();
  });

  test('PROCESS_TEXT 注册在 trampoline，不挂 Flutter MainActivity', () {
    expect(manifest.contains('android:name=".ProcessTextActivity"'), isTrue);
    expect(manifest.contains('<activity-alias'), isFalse);

    final mainName = manifest.indexOf('android:name=".MainActivity"');
    expect(mainName, greaterThanOrEqualTo(0));
    final mainEnd = manifest.indexOf('</activity>', mainName);
    expect(mainEnd, greaterThan(mainName));
    final mainBlock = manifest.substring(mainName, mainEnd);
    expect(mainBlock.contains('PROCESS_TEXT'), isFalse);
  });

  test('trampoline 以 NEW_TASK 转交并立刻 finish，不写回选区', () {
    expect(trampoline.contains('extends Activity'), isTrue);
    expect(trampoline.contains('FlutterActivity'), isFalse);
    expect(trampoline.contains('FLAG_ACTIVITY_NEW_TASK'), isTrue);
    expect(trampoline.contains('RESULT_CANCELED'), isTrue);
    expect(trampoline.contains('finish()'), isTrue);
  });
}
