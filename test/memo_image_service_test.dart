import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/services/memo_image_service.dart';
import 'package:path/path.dart' as p;

void main() {
  group('MemoImageService', () {
    late MemoImageService service;
    late Directory tempDir;

    setUp(() {
      service = MemoImageService();
      tempDir = Directory.systemTemp.createTempSync('mind_recall_image_test');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('uniqueFileName avoids collisions', () {
      File(p.join(tempDir.path, 'photo.png')).writeAsStringSync('a');

      final name = service.uniqueFileNameForTest(tempDir, 'photo.png');
      expect(name, 'photo_1.png');
    });

    test('resolvePath resolves relative asset path from memo directory', () {
      final memoDir = p.join(tempDir.path, 'MindRecall');
      Directory(memoDir).createSync();
      final uri = Uri.parse('./123_assets/photo.png');

      final resolved = service.resolvePathForTest(memoDir, uri);
      expect(resolved, p.normalize(p.join(memoDir, '123_assets/photo.png')));
    });

    test('resolvePath rejects paths outside memo directory', () {
      final memoDir = p.join(tempDir.path, 'MindRecall');
      Directory(memoDir).createSync();
      final uri = Uri.parse('../outside.png');

      expect(service.resolvePathForTest(memoDir, uri), isNull);
    });
  });
}
