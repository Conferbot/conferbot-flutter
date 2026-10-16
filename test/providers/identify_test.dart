// identify() after construction (#79; RN's user prop, iOS identify(user:),
// Android Conferbot.identify): the records' visitorContext and its hash,
// "Your requests" read again for the new user, the greeting's signed-in fact.
import 'dart:async';

import 'package:conferbot_flutter/src/core/requests/requests.dart';
import 'package:conferbot_flutter/src/core/requests/requests_extras.dart';
import 'package:conferbot_flutter/src/core/state/chat_state.dart';
import 'package:conferbot_flutter/src/models/user.dart';
import 'package:conferbot_flutter/src/providers/conferbot_provider.dart';
import 'package:conferbot_flutter/src/widgets/greeting_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/requests/requests_test.dart' show FakeSocket;

const _ada = ConferBotUser(id: 'u1', name: 'Ada', email: 'ada@example.com', hash: 'h1');
const _bob = ConferBotUser(id: 'u2', email: 'bob@example.com', hash: 'h2');

Map<String, dynamic> _summary(String id) => {
      'id': id,
      'title': 'Invoice',
      'status': 'open',
      'lastAt': DateTime.utc(2026, 10, 16, 11).toIso8601String(),
      'lastFrom': 'team',
      'lastText': 'Fixed it',
      'teamName': 'Ada',
    };

class _MemoryStore implements RequestsStore {
  final Map<String, String> data = {};
  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> write(String key, String value) async => data[key] = value;
}

/// Answers my-requests per signed-in user; [hold] keeps the next answer back.
class _UserSocket extends FakeSocket {
  _UserSocket() : super({});
  Completer<void>? hold;

  @override
  Future<dynamic> emitWithAck(String event, dynamic payload, Duration timeout) async {
    acks.add((event, payload, timeout));
    final h = hold;
    if (h != null) await h.future;
    final user = (payload as Map)['user'] as Map?;
    return {
      'ok': true,
      'requests': [if (user != null) _summary('mobile_1_${user['id']}')],
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('provider.identify', () {
    late ConferBotProvider provider;

    setUp(() {
      provider = ConferBotProvider(
        apiKey: 'k',
        botId: 'b1',
        config: const ConferBotConfig(autoConnect: false),
        user: _ada,
      );
    });

    tearDown(() {
      provider.dispose();
      ChatState.instance.visitorContext = null;
    });

    test('signs a user in: the next records carry them with their hash', () {
      expect(ChatState.instance.buildResponseData()['visitorContext'], _ada.toVisitorContext());
      var told = 0;
      provider.addListener(() => told++);

      provider.identify(_bob);
      expect(provider.user, same(_bob));
      final data = ChatState.instance.buildResponseData();
      expect(data['visitorContext'], {'id': 'u2', 'email': 'bob@example.com', 'hash': 'h2'});
      expect(data['visitorEmail'], 'bob@example.com');
      expect(told, greaterThanOrEqualTo(1));
    });

    test('identify(null) signs out: the records carry nobody', () {
      provider.identify(null);
      expect(provider.user, isNull);
      expect(ChatState.instance.visitorContext, isNull);
      final data = ChatState.instance.buildResponseData();
      expect(data.containsKey('visitorContext'), isFalse);
      expect(data.containsKey('visitorEmail'), isFalse);
    });
  });

  group('requests on a sign-in or sign-out', () {
    late _UserSocket socket;
    ConferBotUser? user;

    RequestsExtras extras() => RequestsExtras(
          botId: () => 'bot1',
          socket: () => socket,
          connected: () => true,
          visitorId: () => 'v_1',
          user: () => user,
          store: () => _MemoryStore(),
          chatSessionId: () => null,
          chatEnded: () => false,
          openChat: () {},
          now: () => DateTime.utc(2026, 10, 16, 12).millisecondsSinceEpoch,
        )..attach();

    setUp(() {
      socket = _UserSocket();
      user = null;
    });

    test('a sign-in reads the list for them straight away; a sign-out drops it', () async {
      final r = extras();
      await r.onConnected();
      // A first-time visitor with nobody signed in is asked nothing.
      expect(socket.acks, isEmpty);

      user = _ada;
      await r.onUserChanged();
      expect((socket.acks.single.$2 as Map)['user'], {'id': 'u1', 'email': 'ada@example.com', 'hash': 'h1'});
      expect(r.list!.single.id, 'mobile_1_u1');
      expect(r.hasRequests, isTrue);

      // Within 15s of the last read, still read again for the next user.
      user = _bob;
      await r.onUserChanged();
      expect(socket.acks, hasLength(2));
      expect(r.list!.single.id, 'mobile_1_u2');

      // Signed out with nothing on this device: their list goes, nothing asked.
      user = null;
      await r.onUserChanged();
      expect(socket.acks, hasLength(2));
      expect(r.list, isNull);
      expect(r.hasRequests, isFalse);
      r.dispose();
    });

    test("a list still on its way for the last user isn't shown; the new one is read", () async {
      user = _ada;
      final r = extras();
      socket.hold = Completer<void>();
      final first = r.onConnected();
      await Future<void>.delayed(Duration.zero);
      expect(socket.acks, hasLength(1));

      user = _bob;
      final second = r.onUserChanged();
      final held = socket.hold!;
      socket.hold = null;
      held.complete();
      await first;
      await second;

      expect(socket.acks, hasLength(2));
      expect((socket.acks.last.$2 as Map)['user'], {'id': 'u2', 'email': 'bob@example.com', 'hash': 'h2'});
      expect(r.list!.single.id, 'mobile_1_u2');
      r.dispose();
    });
  });

  group("the greeting's signed-in fact", () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('a sign-in decides again, with the same settings', (tester) async {
      final c = {
        'chatIconCta': true,
        'chatIconCtaText': 'Hi',
        'greetingDelay': 0,
        'greetingRules': [
          {'matchType': 'contains', 'pattern': '/', 'text': 'Welcome back, customer', 'signedIn': 'yes'},
        ],
      };
      final g = GreetingController('bot_identify');
      g.update(customizations: c, chatOpen: false);
      await tester.pump(const Duration(milliseconds: 10));
      expect(g.card?.text, isNot('Welcome back, customer'));

      g.update(customizations: c, chatOpen: false, visitorContext: _ada.toVisitorContext());
      await tester.pump(const Duration(milliseconds: 10));
      expect(g.card?.text, 'Welcome back, customer');
      g.dispose();
    });

    test('signed in means an id or an email', () {
      expect(GreetingController.signedInFrom(null), isFalse);
      expect(GreetingController.signedInFrom(const {'name': 'Ada'}), isFalse);
      expect(GreetingController.signedInFrom(const {'id': 'u1'}), isTrue);
      expect(GreetingController.signedInFrom(const {'email': 'a@b.co'}), isTrue);
    });
  });
}
