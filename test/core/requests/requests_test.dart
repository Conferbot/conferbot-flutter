/// "Your requests" (core/requests/requests.dart): the web's words.ts,
/// store.ts and api.ts (conferbot-widget src/ts/home/requests/), against the
/// payloads of embed-server socket/handlers/visitorRequestsHandler.js.
/// Ported from RN __tests__/core/requests.test.ts.
library;

import 'dart:convert';

import 'package:conferbot_flutter/src/core/requests/requests.dart';
import 'package:conferbot_flutter/src/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime(2026, 10, 16, 15).millisecondsSinceEpoch; // Fri 16 Oct 2026, 15:00 local
String iso(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toIso8601String();

RequestSummary req({String id = 'mobile_1_abcdef', String status = 'open', String? lastAt = '', String lastFrom = 'team', String teamName = 'Ada'}) =>
    RequestSummary(
      id: id,
      title: 'My invoice is wrong',
      status: status,
      lastAt: lastAt == '' ? iso(now - 2 * 3600000) : lastAt,
      lastFrom: lastFrom,
      lastText: 'Fixed it',
      teamName: teamName,
    );

Map<String, dynamic> reqJson() => {
      'id': 'mobile_1_abcdef',
      'title': 'My invoice is wrong',
      'status': 'open',
      'lastAt': iso(now - 2 * 3600000),
      'lastFrom': 'team',
      'lastText': 'Fixed it',
      'teamName': 'Ada',
    };

class FakeSocket implements RequestsSocket {
  FakeSocket(this.answers);
  final Map<String, dynamic> answers;
  final List<(String, dynamic, Duration)> acks = [];
  final List<(String, dynamic)> emits = [];
  final Map<String, List<void Function(dynamic)>> handlers = {};

  @override
  Future<dynamic> emitWithAck(String event, dynamic payload, Duration timeout) async {
    acks.add((event, payload, timeout));
    final a = answers[event];
    if (a is Exception) throw a;
    return a;
  }

  @override
  void emit(String event, dynamic payload) => emits.add((event, payload));

  @override
  void Function() on(String event, void Function(dynamic data) fn) {
    (handlers[event] ??= []).add(fn);
    return () => handlers[event]!.remove(fn);
  }

  void fire(String event, [dynamic data]) {
    for (final f in List.of(handlers[event] ?? const [])) {
      f(data);
    }
  }
}

void main() {
  group('the words (web words.ts)', () {
    test('where it stands: replied, waiting, solved', () {
      expect(stateOf(req()), RequestState.replied);
      expect(stateOf(req(lastFrom: 'you')), RequestState.waiting);
      expect(stateOf(req(status: 'solved')), RequestState.solved);
      expect(stateWords[RequestState.replied]!.label, 'We replied');
      expect(stateWords[RequestState.waiting]!.label, "We're on it");
      expect(stateWords[RequestState.solved]!.detail, "Still need help with this? Write below and we'll pick it up again.");
    });

    test('a new reply: from the team, on an open request, after it was last read here', () {
      final r = req();
      expect(isNewReply(r, {}), isTrue);
      expect(isNewReply(r, {r.id: now}), isFalse);
      expect(isNewReply(req(status: 'solved'), {}), isFalse);
      expect(isNewReply(req(lastFrom: 'you'), {}), isFalse);
      expect(unreadCount([r, req(id: 'other_123', lastFrom: 'you')], {}), 1);
      expect(unreadCount(null, {}), 0);
    });

    test('when, in words', () {
      expect(whenWords(now - 20000, now), 'Just now');
      expect(whenWords(now - 5 * 60000, now), '5 min ago');
      expect(whenWords(now - 70 * 60000, now), '1 hour ago');
      expect(whenWords(now - 3 * 3600000, now), '3 hours ago');
      expect(whenWords(DateTime(2026, 10, 15, 20).millisecondsSinceEpoch, now), 'Yesterday');
      expect(whenWords(DateTime(2026, 10, 12, 9).millisecondsSinceEpoch, now), 'Monday');
      expect(whenWords(DateTime(2026, 10, 3, 9).millisecondsSinceEpoch, now), '3 Oct');
      expect(whenWords(DateTime(2025, 12, 24, 9).millisecondsSinceEpoch, now), '24 Dec 2025');
      expect(whenWords(iso(now - 5 * 60000), now), '5 min ago');
      expect(whenWords(null, now), '');
      expect(whenWords('nonsense', now), '');
    });

    test("a row's line: New reply from the person, else where it stands", () {
      expect(rowLine(req(), {}, now), 'New reply from Ada · 2 hours ago');
      expect(rowLine(req(teamName: ''), {}, now), 'New reply · 2 hours ago');
      expect(rowLine(req(), {'mobile_1_abcdef': now}, now), 'We replied · 2 hours ago');
      expect(rowLine(req(lastFrom: 'you', lastAt: null), {}, now), "We're on it");
    });

    test('newest replies first, then whatever moved last', () {
      final a = req(id: 'aaaaaa', lastFrom: 'you', lastAt: iso(now - 1000));
      final b = req(id: 'bbbbbb', lastAt: iso(now - 9000));
      final c = req(id: 'cccccc', lastFrom: 'you', lastAt: iso(now - 5000));
      expect(ordered([a, b, c], {}).map((r) => r.id), ['bbbbbb', 'aaaaaa', 'cccccc']);
      expect(ordered([a, b, c], {'bbbbbb': now}).map((r) => r.id), ['aaaaaa', 'cccccc', 'bbbbbb']);
    });

    test("read up to the newest message, by the server's clock when it runs ahead", () {
      expect(seenAt(iso(now + 60000), now), now + 60000);
      expect(seenAt(null, now), now);
    });

    test('links in a message are their own runs (web appendText)', () {
      expect(linkRuns('See https://example.com/a?b=1. Thanks'), [
        (text: 'See ', url: null),
        (text: 'https://example.com/a?b=1', url: 'https://example.com/a?b=1'),
        (text: '. Thanks', url: null),
      ]);
      expect(linkRuns('no links'), [(text: 'no links', url: null)]);
      expect(linkRuns(''), isEmpty);
    });

    test('the menu item says when a reply is new', () {
      expect(RequestsText.menu(0), 'Your requests');
      expect(RequestsText.menu(2), 'Your requests · New reply');
    });

    test('the server payloads read as summaries and details', () {
      final s = RequestSummary.fromJson(reqJson());
      expect((s.id, s.status, s.lastFrom, s.teamName), ('mobile_1_abcdef', 'open', 'team', 'Ada'));
      final d = RequestDetail.fromJson({
        ...reqJson(),
        'status': 'solved',
        'messages': [
          {'id': 'm1', 'from': 'you', 'name': '', 'text': 'Hi', 'at': null},
          {'id': 'm2', 'from': 'team', 'name': 'Ada', 'text': 'Done', 'at': iso(now)},
          'junk',
        ],
      });
      expect(d.solved, isTrue);
      expect(d.messages.map((m) => (m.id, m.you)), [('m1', true), ('m2', false)]);
    });
  });

  group('what the device remembers (web store.ts)', () {
    test('reads only clean ids and numbers', () {
      final m = parseMemory(jsonEncode({
        'sessions': ['mobile_1_abcdef', 'bad id!', 42, 'x'],
        'seen': {'mobile_1_abcdef': 5, 'no way': 3, 'other_123': 'x'},
      }));
      expect(m.sessions, ['mobile_1_abcdef']);
      expect(m.seen, {'mobile_1_abcdef': 5});
      expect(parseMemory(null).sessions, isEmpty);
      expect(parseMemory('{nope').seen, isEmpty);
      expect(requestsStorageKey('bot1'), '@conferbot:requests:bot1');
      expect(requestsStorageKey(null), '@conferbot:requests:default');
    });

    test('a chat goes first, once; 30 kept', () {
      var m = const RequestMemory();
      for (var i = 0; i < 35; i++) {
        m = withSession(m, 'mobile_${i}_abcdef') ?? m;
      }
      expect(m.sessions, hasLength(30));
      expect(m.sessions.first, 'mobile_34_abcdef');
      expect(withSession(m, 'mobile_34_abcdef'), isNull);
      expect(withSession(m, 'short'), isNull);
      expect(withSession(m, 'mobile_10_abcdef')!.sessions.first, 'mobile_10_abcdef');
    });

    test('read marks only move forward; the newest 60 are kept', () {
      var m = withSeen(const RequestMemory(), 'mobile_1_abcdef', 10)!;
      expect(m.seen['mobile_1_abcdef'], 10);
      expect(withSeen(m, 'mobile_1_abcdef', 5), isNull);
      for (var i = 0; i < 70; i++) {
        m = withSeen(m, 'mobile_${i}_zzzzzz', i + 1)!;
      }
      final back = parseMemory(serializeMemory(m));
      expect(back.seen, hasLength(60));
      expect(back.seen['mobile_69_zzzzzz'], 70);
      expect(back.seen['mobile_1_abcdef'], isNull);
    });

    test('a chat becomes one to remember once the visitor wrote in it', () {
      expect(hasVisitorEntry([{'type': 'bot-message'}]), isFalse);
      expect(hasVisitorEntry([{'type': 'bot-message'}, {'type': 'user-message'}]), isTrue);
      expect(hasVisitorEntry([{'shape': 'user-live-message'}]), isTrue);
      expect(hasVisitorEntry(null), isFalse);
    });
  });

  group('who is asking (web api.ts who)', () {
    test("the visitor id, this device's chats and only the signed user's checked fields", () {
      const m = RequestMemory(sessions: ['mobile_1_abcdef']);
      expect(requestsWho('v_1', m, null), {'visitorId': 'v_1', 'sessions': ['mobile_1_abcdef']});
      expect(
        requestsWho('v_1', m, const ConferBotUser(id: 'u1', email: 'a@b.co', hash: 'h', name: 'Ada', metadata: {'plan': 'pro'})),
        {
          'visitorId': 'v_1',
          'sessions': ['mobile_1_abcdef'],
          'user': {'id': 'u1', 'email': 'a@b.co', 'hash': 'h'},
        },
      );
      expect(requestsWho(null, m, const ConferBotUser(id: 'u2', hash: 'h2'))['user'], {'id': 'u2', 'hash': 'h2'});
      expect(requestsWho(null, m, null)['visitorId'], '');
    });

    test('asks only with a chat on this device or a signed-in user', () {
      expect(canAskForRequests(const RequestMemory(), null), isFalse);
      expect(canAskForRequests(const RequestMemory(), const ConferBotUser(id: 'u1')), isFalse);
      expect(canAskForRequests(const RequestMemory(), const ConferBotUser(id: 'u1', hash: 'h')), isTrue);
      expect(canAskForRequests(const RequestMemory(sessions: ['mobile_1_abcdef']), null), isTrue);
    });
  });

  group('the server (web api.ts, embed-server visitorRequestsHandler.js)', () {
    Map<String, dynamic> who() => {'visitorId': 'v_1', 'sessions': ['mobile_1_abcdef']};

    test('my-requests: the list, or null when it did not come', () async {
      final s = FakeSocket({
        'my-requests': {'ok': true, 'requests': [reqJson()]},
      });
      final list = await SocketRequestsApi(() => s, who).list();
      expect(list!.single.id, 'mobile_1_abcdef');
      expect(s.acks.single.$1, 'my-requests');
      expect(s.acks.single.$2, who());
      expect(s.acks.single.$3, const Duration(seconds: 10));
      expect(await SocketRequestsApi(() => FakeSocket({'my-requests': {'ok': false}}), who).list(), isNull);
      expect(await SocketRequestsApi(() => FakeSocket({}), who).list(), isNull);
      expect(await SocketRequestsApi(() => FakeSocket({'my-requests': Exception('not connected')}), who).list(), isNull);
      expect(await SocketRequestsApi(() => null, who).list(), isNull);
      // socket_io_client may hand the ack's arguments as a list.
      expect(
          await SocketRequestsApi(
              () => FakeSocket({
                    'my-requests': [
                      {'ok': true, 'requests': []}
                    ]
                  }),
              who).list(),
          isEmpty);
    });

    test('my-request-open, my-request-close and my-request-reply carry the conversation', () async {
      final s = FakeSocket({
        'my-request-open': {
          'ok': true,
          'request': {...reqJson(), 'messages': []}
        },
        'my-request-reply': {'ok': false, 'reason': 'locked'},
      });
      final api = SocketRequestsApi(() => s, who);
      expect((await api.open('mobile_1_abcdef'))!.id, 'mobile_1_abcdef');
      expect(s.acks.last.$1, 'my-request-open');
      expect(s.acks.last.$2, {...who(), 'chatSessionId': 'mobile_1_abcdef'});
      final r = await api.reply('mobile_1_abcdef', 'hi', 'request-reply-x');
      expect((r.ok, r.reason), (false, 'locked'));
      expect(s.acks.last.$1, 'my-request-reply');
      expect(s.acks.last.$2, {...who(), 'chatSessionId': 'mobile_1_abcdef', 'text': 'hi', 'entryId': 'request-reply-x'});
      api.close('mobile_1_abcdef');
      expect(s.emits.single.$1, 'my-request-close');
      expect(s.emits.single.$2, {'chatSessionId': 'mobile_1_abcdef'});
      final off = await SocketRequestsApi(() => FakeSocket({}), who).reply('a', 'b', 'c');
      expect((off.ok, off.reason), (false, 'offline'));
      expect(await SocketRequestsApi(() => FakeSocket({'my-request-open': {'ok': false, 'reason': 'not_found'}}), who).open('x'), isNull);
    });

    test('my-request-update names the request; a reconnect reads the open one again', () async {
      final s = FakeSocket({
        'my-request-open': {
          'ok': true,
          'request': {...reqJson(), 'messages': []}
        },
      });
      final api = SocketRequestsApi(() => s, who);
      final seen = <String>[];
      final off = api.onUpdate(seen.add);
      s.fire('my-request-update', {'chatSessionId': 'other_123'});
      s.fire('my-request-update', {});
      s.fire('connect');
      expect(seen, ['other_123']);
      await api.open('mobile_1_abcdef');
      s.fire('connect');
      expect(seen, ['other_123', 'mobile_1_abcdef']);
      api.close('mobile_1_abcdef');
      s.fire('connect');
      off();
      s.fire('my-request-update', {'chatSessionId': 'other_123'});
      expect(seen, ['other_123', 'mobile_1_abcdef']);
    });

    test("a reply's id is one the server keeps (request-reply-[\\w-]{1,60})", () {
      final id = replyEntryId(now, () => 0.123456789);
      expect(id, matches(RegExp(r'^request-reply-[\w-]{1,60}$')));
      expect(id.startsWith('request-reply-${now.toRadixString(36)}'), isTrue);
      expect(id.length, 'request-reply-${now.toRadixString(36)}'.length + 6);
      expect(replyEntryId(now, () => 0.999999999), matches(RegExp(r'^request-reply-[0-9a-z]+$')));
    });
  });

  group('the accent (web accentFor)', () {
    test('the brand colour, the header, the launcher, unless too light; then indigo', () {
      expect(requestsAccent({'brandColor': '#0808EE', 'headerBgColor': '#ff0000'}), '#0808EE');
      expect(requestsAccent({'brandColor': '#0808EE', '_themePalette': true, 'headerBgColor': '#123456'}), '#123456');
      expect(requestsAccent({'headerBgColor': '#ffffff', 'widgetIconBgColor': '#222222'}), '#222222');
      expect(requestsAccent({'headerBgColor': '#fff'}), '#4F46E5');
      expect(requestsAccent(null), '#4F46E5');
    });
  });
}
