// The home screen in the SDK (lib/src/core/home/home_extras.dart): the view,
// what the device remembers, the help centre data and the server's search
// inside article text. RN __tests__/context/useHomeScreen.test.ts and
// Android HomeExtrasTest.kt, on a fake clock, store and socket.
import 'dart:async';

import 'package:conferbot_flutter/src/core/home/home.dart';
import 'package:conferbot_flutter/src/core/home/home_extras.dart';
import 'package:conferbot_flutter/src/core/requests/requests.dart';
import 'package:conferbot_flutter/src/core/requests/requests_extras.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryStore implements RequestsStore {
  final Map<String, String> data = {};
  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> write(String key, String value) async => data[key] = value;
}

class FakeSocket implements RequestsSocket {
  FakeSocket(this.answer);
  dynamic answer;
  final List<(String, dynamic)> asks = [];
  @override
  Future<dynamic> emitWithAck(String event, dynamic payload, Duration timeout) async {
    asks.add((event, payload));
    if (answer is Exception) throw answer as Exception;
    return answer;
  }

  @override
  void emit(String event, dynamic payload) {}
  @override
  void Function() on(String event, void Function(dynamic data) fn) => () {};
}

const now = 1800000000000;

void main() {
  late Map<String, dynamic> c;
  late MemoryStore store;
  late FakeSocket socket;
  late List<String> sent;
  late int shown;
  String? session;
  String bot = 'bot1';

  HomeExtras make() => HomeExtras(
        botId: () => bot,
        customizations: () => c,
        chatSessionId: () => session,
        store: () => store,
        socket: () => socket,
        connected: () => true,
        send: sent.add,
        onHomeShown: () => shown++,
        now: () => now,
      );

  setUp(() {
    c = {'enableInitialPage': true};
    store = MemoryStore();
    socket = FakeSocket({'success': true, 'articles': []});
    sent = [];
    shown = 0;
    session = 's1';
    bot = 'bot1';
  });

  test('opens on the home screen only while the owner has one', () {
    final h = make();
    expect(h.view, HomeView.home);
    expect(h.hasHome, isTrue);
    h.showChat();
    expect(h.view, HomeView.chat);
    c = {};
    expect(h.view, HomeView.chat);
    h.showHome();
    expect(h.view, HomeView.chat, reason: 'no home to go back to');
    expect(h.back(), isFalse);
  });

  test('the help centre on a topic, and back to the home when it is off', () {
    final h = make();
    c = {'enableInitialPage': true, 'enableKnowledgeBase': true};
    h.showHelp(categoryId: 'c1');
    expect(h.view, HomeView.help);
    expect(h.helpCategoryId, 'c1');
    c = {'enableInitialPage': true};
    expect(h.view, HomeView.home);
  });

  test('back: the help centre to where it came from, the conversation to the home', () {
    final h = make();
    c = {'enableInitialPage': true, 'enableKnowledgeBase': true};
    h.showChat();
    h.showHelp();
    expect(h.back(), isTrue);
    expect(h.view, HomeView.chat);
    expect(h.helpCategoryId, isNull);
    expect(h.back(), isTrue);
    expect(h.view, HomeView.home);
    expect(h.back(), isFalse);
    h.showHelp();
    expect(h.back(), isTrue);
    expect(h.view, HomeView.home);
  });

  test('a question from the home is asked in the chat, after the chat is there', () {
    final timers = <(Duration, void Function(), _FakeTimer)>[];
    final h = HomeExtras(
      botId: () => bot,
      customizations: () => c,
      chatSessionId: () => session,
      socket: () => socket,
      connected: () => true,
      send: sent.add,
      timer: (after, fn) {
        final t = _FakeTimer();
        timers.add((after, fn, t));
        return t;
      },
    );
    h.showChat('  Do you ship to Canada?  ');
    expect(h.view, HomeView.chat);
    expect(sent, isEmpty);
    expect(timers.single.$1, const Duration(milliseconds: 400));
    timers.single.$2();
    expect(sent, ['Do you ship to Canada?']);
    // A new session drops a question not yet asked.
    h.showChat('Another');
    h.reset();
    expect(timers.last.$3.cancelled, isTrue);
  });

  test('the home coming into view reads the requests again', () {
    final h = make();
    h.homeShown();
    expect(shown, 1);
  });

  test('remembers the first real question and the name on the device, per bot', () async {
    final h = make();
    await h.rememberText('hi');
    expect(h.memory!.topic, isNull);
    await h.rememberText('Do you support Shopify stores?');
    await h.rememberName('jamie lee');
    expect(h.memory!.topic, 'Do you support Shopify stores?');
    expect(h.memory!.session, 's1');
    expect(h.memory!.name, 'Jamie');
    final kept = parseHomeMemory(store.data[homeMemoryKey('bot1')], now)!;
    expect(kept.name, 'Jamie');
    expect(kept.topic, 'Do you support Shopify stores?');
    // Not a name: nothing changes.
    await h.rememberName('x@y.com');
    expect(h.memory!.name, 'Jamie');
  });

  test('what the device kept is read back', () async {
    store.data[homeMemoryKey('bot1')] = serializeHomeMemory(const VisitorMemory(at: now - liveChatMs, name: 'Jamie', topic: 'Refunds please, how do they work', session: 's0'));
    final h = make();
    await h.load();
    expect(h.memory!.name, 'Jamie');
    expect(welcomeBack(h.memory, now)!.hello, 'Welcome back, Jamie');
  });

  test('keeps the help centre from the bot data', () {
    final h = make();
    h.setKnowledgeBase({
      'categories': [
        {
          'name': 'Billing',
          'articles': [
            {'_id': '1', 'title': 'Plans'},
          ],
        },
      ],
      'recentArticles': [
        {'_id': '2', 'title': 'Start'},
      ],
    });
    expect(h.knowledgeBase.categories, hasLength(1));
    expect(h.knowledgeBase.rawArticles.map((a) => a['_id']), ['2', '1']);
    h.setKnowledgeBase(null);
    expect(h.knowledgeBase.rawArticles, isEmpty);
  });

  test('asks the server for matches inside article text, once per query that answered', () async {
    socket.answer = {
      'success': true,
      'articles': [
        {'_id': '4', 'snippet': 'Each invoice is a PDF'},
        {'snippet': 'no id'},
      ],
    };
    final h = make();
    final hits = await h.searchArticleText(' PDF Vat ');
    expect(hits, [(id: '4', snippet: 'Each invoice is a PDF')]);
    expect(socket.asks.single.$1, 'search-kb-articles');
    expect(socket.asks.single.$2, {'chatbotId': 'bot1', 'query': 'pdf vat', 'limit': 10});
    await h.searchArticleText('pdf vat');
    expect(socket.asks, hasLength(1));
    expect(await h.searchArticleText('x'), isEmpty);
    expect(socket.asks, hasLength(1));
  });

  test('a failed search is not kept', () async {
    socket.answer = {'success': false};
    final h = make();
    expect(await h.searchArticleText('refunds'), isEmpty);
    socket.answer = Exception('timeout');
    expect(await h.searchArticleText('refunds'), isEmpty);
    socket.answer = {
      'success': true,
      'articles': [
        {'_id': '1', 'snippet': 's'},
      ],
    };
    expect(await h.searchArticleText('refunds'), hasLength(1));
    expect(socket.asks, hasLength(3));
  });

  test('the view is a ValueNotifier the chat listens to', () {
    final h = make();
    final seen = <HomeView?>[];
    h.chosen.addListener(() => seen.add(h.chosen.value));
    h.showChat();
    h.showHome();
    expect(seen, [HomeView.chat, HomeView.home]);
  });
}

class _FakeTimer implements Timer {
  bool cancelled = false;
  @override
  void cancel() => cancelled = true;
  @override
  bool get isActive => !cancelled;
  @override
  int get tick => 0;
}
