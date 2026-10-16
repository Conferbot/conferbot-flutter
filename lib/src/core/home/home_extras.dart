/// The home screen in the SDK (web conferbot-widget
/// src/ts/home/firstImpression.ts enhanceHome / goToChat, index.ts's view
/// switches, ts/home/visitorMemory.ts, ts/knowledgeBase/kbContent.ts
/// remoteSearch; RN context/hooks/useHomeScreen.ts; Android
/// core/home/HomeExtras.kt). Holds:
///
///   - which view the open chat shows ([view], a ValueNotifier): the home
///     screen, the conversation or the help centre ([safeHomeView]: the home
///     only while the owner has it on). It starts on the home and keeps the
///     last view while the app runs, as the web keeps it for the page;
///   - what the device remembers for "Welcome back" (per bot in
///     shared_preferences, in memory without a store): the first real
///     question of the latest conversation the visitor typed in, their first
///     name once a flow asked for it, when they last wrote;
///   - the help centre's data from fetched-chatbot-data, for the home's
///     cards, and the server's search inside article text.
///
/// Owned by ConferBotProvider (`provider.home`); drawn by
/// widgets/home/home_screen_view.dart inside the chat.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../requests/requests.dart';
import '../requests/requests_extras.dart';
import 'home.dart';

/// The help centre as fetched-chatbot-data sends it (`knowledgeBaseData`, lists of maps).
class HomeKnowledgeBase {
  const HomeKnowledgeBase({this.categories = const [], this.recentArticles = const []});
  final List<dynamic> categories;
  final List<dynamic> recentArticles;

  /// Every raw article, for [remoteQueryFor].
  List<dynamic> get rawArticles => [
        ...recentArticles,
        for (final c in categories)
          if (c is Map && c['articles'] is List) ...(c['articles'] as List),
      ];
}

typedef HomeTimer = Timer Function(Duration after, void Function() fn);

class HomeExtras extends ChangeNotifier {
  HomeExtras({
    required String? Function() botId,
    required Map<String, dynamic>? Function() customizations,
    required String? Function() chatSessionId,
    RequestsStore? Function()? store,
    required RequestsSocket? Function() socket,
    required bool Function() connected,
    required void Function(String text) send,
    void Function()? onHomeShown,
    HomeTimer? timer,
    int Function()? now,
  })  : _botId = botId,
        _customizations = customizations,
        _chatSessionId = chatSessionId,
        _store = store ?? (() => null),
        _socket = socket,
        _connected = connected,
        _send = send,
        _onHomeShown = onHomeShown ?? (() {}),
        _timer = timer ?? Timer.new,
        _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  /// The web's wait for the server's article search (kbContent.ts SEARCH_TIMEOUT_MS).
  static const searchTimeout = Duration(seconds: 5);

  /// Into the chat, then the question: the same pause the greeting card's "send" has.
  static const askAfter = Duration(milliseconds: 400);
  static const eventSearch = 'search-kb-articles';

  final String? Function() _botId;
  final Map<String, dynamic>? Function() _customizations;
  final String? Function() _chatSessionId;
  final RequestsStore? Function() _store;
  final RequestsSocket? Function() _socket;
  final bool Function() _connected;
  final void Function(String text) _send;
  final void Function() _onHomeShown;
  final HomeTimer _timer;
  final int Function() _now;

  /// The view chosen (null: none yet, the home when there is one). Read with [viewFor].
  final ValueNotifier<HomeView?> chosen = ValueNotifier<HomeView?>(null);

  /// The topic the help centre opened on, if any.
  String? helpCategoryId;

  // Where the help centre's Back goes: the view it was opened from.
  HomeView _helpFrom = HomeView.home;

  VisitorMemory? _memory;
  VisitorMemory? get memory => _memory;

  HomeKnowledgeBase _knowledgeBase = const HomeKnowledgeBase();
  HomeKnowledgeBase get knowledgeBase => _knowledgeBase;

  String? _loadedFor;
  Future<void>? _loading;
  String _lastName = '';
  final Map<String, List<Map<String, dynamic>>> _searches = {};
  final List<Timer> _pending = [];
  bool _disposed = false;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  /// The view the open chat shows, for these settings.
  HomeView viewFor(Map<String, dynamic>? c) => safeHomeView(c, chosen.value);

  /// The view on screen now.
  HomeView get view => viewFor(_customizations());

  /// Is there a home screen?
  bool get hasHome => homeOn(_customizations());

  void _choose(HomeView v) {
    chosen.value = v;
    _changed();
  }

  void _save(VisitorMemory? next) {
    if (next == null) return;
    _memory = next;
    _changed();
    final store = _store();
    if (store == null) return;
    try {
      unawaited(store.write(homeMemoryKey(_botId()), serializeHomeMemory(next)).catchError((_) {}));
    } catch (_) {
      // storage full or blocked: this app session still remembers
    }
  }

  /// What the device remembers, once per bot.
  Future<void> load() {
    final bot = _botId() ?? '';
    if (_loadedFor == bot && _loading != null) return _loading!;
    _loadedFor = bot;
    _searches.clear();
    _lastName = '';
    return _loading = () async {
      String? raw;
      try {
        raw = await _store()?.read(homeMemoryKey(bot));
      } catch (_) {
        raw = null;
      }
      final read = parseHomeMemory(raw, _now());
      // Something remembered meanwhile is newer than the device's.
      if (_memory == null || (read != null && read.at > _memory!.at)) _memory = read;
      _changed();
    }();
  }

  /// The visitor typed this in a live (or agent) chat (web special.ts _handleHumanHandoverInputSubmit).
  Future<void> rememberText(String? text) async {
    if (text == null || text.trim().isEmpty) return;
    await load();
    _save(withMessage(_memory, _chatSessionId(), text, _now()));
  }

  /// A flow asked for their name (web index.ts _setUserMetaData "name").
  Future<void> rememberName(String? name) async {
    final n = (name ?? '').trim();
    if (n.isEmpty || n == _lastName) return;
    await load();
    _lastName = n;
    _save(withName(_memory, n, _now()));
  }

  /// The help centre as fetched-chatbot-data sent it.
  void setKnowledgeBase(dynamic kb) {
    _knowledgeBase = HomeKnowledgeBase(
      categories: kb is Map && kb['categories'] is List ? List.of(kb['categories'] as List) : const [],
      recentArticles: kb is Map && kb['recentArticles'] is List ? List.of(kb['recentArticles'] as List) : const [],
    );
    _changed();
  }

  /// Back to the home screen (nothing when the owner has none).
  void showHome() {
    if (hasHome) _choose(HomeView.home);
  }

  /// To the conversation; with [text], ask it there as the visitor, once the chat is there.
  void showChat([String? text]) {
    _choose(HomeView.chat);
    final words = (text ?? '').trim();
    if (words.isEmpty) return;
    late final Timer t;
    t = _timer(askAfter, () {
      _pending.remove(t);
      if (!_disposed) _send(words);
    });
    _pending.add(t);
  }

  /// The help centre, on one topic or its list; Back returns to [from].
  void showHelp({String? categoryId, HomeView? from}) {
    final f = from ?? view;
    helpCategoryId = categoryId;
    if (f != HomeView.help) _helpFrom = f;
    _choose(HomeView.help);
  }

  /// Leave the help centre for the view it came from.
  void leaveHelp() {
    helpCategoryId = null;
    if (_helpFrom == HomeView.home) {
      showHome();
    } else {
      _choose(_helpFrom);
    }
    if (view == HomeView.help) _choose(HomeView.chat);
  }

  /// The system back (or the header's back): the help centre goes back where
  /// it came from, the conversation to the home. False when there is nothing
  /// to go back to (the chat closes).
  bool back() {
    switch (view) {
      case HomeView.help:
        leaveHelp();
        return true;
      case HomeView.chat:
        if (!hasHome) return false;
        showHome();
        return true;
      case HomeView.home:
        return false;
    }
  }

  /// The home screen is on screen: its requests card reads again.
  void homeShown() => _onHomeShown();

  /// Matches inside article text from the server (web kbContent.ts
  /// remoteSearch: `search-kb-articles`, cached per query when it
  /// answered): (article id, snippet) pairs, empty on failure.
  Future<List<({String id, String snippet})>> searchArticleText(String? query) async => [
        for (final a in await searchKbArticles(query) ?? const <Map<String, dynamic>>[])
          (id: '${a['_id']}', snippet: a['snippet']?.toString() ?? ''),
      ];

  /// The server's rows for `search-kb-articles` (each with `_id`, title,
  /// description, category and `snippet`), cached per query when it
  /// answered; null when the socket is not there or did not answer (the
  /// help centre then searches over REST). Under two letters: none.
  Future<List<Map<String, dynamic>>?> searchKbArticles(String? query) async {
    final key = (query ?? '').trim().toLowerCase();
    if (key.length < 2) return const [];
    final cached = _searches[key];
    if (cached != null) return cached;
    final s = _socket();
    if (s == null || !_connected()) return null;
    try {
      final reply = await s.emitWithAck(eventSearch, {'chatbotId': _botId() ?? '', 'query': key, 'limit': 10}, searchTimeout);
      final ok = reply is Map && reply['success'] == true;
      if (!ok) return null;
      final list = <Map<String, dynamic>>[
        for (final a in (reply['articles'] is List ? reply['articles'] as List : const []))
          if (a is Map && a['_id'] != null && '${a['_id']}'.isNotEmpty) Map<String, dynamic>.from(a),
      ];
      // Failures are not kept, so the next keystroke can try again.
      _searches[key] = list;
      return list;
    } catch (_) {
      return null;
    }
  }

  /// A new SDK session: the questions waiting to be asked go.
  void reset() {
    for (final t in _pending) {
      t.cancel();
    }
    _pending.clear();
  }

  @override
  void dispose() {
    _disposed = true;
    reset();
    chosen.dispose();
    super.dispose();
  }
}
