/// "Your requests" in the SDK (core/requests/requests_extras.dart; RN
/// context/hooks/useRequestsPortal.ts, web card.ts and store.ts): what the
/// device remembers, when the list is read, the unread count and the
/// server's updates.
library;

import 'package:conferbot_flutter/src/core/requests/requests.dart';
import 'package:conferbot_flutter/src/core/requests/requests_extras.dart';
import 'package:conferbot_flutter/src/core/requests/requests_portal.dart';
import 'package:conferbot_flutter/src/models/user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'requests_test.dart' show FakeSocket;

String iso(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toIso8601String();

class MemoryStore implements RequestsStore {
  final Map<String, String> data = {};
  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> write(String key, String value) async => data[key] = value;
}

Map<String, dynamic> summaryJson(int now, {String id = 'mobile_1_abcdef', String lastFrom = 'team'}) => {
      'id': id,
      'title': 'My invoice is wrong',
      'status': 'open',
      'lastAt': iso(now - 60000),
      'lastFrom': lastFrom,
      'lastText': 'Fixed it',
      'teamName': 'Ada',
    };

class Harness {
  Harness({MemoryStore? store, this.user, this.session = 'mobile_9_current'}) : store = store ?? MemoryStore() {
    socket = FakeSocket({
      'my-requests': {
        'ok': true,
        'requests': [summaryJson(clock)]
      },
      'my-request-open': {
        'ok': true,
        'request': {...summaryJson(clock), 'messages': []}
      },
    });
    extras = RequestsExtras(
      botId: () => 'bot1',
      socket: () => socket,
      connected: () => connected,
      visitorId: () => 'v_1',
      user: () => user,
      store: () => this.store,
      chatSessionId: () => session,
      chatEnded: () => ended,
      openChat: () => chatOpened++,
      now: () => clock,
      rand: () => 0.25,
    );
    extras.attach();
  }

  final MemoryStore store;
  ConferBotUser? user;
  String? session;
  late final FakeSocket socket;
  late final RequestsExtras extras;
  bool connected = true;
  bool ended = false;
  int chatOpened = 0;
  int clock = DateTime.utc(2026, 10, 16, 12).millisecondsSinceEpoch;

  int get lists => socket.acks.where((a) => a.$1 == 'my-requests').length;
}

Future<void> flush() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('a first-time visitor is asked nothing; a chat they wrote in is remembered and stored', () async {
    final h = Harness();
    await h.extras.onConnected();
    expect(h.lists, 0);
    // A chat with only the bot's words is not one to remember.
    await h.extras.onRecord('mobile_9_current', [
      {'type': 'bot-message'}
    ]);
    expect(h.extras.memory.sessions, isEmpty);
    await h.extras.onRecord('mobile_9_current', [
      {'type': 'bot-message'},
      {'shape': 'user-message', 'type': 'user-message'}
    ]);
    expect(h.extras.memory.sessions, ['mobile_9_current']);
    await flush();
    expect(parseMemory(h.store.data['@conferbot:requests:bot1']).sessions, ['mobile_9_current']);
    await h.extras.onConnected();
    expect(h.lists, 1);
    final who = h.socket.acks.single.$2 as Map;
    expect(who, {
      'visitorId': 'v_1',
      'sessions': ['mobile_9_current']
    });
    expect(h.extras.list!.single.id, 'mobile_1_abcdef');
    expect(h.extras.hasRequests, isTrue);
    expect(h.extras.unread, 1);
  });

  test('a signed-in user with a hash is asked for with their checked fields', () async {
    final h = Harness(user: const ConferBotUser(id: 'u1', email: 'a@b.co', hash: 'h1', name: 'Ada'));
    await h.extras.onConnected();
    expect(h.socket.acks.single.$2, {
      'visitorId': 'v_1',
      'sessions': <String>[],
      'user': {'id': 'u1', 'email': 'a@b.co', 'hash': 'h1'},
    });
  });

  test('what the device remembers comes back for the same bot; not while offline', () async {
    final store = MemoryStore()..data['@conferbot:requests:bot1'] = serializeMemory(const RequestMemory(sessions: ['mobile_1_abcdef']));
    final h = Harness(store: store)..connected = false;
    await h.extras.onConnected();
    expect(h.extras.memory.sessions, ['mobile_1_abcdef']);
    expect(h.lists, 0);
    h.connected = true;
    await h.extras.onConnected();
    expect(h.lists, 1);
  });

  test('the chat opening or closing reads the list at most every 15s; connect always does', () async {
    final store = MemoryStore()..data['@conferbot:requests:bot1'] = serializeMemory(const RequestMemory(sessions: ['mobile_1_abcdef']));
    final h = Harness(store: store);
    await h.extras.onConnected();
    await h.extras.onChatShown();
    expect(h.lists, 1);
    h.clock += 14000;
    await h.extras.onChatShown();
    expect(h.lists, 1);
    h.clock += 2000;
    await h.extras.onChatShown();
    expect(h.lists, 2);
    await h.extras.onConnected();
    expect(h.lists, 3);
  });

  test('reading a request marks it read here: the unread count drops and the mark is stored', () async {
    final store = MemoryStore()..data['@conferbot:requests:bot1'] = serializeMemory(const RequestMemory(sessions: ['mobile_1_abcdef']));
    final h = Harness(store: store);
    await h.extras.onConnected();
    expect(h.extras.unread, 1);
    await h.extras.open();
    expect(h.extras.isOpen, isTrue);
    await h.extras.portal.pick('mobile_1_abcdef');
    expect(h.extras.unread, 0);
    await flush();
    expect(parseMemory(store.data['@conferbot:requests:bot1']).seen['mobile_1_abcdef'], h.clock);
    // Leaving the portal reads the list again (forced).
    final before = h.lists;
    h.extras.close();
    await flush();
    expect(h.lists, before + 1);
    expect(h.extras.isOpen, isFalse);
  });

  test("a request changing while the portal is closed reads the list; while it's open the request is read", () async {
    final store = MemoryStore()..data['@conferbot:requests:bot1'] = serializeMemory(const RequestMemory(sessions: ['mobile_1_abcdef']));
    final h = Harness(store: store);
    await h.extras.onConnected();
    h.socket.fire('my-request-update', {'chatSessionId': 'mobile_1_abcdef'});
    await flush();
    expect(h.lists, 2);
    await h.extras.open('mobile_1_abcdef');
    final opens = h.socket.acks.where((a) => a.$1 == 'my-request-open').length;
    h.socket.fire('my-request-update', {'chatSessionId': 'mobile_1_abcdef'});
    await flush();
    expect(h.socket.acks.where((a) => a.$1 == 'my-request-open').length, opens + 1);
    expect(h.lists, 2);
    // A reconnect reads the open one again (the server forgot its room).
    h.socket.fire('connect');
    await flush();
    expect(h.socket.acks.where((a) => a.$1 == 'my-request-open').length, opens + 2);
  });

  test('the chat on screen, not ended, opens the chat instead; once ended it opens as a request', () async {
    final h = Harness(session: 'mobile_1_abcdef');
    await h.extras.open('mobile_1_abcdef');
    expect(h.chatOpened, 1);
    expect(h.extras.portal.state.screen, RequestsScreen.closed);
    h.ended = true;
    await h.extras.open('mobile_1_abcdef');
    expect(h.extras.portal.state.screen, RequestsScreen.request);
  });

  test('shared_preferences keeps it per bot', () async {
    SharedPreferences.setMockInitialValues({});
    const store = SharedPreferencesRequestsStore();
    await store.write(requestsStorageKey('bot1'), serializeMemory(const RequestMemory(sessions: ['mobile_1_abcdef'])));
    expect(parseMemory(await store.read(requestsStorageKey('bot1'))).sessions, ['mobile_1_abcdef']);
    expect(await store.read(requestsStorageKey('bot2')), isNull);
  });
}
