// Masking sensitive details (customizations.redactSensitive), as the web
// widget's privacy/redact.ts (ported from RN __tests__/core/redact.test.ts).
import 'package:conferbot_flutter/src/core/privacy/redact.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('redactSensitive', () {
    test('masks card numbers (Luhn), IBANs, ids, passwords, codes and keys - never e-mails or phones', () {
      final card = redactText('my card 4242 4242 4242 4242 ok');
      expect(card.text, 'my card [card •••• 4242] ok');
      expect(card.found, ['card']);
      expect(redactText('order 4242424242424241').found, isEmpty);
      expect(redactText('IBAN GB82 WEST 1234 5698 7654 32').text, 'IBAN [bank account hidden]');
      expect(redactText('ssn 123-45-6789').text, 'ssn [id hidden]');
      expect(redactText('my password is hunter22').text, 'my password is [hidden]');
      expect(redactText('the otp 482913').text, 'the otp [hidden]');
      expect(redactText('key sk_live_abcdefghijklmnop1234').text, 'key [secret key hidden]');
      expect(redactText('ana+4242424242424242@acme.io, +1 555 123 4567').found, isEmpty);
    });

    test("masks only the visitor's own record entries", () {
      expect(maskRecordEntry(<String, dynamic>{'shape': 'user-ask-custom-question-response', 'text': '4242424242424242'}), {
        'shape': 'user-ask-custom-question-response',
        'text': '[card •••• 4242]',
        'redacted': ['card'],
      });
      expect(maskRecordEntry(<String, dynamic>{'type': 'message-node', 'text': '4242424242424242'})['text'], '4242424242424242');
      expect(maskValue(42), 42);
    });
  });
}
