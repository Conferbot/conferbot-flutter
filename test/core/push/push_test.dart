// Push notifications (core/push/push.dart; embed-server #189
// docs/mobile-push.md), RN's __tests__/core/push.test.ts ported: the
// payload recognised, the request bodies, the server's answers, and the
// registrar that keeps the token with the current conversation.
import 'dart:async';

import 'package:conferbot_flutter/src/core/push/push.dart';
import 'package:flutter_test/flutter_test.dart';

const _data = {
  'source': 'conferbot',
  'type': 'conferbot_message',
  'botId': 'bot1',
  'chatSessionId': 's1',
  'messageId': 'm1',
  'senderType': 'agent',
  'senderName': 'Maya',
  'body': 'Your order ships today',
};
const _parsed = ConferbotPush(
  botId: 'bot1',
  chatSessionId: 's1',
  messageId: 'm1',
  senderType: 'agent',
  senderName: 'Maya',
  body: 'Your order ships today',
);

void main() {
  group('the payload (FCM data / APNs custom keys)', () {
    test('reads the flat data map', () {
      expect(ConferbotPush.parse(_data), _parsed);
      expect(ConferbotPush.isConferbot(_data), isTrue);
      expect(_parsed.fromPerson, isTrue);
    });

    test('reads it under data or userInfo, and APNs keys beside aps', () {
      expect(ConferbotPush.parse({'data': _data}), _parsed);
      expect(ConferbotPush.parse({'userInfo': _data}), _parsed);
      expect(
        ConferbotPush.parse({
          'aps': {
            'alert': {'title': 'Maya', 'body': 'x'},
            'thread-id': 's1',
          },
          ..._data,
        }),
        _parsed,
      );
    });

    test('is not another app\'s, another type, or without a conversation', () {
      expect(ConferbotPush.parse({..._data, 'source': 'other'}), isNull);
      expect(ConferbotPush.parse({..._data, 'type': 'promo'}), isNull);
      expect(ConferbotPush.parse({..._data, 'chatSessionId': ''}), isNull);
      expect(ConferbotPush.parse({..._data}..remove('botId')), isNull);
      expect(ConferbotPush.parse(null), isNull);
      expect(ConferbotPush.parse('conferbot'), isNull);
      expect(ConferbotPush.isConferbot({'data': {'foo': 'bar'}}), isFalse);
    });

    test('a missing messageId is "", an unknown sender the AI', () {
      final p = ConferbotPush.parse({..._data, 'senderType': 'x'}..remove('messageId'))!;
      expect(p.messageId, '');
      expect(p.senderType, 'bot');
      expect(p.fromPerson, isFalse);
    });

    test('names the server\'s Android channel', () {
      expect(pushChannelId, 'conferbot_messages');
    });
  });

  group('the requests', () {
    test('posts to the mobile push paths', () {
      expect(pushRegisterPath, '/push/register');
      expect(pushUnregisterPath, '/push/unregister');
      expect(pushUnregisterBody('t'), {'token': 't'});
    });

    test('sends the token, the conversation and the token type', () {
      expect(pushRegisterBody('tok', 's1', PushTokenType.fcm), {'token': 'tok', 'chatSessionId': 's1', 'tokenType': 'fcm'});
      expect(pushRegisterBody('tok', 's1', PushTokenType.apns, {'model': 'iPhone', 'osVersion': '18'}), {
        'token': 'tok',
        'chatSessionId': 's1',
        'tokenType': 'apns',
        'deviceInfo': {'model': 'iPhone', 'osVersion': '18'},
      });
    });

    test('the token type: what the app said, else 64 hex is APNs', () {
      final hex = 'a' * 64;
      expect(pushTokenTypeOf(hex), PushTokenType.apns);
      expect(pushTokenTypeOf(hex, PushTokenType.fcm), PushTokenType.fcm);
      expect(pushTokenTypeOf('fGx:APA91b-abc'), PushTokenType.fcm);
      expect(pushTokenTypeOf('fGx:APA91b-abc', PushTokenType.apns), PushTokenType.apns);
    });

    test('reads the server\'s answers', () {
      const ok = PushRegisterResult.registered();
      PushRegisterResult f(PushRegisterError e) => PushRegisterResult.failed(e);
      expect(PushRegisterResult.of(200, {'success': true, 'data': {'id': 'p'}}), ok);
      expect(PushRegisterResult.of(400, {'success': false, 'error': 'MISSING_SESSION'}), f(PushRegisterError.missingSession));
      expect(PushRegisterResult.of(400, {'success': false, 'error': 'INVALID_TOKEN'}), f(PushRegisterError.invalidToken));
      expect(PushRegisterResult.of(400, {'success': false, 'error': 'MISSING_TOKEN'}), f(PushRegisterError.missingToken));
      expect(PushRegisterResult.of(403, {'success': false, 'error': 'SESSION_FORBIDDEN'}), f(PushRegisterError.sessionForbidden));
      expect(PushRegisterResult.of(404, {'success': false, 'error': 'SESSION_NOT_FOUND'}), f(PushRegisterError.sessionNotFound));
      expect(PushRegisterResult.of(404, 'Not Found'), f(PushRegisterError.sessionNotFound));
      expect(PushRegisterResult.of(500, {'success': false, 'error': 'REGISTER_PUSH_FAILED'}), f(PushRegisterError.server));
      expect(PushRegisterResult.of(200, {'success': false}), f(PushRegisterError.server));
      expect(PushRegisterResult.of(200, {'success': false, 'error': 'NETWORK'}), f(PushRegisterError.server));
    });

    test('tries again only when it may still work', () {
      expect(PushRegisterError.sessionNotFound.retryable, isTrue);
      expect(PushRegisterError.network.retryable, isTrue);
      expect(PushRegisterError.server.retryable, isTrue);
      expect(PushRegisterError.invalidToken.retryable, isFalse);
      expect(PushRegisterError.sessionForbidden.retryable, isFalse);
    });
  });

  group('the registrar', () {
    late List<Map<String, dynamic>> registered;
    late List<String> unregistered;
    late List<Object> answers;

    PushRegistrar make() => PushRegistrar(
          register: (body) async {
            registered.add(body);
            final a = answers.isEmpty ? const PushRegisterResult.registered() : answers.removeAt(0);
            if (a is Exception) throw a;
            return a as PushRegisterResult;
          },
          unregister: (t) async {
            unregistered.add(t);
            return true;
          },
        );

    setUp(() {
      registered = [];
      unregistered = [];
      answers = [];
    });

    const tok = 'fcm-token-123456789012345';

    test('nothing without a token (opt-in) or without a conversation', () async {
      final r = make();
      await r.setSession('s1');
      expect(registered, isEmpty);
      final b = make();
      await b.setToken(tok);
      expect(registered, isEmpty);
    });

    test('registers the token with the conversation, once, and again for each new one', () async {
      final r = make();
      await r.setToken(tok, PushTokenType.fcm);
      await r.setSession('s1');
      await r.poke();
      await r.setSession('s1');
      expect(registered, [
        {'token': tok, 'chatSessionId': 's1', 'tokenType': 'fcm'}
      ]);
      await r.setSession('s2');
      expect(registered.map((b) => b['chatSessionId']), ['s1', 's2']);
      expect(r.registered, (tok, 's2'));
    });

    test('waits for the conversation to reach the server, then registers', () async {
      answers = [const PushRegisterResult.failed(PushRegisterError.sessionNotFound), Exception('offline')];
      final r = make();
      final hex = 'a' * 64;
      await r.setSession('s1');
      await r.setToken(hex);
      expect(r.registered, isNull);
      await r.poke();
      await r.poke();
      expect(r.registered, (hex, 's1'));
      expect(registered.first['tokenType'], 'apns');
      await r.poke();
      expect(registered, hasLength(3));
    });

    test('a refused token or another visitor\'s conversation is not tried again', () async {
      answers = [const PushRegisterResult.failed(PushRegisterError.sessionForbidden)];
      final r = make();
      await r.setSession('s1');
      await r.setToken(tok);
      await r.poke();
      await r.poke();
      expect(registered, hasLength(1));
      await r.setSession('s2');
      expect(registered, hasLength(2));
    });

    test('unregisters on logout and does not register that conversation again', () async {
      final r = make();
      await r.setToken(tok);
      await r.setSession('s1');
      await r.unregister();
      expect(unregistered, [tok]);
      expect(r.registered, isNull);
      await r.poke();
      expect(registered, hasLength(1));
      await r.setSession('s2');
      expect(registered, hasLength(2));
    });

    test('a refreshed token replaces the old one; null unregisters', () async {
      final r = make();
      await r.setSession('s1');
      await r.setToken('old-token-1234567890123456');
      await r.setToken('new-token-1234567890123456');
      expect(unregistered, ['old-token-1234567890123456']);
      expect(registered.map((b) => b['token']), ['old-token-1234567890123456', 'new-token-1234567890123456']);
      await r.setToken(null);
      expect(unregistered, ['old-token-1234567890123456', 'new-token-1234567890123456']);
      expect(r.token, isNull);
      await r.setSession('s2');
      expect(registered, hasLength(2));
    });

    test('one request at a time; a change meanwhile is registered after it', () async {
      final gate = Completer<PushRegisterResult>();
      final bodies = <Map<String, dynamic>>[];
      final r = PushRegistrar(
        register: (body) {
          bodies.add(body);
          return bodies.length == 1 ? gate.future : Future.value(const PushRegisterResult.registered());
        },
        unregister: (_) async => true,
      );
      await r.setToken(tok);
      final first = r.setSession('s1');
      final second = r.setSession('s2');
      expect(bodies, hasLength(1));
      gate.complete(const PushRegisterResult.registered());
      await first;
      await second;
      expect(bodies.map((b) => b['chatSessionId']), ['s1', 's2']);
      expect(r.registered?.$2, 's2');
    });
  });
}
