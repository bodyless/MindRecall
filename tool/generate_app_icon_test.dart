import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/branding/app_icon_painter.dart';
import 'package:path/path.dart' as p;

/// 用 Flutter Canvas 导出应用图标 PNG。
///
/// ```bash
/// flutter test tool/generate_app_icon_test.dart
/// dart run flutter_launcher_icons
/// ```
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generate app icon png via Flutter canvas', () async {
    final root = Directory.current.path;
    final outDir = Directory(p.join(root, 'assets', 'branding'));
    if (!outDir.existsSync()) {
      outDir.createSync(recursive: true);
    }

    final fullBytes = await AppIconPainter.renderPngBytes(pixelSize: 1024);
    expect(fullBytes.length, greaterThan(1000));
    await File(p.join(outDir.path, 'app_icon.png')).writeAsBytes(fullBytes);

    final fgBytes = await AppIconPainter.renderPngBytes(
      pixelSize: 1024,
      withBackground: false,
    );
    await File(p.join(outDir.path, 'app_icon_foreground.png'))
        .writeAsBytes(fgBytes);

    // ignore: avoid_print
    print('Wrote ${p.join(outDir.path, 'app_icon.png')}');
  });
}
