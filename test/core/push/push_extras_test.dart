// Push notifications wired (core/push/push_extras.dart; RN's
// usePushNotifications.test.ts ported): the token registered with each
// conversation, unregistered on logout, a Conferbot notification opening
// its conversation. The HTTP calls are fakes.
import 'package:conferbot_flutter/src/core/push/push.dart';
import 'package:conferbot_flutter/src/core/push/push_extras.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, String> _push([Map<String, String> over = const {}]) => {
      'source': 'conferbot',
      'type': 'conferbot_message',
      'botId': 'bot1',
      'chatSessionId': 's1',
      'messageId': 'm1',
      'senderType': 'bot',
      'senderName': 'Pip',
      'body': 'Hi',
      ...over,
    };

class _Host {
  String? session;
  int records = 0;
  bool ready = true;
  bool onScreen = false;
  final calls = <String>[];
  final bodies = <Map<String, dynamic>>[];
  final unregistered = <String>[];
  final answers = <PushRegisterResult>[];
  late final PushExtras push = PushExtras(
    botId: () => 'bot1',
    register: (body) async {
      bodies.add(body);
      return answers.isEmpty ? const PushRegisterResult.registered() : answers.removeAt(0);
    },
    unregister: (t) async {
      unregistered.add(t);
      return true;
    },
    chatSessionId: () => session,
    recordLength: () => records,
    initialized: () => ready,
    chatOnScreen: () => onScreen,
    openChat: () async => calls.add('openChat'),
    showChat: () => calls.add('showChat'),
    openRequest: (id) async => calls.add('openRequest:$id'),
    bumpUnread: () => calls.add('unread'),
    retryDelay: Duration.zero,
  );
}

const _tok = 'fcm:token-abcdefghijklmnop';

void main() {
  group('registration', () {
    test('nothing is sent until the app passes a token', () async {
      final h = _Host()..session = 's1';
      h.push.update();
      h.records = 3;
      h.push.update();
      await pumpEventQueue();
      expect(h.bodies, isEmpty);
    });

    test('registers with the conversation (chatSessionId and tokenType), and again for a new one', () async {
      final h = _Host()..session = 's1';
      await h.push.setToken(_tok, PushTokenType.fcm);
      expect(h.bodies, [
        {'token': _tok, 'chatSessionId': 's1', 'tokenType': 'fcm'}
      ]);
      h.session = 's2';
      h.push.update();
      await pumpEventQueue();
      expect(h.bodies.map((b) => b['chatSessionId']), ['s1', 's2']);
    });

    test('a token before any conversation is registered once there is one', () async {
      final h = _Host();
      await h.push.setToken(_tok);
      expect(h.bodies, isEmpty);
      h.session = 's1';
      h.push.update();
      await pumpEventQueue();
      expect(h.bodies.single['chatSessionId'], 's1');
    });

    test('tries again as the conversation goes on while the server does not have it yet', () async {
      final h = _Host()..session = 's1';
      h.answers.add(const PushRegisterResult.failed(PushRegisterError.sessionNotFound));
      await h.push.setToken(_tok);
      expect(h.push.registrar.registered, isNull);
      h.records = 2;
      h.push.update();
      h.records = 3;
      h.push.update();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await pumpEventQueue();
      expect(h.bodies, hasLength(2));
      expect(h.push.registrar.registered, (_tok, 's1'));
      h.push.dispose();
    });

    test('the retry waits for a burst of messages to settle', () {
      expect(pushRetryDebounce, const Duration(seconds: 1));
    });

    test('unregisters when the user logs out or changes, not when one signs in', () async {
      final h = _Host()..session = 's1';
      h.push.userChanged(null);
      await h.push.setToken(_tok);
      h.push.userChanged('u1');
      await pumpEventQueue();
      expect(h.unregistered, isEmpty);
      h.push.userChanged(null);
      await pumpEventQueue();
      expect(h.unregistered, [_tok]);
    });

    test('stop unregisters', () async {
      final h = _Host()..session = 's1';
      await h.push.setToken(_tok);
      await h.push.stop();
      expect(h.unregistered, [_tok]);
    });
  });

  group('a notification', () {
    test('not a Conferbot one, or another bot\'s: false, nothing opened', () async {
      final h = _Host()..session = 's1';
      expect(h.push.handle({'data': {'foo': 'bar'}}), isFalse);
      expect(h.push.handle(_push({'botId': 'other'})), isFalse);
      await pumpEventQueue();
      expect(h.calls, isEmpty);
    });

    test('tapped: opens the chat on its conversation', () async {
      final h = _Host()..session = 's1';
      expect(h.push.handle({'data': _push()}), isTrue);
      await pumpEventQueue();
      expect(h.calls, ['openChat', 'showChat']);
    });

    test('another of the visitor\'s conversations: that one in "Your requests"', () async {
      final h = _Host()..session = 's1';
      h.push.handle(_push({'chatSessionId': 'old'}));
      await pumpEventQueue();
      expect(h.calls, ['openChat', 'openRequest:old']);
    });

    test('before the SDK is ready (the app started from the tap): opened once it is', () async {
      final h = _Host()..ready = false;
      expect(h.push.handle(_push()), isTrue);
      await pumpEventQueue();
      expect(h.calls, isEmpty);
      h.ready = true;
      h.session = 's1';
      h.push.update();
      await pumpEventQueue();
      expect(h.calls, ['openChat', 'showChat']);
      h.push.update();
      await pumpEventQueue();
      expect(h.calls, hasLength(2));
    });

    test('open: false counts it unread, unless that conversation is on screen', () {
      final h = _Host()..session = 's1';
      expect(h.push.handle(_push(), open: false), isTrue);
      expect(h.calls, ['unread']);
      final v = _Host()
        ..session = 's1'
        ..onScreen = true;
      expect(v.push.handle(_push(), open: false), isTrue);
      expect(v.calls, isEmpty);
    });
  });
}
