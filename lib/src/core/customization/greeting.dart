/// The greeting card by the closed launcher, as the web widget decides it
/// (conferbot-widget ts/visibility/nudges.ts greetingSettings / decideGreeting,
/// ts/home/firstImpression.ts upgradeGreeting, ts/home/greetingStyle.ts; ported
/// from the React Native SDK's src/core/greeting.ts): which message, after how
/// long, what a tap does, how often, and how it is dressed. Pure.
///
/// An app has no page address, so it counts as the site's home page ("/"): a
/// rule for every page applies, a rule for a given page does not. Rules that
/// need what only a browser knows (where the visitor came from, pages viewed,
/// the visitor's country, page attributes) never apply here.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'widget_theme.dart';

class ResolvedGreeting {
  final String text;

  /// Seconds after the launcher shows.
  final int delay;

  /// "open", "send" or "link".
  final String click;
  final String linkUrl;

  /// The rule's own suggested questions, else none (the agent's are added by the caller).
  final List<String> starters;

  /// Results key: the rule's id or its words.
  final String key;

  const ResolvedGreeting({
    required this.text,
    required this.delay,
    required this.click,
    required this.linkUrl,
    required this.starters,
    required this.key,
  });
}

class GreetingFacts {
  /// This visitor has been here before (a previous app session).
  final bool returning;

  /// The app identified the visitor (the provider's user has an id or email).
  final bool signedIn;

  /// App sessions so far, this one included (rules' "after N visits").
  final int visits;

  /// The visitor has chatted before.
  final bool chatted;

  /// Each rule's shows (ms) and last close, for its limits (nudges.ts limitsAllow).
  final Map<String, List<int>> shows;
  final Map<String, int> dismissed;
  final int? now;

  const GreetingFacts({
    required this.returning,
    required this.signedIn,
    this.visits = 1,
    this.chatted = false,
    this.shows = const {},
    this.dismissed = const {},
    this.now,
  });
}

class GreetingSeen {
  /// When the card last showed (ms).
  final int? shownAt;

  /// When it was last closed or the chat opened from it (ms).
  final int? closedAt;

  /// Shown in this app session already.
  final bool shownThisSession;

  const GreetingSeen({this.shownAt, this.closedAt, this.shownThisSession = false});
}

/// What is kept per bot (`conferbot.greeting.<botId>`), as RN's useGreeting stores it.
class GreetingRecord {
  final int visits;
  final bool chatted;
  final Map<String, List<int>> shows;
  final Map<String, int> dismissed;
  final int? closedAt;
  final int? shownAt;

  /// The key of the rule last shown, so a close dismisses that rule.
  final String? last;

  const GreetingRecord({
    this.visits = 0,
    this.chatted = false,
    this.shows = const {},
    this.dismissed = const {},
    this.closedAt,
    this.shownAt,
    this.last,
  });

  GreetingRecord copyWith({
    int? visits,
    bool? chatted,
    Map<String, List<int>>? shows,
    Map<String, int>? dismissed,
    int? closedAt,
    int? shownAt,
    String? last,
  }) =>
      GreetingRecord(
        visits: visits ?? this.visits,
        chatted: chatted ?? this.chatted,
        shows: shows ?? this.shows,
        dismissed: dismissed ?? this.dismissed,
        closedAt: closedAt ?? this.closedAt,
        shownAt: shownAt ?? this.shownAt,
        last: last ?? this.last,
      );

  static int? _int(dynamic v) => v is num && v.isFinite ? v.toInt() : null;

  /// Junk or nothing reads as a first visit.
  static GreetingRecord decode(String? raw) {
    if (raw == null || raw.isEmpty) return const GreetingRecord();
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return const GreetingRecord();
      final shows = <String, List<int>>{};
      if (m['shows'] is Map) {
        (m['shows'] as Map).forEach((k, v) {
          if (v is List) shows['$k'] = v.map(_int).whereType<int>().toList();
        });
      }
      final dismissed = <String, int>{};
      if (m['dismissed'] is Map) {
        (m['dismissed'] as Map).forEach((k, v) {
          final t = _int(v);
          if (t != null) dismissed['$k'] = t;
        });
      }
      return GreetingRecord(
        visits: _int(m['visits']) ?? 0,
        chatted: m['chatted'] == true,
        shows: shows,
        dismissed: dismissed,
        closedAt: _int(m['closedAt']),
        shownAt: _int(m['shownAt']),
        last: m['last'] is String ? m['last'] as String : null,
      );
    } catch (_) {
      return const GreetingRecord();
    }
  }

  String encode() => jsonEncode({
        'visits': visits,
        'chatted': chatted,
        'shows': shows,
        'dismissed': dismissed,
        if (closedAt != null) 'closedAt': closedAt,
        if (shownAt != null) 'shownAt': shownAt,
        if (last != null) 'last': last,
      });
}

class GreetingHead {
  final String? avatar;
  final String name;
  final bool online;
  const GreetingHead({required this.avatar, required this.name, required this.online});

  @override
  bool operator ==(Object other) => other is GreetingHead && other.avatar == avatar && other.name == name && other.online == online;

  @override
  int get hashCode => Object.hash(avatar, name, online);

  @override
  String toString() => 'GreetingHead($avatar, $name, $online)';
}

/// The launcher's colours for the phone text and the voice note: one stop, or a 135deg gradient's two.
class GreetingBubble {
  final List<String> bg;
  final String tail;
  final String fg;
  const GreetingBubble({required this.bg, required this.tail, required this.fg});
}

class Greeting {
  Greeting._();

  static const styles = ['card', 'note', 'imessage', 'postcard', 'sticky', 'typewriter', 'glass', 'notification', 'neon', 'voice', 'aurora'];
  static const defaultStyle = 'imessage';
  static const defaultDelay = 3;
  static const defaultFrequencyDays = 7;

  /// Closing the card (or opening the chat) rests it this long on "every page".
  static const pageCooldownSeconds = 300;
  static const _textMax = 140;
  static const _legacyPromptDelay = 8;
  static const _dayMs = 86400000;

  // The smart greetings' own ids (embed-server services/chatbot/greeting/smartGreetings.js).
  static const _smartRuleIds = {'sgpric', 'sgads0', 'sgretn', 'sgengd', 'sgcust', 'sgchko'};

  static String _str(dynamic v) => v is String ? v : '';

  static String _cut(String s, int n) => s.length > n ? s.substring(0, n) : s;

  /// A whole number in [lo, hi] (JS Number + Math.round), else the fallback.
  static int _num(dynamic v, int fallback, int lo, int hi) {
    if (v == null || v == '') return fallback;
    double? n;
    if (v is num) n = v.toDouble();
    if (v is bool) n = v ? 1 : 0;
    if (v is String) n = double.tryParse(v.trim());
    if (n == null || !n.isFinite) return fallback;
    return math.min(math.max((n + 0.5).floor(), lo), hi);
  }

  static Map<String, dynamic>? _obj(dynamic v) => v is Map ? v.cast<String, dynamic>() : null;

  static String normalizeStyle(dynamic v) => v is String && styles.contains(v) ? v : defaultStyle;

  /// A rule's results key: its id, else its words.
  static String ruleKey(Map<String, dynamic> rule) {
    final id = _str(rule['id']);
    return id.isNotEmpty ? id : _cut(_str(rule['text']).trim(), 40);
  }

  /// A rule's address pattern, asked of the app's "/" (nudges.ts ruleMatches).
  static bool _matchesHome(Map<String, dynamic> rule) {
    if (rule['patterns'] is List && (rule['patterns'] as List).isNotEmpty) return false; // a smart greeting's detected pages
    final p = _str(rule['pattern']).trim().toLowerCase();
    if (p.isEmpty) return false;
    switch (rule['matchType']) {
      case 'glob':
        return const ['*', '**', '/*', '/**'].contains(p);
      case 'startsWith':
      case 'exact':
        return p == '/';
      default:
        return '/'.contains(p);
    }
  }

  /// An ISO date as JS Date.parse reads it (a bare date is UTC midnight), else null.
  static int? _instant(dynamic v) {
    if (v is! String || v.isEmpty) return null;
    final s = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v) ? '${v}T00:00:00Z' : v;
    return DateTime.tryParse(s)?.millisecondsSinceEpoch;
  }

  static bool _isUnset(dynamic v) => v == null || v == 0 || (v is List && v.isEmpty);

  /// Who and when (nudges.ts audienceMatches, scheduleMatches); what an app cannot know never matches.
  static bool _applies(Map<String, dynamic> rule, GreetingFacts facts) {
    if (!_matchesHome(rule)) return false;
    final visitors = _str(rule['visitors']).isEmpty ? 'all' : rule['visitors'];
    if (visitors == 'new' && facts.returning) return false;
    if (visitors == 'returning' && !facts.returning) return false;
    final signedIn = _str(rule['signedIn']).isEmpty ? 'any' : rule['signedIn'];
    if (signedIn == 'yes' && !facts.signedIn) return false;
    if (signedIn == 'no' && facts.signedIn) return false;
    if (rule['countries'] is List && (rule['countries'] as List).isNotEmpty) return false;
    final now = facts.now ?? DateTime.now().millisecondsSinceEpoch;
    final start = _instant(rule['startsAt']);
    final end = _instant(rule['endsAt']);
    if (start != null && now < start) return false;
    if (end != null && now > end) return false;
    final source = _obj(rule['source']);
    if (source != null && source.isNotEmpty) return false;
    final b = _obj(rule['behavior']);
    if (b != null) {
      // Pages, time and paths are a browser's; visits and "chatted" an app has.
      if (b.keys.any((k) => k != 'minVisits' && k != 'chatted' && !_isUnset(b[k]))) return false;
      final minVisits = b['minVisits'];
      if (minVisits is num && minVisits != 0 && facts.visits < minVisits) return false;
      if (b['chatted'] == 'yes' && !facts.chatted) return false;
      if (b['chatted'] == 'no' && facts.chatted) return false;
    }
    if (rule['attributes'] is List && (rule['attributes'] as List).isNotEmpty) return false;
    // Its own limits: at most N shows in a window, quiet for days after a close.
    final l = _obj(rule['limits']);
    if (l != null) {
      final key = ruleKey(rule);
      final maxShows = l['maxShows'];
      if (maxShows is num && maxShows != 0) {
        final windowDays = l['windowDays'] is num && l['windowDays'] != 0 ? l['windowDays'] as num : defaultFrequencyDays;
        final since = now - windowDays * _dayMs;
        if ((facts.shows[key] ?? const []).where((t) => t > since).length >= maxShows) return false;
      }
      final d = facts.dismissed[key];
      final quiet = l['quietDaysAfterDismiss'];
      if (quiet is num && quiet != 0 && d != null && d != 0 && now - d < quiet * _dayMs) return false;
    }
    return true;
  }

  static bool _isSmart(Map<String, dynamic> r) => _smartRuleIds.contains(_str(r['id']));
  static bool _isNone(Map<String, dynamic> r) => _obj(r['action'])?['type'] == 'none';

  /// The greeting to show, or null: the highest-priority rule that applies
  /// (a "show nothing" rule that applies silences it), else the default
  /// message when the greeting is on.
  static ResolvedGreeting? decide(Map<String, dynamic>? c, GreetingFacts facts) {
    final raw = c ?? const <String, dynamic>{};
    var on = raw['chatIconCta'] == true;
    var text = _str(raw['chatIconCtaText']).trim();
    var delay = _num(raw['greetingDelay'], defaultDelay, 0, 3600);
    var click = raw['greetingClickAction'] == 'send' || raw['greetingClickAction'] == 'link' ? raw['greetingClickAction'] as String : 'open';
    // Smart greetings with the owner's own greeting off: no default message.
    if (raw['smartOnly'] == true && !on) {
      on = true;
      text = '';
    }
    final rules = (raw['greetingRules'] is List ? raw['greetingRules'] as List : const []).map(_obj).whereType<Map<String, dynamic>>().toList();
    // The old proactive teaser, carried over as the web does: its page rules
    // (never the app's "/"), and its every-page message as the default message,
    // or as a rule when the greeting already has one.
    final legacyText = raw['proactivePromptEnabled'] == true ? _str(raw['proactivePromptText']).trim() : '';
    final legacyRules = (raw['proactivePromptRules'] is List ? raw['proactivePromptRules'] as List : const [])
        .map(_obj)
        .where((r) => r != null && _str(r['text']).trim().isNotEmpty && _str(r['urlPattern']).trim().isNotEmpty);
    if (legacyRules.isNotEmpty || legacyText.isNotEmpty) {
      if (!on) text = '';
      if (legacyText.isNotEmpty) {
        final legacyDelay = _num(raw['proactivePromptDelay'], _legacyPromptDelay, 0, 3600);
        if (text.isNotEmpty) {
          rules.add({'matchType': 'contains', 'pattern': '/', 'text': legacyText, 'delay': legacyDelay, 'clickAction': 'send'});
        } else {
          text = legacyText;
          delay = legacyDelay;
          click = 'send';
        }
      }
      on = true;
    }
    if (!on) return null;
    // "Show nothing" wins for the visitors it fits - a smart one yields to the
    // owner's own talking rule for the same visitor.
    final ownTalks = rules.any((r) => !_isSmart(r) && !_isNone(r) && _str(r['text']).trim().isNotEmpty && _applies(r, facts));
    if (rules.any((r) => _isNone(r) && _applies(r, facts) && !(_isSmart(r) && ownTalks))) return null;
    final ranked = [for (var i = 0; i < rules.length; i++) (rules[i], i, rules[i]['priority'] is num ? rules[i]['priority'] as num : 50)]
      ..sort((a, b) {
        final p = b.$3.compareTo(a.$3);
        return p != 0 ? p : a.$2.compareTo(b.$2);
      });
    for (final (rule, _, _) in ranked) {
      final ruleText = _str(rule['text']).trim();
      if (ruleText.isEmpty || _isNone(rule) || !_applies(rule, facts)) continue;
      final rc = rule['clickAction'];
      final ruleClick = rc == 'send' || rc == 'open' || rc == 'link' ? rc as String : click;
      return ResolvedGreeting(
        text: _cut(ruleText, _textMax),
        delay: rule['delay'] is num ? _num(rule['delay'], delay, 0, 3600) : delay,
        click: ruleClick,
        linkUrl: ruleClick == 'link' ? _str(rule['linkUrl']) : '',
        starters: (rule['starters'] is List ? rule['starters'] as List : const [])
            .whereType<String>()
            .where((s) => s.trim().isNotEmpty)
            .take(3)
            .toList(),
        key: ruleKey(rule),
      );
    }
    if (text.isEmpty) return null;
    return ResolvedGreeting(
      text: _cut(text, _textMax),
      delay: delay,
      click: click == 'link' ? 'open' : click,
      linkUrl: '',
      starters: const [],
      key: _cut(text, 40),
    );
  }

  /// Whether the frequency lets the card show now (nudges.ts frequencyAllows).
  static bool frequencyAllows(Map<String, dynamic>? c, GreetingSeen st, [int? now]) {
    final t = now ?? DateTime.now().millisecondsSinceEpoch;
    final f = c?['greetingFrequency'];
    final frequency = f == 'session' || f == 'visitor' ? f : 'page';
    final days = _num(c?['greetingFrequencyDays'], defaultFrequencyDays, 1, 365);
    if (frequency == 'session') return !st.shownThisSession;
    if (frequency == 'visitor') return st.shownAt == null || st.shownAt == 0 || t - st.shownAt! >= days * _dayMs;
    // Every page (each launch in an app): a close rests it a few minutes.
    return st.closedAt == null || st.closedAt == 0 || t - st.closedAt! >= pageCooldownSeconds * 1000;
  }

  /// The card's header: the agent or bot's avatar and name, and "Online" unless the owner hid it.
  static GreetingHead head(Map<String, dynamic>? c, [String botName = '']) {
    final x = c ?? const <String, dynamic>{};
    String? pick(bool ok, dynamic v) => ok && _str(v).isNotEmpty ? _str(v) : null;
    final avatar = pick(x['hideAvatar'] != true, x['avatar']) ?? pick(true, x['initialPageAvatar']) ?? pick(x['hideLogo'] != true, x['logo']);
    final name = _str(x['logoText']).isNotEmpty ? _str(x['logoText']) : (botName.isNotEmpty ? botName : 'Support');
    return GreetingHead(avatar: avatar, name: name, online: x['hideOnlineStatus'] != true);
  }

  static double _channel(double v) {
    final s = v / 255;
    return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  static double _luminance(Rgba c) => 0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

  static String _hex(Rgba c) => '#${[c.r, c.g, c.b].map((n) => n.round().clamp(0, 255).toRadixString(16).padLeft(2, '0')).join()}';

  static (String, String)? _gradientStops(Map<String, dynamic> c) {
    final one = _str(c['widgetGradientBgOne']);
    final two = _str(c['widgetGradientBgTwo']);
    return c['widgetIconThemeType'] == 'Gradient' && one.isNotEmpty && two.isNotEmpty ? (one, two) : null;
  }

  /// The card's accent (firstImpression.ts accentFor): the first bot colour that is not too light.
  static String accent(Map<String, dynamic>? c) {
    final x = c ?? const <String, dynamic>{};
    final g = _gradientStops(x);
    final header = _str(x['headerBgColor']);
    final brandColor = _str(x['brandColor']);
    final themed = x['_themePalette'] != null && x['_themePalette'] != false;
    final brand = !themed && brandColor.isNotEmpty ? brandColor : (header.isNotEmpty ? header : '#1b55f3');
    final iconBg = _str(x['widgetIconBgColor']);
    final launcher = g != null ? [g.$1, g.$2] : [iconBg.isNotEmpty ? iconBg : (header.isNotEmpty ? header : '#4f46e5')];
    for (final v in [brand, header, ...launcher]) {
      final rgb = WidgetTheme.parseColor(v);
      if (rgb != null && _luminance(rgb) <= 0.55) return _hex(rgb);
    }
    return '#4f46e5';
  }

  /// The launcher's colours for the phone text and the voice note (greetingStyle.ts).
  static GreetingBubble bubble(Map<String, dynamic>? c) {
    final x = c ?? const <String, dynamic>{};
    final g = _gradientStops(x);
    final rgb = WidgetTheme.parseColor(g?.$1 ?? x['widgetIconBgColor']);
    final solid = rgb != null ? _hex(rgb) : '#1b55f3';
    final fg = _luminance(WidgetTheme.parseColor(solid)!) > 0.6 ? '#111827' : '#ffffff';
    return g != null ? GreetingBubble(bg: [g.$1, g.$2], tail: g.$2, fg: fg) : GreetingBubble(bg: [solid], tail: solid, fg: fg);
  }

  /// The bot's own font for the card, or null for the system font (Arial and Gill Sans read as the default).
  static String? font(Map<String, dynamic>? c) {
    final f = _str(c?['font']).trim();
    return f.isEmpty || RegExp(r'^(arial|gill sans)', caseSensitive: false).hasMatch(f) ? null : f;
  }
}
