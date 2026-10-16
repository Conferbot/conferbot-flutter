/// While you wait for a person: the help that may answer the visitor
/// meanwhile, as one card. Ported from the React Native SDK
/// (src/core/waitArticles.ts), itself from the web widget:
///
///   - conferbot-widget src/ts/chat/waitArticles.ts: WAIT_BEFORE_MS, the
///     articles picked for the visitor's last real question
///     (waitArticlesFor), and the card (mountHelpCard): up to two rows,
///     "That solved it" when the wait can end there.
///   - src/ts/chat/handlers/special.ts: the timer's start and stop points
///     (waitForPerson), lastVisitorText (ASKS_FOR_PERSON), queueServerSeen,
///     and _wireQueue: the server's own pick (queue-help, or queue-status's
///     `help`) replacing the card when it has new items, and "That solved it"
///     sending queue-self-resolve {chatSessionId, articleId}.
///   - src/ts/home/askBox.ts answersFor / keywordsOf, homeUtils.ts
///     flattenArticles, knowledgeBase/kbUtils.ts tokenize / searchArticles,
///     home/visitorMemory.ts isRealQuestion, core/helpCentre.ts helpCentreOn.
///   - src/ts/chat/handoverState.ts: once the wait is over the card stays as
///     history under "Articles that might help".
///
/// The server (embed-server liveChat/queueHelp.js) emits queue-help
/// { chatSessionId, items: [{ kind: 'article' | 'page', id, title,
/// description, url?, score }], offer } to the chat room; at most two cards
/// per wait. Pure: the provider (core/waiting/waiting_extras.dart) feeds it.
library;

import 'dart:async';

import '../i18n/i18n.dart' show t;
import '../live_chat/handover_waiting.dart' show SetTimer, ClearTimer;

/// The articles card comes this long into a wait for a person.
const waitBefore = Duration(milliseconds: 6000);

/// "That solved it" waits this long for the server's answer.
const solveTimeout = Duration(milliseconds: 8000);

/// The card's words (web wait.*, handover.articlesTitle, queue.leftHelped), in the active language.
class WaitText {
  WaitText._();

  static String get label => t('wait.label');
  static String get title => t('wait.title');

  /// Once nobody is waiting any more (web handover.articlesTitle).
  static String get settledTitle => t('handover.articlesTitle');
  static String get read => t('common.read');
  static String get solved => t('wait.solved');
  static String get done => t('wait.done');

  /// The line drawn for a queue left this way (web queue.leftHelped).
  static String get leftHelped => t('queue.leftHelped');

  /// What the record keeps (web special.ts leave()): English, for the team.
  static const recordText = 'Resolved while waiting';
}

// ------------------------------------------------------------ help centre

/// The help centre is on only when enableKnowledgeBase is true (web core/helpCentre.ts).
bool helpCentreOn(dynamic c) => c is Map && c['enableKnowledgeBase'] == true;

class HelpArticle {
  const HelpArticle({
    required this.id,
    required this.title,
    this.description = '',
    this.categoryName = '',
    this.text = '',
  });

  final String id;
  final String title;
  final String description;
  final String categoryName;

  /// The body as plain text.
  final String text;
}

String _str(dynamic v) => v == null ? '' : v.toString();

String _plain(dynamic html) => _str(html)
    .replaceAll(RegExp(r'<(script|style)[^>]*>[\s\S]*?</\1>', caseSensitive: false), ' ')
    .replaceAll(RegExp(r'<[^>]*>'), ' ')
    .replaceAll(RegExp(r'&[a-z#0-9]+;', caseSensitive: false), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

List _list(dynamic v) => v is List ? v : const [];

/// Every article the visitor can open, once each: the categories' articles
/// first (they carry the category name), then any recent article not
/// already listed. Only ones with an id and a title (web homeUtils.ts).
List<HelpArticle> flattenArticles(dynamic categories, [dynamic recent]) {
  final out = <HelpArticle>[];
  final seen = <String>{};
  void add(dynamic a, String categoryName) {
    if (a is! Map) return;
    final id = a['_id'] != null && _str(a['_id']).isNotEmpty ? _str(a['_id']) : '';
    final title = a['title'] is String ? (a['title'] as String).trim() : '';
    if (id.isEmpty || title.isEmpty || seen.contains(id)) return;
    seen.add(id);
    final d = a['description'];
    out.add(HelpArticle(
      id: id,
      title: title,
      description: d == null || d == false || d == '' ? '' : _str(d),
      categoryName: categoryName,
      text: _plain(a['content']),
    ));
  }

  for (final c in _list(categories)) {
    final name = c is Map ? _str(c['name']) : '';
    for (final a in _list(c is Map ? c['articles'] : null)) {
      add(a, name);
    }
  }
  for (final a in _list(recent)) {
    final cat = a is Map && a['category'] is Map ? _str((a['category'] as Map)['name']) : '';
    add(a, cat);
  }
  return out;
}

/// An article by id among the bot's help centre data, or null.
Map? findArticle(String id, dynamic categories, dynamic recent) {
  if (id.isEmpty) return null;
  for (final c in _list(categories)) {
    for (final a in _list(c is Map ? c['articles'] : null)) {
      if (a is Map && _str(a['_id']) == id) return a;
    }
  }
  for (final a in _list(recent)) {
    if (a is Map && _str(a['_id']) == id) return a;
  }
  return null;
}

// ------------------------------------------------------------ search (web kbUtils.ts, askBox.ts)

final _splitWords = RegExp('[^a-z0-9À-￿]+');

List<String> tokenize(String query) {
  final words = query.toLowerCase().split(_splitWords).where((w) => w.isNotEmpty).toList();
  // One-letter words only count when they are all there is.
  final long = words.where((w) => w.length > 1).toList();
  return (long.isNotEmpty ? long : words).toSet().toList();
}

/// Rank articles for a query. Every word must appear somewhere (title,
/// summary, category or body); titles weigh most, then summaries, then the
/// category, then the body. A title that starts with the query wins.
List<HelpArticle> searchArticles(List<HelpArticle> articles, String query) {
  final tokens = tokenize(query);
  if (tokens.isEmpty) return [];
  final phrase = query.trim().toLowerCase();
  final scored = <({HelpArticle article, int score, int index})>[];
  for (var index = 0; index < articles.length; index++) {
    final article = articles[index];
    final title = article.title.toLowerCase();
    final desc = article.description.toLowerCase();
    final cat = article.categoryName.toLowerCase();
    final body = article.text.toLowerCase();
    var score = 0;
    var all = true;
    for (final t in tokens) {
      final inTitle = title.contains(t);
      final inDesc = desc.contains(t);
      final inCat = cat.contains(t);
      final inBody = body.contains(t);
      if (!inTitle && !inDesc && !inCat && !inBody) {
        all = false; // every word must match
        break;
      }
      if (inTitle) score += RegExp('(^|[^a-z0-9À-￿])${RegExp.escape(t)}').hasMatch(title) ? 12 : 8;
      if (inDesc) score += 4;
      if (inCat) score += 3;
      if (inBody) score += 1;
    }
    if (!all) continue;
    if (phrase.isNotEmpty && title.startsWith(phrase)) {
      score += 10;
    } else if (phrase.isNotEmpty && title.contains(phrase)) {
      score += 5;
    }
    scored.add((article: article, score: score, index: index));
  }
  scored.sort((a, b) => b.score != a.score ? b.score - a.score : a.index - b.index);
  return scored.map((s) => s.article).toList();
}

// Words that say nothing about what the question is about.
final Set<String> _stop = ('a an and are as at be but by can could did do does for from get got had has have how i if in is it its '
        'me my of on or our so that the their them then there this to us was we what when where which who why '
        "will with would you your yours about any anyone need want please hi hello hey tell know help there's "
        "i'm im ive i've dont don't cant can't")
    .split(RegExp(r'\s+'))
    .toSet();

/// The words of a question worth matching on (no "how do I ...").
List<String> keywordsOf(String query) =>
    tokenize(query).where((w) => (w.length > 2 || RegExp(r'\d').hasMatch(w)) && !_stop.contains(w)).toList();

// A word and its plain forms: "changing" also finds "change", "plans" "plan".
List<String> _stemsOf(String w) {
  final out = [w];
  if (w.length > 5 && w.endsWith('ing')) out.addAll([w.substring(0, w.length - 3), '${w.substring(0, w.length - 3)}e']);
  if (w.length > 4 && w.endsWith('es')) out.add(w.substring(0, w.length - 2));
  if (w.length > 3 && w.endsWith('s') && !w.endsWith('ss')) out.add(w.substring(0, w.length - 1));
  if (w.length > 4 && w.endsWith('ed')) out.addAll([w.substring(0, w.length - 2), w.substring(0, w.length - 1)]);
  return out;
}

bool _has(String text, String w) => _stemsOf(w).any(text.contains);

/// The articles that answer a question, best first: those matching every
/// word, then those matching most of its key words, weighted to titles.
List<HelpArticle> answersFor(List<HelpArticle> articles, String query, [int max = 4]) {
  final strict = searchArticles(articles, query);
  final seen = strict.map((a) => a.id).toSet();
  final words = keywordsOf(query);
  final need = words.isEmpty ? 1 : (words.length / 2).ceil().clamp(1, 1 << 30);
  final loose = <HelpArticle>[];
  if (words.isNotEmpty) {
    final rest = articles.where((a) => !seen.contains(a.id)).toList();
    final rows = <({HelpArticle a, int hits, int score, int index})>[];
    for (var index = 0; index < rest.length; index++) {
      final a = rest[index];
      final title = a.title.toLowerCase();
      final desc = '${a.description} ${a.categoryName}'.toLowerCase();
      final body = a.text.toLowerCase();
      var hits = 0;
      var score = 0;
      for (final w in words) {
        final t = _has(title, w);
        final d = _has(desc, w);
        final b = _has(body, w);
        if (t || d || b) hits += 1;
        score += (t ? 6 : 0) + (d ? 3 : 0) + (b ? 1 : 0);
      }
      rows.add((a: a, hits: hits, score: score, index: index));
    }
    final kept = rows.where((r) => r.hits >= need).toList()
      ..sort((x, y) => y.hits != x.hits
          ? y.hits - x.hits
          : y.score != x.score
              ? y.score - x.score
              : x.index - y.index);
    loose.addAll(kept.map((r) => r.a));
  }
  return [...strict, ...loose].take(max).toList();
}

// ------------------------------------------------------------ the question

final _greetingOnly = RegExp(
  r'^(hi+|hey+|hello+|yo|hiya|ok(ay)?|thanks?|thank you|thx|ty|yes|no|yep|nope|sure|cool|great|bye|good (morning|afternoon|evening))[\s!.?,]*$',
  caseSensitive: false,
);

/// Is this a question worth matching (web visitorMemory.ts)?
bool isRealQuestion(String text) {
  final t = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (t.length < 10 || t.length > 300) return false;
  if (_greetingOnly.hasMatch(t)) return false;
  if (RegExp(r'^\S+@\S+\.\S+$').hasMatch(t) || RegExp(r'^[+\d\s().-]{7,}$').hasMatch(t)) return false;
  final word = RegExp('[a-zÀ-￿]{2,}', caseSensitive: false);
  return t.split(' ').where(word.hasMatch).length >= 3;
}

/// "Can I talk to a person" says nothing about the problem (web special.ts).
final askForPerson = RegExp(
  r'\b(human|person|agent|someone|somebody|representative|operator|real people|staff|talk to|speak to|speak with|call me)\b',
  caseSensitive: false,
);

const _typedKinds = {'user-message', 'user-input-response', 'user-live-message', 'user-input'};

/// The visitor's last real question in their own words (web special.ts
/// lastVisitorText): the newest typed message that is a real question and
/// not an ask for a person. The record's entries name their kind in `type`
/// or `shape` (a flow answer keeps the step's type there), so both count.
String waitQuestion(dynamic record) {
  final list = _list(record);
  for (var i = list.length - 1; i >= 0; i--) {
    final r = list[i];
    if (r is! Map) continue;
    if (!_typedKinds.contains(_str(r['type'])) && !_typedKinds.contains(_str(r['shape']))) continue;
    final raw = r['text'] ?? r['value'];
    final text = _str(raw).replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (isRealQuestion(text) && !askForPerson.hasMatch(text)) return text;
  }
  return '';
}

// ------------------------------------------------------------ the card

class HelpItem {
  const HelpItem({required this.kind, required this.id, required this.title, this.description, this.url});

  /// 'article' or 'page'.
  final String kind;
  final String id;
  final String title;
  final String? description;

  /// A page's address (http/https only).
  final String? url;

  bool get isPage => kind == 'page';

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'id': id,
        'title': title,
        if (description != null) 'description': description,
        if (url != null) 'url': url,
      };

  @override
  bool operator ==(Object other) =>
      other is HelpItem &&
      other.kind == kind &&
      other.id == id &&
      other.title == title &&
      other.description == description &&
      other.url == url;

  @override
  int get hashCode => Object.hash(kind, id, title, description, url);

  @override
  String toString() => 'HelpItem(${toJson()})';
}

/// The articles to offer for this question (none when the help centre is off).
List<HelpItem> waitArticlesFor(dynamic c, String question, dynamic categories, dynamic recent) {
  if (!helpCentreOn(c) || question.trim().isEmpty) return [];
  return answersFor(flattenArticles(categories ?? const [], recent ?? const []), question, 2)
      .map((a) => HelpItem(
            kind: 'article',
            id: a.id,
            title: a.title,
            description: a.description.isNotEmpty ? a.description : null,
          ))
      .toList();
}

String _safeUrl(dynamic u) => u is String && RegExp(r'^https?://', caseSensitive: false).hasMatch(u) ? u : '';

/// The server's items (queue-help, queue-status help), cleaned: an id and a title each.
List<HelpItem> helpItemsOf(dynamic data) {
  final items = data is Map ? _list(data['items']) : const [];
  final out = <HelpItem>[];
  for (final i in items) {
    if (i is! Map) continue;
    final id = i['id'];
    if (id == null || id == false || id == '' || id == 0) continue;
    if (i['title'] is! String || (i['title'] as String).trim().isEmpty) continue;
    final kind = i['kind'] == 'page' ? 'page' : 'article';
    final url = kind == 'page' ? _safeUrl(i['url']) : '';
    final d = i['description'];
    out.add(HelpItem(
      kind: kind,
      id: _str(id),
      title: (i['title'] as String).trim(),
      description: d is String && d.trim().isNotEmpty ? d.trim() : null,
      url: url.isNotEmpty ? url : null,
    ));
  }
  return out;
}

class HelpCardState {
  const HelpCardState({
    required this.key,
    required this.items,
    required this.solvable,
    this.settled = false,
    this.busy = false,
    this.done = false,
  });

  /// Bumped each time a new card replaces the old (it is drawn at the end again).
  final int key;
  final List<HelpItem> items;

  /// The wait can end here ("That solved it"): only the server's pick.
  final bool solvable;

  /// The wait is over: the history title, no button.
  final bool settled;

  /// "That solved it" is waiting for the server.
  final bool busy;

  /// Left the queue this way: "Glad that helped."
  final bool done;

  HelpCardState copyWith({bool? solvable, bool? settled, bool? busy, bool? done}) => HelpCardState(
        key: key,
        items: items,
        solvable: solvable ?? this.solvable,
        settled: settled ?? this.settled,
        busy: busy ?? this.busy,
        done: done ?? this.done,
      );

  @override
  String toString() =>
      'HelpCardState(key: $key, items: ${items.map((i) => i.id).toList()}, solvable: $solvable, settled: $settled, busy: $busy, done: $done)';
}

/// The bot's help centre as sent: { categories, recentArticles }.
typedef HelpCentreLists = ({List categories, List recentArticles});

Object _setTimer(void Function() fn, Duration after) => Timer(after, fn);
void _clearTimer(Object t) => (t as Timer).cancel();

/// The help card's rules. startWait() where a wait for a person begins
/// (with no AI agent taking it first), endWait() wherever it ends; feed the
/// server's queue-status and queue-help in; solving() / solved(ok) around
/// the queue-self-resolve call.
class WaitHelp {
  WaitHelp({
    required dynamic Function() customizations,
    required String Function() question,
    required HelpCentreLists Function() articles,
    required bool Function() joined,
    required void Function(HelpCardState? card) onChange,
    SetTimer? setTimer,
    ClearTimer? clearTimer,
  })  : _customizations = customizations,
        _question = question,
        _articles = articles,
        _joined = joined,
        _onChange = onChange,
        _set = setTimer ?? _setTimer,
        _clear = clearTimer ?? _clearTimer;

  final dynamic Function() _customizations;
  final String Function() _question;
  final HelpCentreLists Function() _articles;
  final bool Function() _joined;
  final void Function(HelpCardState? card) _onChange;
  final SetTimer _set;
  final ClearTimer _clear;

  Object? _timer;
  // The server keeps a queue: it picks the help itself, ours stays out.
  bool _serverSeen = false;
  String _helpKey = '';
  bool _done = false;
  HelpItem? _opened;
  HelpCardState? _card;
  int _key = 0;

  /// The card on screen, or null.
  HelpCardState? get card => _card;

  void _put(HelpCardState? next) {
    _card = next;
    _onChange(next);
  }

  void _cancel() {
    final t = _timer;
    if (t != null) _clear(t);
    _timer = null;
  }

  void _mount(List<HelpItem> items, bool solvable) {
    if (items.isEmpty) return;
    _opened = null;
    _key += 1;
    _put(HelpCardState(key: _key, items: items, solvable: solvable));
  }

  void _showServerHelp(dynamic data) {
    final items = helpItemsOf(data);
    final k = items.map((i) => i.id).join(',');
    if (_done || items.isEmpty || k == _helpKey) return;
    _helpKey = k;
    _mount(items, true);
  }

  /// A wait for a person began: after [waitBefore], the articles for their question.
  void startWait() {
    _cancel();
    // A new wait: the server's pick and "That solved it" start over (web _wireQueue).
    _helpKey = '';
    _done = false;
    _timer = _set(() {
      _timer = null;
      final question = _question();
      if (question.isEmpty || _serverSeen) return;
      if (_joined()) return;
      final kb = _articles();
      _mount(waitArticlesFor(_customizations(), question, kb.categories, kb.recentArticles), false);
    }, waitBefore);
  }

  /// The wait ended (a person, nobody, left, ended): no card yet to come; one drawn stays as history.
  void endWait() {
    _cancel();
    final c = _card;
    if (c != null && !c.settled) _put(c.copyWith(settled: true, solvable: c.done ? c.solvable : false, busy: false));
  }

  /// queue-status (event or answer): a waiting status means the server picks the help.
  void queueStatus(dynamic data) {
    if (_done || data is! Map || data['status'] != 'waiting') return;
    _serverSeen = true;
    final help = data['help'];
    if (help != null && help != false) _showServerHelp(help);
  }

  /// queue-help: the server's pick for this wait.
  void queueHelp(dynamic data) {
    _serverSeen = true;
    _showServerHelp(data);
  }

  /// A row was opened (it is the article "That solved it" names).
  void open(String id) {
    final items = _card?.items ?? const <HelpItem>[];
    _opened = items.where((i) => i.id == id).firstOrNull;
  }

  /// "That solved it" pressed: the article to send, or null when it cannot go now.
  HelpItem? solving() {
    final c = _card;
    if (c == null || !c.solvable || c.busy || c.done || c.settled) return null;
    _put(c.copyWith(busy: true));
    return _opened ?? c.items.firstOrNull;
  }

  /// The server's answer: ok leaves the queue ("Glad that helped."), else the button comes back.
  void solved(bool ok) {
    final c = _card;
    if (c == null) return;
    if (!ok) {
      _put(c.copyWith(busy: false));
      return;
    }
    _done = true;
    _cancel();
    _put(c.copyWith(busy: false, done: true));
  }

  /// Left the queue another way (queue-left from another device): no more server cards.
  void left() {
    _done = true;
    _cancel();
  }

  /// A new conversation.
  void reset() {
    _cancel();
    _serverSeen = false;
    _helpKey = '';
    _done = false;
    _opened = null;
    if (_card != null) _put(null);
  }
}
