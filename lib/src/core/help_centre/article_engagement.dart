/// The help centre over the chat's socket, as the web widget does it:
/// helpful / not helpful (`rate-article`), reading time and scroll depth
/// (`track-article-engagement`) and the server's search inside article
/// bodies (`search-kb-articles`, with snippets).
///
/// Ported from the web widget's `ts/knowledgeBase/knowledgeBase.ts`
/// (`_rateArticle`, `_startArticleEngagement`, `_updateScrollDepth`,
/// `_sendArticleEngagement`) and `ts/knowledgeBase/kbContent.ts`
/// (`remoteSearch`); the payloads are the ones embed-server's
/// `socket/handlers/chatbotHandler.js` reads.
library;

/// Sends on the chat's socket: false when it is not connected (nothing sent).
typedef HelpCentreEmit = bool Function(String event, Map<String, dynamic> payload);

/// The server's article search: its rows (each with `_id` and `snippet`),
/// or null when the socket could not answer (then REST is used).
typedef HelpCentreSearch = Future<List<Map<String, dynamic>>?> Function(String query);

/// What the help centre needs from the chat: its socket and conversation.
class HelpCentreLink {
  const HelpCentreLink({required this.emit, this.search, this.sessionId});

  final HelpCentreEmit emit;
  final HelpCentreSearch? search;

  /// The conversation (`chatSessionId`), sent as the web's `sessionId`.
  final String? Function()? sessionId;
}

/// How a rating went.
enum ArticleVote {
  /// Sent on the socket (`rate-article`).
  sent,

  /// Not connected: nothing sent, the caller may use REST.
  offline,

  /// This article was rated already in this session (the web's guard).
  already,
}

/// One article read at a time: when it opened, how far it was scrolled.
/// Ratings once per article per session.
class ArticleEngagement {
  ArticleEngagement({
    this.link,
    this.visitorId,
    int Function()? now,
    this.device = 'mobile',
  }) : _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  static const eventRate = 'rate-article';
  static const eventEngagement = 'track-article-engagement';

  /// Fewer seconds than this is an accidental tap: not sent (web).
  static const minSeconds = 2;

  /// Scrolled this far (percent) counts as read to the end (web).
  static const completedAt = 90;

  HelpCentreLink? link;

  /// The web's `_getDeviceType()`; an app is on a phone or tablet.
  final String device;

  /// The visitor, sent as the web's `visitorId` when known.
  String? visitorId;
  final int Function() _now;

  final Set<String> _rated = {};
  String? _articleId;
  int _startedAt = 0;
  double _maxDepth = 0;
  bool _completed = false;

  /// The article being read, if any.
  String? get articleId => _articleId;

  /// The deepest scroll so far (0-100).
  double get maxDepth => _maxDepth;
  bool get completed => _completed;

  bool hasRated(String articleId) => _rated.contains(articleId);

  /// An article opened: the one before it is sent first.
  void start(String articleId) {
    send();
    _articleId = articleId;
    _startedAt = _now();
    _maxDepth = 0;
    _completed = false;
  }

  /// The article was scrolled to [depth] percent of its scrollable height.
  void scrolled(num depth) {
    if (_articleId == null) return;
    final d = depth.toDouble();
    if (!d.isFinite || d <= _maxDepth) return;
    _maxDepth = d > 100 ? 100 : d;
    if (_maxDepth >= completedAt) _completed = true;
  }

  /// The article was left: its reading time and depth go to the server
  /// (at least [minSeconds]). Returns what was sent, else null. Reading
  /// stops either way.
  Map<String, dynamic>? send() {
    final id = _articleId;
    if (id == null) return null;
    final seconds = ((_now() - _startedAt) / 1000).round();
    final payload = seconds < minSeconds
        ? null
        : engagementPayload(
            articleId: id,
            visitorId: visitorId,
            sessionId: link?.sessionId?.call(),
            timeSpent: seconds,
            scrollDepth: _maxDepth,
            isCompleted: _completed,
            device: device,
          );
    // Sent once: a socket that is not there loses it, as on the web.
    final sent = payload != null && (link?.emit(eventEngagement, payload) ?? false);
    _articleId = null;
    _startedAt = 0;
    _maxDepth = 0;
    _completed = false;
    return sent ? payload : null;
  }

  /// Helpful or not, once per article per session (the web answers at once).
  ArticleVote rate(String articleId, bool helpful) {
    if (articleId.isEmpty || _rated.contains(articleId)) return ArticleVote.already;
    final ok = link?.emit(
          eventRate,
          ratePayload(articleId: articleId, helpful: helpful, visitorId: visitorId, sessionId: link?.sessionId?.call(), device: device),
        ) ??
        false;
    _rated.add(articleId);
    return ok ? ArticleVote.sent : ArticleVote.offline;
  }

  /// A new SDK session: nothing rated yet, nothing being read.
  void reset() {
    _rated.clear();
    _articleId = null;
    _maxDepth = 0;
    _completed = false;
  }

  /// `rate-article` (chatbotHandler.js: articleId, visitorId, sessionId,
  /// helpful, rating; the web sends 5 for helpful and 1 for not).
  static Map<String, dynamic> ratePayload({
    required String articleId,
    required bool helpful,
    String? visitorId,
    String? sessionId,
    String? device,
  }) =>
      {
        'articleId': articleId,
        if (_set(visitorId)) 'visitorId': visitorId,
        if (_set(sessionId)) 'sessionId': sessionId,
        'helpful': helpful,
        'rating': helpful ? 5 : 1,
        if (_set(device)) 'device': device,
      };

  /// `track-article-engagement` (chatbotHandler.js: articleId, visitorId,
  /// sessionId, timeSpent in seconds, scrollDepth 0-100, isCompleted, device).
  static Map<String, dynamic> engagementPayload({
    required String articleId,
    String? visitorId,
    String? sessionId,
    required int timeSpent,
    required num scrollDepth,
    required bool isCompleted,
    String? device,
  }) =>
      {
        'articleId': articleId,
        if (_set(visitorId)) 'visitorId': visitorId,
        if (_set(sessionId)) 'sessionId': sessionId,
        'timeSpent': timeSpent,
        'scrollDepth': scrollDepth.round(),
        'isCompleted': isCompleted,
        if (_set(device)) 'device': device,
      };

  static bool _set(String? v) => v != null && v.isNotEmpty;
}
