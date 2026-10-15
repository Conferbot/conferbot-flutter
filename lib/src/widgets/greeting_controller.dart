/// The greeting card's life, as the web runs it (conferbot-widget
/// ts/visibility/greeting.ts; ported from the React Native SDK's
/// src/components/FloatingWidget/useGreeting.ts): decided once the bot's
/// settings arrive, shown after its delay unless the chat is open or the
/// frequency says no, gone for a while once closed or used. A new visit
/// counts once per app session. Kept per bot as `conferbot.greeting.<botId>`.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/agent/agent_bot.dart';
import '../core/customization/greeting.dart';

/// What the card shows, decided when it appears.
class GreetingCardData {
  final String style;
  final String text;
  final GreetingHead head;
  final List<String> starters;

  /// The launcher's colours (imessage and voice) and the accent (chips, stamp, glows).
  final GreetingBubble bubble;
  final String accent;

  /// The bot's own font, or null.
  final String? font;

  /// The phone text's typing moment plays once per app session.
  final bool firstShow;
  final String click;
  final String linkUrl;

  const GreetingCardData({
    required this.style,
    required this.text,
    required this.head,
    required this.starters,
    required this.bubble,
    required this.accent,
    required this.font,
    required this.firstShow,
    required this.click,
    required this.linkUrl,
  });

  /// The card as the bot's settings dress it.
  factory GreetingCardData.from(Map<String, dynamic> c, ResolvedGreeting g, {AgentBot? agentBot, String botName = '', bool firstShow = true}) {
    final head = Greeting.head(c, botName);
    final agentAvatar = agentBot?.avatar;
    return GreetingCardData(
      style: Greeting.normalizeStyle(c['greetingStyle']),
      text: g.text,
      head: agentBot == null
          ? head
          : GreetingHead(
              avatar: agentAvatar != null && agentAvatar.isNotEmpty ? agentAvatar : head.avatar,
              name: agentBot.displayName.isNotEmpty ? agentBot.displayName : head.name,
              online: head.online,
            ),
      starters: (g.starters.isNotEmpty ? g.starters : agentBot?.starters ?? const <String>[]).take(3).toList(),
      bubble: Greeting.bubble(c),
      accent: Greeting.accent(c),
      font: Greeting.font(c),
      firstShow: firstShow,
      click: g.click,
      linkUrl: g.linkUrl,
    );
  }
}

class _Session {
  bool counted = false;
  bool shownThisSession = false;
  bool typed = false;
}

class GreetingController extends ChangeNotifier {
  GreetingController(this.botId);

  final String botId;

  /// Seen state per bot for this app session (the "session" frequency, the phone text's typing moment).
  static final Map<String, _Session> _sessions = {};

  @visibleForTesting
  static void resetSession() => _sessions.clear();

  static String storageKey(String botId) => 'conferbot.greeting.${botId.isEmpty ? 'default' : botId}';

  GreetingCardData? _card;
  GreetingCardData? get card => _card;

  GreetingRecord? _seen;
  Map<String, dynamic>? _customizations;
  bool _chatOpen = false;
  AgentBot? _agentBot;
  Timer? _timer;
  int _run = 0;
  bool _disposed = false;

  _Session get _session => _sessions.putIfAbsent(botId, _Session.new);

  Future<GreetingRecord> _read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return GreetingRecord.decode(prefs.getString(storageKey(botId)));
    } catch (_) {
      return const GreetingRecord();
    }
  }

  void _write(GreetingRecord st) {
    _seen = st;
    SharedPreferences.getInstance().then((p) => p.setString(storageKey(botId), st.encode())).catchError((_) => false);
  }

  void _set(GreetingCardData? card) {
    if (_disposed || identical(card, _card)) return;
    _card = card;
    notifyListeners();
  }

  /// Feed the bot's settings and the chat's state; re-decides only when they change.
  /// [visitorContext] is the signed-in user (ChatState.visitorContext); [enabled] false keeps the card away.
  void update({
    required Map<String, dynamic>? customizations,
    required bool chatOpen,
    AgentBot? agentBot,
    Map<String, dynamic>? visitorContext,
    String botName = '',
    bool enabled = true,
  }) {
    final c = enabled ? customizations : null;
    if (identical(c, _customizations) && chatOpen == _chatOpen && agentBot == _agentBot) return;
    final opened = chatOpen && !_chatOpen;
    _customizations = c;
    _chatOpen = chatOpen;
    _agentBot = agentBot;
    if (opened) _markChatted(_card != null);
    _timer?.cancel();
    final run = ++_run;
    if (c == null || chatOpen) {
      _set(null);
      return;
    }
    _decide(run, c, agentBot, visitorContext, botName);
  }

  /// Chatted, for rules that ask; and opening the chat rests the card, as closing it does.
  Future<void> _markChatted(bool showing) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final st = _seen ?? await _read();
    if (_disposed) return;
    _write(st.copyWith(chatted: true, closedAt: showing ? now : null));
  }

  Future<void> _decide(int run, Map<String, dynamic> c, AgentBot? agentBot, Map<String, dynamic>? ctx, String botName) async {
    var st = _seen ?? await _read();
    if (run != _run || _disposed) return;
    final s = _session;
    if (!s.counted) {
      s.counted = true;
      st = st.copyWith(visits: st.visits + 1);
      _write(st);
    }
    _seen = st;
    bool has(String k) => ctx?[k] != null && '${ctx![k]}'.isNotEmpty;
    final g = Greeting.decide(
      c,
      GreetingFacts(
        returning: st.visits > 1,
        signedIn: has('id') || has('email'),
        visits: st.visits == 0 ? 1 : st.visits,
        chatted: st.chatted,
        shows: st.shows,
        dismissed: st.dismissed,
      ),
    );
    if (g == null) return;
    if (!Greeting.frequencyAllows(c, GreetingSeen(shownAt: st.shownAt, closedAt: st.closedAt, shownThisSession: s.shownThisSession))) return;
    _timer = Timer(Duration(seconds: g.delay), () {
      if (run != _run || _disposed) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      s.shownThisSession = true;
      // Each rule's shows count against its limits.
      final seen = _seen ?? st;
      final shows = Map<String, List<int>>.from(seen.shows);
      final kept = [...(shows[g.key] ?? const <int>[]).where((t) => now - t < 90 * 86400000), now];
      shows[g.key] = kept.length > 20 ? kept.sublist(kept.length - 20) : kept;
      _write(seen.copyWith(shownAt: now, shows: shows, last: g.key));
      final card = GreetingCardData.from(c, g, agentBot: agentBot, botName: botName, firstShow: !s.typed);
      s.typed = true;
      _set(card);
    });
  }

  /// Closed with the X: rests on this "page" and counts as a dismissal of its rule.
  void dismiss() {
    final now = DateTime.now().millisecondsSinceEpoch;
    var st = (_seen ?? const GreetingRecord()).copyWith(closedAt: now);
    if (st.last != null) st = st.copyWith(dismissed: {...st.dismissed, st.last!: now});
    _write(st);
    _set(null);
  }

  /// Used (tapped): rests for a while like a close, but is not a dismissal of its rule.
  void closeForNow() {
    _write((_seen ?? const GreetingRecord()).copyWith(closedAt: DateTime.now().millisecondsSinceEpoch));
    _set(null);
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
