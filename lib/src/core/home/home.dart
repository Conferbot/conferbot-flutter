/// The home screen: what the visitor sees when the chat opens, before they
/// have said anything, and the shortest path from there to an answer.
/// Ported from the React Native SDK (src/core/home.ts), itself from the web
/// widget (all under conferbot-widget/src/):
///
///   ts/home/firstImpression.ts  enhanceHome, buildHelpCard: what shows and in what order
///   ts/home/homeCopy.ts          honest words for early bots' placeholder copy
///   ts/home/homeUtils.ts         salutation, topCategories, isLight, homeBrand, homeCardAvatar
///   ts/home/askBox.ts            "Ask anything": askBoxOn, askPlaceholder, the list as rows
///   ts/home/trust.ts             the team's faces, the rating, the customer logos
///   ts/home/visitorMemory.ts     "Welcome back, Jamie", "Pick up where you left off"
///   ts/home/requests/card.ts     "Your requests" on the home screen
///   ts/chat/replyTimeView.ts     decorateHomeReply: the card's status line
///   core/helpCentre.ts           showsRecentArticles, publishedArticles
///   templates/shared.ts          generateInitialPage: the template the above decorate
///   core/customizations.ts       enableInitialPage, initialPageCardButtonText, homeAskBox...
///   ts/i18n/en.ts                home.*, trust.*, requests.* (English)
///
/// The home exists only when the owner turned it on (`enableInitialPage`);
/// with it off the chat opens straight on the conversation, as the web's
/// templates and core/state.ts decide.
///
/// Not in an app, on purpose: the page-aware parts (ts/home/pageAware.ts -
/// "For this page" articles and a greeting page rule's own questions; an app
/// has no page address or title, so the agent's own questions are used), the
/// help card's own search's "For this page", and the floating panel's
/// three-article cap (wider than 500px only). The web's home draws no mascot
/// (it appears on the launcher, the greeting card, the typing bubble and the
/// idle call); [HomeModel.mascot] is the owner's, for an app's own spot
/// (`HomeScreenView(mascotBuilder:)`, the `Mascot` widget).
///
/// Pure: everything the view needs comes out of [homeModel].
library;

import 'dart:convert';
import 'dart:math' as math;

import '../customization/mascot_art.dart';
import '../live_chat/reply_time.dart';
import '../requests/requests.dart';
import '../waiting/wait_articles.dart';

export '../waiting/wait_articles.dart' show HelpArticle, isRealQuestion;

// ------------------------------------------------------------ words (web ts/i18n/en.ts)

class HomeText {
  HomeText._();
  static const title = 'Hi there 👋';
  static const description = "Ask us anything - we're here to help.";
  static const onlineNow = 'Online now';
  static const support = 'Support';
  static const chatWithUs = 'Chat with us';
  static const ourAssistant = 'Our assistant';
  static const resume = 'Pick up where you left off';
  static const continueConversation = 'Continue the conversation';
  static const askAgain = "Ask it again - we'll answer right away";
  static const helpCentre = 'Help centre';
  static const recentArticles = 'Recent articles';
  static const seeAll = 'See all';
  static const searchPlaceholder = 'Search for help';
  static const searchLabel = 'Search help articles';
  static String noMatch(String query) => 'No articles match “$query”.';
  static const askInstead = 'Ask us instead';
  static const chatInstead = 'Chat with us instead';
  static const askPlaceholder = 'Ask a question…';
  static String askLabel(String name) => 'Ask $name a question';

  /// "Ask “<query>”": the query is drawn bold.
  static const askQuery = 'Ask';
  static String answersRightAway(String name) => '$name answers right away';
  static const wellHelp = "We'll help you with it";
  static const articles = 'Articles';
  static const goodMorning = 'Good morning';
  static const goodAfternoon = 'Good afternoon';
  static const goodEvening = 'Good evening';
  static const hello = 'Hello';
  static String welcomeBackName(String name) => 'Welcome back, $name';
  static const welcomeBack = 'Welcome back';
  static const requestsTitle = 'Your requests';
  static String requestsSeeAll(int n) => 'See all ($n)';
  static const review = 'review';
  static const reviews = 'reviews';
  static String rated(String avg, int count, String reviews) => 'Rated $avg out of 5 from $count $reviews';
  static const ourTeam = 'Our team';
  static const customerLogo = 'Customer logo';
  static const close = 'Close';
  static const back = 'Back';
}

Map<String, dynamic> _map(dynamic v) => v is Map<String, dynamic> ? v : (v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{});
List _list(dynamic v) => v is List ? v : const [];
String _trim(dynamic v) => v is String ? v.trim() : '';

// ------------------------------------------------------------ on or off

/// Is there a home screen at all? The web's templates draw it when
/// `enableInitialPage` is truthy (core/customizations.ts keeps
/// `c.enableInitialPage || false`), and the panel opens on it.
bool homeOn(Map<String, dynamic>? c) {
  final v = c?['enableInitialPage'];
  return v != null && v != false && v != 0 && v != '';
}

/// The open chat's three views.
enum HomeView { home, chat, help }

/// A view that cannot be shown falls back (web core/helpCentre.ts safeView).
HomeView safeHomeView(Map<String, dynamic>? c, HomeView? view) {
  final home = homeOn(c);
  switch (view) {
    case HomeView.help:
      return helpCentreOn(c) ? HomeView.help : (home ? HomeView.home : HomeView.chat);
    case HomeView.home:
      return home ? HomeView.home : HomeView.chat;
    case HomeView.chat:
      return HomeView.chat;
    case null:
      return home ? HomeView.home : HomeView.chat;
  }
}

// ------------------------------------------------------------ the help centre's articles

/// Drafts never show (web core/helpCentre.ts publishedArticles).
List<Map<String, dynamic>> publishedArticles(dynamic list) => [
      for (final a in _list(list))
        if (a is Map && a['_id'] != null && '${a['_id']}'.isNotEmpty && (a['reviewStatus'] == null || a['reviewStatus'] == 'published')) _map(a),
    ];

List<Map<String, dynamic>> _publishedCategories(dynamic categories) => [
      for (final c in _list(categories))
        if (c is Map) (c['articles'] is List ? {..._map(c), 'articles': publishedArticles(c['articles'])} : _map(c)),
    ];

/// The help centre counts as on: the owner's switch, and at least one
/// published article (web index.ts: a help centre with no published
/// articles is a blank screen and counts as off).
bool helpOn(Map<String, dynamic>? c, dynamic categories, dynamic recent) {
  if (!helpCentreOn(c)) return false;
  final inCategories = _publishedCategories(categories).any((cat) => _list(cat['articles']).isNotEmpty);
  return inCategories || publishedArticles(recent).isNotEmpty;
}

/// The home screen's Recent articles list (web core/helpCentre.ts showsRecentArticles).
bool showsRecentArticles(Map<String, dynamic>? c, dynamic articles) =>
    c != null && c['enableInitialPage'] == true && helpCentreOn(c) && c['hideRecentArticles'] != true && publishedArticles(articles).isNotEmpty;

/// The categories worth a shortcut: named, not empty, most articles first (ties keep order).
List<Map<String, dynamic>> topCategories(dynamic categories, [int max = 4]) {
  final rows = <({Map<String, dynamic> c, int i, int n})>[];
  final all = _list(categories);
  for (var i = 0; i < all.length; i++) {
    final c = _map(all[i]);
    final n = _list(c['articles']).length;
    if (n > 0 && '${c['name'] ?? ''}'.trim().isNotEmpty) rows.add((c: c, i: i, n: n));
  }
  rows.sort((a, b) => b.n != a.n ? b.n - a.n : a.i - b.i);
  return rows.take(max).map((r) => r.c).toList();
}

// ------------------------------------------------------------ the header

/// "Good morning" / "Good afternoon" / "Good evening" by the visitor's clock.
String salutation(num? hour) {
  final h = hour != null && hour.isFinite ? ((hour.floor() % 24) + 24) % 24 : 12;
  if (h >= 5 && h < 12) return HomeText.goodMorning;
  if (h >= 12 && h < 18) return HomeText.goodAfternoon;
  if (h >= 18 && h < 23) return HomeText.goodEvening;
  return HomeText.hello;
}

/// Who the home screen is from: the logo and name the chat header shows.
class HomeBrand {
  const HomeBrand(this.logo, this.name);
  final String logo;
  final String name;
  @override
  bool operator ==(Object other) => other is HomeBrand && other.logo == logo && other.name == name;
  @override
  int get hashCode => Object.hash(logo, name);
  @override
  String toString() => 'HomeBrand($logo, $name)';
}

final _imageUrl = RegExp(r'^(https?:|data:image/|blob:|/)', caseSensitive: false);

/// Null when the owner hid the logo or there is no usable image.
HomeBrand? homeBrand(Map<String, dynamic>? c, [String fallbackName = '']) {
  if (c == null || (c['hideLogo'] != null && c['hideLogo'] != false)) return null;
  final logo = _trim(c['logo']);
  if (logo.isEmpty || !_imageUrl.hasMatch(logo)) return null;
  final own = _trim(c['logoText']);
  final name = (own.isNotEmpty ? own : fallbackName).replaceAll(RegExp(r'\s+'), ' ').trim();
  return HomeBrand(logo, name);
}

const _conferbotFace = 'https://prd.media.cdn.conferbot.com/62829a1c49f355163dfdbfb2/conferbot-logo-1710782074234.png';
String _ownImage(dynamic v) => v is String && v.trim().isNotEmpty && !RegExp('conferbot-logo', caseSensitive: false).hasMatch(v) ? v.trim() : '';
bool _truthy(dynamic v) => v != null && v != false && v != 0 && v != '';

/// The card's face when the owner set none: the bot's avatar, then its logo, then Conferbot's.
String homeCardAvatar(Map<String, dynamic>? c) {
  final own = _trim(c?['initialPageAvatar']);
  if (own.isNotEmpty) return own;
  final avatar = !_truthy(c?['hideAvatar']) ? _ownImage(c?['avatar']) : '';
  if (avatar.isNotEmpty) return avatar;
  final logo = !_truthy(c?['hideLogo']) ? _ownImage(c?['logo']) : '';
  if (logo.isNotEmpty) return logo;
  return _conferbotFace;
}

// ------------------------------------------------------------ honest words (web homeCopy.ts)

String _norm(dynamic v) => v is String ? v.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase() : '';
const _legacyTitles = ['our usual reply time', 'our usual reply time is'];
const _legacyTaglines = ['later today', 'a few hours', 'within a day'];
bool _isLegacyDescription(dynamic v) {
  final n = _norm(v);
  return n.isEmpty || n.startsWith('welcome to the conferbot') || n == 'we help your business to connect with your customer';
}

class HomeCopy {
  const HomeCopy({required this.cardTitle, required this.cardTagline, required this.description, required this.online});

  /// Who answers: the owner's card title, else the bot's (or agent's) name.
  final String cardTitle;
  final String cardTagline;
  final String description;

  /// Whether the tagline is ours (so the status line replaces it).
  final bool online;

  @override
  bool operator ==(Object other) =>
      other is HomeCopy && other.cardTitle == cardTitle && other.cardTagline == cardTagline && other.description == description && other.online == online;
  @override
  int get hashCode => Object.hash(cardTitle, cardTagline, description, online);
  @override
  String toString() => 'HomeCopy($cardTitle, $cardTagline, $description, $online)';
}

HomeCopy homeCopy(Map<String, dynamic>? c, String name) {
  final title = _norm(c?['initialPageCardSubTitle']);
  final tagline = _norm(c?['initialPageCardTagline']);
  final ownTagline = tagline.isNotEmpty && !_legacyTaglines.contains(tagline);
  return HomeCopy(
    cardTitle: title.isEmpty || _legacyTitles.contains(title) ? (name.isNotEmpty ? name : HomeText.support) : '${c!['initialPageCardSubTitle']}'.trim(),
    cardTagline: ownTagline ? '${c!['initialPageCardTagline']}'.trim() : HomeText.onlineNow,
    description: _isLegacyDescription(c?['initialPageDescription']) ? HomeText.description : '${c!['initialPageDescription']}',
    online: !ownTagline,
  );
}

String _plainText(String v) => v.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

/// The owner's words, or the stock ones (web i18n.ts ownerTextOr).
String _ownerTextOr(dynamic value, String stock) {
  final v = value is String ? _plainText(value) : '';
  return v.isEmpty || v == _plainText(stock) ? stock : '$value';
}

// ------------------------------------------------------------ colours

/// Parse "#abc", "#aabbcc" or "rgb(a, b, c)" to [r, g, b]; null for anything else.
List<int>? parseColor(String? value) {
  final s = (value ?? '').trim();
  final m = RegExp(r'^#?([0-9a-f]{3}|[0-9a-f]{6})$', caseSensitive: false).firstMatch(s);
  if (m != null) {
    var hex = m.group(1)!;
    if (hex.length == 3) hex = hex.split('').map((ch) => '$ch$ch').join();
    final n = int.parse(hex, radix: 16);
    return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
  }
  final rgb = RegExp(r'^rgba?\(\s*(\d+)[,\s]+(\d+)[,\s]+(\d+)', caseSensitive: false).firstMatch(s);
  return rgb == null ? null : [int.parse(rgb.group(1)!), int.parse(rgb.group(2)!), int.parse(rgb.group(3)!)];
}

/// True when white text would not read on this colour (relative luminance above ~0.55).
bool isLight(List<int>? rgb) {
  if (rgb == null) return false;
  double lin(int ch) {
    final s = ch / 255;
    return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * lin(rgb[0]) + 0.7152 * lin(rgb[1]) + 0.0722 * lin(rgb[2]) > 0.55;
}

/// The band's two colours: the launcher's gradient, else its solid colour (firstImpression.ts brandColors).
(String, String) brandColors(Map<String, dynamic>? c) {
  if (c?['widgetIconThemeType'] == 'Gradient' && _truthy(c?['widgetGradientBgOne']) && _truthy(c?['widgetGradientBgTwo'])) {
    return ('${c!['widgetGradientBgOne']}', '${c['widgetGradientBgTwo']}');
  }
  final solid = [c?['widgetIconBgColor'], c?['headerBgColor']].firstWhere(_truthy, orElse: () => '#4f46e5');
  return ('$solid', '$solid');
}

/// The home screen's surfaces: the widget theme's canvas, cards, quiet fills
/// and text (core/widgetTheme.ts tokens: bg2 is "home screen, help
/// centre"), else the classic widget's (web polish.css / polish-home.css:
/// page #f6f7fb, white cards, #0f172a ink, #64748b muted, #f1f5f9 fills).
class HomePalette {
  const HomePalette({required this.page, required this.card, required this.soft, required this.ink, required this.muted, required this.line});
  final String page;
  final String card;
  final String soft;
  final String ink;
  final String muted;
  final String line;

  @override
  bool operator ==(Object other) =>
      other is HomePalette && other.page == page && other.card == card && other.soft == soft && other.ink == ink && other.muted == muted && other.line == line;
  @override
  int get hashCode => Object.hash(page, card, soft, ink, muted, line);
  @override
  String toString() => 'HomePalette($page, $card, $soft, $ink, $muted, $line)';
}

const classicHomePalette = HomePalette(page: '#f6f7fb', card: '#ffffff', soft: '#f1f5f9', ink: '#0f172a', muted: '#64748b', line: '#f1f5f9');

/// From the widget theme's tokens (bg2, card, card2, ink, muted, line); null tokens: the classic look.
HomePalette homePalette({String? bg2, String? card, String? card2, String? ink, String? muted, String? line}) {
  bool has(String? v) => v != null && v.isNotEmpty;
  if (!has(bg2) || !has(card) || !has(ink)) return classicHomePalette;
  return HomePalette(
    page: bg2!,
    card: card!,
    soft: has(card2) ? card2! : bg2,
    ink: ink!,
    muted: has(muted) ? muted! : ink,
    line: has(line) ? line! : (has(card2) ? card2! : bg2),
  );
}

// ------------------------------------------------------------ trust (web trust.ts)

final _safeImage = RegExp(r'''^https://[^\s"'<>]+$''', caseSensitive: false);

/// The owner's images, https only, once each, at most [max].
List<String> trustImages(dynamic list, int max) {
  final out = <String>[];
  for (final v in _list(list)) {
    final url = v is String ? v.trim() : '';
    if (_safeImage.hasMatch(url) && !out.contains(url)) out.add(url);
  }
  return out.take(max).toList();
}

/// A count as people say it: 120, 1.2k, 12k.
String compactCount(num n) {
  final v = math.max(0, n.isFinite ? n.floor() : 0);
  if (v < 1000) return '$v';
  final k = v / 1000;
  final shown = k < 10 ? (k * 10).floor() / 10 : k.floor().toDouble();
  final s = shown == shown.roundToDouble() ? '${shown.round()}' : '$shown';
  return '${s}k';
}

class RatingLine {
  const RatingLine({required this.average, required this.count, required this.fill, required this.label});
  final String average;
  final String count;

  /// How far the five stars fill, in percent.
  final double fill;
  final String label;

  @override
  bool operator ==(Object other) => other is RatingLine && other.average == average && other.count == count && other.fill == fill && other.label == label;
  @override
  int get hashCode => Object.hash(average, count, fill, label);
  @override
  String toString() => 'RatingLine($average, $count, $fill, $label)';
}

/// The rating to show (the server's average of real post-chat scores), or null.
RatingLine? ratingLine(dynamic r) {
  if (r is! Map) return null;
  final average = r['average'] is num ? (r['average'] as num).toDouble() : double.tryParse('${r['average']}');
  final rawCount = r['count'] is num ? (r['count'] as num) : num.tryParse('${r['count']}');
  if (average == null || !average.isFinite || average < 1 || average > 5 || rawCount == null || !rawCount.isFinite) return null;
  final count = rawCount.floor();
  if (count < 1) return null;
  final avg = average.toStringAsFixed(1);
  final many = count == 1 ? HomeText.review : HomeText.reviews;
  return RatingLine(
    average: avg,
    count: '${compactCount(count)} $many',
    // The stars fill to the average shown, so they agree with the number.
    fill: (double.parse(avg) / 5 * 1000).round() / 10,
    label: HomeText.rated(avg, count, many),
  );
}

// ------------------------------------------------------------ visitor memory (web visitorMemory.ts)

/// Per bot, on the device only (web localStorage `cb_mem_<botId>`).
String homeMemoryKey(String? botId) => '@conferbot:memory:${botId == null || botId.isEmpty ? 'default' : botId}';
const _forgetAfterMs = 60 * 24 * 60 * 60 * 1000;

/// The web restores a live chat this long after its last message (BOT_STATE_EXPIRY).
const liveChatMs = 30 * 60 * 1000;

class VisitorMemory {
  const VisitorMemory({required this.at, this.name, this.topic, this.session});

  /// Last time they wrote (ms since the epoch).
  final int at;
  final String? name;

  /// The first real question of their latest conversation.
  final String? topic;

  /// The conversation that question came from.
  final String? session;

  VisitorMemory copyWith({int? at, String? name, String? topic, String? session}) =>
      VisitorMemory(at: at ?? this.at, name: name ?? this.name, topic: topic ?? this.topic, session: session ?? this.session);

  Map<String, dynamic> toJson() => {
        'at': at,
        if (name != null) 'name': name,
        if (topic != null) 'topic': topic,
        if (session != null) 'session': session,
      };

  @override
  bool operator ==(Object other) => other is VisitorMemory && other.at == at && other.name == name && other.topic == topic && other.session == session;
  @override
  int get hashCode => Object.hash(at, name, topic, session);
  @override
  String toString() => 'VisitorMemory(${toJson()})';
}

String serializeHomeMemory(VisitorMemory m) => jsonEncode(m.toJson());

String? _cut(dynamic v, int max) => v is String ? (v.length > max ? v.substring(0, max) : v) : null;

/// What the device remembers, or null (none, broken, or older than 60 days).
VisitorMemory? parseHomeMemory(String? raw, [int? now]) {
  final n = now ?? DateTime.now().millisecondsSinceEpoch;
  try {
    final m = jsonDecode(raw ?? 'null');
    if (m is! Map || m['at'] is! num || n - (m['at'] as num) > _forgetAfterMs) return null;
    return VisitorMemory(
      at: (m['at'] as num).toInt(),
      name: _cut(m['name'], 40),
      topic: _cut(m['topic'], 160),
      session: m['session'] is String ? m['session'] as String : null,
    );
  } catch (_) {
    return null;
  }
}

VisitorMemory? _fresh(VisitorMemory? m, int now) => m != null && now - m.at <= _forgetAfterMs ? m : null;

/// They wrote [text] in conversation [session] (web rememberMessage).
VisitorMemory withMessage(VisitorMemory? m, String? session, String text, [int? now]) {
  final n = now ?? DateTime.now().millisecondsSinceEpoch;
  var next = (_fresh(m, n) ?? VisitorMemory(at: n)).copyWith(at: n);
  // A new conversation's first real question becomes what they came for.
  if (session != null && session.isNotEmpty && next.session != session && isRealQuestion(text)) {
    final topic = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    next = next.copyWith(topic: topic.length > 160 ? topic.substring(0, 160) : topic, session: session);
  }
  return next;
}

/// They told us their name (web rememberName): a first name, or null when it is not one.
VisitorMemory? withName(VisitorMemory? m, String? name, [int? now]) {
  final n = now ?? DateTime.now().millisecondsSinceEpoch;
  final trimmed = (name ?? '').trim();
  final first = trimmed.isEmpty ? '' : trimmed.split(RegExp(r'\s+')).first;
  if (first.isEmpty || first.length > 40 || RegExp(r'[@\d<>]').hasMatch(first)) return null;
  return (_fresh(m, n) ?? VisitorMemory(at: n)).copyWith(name: first[0].toUpperCase() + first.substring(1));
}

/// "Welcome back[, Name]" once their last chat is over (not while the web
/// would still restore it), and the question to pick up. null for a first visit.
({String hello, String? topic})? welcomeBack(VisitorMemory? m, [int? now]) {
  final n = now ?? DateTime.now().millisecondsSinceEpoch;
  if (m == null || n - m.at < liveChatMs) return null;
  final hasTopic = m.topic != null && m.topic!.isNotEmpty;
  final hasName = m.name != null && m.name!.isNotEmpty;
  if (!hasTopic && !hasName) return null;
  return (hello: hasName ? HomeText.welcomeBackName(m.name!) : HomeText.welcomeBack, topic: hasTopic ? m.topic : null);
}

/// The remembered conversation is the one on the device, so the card can open it (web canResume).
bool canResume(VisitorMemory? m, String? chatSessionId) =>
    m?.session != null && m!.session!.isNotEmpty && chatSessionId != null && chatSessionId.isNotEmpty && m.session == chatSessionId;

// ------------------------------------------------------------ "Ask anything" (web askBox.ts)

/// Whether the box shows at all: the owner's switch (on unless off), and an agent or an article to find.
bool askBoxOn(Map<String, dynamic>? c, bool hasAgent, bool hasArticles) => c?['homeAskBox'] != false && (hasAgent || hasArticles);

/// The box's words: a question for an agent, a search for articles alone.
String askPlaceholder(bool hasAgent, bool hasArticles) => hasAgent ? HomeText.askPlaceholder : (hasArticles ? HomeText.searchPlaceholder : '');

/// A run of text, marked where it matches the question (web kbUtils.ts highlight).
class TextRun {
  const TextRun(this.text, {this.mark = false});
  final String text;
  final bool mark;
  @override
  bool operator ==(Object other) => other is TextRun && other.text == text && other.mark == mark;
  @override
  int get hashCode => Object.hash(text, mark);
  @override
  String toString() => mark ? '[$text]' : text;
}

List<TextRun> highlightRuns(String? text, List<String> tokens) {
  final source = text ?? '';
  final words = tokens.where((t) => t.isNotEmpty).toList()..sort((a, b) => b.length - a.length);
  if (words.isEmpty || source.isEmpty) return [TextRun(source)];
  final re = RegExp('(${words.map(RegExp.escape).join('|')})', caseSensitive: false);
  final out = <TextRun>[];
  var last = 0;
  for (final m in re.allMatches(source)) {
    if (m.start > last) out.add(TextRun(source.substring(last, m.start)));
    out.add(TextRun(m.group(0)!, mark: true));
    last = m.end;
  }
  if (last < source.length) out.add(TextRun(source.substring(last)));
  return out;
}

enum AskKind { ask, label, article, none, chat }

/// One row of the list under the ask box.
sealed class AskRow {
  const AskRow(this.key);
  final String key;
  AskKind get kind;
}

/// Ask the agent this question: the chat opens and asks.
class AskQueryRow extends AskRow {
  const AskQueryRow({required this.query, required this.sub}) : super('ask');
  final String query;
  final String sub;
  @override
  AskKind get kind => AskKind.ask;
}

class AskLabelRow extends AskRow {
  const AskLabelRow(this.text) : super('label');
  final String text;
  @override
  AskKind get kind => AskKind.label;
}

class AskArticleRow extends AskRow {
  AskArticleRow({required this.id, required this.title, required this.sub}) : super('a-$id');
  final String id;
  final List<TextRun> title;
  final String sub;
  @override
  AskKind get kind => AskKind.article;
}

class AskNoneRow extends AskRow {
  const AskNoneRow(this.text) : super('none');
  final String text;
  @override
  AskKind get kind => AskKind.none;
}

/// A flow bot with nothing found: open the chat.
class AskChatRow extends AskRow {
  const AskChatRow({required this.title, required this.sub}) : super('chat');
  final String title;
  final String sub;
  @override
  AskKind get kind => AskKind.chat;
}

/// Matches inside article text from the server, for the query they were asked for.
class RemoteHits {
  const RemoteHits(this.query, this.hits);
  final String query;
  final List<({String id, String snippet})> hits;
}

/// The list under the box as the visitor types (web askBox.ts render): for
/// an agent first "Ask “...”"; the articles that answer it (best first, at
/// most 4, the server's body matches after the local ones); for a flow bot
/// with nothing found, "No articles match" and "Chat with us". Empty while
/// the box is empty. The first row that does something is what Enter picks.
List<AskRow> askRows(String? query, {required String? agentName, required List<HelpArticle> articles, RemoteHits? remote}) {
  final q = (query ?? '').trim();
  if (q.isEmpty) return const [];
  final words = keywordsOf(q);
  final tokens = words.isNotEmpty ? words : tokenize(q);
  final found = [...answersFor(articles, q, 4)];
  if (remote != null && remote.query == q.toLowerCase()) {
    final byId = {for (final a in articles) a.id: a};
    for (final h in remote.hits.where((h) => byId.containsKey(h.id) && !found.any((a) => a.id == h.id)).take(math.max(0, 4 - found.length))) {
      final a = byId[h.id]!;
      found.add(HelpArticle(id: a.id, title: a.title, description: h.snippet, categoryName: a.categoryName, text: a.text));
    }
  }
  final rows = <AskRow>[];
  if (agentName != null) rows.add(AskQueryRow(query: q, sub: HomeText.answersRightAway(agentName)));
  if (found.isNotEmpty) {
    rows.add(const AskLabelRow(HomeText.articles));
    for (final a in found) {
      rows.add(AskArticleRow(id: a.id, title: highlightRuns(a.title, tokens), sub: a.description.isNotEmpty ? a.description : a.categoryName));
    }
  } else if (agentName == null) {
    rows.add(AskNoneRow(HomeText.noMatch(q)));
    rows.add(const AskChatRow(title: HomeText.chatWithUs, sub: HomeText.wellHelp));
  }
  return rows;
}

/// What Enter does: the first row that does something.
AskRow? askDefault(List<AskRow> rows) {
  for (final r in rows) {
    if (r is AskQueryRow || r is AskArticleRow || r is AskChatRow) return r;
  }
  return null;
}

/// What to ask the server for matches inside article bodies (web
/// askBox.ts askRemote): the question's two longest key words, or null when
/// there is nothing to ask or no article lacks its body.
String? remoteQueryFor(String? query, dynamic articles) {
  if (!_list(articles).any((a) => a is Map && a['content'] is! String)) return null;
  final words = keywordsOf((query ?? '').trim())..sort((a, b) => b.length - a.length);
  if (words.isEmpty) return null;
  final key = words.take(2).join(' ');
  return key.length < 2 ? null : key;
}

/// The help card's own search, when the ask box is off (web buildHelpCard render).
sealed class HelpSearch {
  const HelpSearch();
}

class HelpSearchResults extends HelpSearch {
  const HelpSearchResults(this.rows);
  final List<({String id, List<TextRun> title, String sub})> rows;
}

class HelpSearchEmpty extends HelpSearch {
  const HelpSearchEmpty({required this.text, required this.action, required this.asks});
  final String text;
  final String action;
  final bool asks;
  @override
  bool operator ==(Object other) => other is HelpSearchEmpty && other.text == text && other.action == action && other.asks == asks;
  @override
  int get hashCode => Object.hash(text, action, asks);
}

HelpSearch? helpSearch(String? query, List<HelpArticle> articles, bool hasAgent) {
  final q = (query ?? '').trim();
  if (q.isEmpty) return null;
  final tokens = tokenize(q);
  final found = searchArticles(articles, q).take(5).toList();
  if (found.isNotEmpty) {
    return HelpSearchResults([
      for (final a in found) (id: a.id, title: highlightRuns(a.title, tokens), sub: a.categoryName.isNotEmpty ? a.categoryName : a.description),
    ]);
  }
  return HelpSearchEmpty(text: HomeText.noMatch(q), action: hasAgent ? HomeText.askInstead : HomeText.chatInstead, asks: hasAgent);
}

// ------------------------------------------------------------ the model

class HomeAgent {
  const HomeAgent({this.displayName = '', this.starters = const [], this.avatar});
  final String displayName;
  final List<String> starters;
  final String? avatar;
}

class HomeArticleRow {
  const HomeArticleRow({required this.id, required this.title, required this.description, this.image});
  final String id;
  final String title;
  final String description;

  /// The cover image, when it has one (else the document icon).
  final String? image;
}

class HomeRequestRow {
  const HomeRequestRow({required this.id, required this.title, required this.line, required this.state, required this.fresh});
  final String id;
  final String title;
  final String line;
  final RequestState state;
  final bool fresh;
}

class HomeTopic {
  const HomeTopic(this.id, this.name, this.count);
  final String id;
  final String name;
  final int count;
  @override
  bool operator ==(Object other) => other is HomeTopic && other.id == id && other.name == name && other.count == count;
  @override
  int get hashCode => Object.hash(id, name, count);
  @override
  String toString() => 'HomeTopic($id, $name, $count)';
}

enum HomeSection { ask, resume, requests, talk, help, trust }

class HomeTalk {
  const HomeTalk({
    required this.avatar,
    required this.title,
    required this.tagline,
    required this.status,
    required this.away,
    required this.dot,
    required this.button,
    required this.starters,
    required this.faces,
    required this.rating,
  });
  final String avatar;
  final String title;

  /// The owner's own tagline (kept), else null (the status line takes its place).
  final String? tagline;

  /// "Online · Usually replies in a few minutes"; null when there is nothing to say.
  final String? status;

  /// The status's tone: nobody is there now (web tone 'away').
  final bool away;

  /// The green dot on the avatar (off with hideOnlineStatus).
  final bool dot;
  final String button;

  /// An AI agent's suggested questions: one tap opens the chat and asks.
  final List<String> starters;

  /// The team's photos, a small stack at the end of the name row.
  final List<String> faces;
  final RatingLine? rating;
}

class HomeAsk {
  const HomeAsk({required this.placeholder, required this.label, required this.agentName});
  final String placeholder;
  final String label;
  final String? agentName;
}

class HomeResume {
  const HomeResume({required this.topic, required this.line, required this.resumable});
  final String topic;
  final String line;
  final bool resumable;
}

class HomeRequests {
  const HomeRequests({required this.rows, required this.total, required this.seeAll, required this.fresh});
  final List<HomeRequestRow> rows;
  final int total;
  final String? seeAll;
  final bool fresh;
}

class HomeHelp {
  const HomeHelp({required this.title, required this.recent, required this.seeAll, required this.topics, required this.search});
  final String title;
  final List<HomeArticleRow> recent;
  final bool seeAll;
  final List<HomeTopic> topics;

  /// The card's own search (only when the ask box is not there).
  final bool search;
}

class HomeTrust {
  const HomeTrust(this.label, this.logos);
  final String label;
  final List<String> logos;
}

/// The owner's mascot (art3d mascotLookOf) and its colour, for an app that draws it on its home.
class HomeMascot {
  final MascotLook look;

  /// The colour it is drawn in when the owner chose none: widgetIconBgColor, else the header's.
  final String accent;
  const HomeMascot(this.look, this.accent);
}

class HomeModel {
  const HomeModel({
    required this.hello,
    required this.brand,
    required this.title,
    required this.description,
    required this.message,
    required this.band,
    required this.light,
    required this.accent,
    required this.talk,
    required this.ask,
    required this.resume,
    required this.requests,
    required this.help,
    required this.trust,
    required this.order,
    required this.articles,
    this.mascot = const HomeMascot(MascotLook(), '#4f46e5'),
  });

  /// "Good afternoon", or "Welcome back, Jamie".
  final String hello;
  final HomeBrand? brand;

  /// The owner's title (may be empty, as the web prints it).
  final String title;
  final String description;

  /// The owner's line above the card (initialPageMessage), or "".
  final String message;

  /// The band behind the top: the launcher's colours; [light] means dark ink on it.
  final (String, String) band;
  final bool light;

  /// Chips, links and the ask box's ring (web --cb-accent).
  final String accent;
  final HomeTalk talk;
  final HomeAsk? ask;
  final HomeResume? resume;
  final HomeRequests? requests;
  final HomeHelp? help;
  final HomeTrust? trust;

  /// The cards from the top down.
  final List<HomeSection> order;

  /// Every article the ask box and the help card search.
  final List<HelpArticle> articles;

  /// The owner's mascot and its colour, for an app that draws it on its home (`mascotBuilder`); the web's home has none.
  final HomeMascot mascot;
}

String _truncate(dynamic text, int max) {
  final s = text == null ? '' : '$text';
  return s.length > max ? '${s.substring(0, max)}...' : s;
}

/// What the home screen shows, from the owner's settings (themed and
/// personalised, as the chat uses them) and what the device knows.
HomeModel? homeModel({
  required Map<String, dynamic>? c,
  String? botName,
  HomeAgent? agent,
  dynamic categories,
  dynamic recentArticles,
  VisitorMemory? memory,
  String? chatSessionId,
  List<RequestSummary>? requests,
  Map<String, int> seen = const {},
  int? now,
  int? hour,
}) {
  if (!homeOn(c)) return null;
  final cc = c!;
  final n = now ?? DateTime.now().millisecondsSinceEpoch;
  final cats = _publishedCategories(categories);
  final recent = publishedArticles(recentArticles);
  final kbOn = helpOn(cc, cats, recent);
  final logoText = _trim(cc['logoText']);
  String firstOf(List<String?> v) => v.firstWhere((s) => s != null && s.isNotEmpty, orElse: () => '') ?? '';
  final name = firstOf([agent?.displayName, cc['logoText'] is String ? cc['logoText'] as String : null, botName]);

  // The header: salutation (or welcome back), the brand, the owner's words.
  final back = welcomeBack(memory, n);
  final copy = homeCopy(cc, name);
  final (a, b) = brandColors(cc);

  // "Talk to us": the status line replaces our own tagline (replyTimeView.ts decorateHomeReply).
  final hideStatus = cc['hideOnlineStatus'] == true;
  final people = ReplyTime.homePeople(cc['replyTime'], agent: agent != null, now: DateTime.fromMillisecondsSinceEpoch(n));
  final status = [if (!hideStatus) ReplyTime.online, if (people.text.isNotEmpty) people.text].join(ReplyTime.sep);
  final talk = HomeTalk(
    avatar: homeCardAvatar(cc),
    title: copy.cardTitle,
    tagline: copy.online ? null : copy.cardTagline,
    status: status.isEmpty ? null : status,
    away: people.away,
    dot: !hideStatus,
    button: _ownerTextOr(cc['initialPageCardButtonText'], HomeText.chatWithUs),
    starters: agent == null ? const [] : agent.starters.where((s) => s.trim().isNotEmpty).take(3).toList(),
    faces: trustImages(cc['homeTeamPhotos'], 3),
    rating: ratingLine(cc['homeRating']),
  );

  // Search first.
  final articles = kbOn ? flattenArticles(cats, recent) : <HelpArticle>[];
  final agentName = agent == null ? null : firstOf([agent.displayName, logoText, botName, HomeText.ourAssistant]);
  final ask = askBoxOn(cc, agent != null, articles.isNotEmpty)
      ? HomeAsk(
          placeholder: askPlaceholder(agent != null, articles.isNotEmpty),
          label: agentName != null ? HomeText.askLabel(agentName) : HomeText.searchLabel,
          agentName: agentName,
        )
      : null;

  // Pick up where they left off: an agent bot only.
  final resumable = canResume(memory, chatSessionId);
  final resume = back?.topic != null && agent != null
      ? HomeResume(topic: back!.topic!, resumable: resumable, line: resumable ? HomeText.continueConversation : HomeText.askAgain)
      : null;

  // Their requests: up to two, "See all (n)" when there are more; a new reply puts it above "Talk to us".
  final list = requests == null ? const <RequestSummary>[] : ordered(requests, seen);
  final req = list.isEmpty
      ? null
      : HomeRequests(
          rows: [
            for (final r in list.take(requestsOnHome))
              HomeRequestRow(id: r.id, title: r.title, line: rowLine(r, seen, n), state: stateOf(r), fresh: isNewReply(r, seen)),
          ],
          total: list.length,
          seeAll: list.length > requestsOnHome ? HomeText.requestsSeeAll(list.length) : null,
          fresh: list.any((r) => isNewReply(r, seen)),
        );

  // The help card: the recent list (unless hidden), the topics, See all.
  HomeHelp? help;
  if (kbOn) {
    final topics = topCategories(cats, 6);
    final withList = showsRecentArticles(cc, recent);
    if (articles.isNotEmpty || topics.isNotEmpty) {
      help = HomeHelp(
        title: withList ? HomeText.recentArticles : HomeText.helpCentre,
        recent: withList
            ? [
                for (final r in recent)
                  HomeArticleRow(
                    id: '${r['_id']}',
                    title: _truncate(r['title'], 100),
                    description: _truncate(r['description'], 120),
                    image: _trim(r['coverImage']).isNotEmpty ? _trim(r['coverImage']) : null,
                  ),
              ]
            : const [],
        seeAll: topics.isNotEmpty,
        topics: [for (final t in topics) HomeTopic('${t['_id'] ?? t['id'] ?? t['name']}', '${t['name']}', _list(t['articles']).length)],
        search: ask == null,
      );
    }
  }

  // The owner's customer logos with their line, last.
  final logos = trustImages(cc['homeTrustLogos'], 6);
  final trust = logos.isEmpty ? null : HomeTrust(_trim(cc['homeTrustLabel'] is String ? cc['homeTrustLabel'] : ''), logos);

  final order = <HomeSection>[
    if (ask != null) HomeSection.ask,
    if (resume != null) HomeSection.resume,
    if (req != null && req.fresh) HomeSection.requests,
    HomeSection.talk,
    if (req != null && !req.fresh) HomeSection.requests,
    if (help != null) HomeSection.help,
    if (trust != null) HomeSection.trust,
  ];

  return HomeModel(
    hello: back != null ? back.hello : salutation(hour ?? DateTime.fromMillisecondsSinceEpoch(n).hour),
    brand: homeBrand(cc, firstOf([agent?.displayName, botName])),
    title: _trim(cc['initialPageTitle']),
    description: copy.description,
    message: cc['initialPageMessage'] is String ? _plainText(cc['initialPageMessage'] as String) : '',
    band: (a, b),
    light: isLight(parseColor(a)) && isLight(parseColor(b)),
    accent: requestsAccent(cc),
    talk: talk,
    ask: ask,
    resume: resume,
    requests: req,
    help: help,
    trust: trust,
    order: order,
    articles: articles,
    mascot: HomeMascot(mascotLookOf(cc), _mascotAccent(cc)),
  );
}

/// The mascot's colour when the owner chose none: widgetIconBgColor, else the header's.
String _mascotAccent(Map<String, dynamic> c) {
  for (final k in ['widgetIconBgColor', 'headerBgColor']) {
    final v = c[k];
    if (v is String && v.trim().isNotEmpty) return v.trim();
  }
  return '#4f46e5';
}

/// While the visitor types in the ask box, the list is the page: these go (web cb-home--asking).
const hiddenWhileAsking = [HomeSection.resume, HomeSection.requests, HomeSection.talk, HomeSection.help];
