// The post-chat rating at the flow's end (#88; web index.ts: the end of a
// path that is not a sub-flow's shows the rating 1.5 s later), once per
// conversation and remembered across restarts, and the post-chat redirect
// waiting for it (LiveChatExtras.ratingPending into PostChatRedirect). The
// cases of React Native's __tests__/context/flowEndRating.test.ts, on timers
// run by hand.
import 'dart:async';

import 'package:conferbot_flutter/src/core/i18n/i18n.dart';
import 'package:conferbot_flutter/src/core/live_chat/live_chat_extras.dart';
import 'package:conferbot_flutter/src/core/live_chat/post_chat_redirect.dart';
import 'package:conferbot_flutter/src/core/requests/requests_extras.dart';
import 'package:conferbot_flutter/src/core/state/chat_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mocks/mock_socket_client.dart';

class _Store implements RequestsStore {
  _Store([Map<String, String>? seed]) : m = {...?seed};
  final Map<String, String> m;
  @override
  Future<String?> read(String key) async => m[key];
  @override
  Future<void> write(String key, String value) async => m[key] = value;
}

class _FakeTimer implements Timer {
  _FakeTimer(this.fire, this.after);
  final void Function() fire;
  final Duration after;
  bool live = true;
  @override
  void cancel() => live = false;
  @override
  bool get isActive => live;
  @override
  int get tick => 0;
}

const sid = 'sess-1';

/// A chat on screen: the live chat extras and the redirect, wired as the provider does.
class _Chat {
  _Chat({bool rating = true, _Store? store}) : store = store ?? _Store() {
    live = LiveChatExtras(
      socket: () => socket,
      sessionId: () => sid,
      addMessage: (_) {},
      sendRecord: () {},
      store: () => this.store,
      after: (d, fn) => _timer(ratingTimers, d, fn),
    );
    if (rating) {
      live.setChatbotData({
        'csatConfig': {'enabled': true, 'ratingType': 'stars'},
      });
    }
    live.setupListeners();
    redirect = PostChatRedirect(
      redirectUrl: () => 'https://www.example.com/thanks',
      sessionId: () => sid,
      chatVisible: () => true,
      blocked: () => live.blocked != null,
      live: () => false,
      ratingPending: () => live.ratingPending,
      store: () => _Store(),
      appInForeground: () => true,
      open: (href) async => true,
      periodic: (d, fn) {
        late _FakeTimer t;
        t = _FakeTimer(() => fn(t), d);
        return t;
      },
      after: (d, fn) => _timer(settleTimers, d, fn),
    );
    live.addListener(redirect.update);
  }

  final _Store store;
  final MockSocketClient socket = MockSocketClient()..mockIsConnected = true;
  late final LiveChatExtras live;
  late final PostChatRedirect redirect;
  final List<_FakeTimer> ratingTimers = [];
  final List<_FakeTimer> settleTimers = [];

  static _FakeTimer _timer(List<_FakeTimer> into, Duration d, void Function() fn) {
    final t = _FakeTimer(fn, d);
    into.add(t);
    return t;
  }

  Future<void> flush() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// The flow's end, as the provider wires it: the rating, then the redirect.
  Future<void> flowEnd() async {
    unawaited(live.flowEnded());
    redirect.conversationEnded();
    await flush();
  }

  static Future<void> _fire(List<_FakeTimer> ts) async {
    for (final t in List.of(ts)) {
      if (t.live) {
        t.live = false;
        t.fire();
      }
    }
  }

  /// The rating's 1.5 s passed.
  Future<void> ratingDelay() async {
    await _fire(ratingTimers);
    await flush();
  }

  /// The redirect's own 1.5 s passed.
  Future<void> settle() async {
    await _fire(settleTimers);
    await flush();
  }

  bool get ratingDue => ratingTimers.any((t) => t.live);
  String? get line => redirect.line?.text;

  void dispose() {
    redirect.dispose();
    live.dispose();
  }
}

void main() {
  final state = ChatState.instance;
  late _Chat c;

  setUp(() {
    I18n.setWidgetLanguage('en');
    state.reset();
    state.initialize(chatSessionId: sid, visitorId: 'v1', botId: 'b1');
  });

  tearDown(() {
    c.dispose();
    state.reset();
  });

  test('the flow\'s end opens the rating 1.5 s later; the redirect waits until it is sent', () async {
    c = _Chat();
    expect(c.live.ratingPending, isFalse);
    await c.flowEnd();
    // Due: the redirect already waits, the card is not up yet.
    expect(c.live.csatOpen, isFalse);
    expect(c.live.csatDue, isTrue);
    expect(c.live.ratingPending, isTrue);
    expect(c.ratingTimers.single.after, flowEndRatingDelay);
    expect(flowEndRatingDelay, const Duration(milliseconds: 1500));
    expect(c.settleTimers.where((t) => t.live), isEmpty);
    await c.ratingDelay();
    expect(c.live.csatOpen, isTrue);
    expect(c.live.csatDue, isFalse);
    expect(c.live.ratingPending, isTrue);
    await c.settle();
    expect(c.line, isNull);
    c.live.submitRating(5, '');
    expect(c.socket.emittedEvents.any((e) => e.event == 'submit-chat-rating'), isTrue);
    expect(c.live.ratingPending, isFalse);
    await c.settle();
    expect(c.line, 'Taking you to example.com in 10s');
  });

  test('put away (skipped or closed): the redirect goes on', () async {
    c = _Chat();
    await c.flowEnd();
    await c.ratingDelay();
    expect(c.live.csatOpen, isTrue);
    c.live.dismissCsat();
    expect(c.live.ratingPending, isFalse);
    await c.settle();
    expect(c.line, 'Taking you to example.com in 10s');
  });

  test('once per conversation: a second end asks no second time', () async {
    c = _Chat();
    await c.flowEnd();
    await c.ratingDelay();
    c.live.dismissCsat();
    await c.flowEnd();
    expect(c.live.csatDue, isFalse);
    expect(c.ratingDue, isFalse);
    expect(c.live.csatOpen, isFalse);
  });

  test('remembered in storage, so a restart does not ask again', () async {
    c = _Chat();
    await c.flowEnd();
    expect(c.store.m['$ratingOfferedKeyPrefix$sid'], '1');
    c.dispose();
    // A restart: the same conversation, the store says it was asked.
    c = _Chat(store: _Store({'$ratingOfferedKeyPrefix$sid': '1'}));
    await c.flowEnd();
    expect(c.ratingDue, isFalse);
    expect(c.live.csatDue, isFalse);
    expect(c.live.csatOpen, isFalse);
    expect(c.live.ratingPending, isFalse);
    // And the redirect does not wait for a rating that will not come.
    await c.settle();
    expect(c.line, 'Taking you to example.com in 10s');
  });

  test('no rating when the owner has it off: the redirect goes at once', () async {
    c = _Chat(rating: false);
    await c.flowEnd();
    expect(c.live.ratingPending, isFalse);
    expect(c.ratingDue, isFalse);
    await c.settle();
    expect(c.line, 'Taking you to example.com in 10s');
  });

  test('not after an agent\'s end already asked, nor once sent', () async {
    c = _Chat();
    c.socket.simulateEvent('chat-ended', {'chatSessionId': sid});
    expect(c.live.csatOpen, isTrue);
    c.live.dismissCsat();
    await c.flowEnd();
    expect(c.ratingDue, isFalse);
    expect(c.live.csatOpen, isFalse);
    c.dispose();

    state.reset();
    state.initialize(chatSessionId: sid, visitorId: 'v1', botId: 'b1');
    c = _Chat();
    c.socket.simulateEvent('chat-ended', {'chatSessionId': sid});
    c.live.submitRating(4, '');
    await c.flowEnd();
    expect(c.live.csatDue, isFalse);
  });

  test('blocked before it shows: no rating', () async {
    c = _Chat();
    await c.flowEnd();
    c.socket.simulateEvent('visitor-blocked', {'chatSessionId': sid});
    expect(c.live.csatDue, isFalse);
    expect(c.ratingDue, isFalse);
    await c.ratingDelay();
    expect(c.live.csatOpen, isFalse);
  });

  test('a new conversation forgets the last one\'s due rating', () async {
    c = _Chat();
    await c.flowEnd();
    c.live.reset();
    expect(c.live.ratingPending, isFalse);
    expect(c.ratingDue, isFalse);
    expect(c.live.csatOpen, isFalse);
  });
}
