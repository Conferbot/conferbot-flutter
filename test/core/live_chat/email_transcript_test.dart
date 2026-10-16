// "Email me this chat" as the web's ts/chat/emailTranscript.ts (#42), the
// cases of the React Native SDK's __tests__/core/emailTranscript.test.ts.
import 'package:conferbot_flutter/src/core/live_chat/email_transcript.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('checks the address as the web does', () {
    expect(EmailTranscript.isEmail('ada@example.com'), isTrue);
    expect(EmailTranscript.isEmail('  ada@example.co '), isTrue);
    expect(EmailTranscript.isEmail('ada@example.c'), isFalse);
    expect(EmailTranscript.isEmail('ada@example'), isFalse);
    expect(EmailTranscript.isEmail('a da@example.com'), isFalse);
    expect(EmailTranscript.isEmail(''), isFalse);
  });

  test("posts the session and the address to the mobile path (the bot is the header's)", () {
    expect(EmailTranscript.path, '/chat/transcript-email');
    expect(EmailTranscript.body('s-1', ' ada@example.com '), {'chatSessionId': 's-1', 'email': 'ada@example.com'});
  });

  test('reads the answer: sent only on success true', () {
    expect(EmailTranscript.resultOf(200, {'success': true}), const TranscriptEmailResult(true));
    expect(
      EmailTranscript.resultOf(200, {'success': false, 'message': "We couldn't email the transcript. Please try again later."}),
      const TranscriptEmailResult(false, "We couldn't email the transcript. Please try again later."),
    );
    expect(EmailTranscript.resultOf(400, {'success': false, 'message': 'Please enter a valid email address.'}).message,
        'Please enter a valid email address.');
    expect(EmailTranscript.resultOf(429, {'error': true, 'message': 'Too many requests. Please try again later.'}),
        const TranscriptEmailResult(false, 'Too many requests. Please try again later.'));
    expect(EmailTranscript.resultOf(500, {'success': false}), const TranscriptEmailResult(false));
    expect(EmailTranscript.resultOf(201, {'success': 'yes'}), const TranscriptEmailResult(false));
    expect(EmailTranscript.resultOf(200, null), const TranscriptEmailResult(false));
  });

  test("says the server's reason, else ours", () {
    expect(EmailTranscript.errorOf(const TranscriptEmailResult(false, 'Too many requests. Please try again later.')),
        'Too many requests. Please try again later.');
    expect(EmailTranscript.errorOf(const TranscriptEmailResult(false)), EmailTranscript.sendFailed);
    expect(EmailTranscript.errorOf(null), EmailTranscript.sendFailed);
    expect(EmailTranscript.sent('ada@example.com'), 'Sent! Check your inbox at ada@example.com');
  });
}
