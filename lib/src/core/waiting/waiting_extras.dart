/// While the visitor waits for a person, as the web widget has it: the help
/// card (the articles for their question 6s in, or the server's queue-help
/// pick with "That solved it"), the games offer 2.5s after the waiting
/// signal, and "play" typed while waiting. Ported from the React Native SDK
/// (src/context/hooks/useWaitingExtras.ts). The rules are in
/// wait_articles.dart, waiting_games.dart and games_card.dart (from the
/// web's waitArticles.ts, games/wire.ts, games/ui.ts and handlers/special.ts
/// _wireQueue); this class feeds them the handover's signals and the socket.
/// Owned by ConferBotProvider.
///
/// Each card sits in the conversation after the message that was last on
/// screen when it was drawn ([helpAfter], [gamesAfter]); it is never put in
/// the record the server keeps, the message store or the device.
library;


import 'package:flutter/foundation.dart';

import '../../services/socket_client.dart';
import '../live_chat/handover_state.dart';
import '../live_chat/handover_waiting.dart';
import 'games_card.dart';
import 'wait_articles.dart';
import 'waiting_games.dart';

class WaitingExtras extends ChangeNotifier {
  WaitingExtras({
    required SocketClient? Function() socket,
    required String? Function() sessionId,
    required List<Map<String, dynamic>> Function() record,
    required dynamic Function() customizations,
    required bool Function() personJoined,
    required void Function() leftQueueHelped,
    String? Function()? lastShownId,
    bool Function()? reducedMotion,
    SetTimer? setTimer,
    ClearTimer? clearTimer,
    double Function()? now,
  })  : _socket = socket,
        _sessionId = sessionId,
        _record = record,
        _customizations = customizations,
        _leftQueueHelped = leftQueueHelped,
        _lastShownId = lastShownId ?? (() => null),
        _reducedMotion = reducedMotion ?? (() => PlatformDispatcher.instance.accessibilityFeatures.disableAnimations),
        _setTimer = setTimer,
        _clearTimer = clearTimer,
        _now = now {
    help = WaitHelp(
      customizations: _customizations,
      question: () => waitQuestion(_record()),
      articles: () => (categories: _categories, recentArticles: _recent),
      joined: personJoined,
      onChange: _onHelpCard,
      setTimer: setTimer,
      clearTimer: clearTimer,
    );
    offer = GamesOffer(
      enabled: () => waitingGamesOf(_customizations()).enabled,
      mount: _mountGames,
      setTimer: setTimer,
      clearTimer: clearTimer,
    );
  }

  final SocketClient? Function() _socket;
  final String? Function() _sessionId;
  final List<Map<String, dynamic>> Function() _record;
  final dynamic Function() _customizations;
  final void Function() _leftQueueHelped;
  final String? Function() _lastShownId;
  final bool Function() _reducedMotion;
  final SetTimer? _setTimer;
  final ClearTimer? _clearTimer;
  final double Function()? _now;

  late final WaitHelp help;
  late final GamesOffer offer;

  // The bot's help centre from fetched-chatbot-data, as sent.
  List _categories = const [];
  List _recent = const [];

  /// The help card, or null.
  HelpCardState? helpCard;

  /// The message the help card is drawn after (null: at the end).
  String? helpAfter;

  /// The games card on screen, or null.
  GamesCard? gamesCard;

  /// The message the games card is drawn after (null: at the end).
  String? gamesAfter;

  /// Which card was drawn last (it comes second when both follow one message).
  bool gamesAfterHelp = false;

  int _gamesSeq = 0;
  final List<void Function()> _offs = [];
  bool _disposed = false;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void _onHelpCard(HelpCardState? card) {
    final before = helpCard;
    helpCard = card;
    // A new card (its key) is drawn after the conversation so far.
    if (card != null && card.key != before?.key) {
      helpAfter = _lastShownId();
      gamesAfterHelp = false;
    }
    if (card == null) helpAfter = null;
    _changed();
  }

  OfferCard? _mountGames(String mode) {
    final card = GamesCard.create(GamesCardOptions(
      customizations: _customizations(),
      categories: _categories,
      recentArticles: _recent,
      mode: mode,
      reducedMotion: _reducedMotion(),
      onDismiss: () => offer.dismissed(),
      setTimer: _setTimer,
      clearTimer: _clearTimer,
      now: _now,
    ));
    if (card == null) return null;
    final n = ++_gamesSeq;
    // Gone (Not now, the x, the wait over, a person joined before it was played): off the screen.
    card.subscribe((s) {
      if (_gamesSeq != n) return;
      if (s.view == 'gone') {
        gamesCard = null;
        gamesAfter = null;
      }
      _changed();
    });
    gamesCard = card;
    gamesAfter = _lastShownId();
    gamesAfterHelp = true;
    _changed();
    return card;
  }

  /// Listen to the handover's signals (HandoverLifecycle.onSignal).
  void bind(void Function() Function(String name, void Function(Map<String, dynamic> detail) fn) onSignal) {
    _offs.add(onSignal(WidgetSignals.waitingForHuman, (_) => offer.waiting()));
    _offs.add(onSignal(WidgetSignals.humanJoined, (d) {
      help.endWait();
      offer.joined(d['name'] ?? '');
    }));
    _offs.add(onSignal(WidgetSignals.waitOver, (_) {
      help.endWait();
      offer.waitOver();
    }));
  }

  bool _own(dynamic data) {
    final id = data is Map ? data['chatSessionId']?.toString() ?? '' : '';
    final mine = _sessionId() ?? '';
    return id.isEmpty || mine.isEmpty || id == mine;
  }

  /// The socket: the server's pick of help, and the queue it keeps.
  void setupListeners() {
    final s = _socket();
    if (s == null) return;
    s.on('queue-help', (data) {
      if (_own(data)) help.queueHelp(data);
    });
    s.on('queue-left', (data) {
      if (_own(data) && data is Map && data['reason'] == 'self_service') help.left();
    });
  }

  /// queue-status, from the event or the poll's answer (LiveChatExtras).
  void onQueueStatus(dynamic data) {
    if (data is Map && _own(data)) help.queueStatus(data);
  }

  /// Where the handover begins a wait for a person (HandoverLifecycle).
  void startWait() => help.startWait();

  /// Where the handover's wait for a person ends.
  void endWait() => help.endWait();

  /// "That solved it": queue-self-resolve with the article; ok leaves the queue.
  Future<bool> solveWait() async {
    final item = help.solving();
    if (item == null) return false;
    dynamic res;
    try {
      final s = _socket();
      final sid = _sessionId() ?? '';
      final raw = s == null
          ? null
          : await s.emitWithAck('queue-self-resolve', HandoverRecord.queueSelfResolvePayload(sid, item.id), timeout: solveTimeout);
      res = raw is List && raw.isNotEmpty ? raw.first : raw;
    } catch (_) {
      res = null;
    }
    final ok = res is Map && res['ok'] == true;
    help.solved(ok);
    if (ok) _leftQueueHelped();
    return ok;
  }

  /// A row of the help card was opened (it is the article "That solved it" names).
  void opened(HelpItem item) => help.open(item.id);

  /// An article by id in the bot's help centre data, or null.
  Map? articleById(String id) => findArticle(id, _categories, _recent);

  /// The visitor's words while waiting: "play" opens the games instead (true: do not send).
  bool interceptPlay(String text) => offer.play(text);

  /// fetched-chatbot-data's knowledgeBaseData.
  void setKnowledgeBase(dynamic kb) {
    _categories = kb is Map && kb['categories'] is List ? kb['categories'] as List : const [];
    _recent = kb is Map && kb['recentArticles'] is List ? kb['recentArticles'] as List : const [];
  }

  /// A new conversation: no card, no wait ("Not now" still holds for the app session).
  void reset() {
    help.reset();
    offer.reset();
    gamesCard?.remove();
    gamesCard = null;
    gamesAfter = null;
    _gamesSeq += 1;
    _changed();
  }

  @override
  void dispose() {
    for (final off in _offs) {
      off();
    }
    _offs.clear();
    help.reset();
    offer.reset();
    gamesCard?.remove();
    _disposed = true;
    super.dispose();
  }
}
