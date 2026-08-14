import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/features/memo/editor/mode_input_session.dart';

void main() {
  group('EditInputSession', () {
    test('resetKeyboardInsets clears pending and applied inset', () {
      final session = EditInputSession();
      addTearDown(session.dispose);
      session.keyboardBottomInset = 280;
      session.pendingKeyboardInset = 300;
      session.resetKeyboardInsets();
      expect(session.keyboardBottomInset, 0);
      expect(session.pendingKeyboardInset, 0);
    });
  });

  group('LiveInputSession', () {
    test('inputSessionActive follows hadFocus and deferFocusBlur', () {
      final session = LiveInputSession();
      addTearDown(session.dispose);
      expect(session.inputSessionActive, isFalse);

      session.hadFocus = true;
      expect(session.inputSessionActive, isTrue);

      session.hadFocus = false;
      session.deferFocusBlur = true;
      expect(session.inputSessionActive, isTrue);

      session.clearSessionFlags();
      expect(session.hadFocus, isFalse);
      expect(session.deferFocusBlur, isFalse);
      expect(session.inputSessionActive, isFalse);
    });

    test('edit and live use distinct FocusNode and ScrollController', () {
      final edit = EditInputSession();
      final live = LiveInputSession();
      addTearDown(() {
        edit.dispose();
        live.dispose();
      });
      expect(identical(edit.focusNode, live.focusNode), isFalse);
      expect(
        identical(edit.scrollController, live.scrollController),
        isFalse,
      );
    });
  });
}
