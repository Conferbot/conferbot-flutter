/// "Your requests" screens as states (core/requests/requests_portal.dart;
/// web conferbot-widget src/ts/home/requests/view.ts mountRequestsView).
/// Ported from RN __tests__/core/requestsPortal.test.ts.
library;

import 'dart:async';

import 'package:conferbot_flutter/src/core/requests/requests.dart';
import 'package:conferbot_flutter/src/core/requests/requests_portal.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime.utc(2026, 10, 16, 12).millisecondsSinceEpoch;
String iso(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toIso8601String();

RequestSummary summary({String id = 'mobile_1_abcdef', String lastFrom = 'team', String status = 'open'}) => RequestSummary(
      id: id,
      title: 'My invoice is wrong',
      status: status,
      lastAt: iso(now - 60000),
      lastFrom: lastFrom,
      lastText: 'Fixed it',
      teamName: 'Ada',
    );

const _m1 = RequestMessage(id: 'm1', from: 'you', name: '', text: 'My invoice is wrong');
const _m2 = RequestMessage(id: 'm2', from: 'team', name: 'Ada', text: 'Fixed it');

RequestDetail detail({String status = 'open', String lastFrom = 'team', List<RequestMessage> messages = const [_m1, _m2]}) => RequestDetail(
      id: 'mobile_1_abcdef',
      title: 'My invoice is wrong',
      status: status,
      lastAt: iso(now - 60000),
      lastFrom: lastFrom,
      lastText: 'Fixed it',
      teamName: 'Ada',
      messages: messages,
    );

class FakeApi implements RequestsApi {
  FakeApi({this.listAnswer, this.openAnswer, this.replyAnswer});

  List<RequestSummary>? Function()? listAnswer;
  Future<RequestDetail?> Function()? openAnswer;
  Future<ReplyResult> Function(String id, String text, String entryId)? replyAnswer;

  int lists = 0;
  int opens = 0;
  final List<String> closes = [];
  final List<(String, String, String)> replies = [];
  void Function(String id)? update;
  int subscribed = 0;

  @override
  Future<List<RequestSummary>?> list() async {
    lists++;
    return listAnswer != null ? listAnswer!() : [summary()];
  }

  @override
  Future<RequestDetail?> open(String id) {
    opens++;
    return openAnswer != null ? openAnswer!() : Future.value(detail());
  }

  @override
  void close(String id) => closes.add(id);

  @override
  Future<ReplyResult> reply(String id, String text, String entryId) {
    replies.add((id, text, entryId));
    return replyAnswer != null ? replyAnswer!(id, text, entryId) : Future.value(ReplyResult(ok: true, request: detail(lastFrom: 'you')));
  }

  @override
  void Function() onUpdate(void Function(String id) fn) {
    subscribed++;
    update = fn;
    return () => update = null;
  }
}

class Setup {
  Setup({FakeApi? api, this.current}) : api = api ?? FakeApi() {
    portal = RequestsPortal(
      api: this.api,
      seen: () => seen,
      markSeen: (id, at) {
        marks.add((id, at));
        seen[id] = at;
      },
      isCurrentChat: (id) => id == current,
      openChat: () => chatOpened++,
      onChanged: () => changed++,
      now: () => now,
      rand: () => 0.5,
    );
  }

  final FakeApi api;
  final String? current;
  late final RequestsPortal portal;
  final Map<String, int> seen = {};
  final List<(String, int)> marks = [];
  int chatOpened = 0;
  int changed = 0;

  RequestsPortalState get s => portal.state;
}

Future<void> flush() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('the list', () {
    test('loading, then the requests in order; Back leaves and the list is read again', () async {
      final t = Setup(api: FakeApi(listAnswer: () => [summary(id: 'old_aaaaaa', lastFrom: 'you'), summary()]));
      final p = t.portal.openList();
      expect((t.s.screen, t.s.title, t.s.loading), (RequestsScreen.list, 'Your requests', true));
      await p;
      expect(t.s.loading, isFalse);
      expect(t.s.list!.map((r) => r.id), ['mobile_1_abcdef', 'old_aaaaaa']);
      t.portal.back();
      expect(t.s.screen, RequestsScreen.closed);
      expect(t.changed, 1);
      expect(t.api.closes, isEmpty);
    });

    test('empty is an empty list (the view says "Nothing here yet")', () async {
      final t = Setup(api: FakeApi(listAnswer: () => []));
      await t.portal.openList();
      expect(t.s.list, isEmpty);
    });

    test('could not load: failed, and Try again reads it again', () async {
      final api = FakeApi(listAnswer: () => null);
      final t = Setup(api: api);
      await t.portal.openList();
      expect((t.s.failed, t.s.loading), (true, false));
      api.listAnswer = () => [summary()];
      t.portal.reload();
      await flush();
      expect(t.s.failed, isFalse);
      expect(t.s.list!.single.id, 'mobile_1_abcdef');
    });
  });

  group('one request', () {
    test('from the list: the banner, the messages, read here; Back to the list (and its live updates stop)', () async {
      final t = Setup();
      await t.portal.openList();
      await t.portal.pick('mobile_1_abcdef');
      expect((t.s.screen, t.s.title, t.s.requestState, t.s.placeholder),
          (RequestsScreen.request, 'Your request', RequestState.replied, 'Write your reply...'));
      expect(t.s.banner!.label, 'We replied');
      expect(t.s.request!.messages, hasLength(2));
      expect(t.marks, [('mobile_1_abcdef', now)]);
      t.portal.back();
      expect(t.api.closes, ['mobile_1_abcdef']);
      expect(t.s.screen, RequestsScreen.list);
      await flush();
      t.portal.back();
      expect(t.s.screen, RequestsScreen.closed);
    });

    test('opened straight away: Back leaves', () async {
      final t = Setup();
      await t.portal.openRequest('mobile_1_abcdef');
      t.portal.back();
      expect(t.s.screen, RequestsScreen.closed);
      expect(t.api.closes, ['mobile_1_abcdef']);
    });

    test('a solved one says a reply opens it again', () async {
      final t = Setup(api: FakeApi(openAnswer: () async => detail(status: 'solved')));
      await t.portal.openRequest('mobile_1_abcdef');
      expect((t.s.requestState, t.s.placeholder), (RequestState.solved, 'Write here to open it again...'));
      expect(t.s.banner!.detail, contains('pick it up again'));
    });

    test('the chat on screen right now: that chat instead', () async {
      final t = Setup(current: 'mobile_1_abcdef');
      await t.portal.openRequest('mobile_1_abcdef');
      expect(t.api.opens, 0);
      expect(t.chatOpened, 1);
      expect(t.s.screen, RequestsScreen.closed);
    });

    test('not found: failed with Try again', () async {
      final t = Setup(api: FakeApi(openAnswer: () async => null));
      await t.portal.openRequest('mobile_1_abcdef');
      expect((t.s.screen, t.s.failed), (RequestsScreen.request, true));
    });
  });

  group('a reply', () {
    test('sent: shown as sending, then the answer replaces it and the draft is gone', () async {
      final answer = Completer<ReplyResult>();
      final t = Setup(api: FakeApi(replyAnswer: (_, __, ___) => answer.future));
      await t.portal.openRequest('mobile_1_abcdef');
      expect(t.s.canSend, isFalse);
      t.portal.setDraft('  Thanks!  ');
      expect((t.s.draft, t.s.canSend), ('  Thanks!  ', true));
      t.portal.send();
      final (_, text, entryId) = t.api.replies.single;
      expect(text, 'Thanks!');
      expect(entryId, startsWith('request-reply-'));
      final p = t.s.pending.single;
      expect((p.entryId, p.text, p.at, p.status), (entryId, 'Thanks!', iso(now), PendingStatus.sending));
      expect((t.s.draft, t.s.canSend), ('', false));
      answer.complete(ReplyResult(
        ok: true,
        request: detail(lastFrom: 'you', messages: [_m1, _m2, RequestMessage(id: entryId, from: 'you', name: '', text: 'Thanks!')]),
      ));
      await flush();
      expect(t.s.pending, isEmpty);
      expect(t.s.request!.messages, hasLength(3));
      expect(t.s.requestState, RequestState.waiting);
    });

    test('not sent: Try again sends the same entry; locked: no Try again', () async {
      final api = FakeApi(replyAnswer: (_, __, ___) async => const ReplyResult(ok: false, reason: 'offline'));
      final t = Setup(api: api);
      await t.portal.openRequest('mobile_1_abcdef');
      t.portal.setDraft('Hello');
      t.portal.send();
      await flush();
      final p = t.s.pending.single;
      expect(p.status, PendingStatus.failed);
      api.replyAnswer = (_, __, ___) async => const ReplyResult(ok: false, reason: 'locked');
      t.portal.retry(p.entryId);
      await flush();
      expect(api.replies[1].$3, p.entryId);
      expect(t.s.pending.single.status, PendingStatus.locked);
      t.portal.retry(p.entryId);
      expect(api.replies, hasLength(2));
    });

    test('an empty draft sends nothing; drafts are kept per request until reset', () async {
      final t = Setup();
      await t.portal.openRequest('mobile_1_abcdef');
      t.portal.setDraft('   ');
      t.portal.send();
      expect(t.api.replies, isEmpty);
      t.portal.setDraft('half written');
      t.portal.close();
      await t.portal.openRequest('mobile_1_abcdef');
      expect(t.s.draft, 'half written');
      t.portal.reset();
      t.portal.close();
      await t.portal.openRequest('mobile_1_abcdef');
      expect(t.s.draft, '');
    });
  });

  group('live updates (my-request-update)', () {
    test('the open request is read again, keeping the draft and a reply that did not go', () async {
      final api = FakeApi(replyAnswer: (_, __, ___) async => const ReplyResult(ok: false, reason: 'error'));
      final t = Setup(api: api);
      await t.portal.openRequest('mobile_1_abcdef');
      t.portal.setDraft('one');
      t.portal.send();
      await flush();
      t.portal.setDraft('still typing');
      api.openAnswer = () async => detail(status: 'solved');
      api.update!('mobile_1_abcdef');
      await flush();
      expect((t.s.requestState, t.s.draft), (RequestState.solved, 'still typing'));
      expect(t.s.pending.map((p) => p.status), [PendingStatus.failed]);
    });

    test('another request, a closed portal or a reply on its way: nothing', () async {
      final answer = Completer<ReplyResult>();
      final api = FakeApi(replyAnswer: (_, __, ___) => answer.future);
      final t = Setup(api: api);
      api.update!('mobile_1_abcdef');
      await t.portal.openRequest('mobile_1_abcdef');
      api.update!('other_123456');
      await flush();
      expect(api.opens, 1);
      t.portal.setDraft('x');
      t.portal.send();
      api.openAnswer = () async => detail(status: 'solved');
      api.update!('mobile_1_abcdef');
      await flush();
      expect(t.s.requestState, RequestState.replied);
    });

    test('a late answer for a screen that is gone is dropped', () async {
      final opened = Completer<RequestDetail?>();
      final api = FakeApi(openAnswer: () => opened.future);
      final t = Setup(api: api);
      final p = t.portal.openRequest('mobile_1_abcdef');
      t.portal.close();
      opened.complete(detail());
      await p;
      expect(t.s.screen, RequestsScreen.closed);
    });

    test('listeners hear each change; dispose stops the updates', () async {
      final t = Setup();
      var heard = 0;
      t.portal.addListener(() => heard++);
      await t.portal.openList();
      expect(heard, greaterThan(0));
      t.portal.dispose();
      expect(t.api.subscribed, 1);
      expect(t.api.update, isNull);
    });
  });
}
