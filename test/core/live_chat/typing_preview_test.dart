// Typing preview (lib/src/core/live_chat/typing_preview.dart): the React
// Native SDK's __tests__/core/typingPreview.test.ts ported (web
// ts/chat/typingPreview.ts and index.ts updateVisitorDraft).
import 'package:conferbot_flutter/src/core/live_chat/typing_preview.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('trims and caps a draft', () {
    expect(TypingPreview.cleanDraft('  hi  '), 'hi');
    expect(TypingPreview.cleanDraft('x' * (TypingPreview.maxLength + 10)), hasLength(TypingPreview.maxLength));
    expect(TypingPreview.cleanDraft(5), '');
  });

  test('sends at most every 300 ms, the latest text trailing, and one empty draft to clear', () {
    var now = 0;
    var seq = 0;
    final timers = <({int at, void Function() fn, int id})>[];
    void advance(int ms) {
      now += ms;
      timers.sort((a, b) => a.at.compareTo(b.at));
      while (timers.isNotEmpty && timers.first.at <= now) {
        timers.removeAt(0).fn();
      }
    }

    final sent = <String>[];
    final s = DraftSender(
      sent.add,
      now: () => now,
      setTimer: (fn, ms) {
        timers.add((at: now + ms, fn: fn, id: ++seq));
        return seq;
      },
      clearTimer: (id) => timers.removeWhere((t) => t.id == id),
    );
    s.update('h');
    s.update('he');
    s.update('hel');
    expect(sent, ['h']);
    advance(299);
    expect(sent, ['h']);
    advance(1);
    expect(sent, ['h', 'hel']);
    s.update('hel ');
    advance(300);
    expect(sent, ['h', 'hel']); // the same text after trimming: nothing new
    s.clear();
    s.clear();
    expect(sent, ['h', 'hel', '']);
    s.update('   ');
    expect(sent, ['h', 'hel', '']);
  });

  test('never previews a secret field', () {
    expect(TypingPreview.isSensitiveField(obscureText: true), isTrue);
    expect(TypingPreview.isSensitiveField(autofillHints: const [AutofillHints.oneTimeCode]), isTrue);
    expect(TypingPreview.isSensitiveField(autofillHints: const [AutofillHints.creditCardNumber]), isTrue);
    expect(TypingPreview.isSensitiveField(autofillHints: const ['cc-number']), isTrue);
    expect(TypingPreview.isSensitiveField(autofillHints: const ['sms-otp']), isTrue);
    expect(TypingPreview.isSensitiveField(autofillHints: const [AutofillHints.password]), isTrue);
    expect(TypingPreview.isSensitiveField(keyboardType: TextInputType.visiblePassword), isTrue);
    expect(TypingPreview.isSensitiveField(autofillHints: const [AutofillHints.email]), isFalse);
    expect(TypingPreview.isSensitiveField(), isFalse);
  });

  test('is on only with a person in the chat, unless the owner turned it off', () {
    expect(TypingPreview.draftPreviewOn(<String, dynamic>{}, true), isTrue);
    expect(TypingPreview.draftPreviewOn({'visitorDraftPreview': false}, true), isFalse);
    expect(TypingPreview.draftPreviewOn(<String, dynamic>{}, false), isFalse);
  });
}
