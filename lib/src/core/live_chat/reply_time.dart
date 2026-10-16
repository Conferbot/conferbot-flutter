/// The chat header's status under the bot name: "Online", the team's reply
/// time, or when the team is back. Ported from the React Native SDK
/// (src/core/replyTime.ts), itself from the web widget's
/// src/ts/chat/replyTime.ts (headerLine, backWhen, the English words from
/// ts/i18n/en.ts reply.*) and src/ts/chat/headerPresence.ts (a person in the
/// chat puts it back to a plain "Online").
///
/// The server works the reply time out (embed-server
/// liveChat/replyTimeService) and sends it with the bot data as
/// customizations.replyTime. The bot itself is always Online; the words say
/// when people answer. The header never changes to the agent: it keeps the
/// bot's name. The home screen's "Talk to us" card has its own words
/// (homeLine, homePeople). Pure.
library;

import 'package:intl/intl.dart';

import '../i18n/i18n.dart';

class ReplyTime {
  ReplyTime._();

  static String get online => t('status.online');
  static const sep = ' · ';

  static const _buckets = ['under_minute', 'few_minutes', 'under_15_minutes', 'under_hour', 'few_hours', 'day', 'few_days'];

  /// "The team typically replies <phrase>", per bucket, in the active
  /// language (web reply.phrase.*).
  static Map<String, String> get phrases => {for (final b in _buckets) b: t('reply.phrase.$b')};

  static String _phrase(dynamic bucket) => _buckets.contains(bucket) ? t('reply.phrase.$bucket') : '';

  /// The visitor's language and region for dates (web: locale ||
  /// widgetLocale() || "en-US").
  static String _locale(String? locale) {
    if (locale != null && locale.isNotEmpty) return locale;
    final l = I18n.intlLocale;
    return l == 'en' ? 'en_US' : l;
  }

  static String _str(dynamic v) => v is String ? v.trim() : '';

  /// When the team is back, in the visitor's time: "at 9 AM" (today),
  /// "tomorrow 9 AM", "Monday 9:30 AM", "Mon, Oct 12 9 AM".
  static String backWhen(dynamic backAt, {DateTime? now, String? locale}) {
    final raw = _str(backAt);
    if (raw.isEmpty) return '';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return '';
    final d = parsed.toLocal();
    final n = now ?? DateTime.now();
    final loc = _locale(locale);
    // English keeps its own patterns; other languages use their own clock
    // and date order.
    final english = loc.startsWith('en');
    final time = english
        ? DateFormat(d.minute != 0 ? 'h:mm a' : 'h a', loc).format(d)
        : (d.minute != 0 ? DateFormat.jm(loc) : DateFormat.j(loc)).format(d);
    final days = DateTime(d.year, d.month, d.day).difference(DateTime(n.year, n.month, n.day)).inHours / 24;
    final whole = days.round();
    if (whole <= 0) return t('reply.atTime', {'time': time});
    if (whole == 1) return '${t('reply.tomorrow')} $time';
    if (whole < 7) return '${DateFormat('EEEE', loc).format(d)} $time';
    return '${(english ? DateFormat('EEE, MMM d', loc) : DateFormat.MMMEd(loc)).format(d)} $time';
  }

  /// The header's status from the server's reply time; null keeps "Online".
  /// The bot stays Online when the team is away or offline ("Online · team
  /// back at 9 AM", "Online · team replies by email"). [agent]: an AI agent
  /// bot, which answers itself whatever the hour (no line).
  static String? headerLine(dynamic rt, {bool agent = false, DateTime? now, String? locale}) {
    if (rt is! Map || rt['mode'] == 'hide' || rt['handover'] != true || agent) return null;
    final state = rt['state'];
    if (state == 'away' || state == 'offline') {
      final when = backWhen(rt['backAt'], now: now, locale: locale);
      final words = when.isNotEmpty
          ? t('reply.teamBack', {'when': when})
          : rt['leaveMessage'] == false
              ? t('reply.teamAwayNow')
              : t('reply.teamByEmail');
      return '$online$sep$words';
    }
    final fixed = rt['mode'] == 'fixed' ? _str(rt['text']) : '';
    if (fixed.isNotEmpty) return fixed;
    final known = _phrase(rt['bucket']);
    final phrase = known.isNotEmpty ? known : _str(rt['phrase']);
    return phrase.isEmpty ? null : t('reply.typicallyShort', {'phrase': phrase});
  }

  /// What the header shows under the bot name: the reply-time line, or plain
  /// "Online" once a person is in the chat (the snapshot about an away team
  /// is no longer true), or nothing when the owner turned it off ([hidden]).
  static String? headerStatus(dynamic rt, {bool personInChat = false, bool agentBot = false, bool hidden = false, DateTime? now, String? locale}) {
    if (hidden) return null;
    if (personInChat) return online;
    return headerLine(rt, agent: agentBot, now: now, locale: locale) ?? online;
  }
  // ------------------------------------------------------------ the wait card (web typicalWait)

  /// The usual wait, per bucket, in the active language (web reply.wait.*).
  static Map<String, String> get waits => {for (final b in _buckets) b: t('reply.wait.$b')};

  static String _waitOf(dynamic bucket, dynamic fallback) =>
      _buckets.contains(bucket) ? t('reply.wait.$bucket') : _str(fallback);

  /// "Typical wait: a few minutes" for the wait card (web replyTime.ts
  /// typicalWait): the routed team's usual first reply (queue-status
  /// `typical`), else the workspace's (customizations.replyTime). null when
  /// the owner chose Fixed or Hide, or there is no data.
  static String? typicalWait(dynamic rt, [dynamic queueTypical]) {
    if (rt is Map && (rt['mode'] == 'hide' || _fixedOf(rt).isNotEmpty)) return null;
    var w = queueTypical is Map ? _waitOf(queueTypical['bucket'], queueTypical['wait']) : '';
    if (w.isEmpty && rt is Map) w = _waitOf(rt['bucket'], rt['wait']);
    return w.isEmpty ? null : t('reply.typicalWait', {'wait': w});
  }

  // ------------------------------------------------------------ the home card (web homeLine, homePeople)

  static bool _live(dynamic rt) => rt is Map && rt['mode'] != 'hide';
  static String _fixedOf(Map rt) => rt['mode'] == 'fixed' ? _str(rt['text']) : '';
  static String _phraseOf(Map rt) {
    final known = _phrase(rt['bucket']);
    return known.isNotEmpty ? known : _str(rt['phrase']);
  }

  // The home card's words (web replyTime.ts STRINGS, reply.*), read when drawn.
  static String typically(String phrase) => t('reply.typically', {'phrase': phrase});
  static String teamReplies(String phrase) => t('reply.teamReplies', {'phrase': phrase});
  static String get answersInstantly => t('reply.answersInstantly');
  static String get answersAlways => t('reply.answersAlways');
  static String get awayNow => t('reply.away');
  static String back(String when) => t('reply.back', {'when': when});
  static String get offline => t('reply.offline');
  static String get byEmail => t('reply.byEmail');
  static String get offlineNow => t('reply.offlineNow');
  static String usually(String phrase) => t('reply.usually', {'phrase': phrase});
  static String get usuallyInstantly => t('reply.usuallyInstantly');
  static String teamBackAt(String when) => t('reply.teamBackAt', {'when': when});
  static String get teamRepliesByEmail => t('reply.teamRepliesByEmail');
  static String get teamAwayRightNow => t('reply.teamAwayRightNow');

  /// The "Talk to us" card's line (web replyTime.ts homeLine). A
  /// [HomeLine.hidden] line means take it away (the owner chose Hide); null
  /// keeps the old line.
  static HomeLine? homeLine(dynamic rt, {bool agent = false, DateTime? now, String? locale}) {
    if (rt is Map && rt['mode'] == 'hide') return agent ? null : HomeLine.hidden;
    if (!_live(rt) || rt['handover'] != true) return null;
    final m = rt as Map;
    final when = backWhen(m['backAt'], now: now, locale: locale);
    final fixed = _fixedOf(m);
    final words = fixed.isNotEmpty ? fixed : _phraseOf(m);
    final state = m['state'];
    if (agent) {
      // The AI answers whatever the hour; say when people are around.
      if (state == 'away') return HomeLine(answersInstantly + (when.isNotEmpty ? '$sep${t('reply.teamBack', {'when': when})}' : ''), away: true);
      if (state == 'offline' || words.isEmpty) return null;
      return HomeLine('$answersInstantly$sep${fixed.isNotEmpty ? fixed : teamReplies(words)}');
    }
    if (state == 'away') return HomeLine(awayNow + (when.isNotEmpty ? '$sep${back(when)}' : ''), away: true);
    if (state == 'offline') return HomeLine(m['leaveMessage'] != false ? '$offline$sep$byEmail' : offlineNow, away: true);
    if (fixed.isNotEmpty) return HomeLine(fixed);
    return words.isNotEmpty ? HomeLine(typically(words)) : null;
  }

  /// The home card's promise (web replyTime.ts homePeople), read after
  /// "Online" under the bot's name:
  ///
  /// - an AI agent answers whatever the hour: "Answers instantly, day or
  ///   night" (or with when the team replies / is back, from homeLine);
  /// - a bot that never hands over (or no data, an older server): "Answers
  ///   instantly, day or night";
  /// - a team that is online: "Usually replies in a few minutes" (or the
  ///   owner's Fixed words);
  /// - a team that is away or offline: "Team back tomorrow 9 AM", else "Team
  ///   replies by email" (or "Team away right now" with leave-a-message off);
  /// - Hide: no words ("").
  static HomeLine homePeople(dynamic rt, {bool agent = false, DateTime? now, String? locale}) {
    final line = homeLine(rt, agent: agent, now: now, locale: locale);
    if (agent) return line != null && !line.hide ? HomeLine(line.text, away: line.away) : HomeLine(answersAlways);
    if (line != null && line.hide) return const HomeLine('');
    if (!_live(rt) || rt['handover'] != true) return HomeLine(answersAlways);
    final m = rt as Map;
    final state = m['state'];
    if (state == 'away' || state == 'offline') {
      final when = backWhen(m['backAt'], now: now, locale: locale);
      final text = when.isNotEmpty ? teamBackAt(when) : m['leaveMessage'] == false ? teamAwayRightNow : teamRepliesByEmail;
      return HomeLine(text, away: true);
    }
    final fixed = _fixedOf(m);
    final words = _phraseOf(m);
    return HomeLine(fixed.isNotEmpty ? fixed : (words.isNotEmpty ? usually(words) : usuallyInstantly));
  }
}

/// A home card line and its tone: [away] when nobody is there (web
/// `tone: 'away'`); [hide] when the owner chose to hide it.
class HomeLine {
  const HomeLine(this.text, {this.away = false}) : hide = false;
  const HomeLine._hidden()
      : text = '',
        away = false,
        hide = true;

  static const hidden = HomeLine._hidden();

  final String text;
  final bool away;
  final bool hide;

  @override
  bool operator ==(Object other) => other is HomeLine && other.text == text && other.away == away && other.hide == hide;

  @override
  int get hashCode => Object.hash(text, away, hide);

  @override
  String toString() => hide ? 'HomeLine.hidden' : 'HomeLine($text${away ? ', away' : ''})';
}
