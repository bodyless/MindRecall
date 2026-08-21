import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String gradle;

  setUpAll(() {
    gradle = File('android/app/build.gradle.kts').readAsStringSync();
  });

  test('APK 产物名为 mind_recall_<versionName>_<debug|release>.apk', () {
    expect(gradle.contains('val apkArtifactBaseName = "mind_recall"'), isTrue);
    expect(
      gradle.contains(
        r'"${apkArtifactBaseName}_${variant.versionName}_${buildTypeName}.apk"',
      ),
      isTrue,
    );
    expect(gradle.contains('outputFileName = apkFileName'), isTrue);
    expect(gradle.contains(r'val flutterCliApkName = "app-$buildTypeName.apk"'), isTrue);
    expect(gradle.contains('src.copyTo(File(destDir, flutterCliApkName), overwrite = true)'), isTrue);
  });
}
