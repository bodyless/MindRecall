import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/core/debug/live_editor_timeline.dart';

void main() {
  group('liveApplyBlockTypeArgs', () {
    test('组装 from/to/layoutChanged/didSetState', () {
      expect(
        liveApplyBlockTypeArgs(
          from: 'H1',
          to: 'H2',
          layoutChanged: false,
          didSetState: false,
        ),
        {
          'from': 'H1',
          'to': 'H2',
          'layoutChanged': 'false',
          'didSetState': 'false',
        },
      );
    });
  });

  group('formatLiveTapDebugLog', () {
    test('固定前缀且字段与 HUD 一致', () {
      final log = formatLiveTapDebugLog(
        phase: 'overlay.pointer',
        overlayHit: true,
        overlayInView: true,
        imeSessionFocused: true,
        editorFocused: true,
        languageFocused: false,
        sameBlockTapDiscarded: false,
        path: 'switch',
        pending: 'used',
        canFocus: true,
        hasFocus: true,
      );
      expect(log.startsWith('[LiveTap] '), isTrue);
      expect(log, contains('phase=overlay.pointer'));
      expect(log, contains('ovHit=1'));
      expect(log, contains('ovView=1'));
      expect(log, contains('imeF=1'));
      expect(log, contains('edF=1'));
      expect(log, contains('langF=0'));
      expect(log, contains('sameTap=0'));
      expect(log, contains('path=switch'));
      expect(log, contains('pending=used'));
      expect(log, contains('canFocus=1'));
      expect(log, contains('hasFocus=1'));
    });
  });
}
