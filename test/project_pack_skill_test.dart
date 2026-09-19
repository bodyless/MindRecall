import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String skill;

  setUpAll(() {
    skill = File('.cursor/skills/project-pack/SKILL.md').readAsStringSync();
  });

  test('project-pack 按标准包体名打 debug/release APK，且不改版本号', () {
    expect(skill.contains('name: project-pack'), isTrue);
    expect(
      skill.contains('mind_recall_<versionName>_<debug|release>.apk'),
      isTrue,
    );
    expect(skill.contains('flutter build apk --release'), isTrue);
    expect(skill.contains('flutter build apk --debug'), isTrue);
    expect(skill.contains('打包不加版本'), isTrue);
    expect(skill.contains('打一个release包或者打个debug'), isTrue);
  });
}
