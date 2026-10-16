// Post-chat redirect (lib/src/core/live_chat/post_chat_redirect.dart), the
// cases of the web widget's tests/postChatRedirect.test.js and React
// Native's __tests__/core/postChatRedirect.test.ts and
// __tests__/context/usePostChatRedirect.test.ts: which URLs are followed,
// the 10-second line with Cancel, once per conversation (also after a
// restart), the app's hook first, waiting for the rating, what stops it,
// and a "Continue to" button when the system cannot open the URL.
import 'dart:async';

import 'package:conferbot_flutter/src/core/i18n/i18n.dart';
import 'package:conferbot_flutter/src/core/live_chat/post_chat_redirect.dart';
import 'package:conferbot_flutter/src/core/requests/requests_extras.dart';
import 'package:flutter_test/flutter_test.dart';

class _Store implements RequestsStore {
  final Map<String, String> m = {};
  @override
  Future<String?> read(String key) async => m[key];
  @override
  Future<void> write(String key, String value) async => m[key] = value;
}

class _FakeTimer implements Timer {
  _FakeTimer(this.fire);
  final void Function() fire;
  bool live = true;
  @override
  void cancel() => live = false;
  @override
  bool get isActive => live;
  @override
  int get tick => 0;
}

/// A chat on screen whose timers run by hand.
class _Chat {
  _Chat({_Store? store, bool noStore = false, this.onHook}) : store = noStore ? null : (store ?? _Store());

  final _Store? store;
  final bool Function(String url)? onHook;
  String? session = 's1';
  bool visible = true;
  bool blocked = false;
  bool live = false;
  bool rating = false;
  bool disabled = false;
  bool foreground = true;
  Object? url = 'https://www.example.com/thanks';
  Future<bool> Function(String href)? opener;
  final List<String> went = [];
  final List<_FakeTimer> periodic = [];
  final List<_FakeTimer> once = [];

  late final PostChatRedirect r = PostChatRedirect(
    redirectUrl: () => url,
    sessionId: () => session,
    chatVisible: () => visible,
    blocked: () => blocked,
    live: () => live,
    ratingPending: () => rating,
    disabled: () => disabled,
    onPostChatRedirect: () => onHook,
    store: () => store,
    appInForeground: () => foreground,
    open: (href) => opener != null ? opener!(href) : _record(went, href),
    periodic: (d, fn) {
      late _FakeTimer t;
      t = _FakeTimer(() => fn(t));
      periodic.add(t);
      return t;
    },
    after: (d, fn) {
      final t = _FakeTimer(fn);
      once.add(t);
      return t;
    },
  );

  Future<void> flush() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// The settle passed (the rating's 1.5 s).
  Future<void> settle() async {
    for (final t in List.of(once)) {
      if (t.live) {
        t.live = false;
        t.fire();
      }
    }
    await flush();
  }

  Future<void> tick([int n = 1]) async {
    for (var i = 0; i < n; i++) {
      for (final t in List.of(periodic)) {
        if (t.live) t.fire();
      }
      await flush();
    }
  }

  RedirectLine? get line => r.line;
}

void main() {
  setUp(() => I18n.setWidgetLanguage('en'));

  group('safeRedirectUrl', () {
    test('only plain http(s) addresses are followed', () {
      expect(safeRedirectUrl('https://example.com/thanks'), 'https://example.com/thanks');
      expect(safeRedirectUrl('  http://example.com  '), 'http://example.com/');
      expect(safeRedirectUrl('HTTPS://Example.com/a?b=1#c'), 'https://example.com/a?b=1#c');
      for (final bad in <Object?>[
        'javascript:alert(1)',
        ' JavaScript:alert(1)',
        'data:text/html,<script>alert(1)</script>',
        'mailto:a@b.co',
        '//example.com',
        'example.com',
        'ftp://example.com',
        'https://user:pass@example.com',
        'https://',
        '',
        null,
        42,
        'https://example.com/${'a' * 3000}',
      ]) {
        expect(safeRedirectUrl(bad), isNull, reason: '$bad');
      }
    });

    test('writes the address as a browser does', () {
      expect(safeRedirectUrl('https://example.com?x=1'), 'https://example.com/?x=1');
      expect(safeRedirectUrl('https://example.com:443/a'), 'https://example.com/a');
      expect(safeRedirectUrl('http://example.com:8080/a'), 'http://example.com:8080/a');
      expect(safeRedirectUrl('https://[::1]/a'), 'https://[::1]/a');
      expect(safeRedirectUrl('https://user@example.com'), isNull);
      expect(safeRedirectUrl('https://exa mple.com'), isNull);
      expect(safeRedirectUrl('https://example.com:99999'), isNull);
      expect(safeRedirectUrl('https://example.com:abc'), isNull);
    });
  });

  test('the line names the site without www', () {
    expect(redirectHost('https://www.example.com/x'), 'example.com');
    expect(redirectHost('https://shop.example.co.uk/'), 'shop.example.co.uk');
  });

  test('counts down 10 seconds, then opens the URL outside the chat', () async {
    final c = _Chat();
    expect(await c.r.start('s1'), RedirectStart.none, reason: 'not ended yet');
    c.r.conversationEnded();
    await c.settle();
    expect(c.line?.text, I18n.tFor('en', 'redirect.countdown', {'host': 'example.com', 'n': 10}));
    expect(c.line?.text, 'Taking you to example.com in 10s');
    expect(c.line?.cancelText, 'Cancel');
    expect(c.line?.cancelLabel, 'Cancel going to example.com');
    await c.tick(3);
    expect(c.line?.text, 'Taking you to example.com in 7s');
    // Said once, not every second.
    expect(c.line?.said, 'Taking you to example.com in 10s');
    await c.tick(6);
    expect(c.went, isEmpty);
    await c.tick();
    expect(c.went, ['https://www.example.com/thanks']);
    expect(c.line?.phase, RedirectPhase.going);
    expect(c.line?.text, 'Taking you to example.com…');
    await c.tick(5);
    expect(c.went.length, 1);
  });

  test('Cancel stops it and takes the line away', () async {
    final c = _Chat();
    c.r.conversationEnded();
    await c.settle();
    c.r.cancel();
    expect(c.line, isNull);
    await c.tick(20);
    expect(c.went, isEmpty);
  });

  test('once per conversation, also after a restart restores it', () async {
    final store = _Store();
    var c = _Chat(store: store);
    c.r.conversationEnded();
    await c.settle();
    c.r.cancel();
    // The agent ends it again.
    c.r.conversationEnded();
    await c.settle();
    expect(c.line, isNull);
    // The ended chat restored after a restart.
    c = _Chat(store: store);
    expect(await redirectAlreadyOffered('s1', store), isTrue);
    expect(store.m['${redirectDoneKeyPrefix}s1'], '1');
    c.r.conversationEnded();
    await c.settle();
    expect(c.line, isNull);
    // A new conversation gets its own.
    c.session = 's2';
    c.r.conversationEnded();
    await c.settle();
    expect(c.line?.phase, RedirectPhase.counting);
  });

  test('without storage, once per conversation while the app runs', () async {
    final c = _Chat(noStore: true);
    c.r.conversationEnded();
    await c.settle();
    c.r.cancel();
    expect(await c.r.start('s1'), RedirectStart.none);
  });

  test('nothing for a bad URL, no URL, or the app turning it off', () async {
    for (final setup in <void Function(_Chat)>[
      (c) => c.url = 'javascript:alert(1)',
      (c) => c.url = '',
      (c) => c.url = null,
      (c) => c.disabled = true,
    ]) {
      final c = _Chat();
      setup(c);
      c.r.conversationEnded();
      await c.settle();
      expect(c.line, isNull);
      expect(c.store!.m, isEmpty);
    }
  });

  test('the app\'s hook gets the URL first: true means no countdown', () async {
    final got = <String>[];
    final c = _Chat(onHook: (u) { got.add(u); return true; });
    c.r.conversationEnded();
    await c.settle();
    expect(got, ['https://www.example.com/thanks']);
    expect(c.line, isNull);
    await c.tick(20);
    expect(c.went, isEmpty);
    // Remembered: not offered again.
    c.r.conversationEnded();
    await c.settle();
    expect(got.length, 1);

    // Anything but true (or a throw): the SDK counts down.
    for (final hook in <bool Function(String)>[(_) => false, (_) => throw StateError('x')]) {
      final d = _Chat(onHook: hook);
      d.r.conversationEnded();
      await d.settle();
      expect(d.line?.phase, RedirectPhase.counting);
    }
  });

  test('waits for the rating to be sent or put away', () async {
    final c = _Chat()..rating = true;
    c.r.conversationEnded();
    await c.settle();
    expect(c.line, isNull);
    c.rating = false;
    c.r.update();
    await c.settle();
    expect(c.line?.phase, RedirectPhase.counting);
  });

  test('the rating coming up within the settle waits for it', () async {
    final c = _Chat();
    c.r.conversationEnded();
    c.rating = true;
    c.r.update();
    await c.settle();
    expect(c.line, isNull);
    c.rating = false;
    c.r.update();
    await c.settle();
    expect(c.line?.phase, RedirectPhase.counting);
  });

  test('a closed chat, a new conversation, a block, a person or the background stops it', () async {
    for (final change in <void Function(_Chat)>[
      (c) => c.visible = false,
      (c) => c.session = 's2',
      (c) => c.blocked = true,
      (c) => c.live = true,
      (c) => c.foreground = false,
    ]) {
      final c = _Chat();
      c.r.conversationEnded();
      await c.settle();
      await c.tick(2);
      expect(c.line?.phase, RedirectPhase.counting);
      change(c);
      await c.tick(20);
      expect(c.line, isNull);
      expect(c.went, isEmpty);
    }
    // update() stops it at once (the provider calls it on every change).
    final c = _Chat();
    c.r.conversationEnded();
    await c.settle();
    c.visible = false;
    c.r.update();
    expect(c.line, isNull);
  });

  test('a chat that ended off screen does not count down when opened later', () async {
    final c = _Chat()..visible = false;
    c.r.conversationEnded();
    await c.settle();
    c.visible = true;
    c.r.update();
    await c.settle();
    expect(c.line, isNull);
    expect(c.store!.m, isEmpty);
    // An agent ending it again, on screen: tried again.
    c.r.conversationEnded();
    await c.settle();
    expect(c.line?.phase, RedirectPhase.counting);
  });

  test('a restart: the next conversation gets its own', () async {
    final c = _Chat();
    c.r.conversationEnded();
    await c.settle();
    c.r.reset();
    expect(c.line, isNull);
    c.session = 's2';
    c.r.conversationEnded();
    await c.settle();
    expect(c.line?.phase, RedirectPhase.counting);
    expect(c.store!.m.length, 2);
  });

  test('when the system cannot open it, a Continue button to tap', () async {
    final c = _Chat();
    var refuse = true;
    final went = <String>[];
    c.opener = (u) async {
      if (refuse) throw StateError('no browser');
      went.add(u);
      return true;
    };
    c.url = 'https://example.com/next';
    c.r.conversationEnded();
    await c.settle();
    await c.tick(10);
    expect(c.line?.phase, RedirectPhase.continueLink);
    expect(c.line?.text, 'Continue to example.com');
    expect(c.line?.href, 'https://example.com/next');
    refuse = false;
    expect(await c.r.continueNow(), isTrue);
    expect(went, ['https://example.com/next']);
    expect(c.line, isNull);
  });

  test('translated in every widget language', () {
    String en(String key) => I18n.tFor('en', key, {'host': 'example.com', 'n': 10});
    for (final lang in ['nl', 'fr', 'de', 'es']) {
      for (final key in ['redirect.countdown', 'redirect.cancel', 'redirect.going', 'redirect.continue']) {
        final s = I18n.tFor(lang, key, {'host': 'example.com', 'n': 10});
        expect(s, isNot(en(key)), reason: '$lang $key');
        expect(s, contains('example.com'));
      }
      expect(I18n.tFor(lang, 'redirect.countdown', {'host': 'x.io', 'n': 7}), contains('7'));
    }
  });
}

Future<bool> _record(List<String> went, String href) {
  went.add(href);
  return Future.value(true);
}
