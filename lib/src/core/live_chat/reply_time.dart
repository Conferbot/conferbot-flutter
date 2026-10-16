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

class ReplyTime {
  ReplyTime._();

  static const online = 'Online';
  static const sep = ' · ';

  /// "The team typically replies <phrase>"
  static const phrases = {
    'under_minute': 'in under a minute',
    'few_minutes': 'in a few minutes',
    'under_15_minutes': 'in under 15 minutes',
    'under_hour': 'in under an hour',
    'few_hours': 'in a few hours',
    'day': 'within a day',
    'few_days': 'in a few days',
  };

  static String _str(dynamic v) => v is String ? v.trim() : '';

  /// When the team is back, in the visitor's time: "at 9 AM" (today),
  /// "tomorrow 9 AM", "Monday 9:30 AM", "Mon, Oct 12 9 AM".
  static String backWhen(dynamic backAt, {DateTime? now, String locale = 'en_US'}) {
    final raw = _str(backAt);
    if (raw.isEmpty) return '';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return '';
    final d = parsed.toLocal();
    final n = now ?? DateTime.now();
    final time = DateFormat(d.minute != 0 ? 'h:mm a' : 'h a', locale).format(d);
    final days = DateTime(d.year, d.month, d.day).difference(DateTime(n.year, n.month, n.day)).inHours / 24;
    final whole = days.round();
    if (whole <= 0) return 'at $time';
    if (whole == 1) return 'tomorrow $time';
    if (whole < 7) return '${DateFormat('EEEE', locale).format(d)} $time';
    return '${DateFormat('EEE, MMM d', locale).format(d)} $time';
  }

  /// The header's status from the server's reply time; null keeps "Online".
  /// The bot stays Online when the team is away or offline ("Online · team
  /// back at 9 AM", "Online · team replies by email"). [agent]: an AI agent
  /// bot, which answers itself whatever the hour (no line).
  static String? headerLine(dynamic rt, {bool agent = false, DateTime? now, String locale = 'en_US'}) {
    if (rt is! Map || rt['mode'] == 'hide' || rt['handover'] != true || agent) return null;
    final state = rt['state'];
    if (state == 'away' || state == 'offline') {
      final when = backWhen(rt['backAt'], now: now, locale: locale);
      final words = when.isNotEmpty
          ? 'team back $when'
          : rt['leaveMessage'] == false
              ? 'team away right now'
              : 'team replies by email';
      return '$online$sep$words';
    }
    final fixed = rt['mode'] == 'fixed' ? _str(rt['text']) : '';
    if (fixed.isNotEmpty) return fixed;
    final phrase = phrases[rt['bucket']] ?? _str(rt['phrase']);
    return phrase.isEmpty ? null : 'Typically replies $phrase';
  }

  /// What the header shows under the bot name: the reply-time line, or plain
  /// "Online" once a person is in the chat (the snapshot about an away team
  /// is no longer true), or nothing when the owner turned it off ([hidden]).
  static String? headerStatus(dynamic rt, {bool personInChat = false, bool agentBot = false, bool hidden = false, DateTime? now, String locale = 'en_US'}) {
    if (hidden) return null;
    if (personInChat) return online;
    return headerLine(rt, agent: agentBot, now: now, locale: locale) ?? online;
  }
  // ------------------------------------------------------------ the home card (web homeLine, homePeople)

  static bool _live(dynamic rt) => rt is Map && rt['mode'] != 'hide';
  static String _fixedOf(Map rt) => rt['mode'] == 'fixed' ? _str(rt['text']) : '';
  static String _phraseOf(Map rt) => phrases[rt['bucket']] ?? _str(rt['phrase']);

  static String typically(String phrase) => 'The team typically replies $phrase';
  static String teamReplies(String phrase) => 'team replies $phrase';
  static const answersInstantly = 'Answers instantly';
  static const answersAlways = 'Answers instantly, day or night';
  static const awayNow = "We're away right now";
  static String back(String when) => 'back $when';
  static const offline = 'The team is offline';
  static const byEmail = "we'll reply by email";
  static const offlineNow = 'The team is offline right now';
  static String usually(String phrase) => 'Usually replies $phrase';
  static const usuallyInstantly = 'Usually replies instantly';
  static String teamBackAt(String when) => 'Team back $when';
  static const teamRepliesByEmail = 'Team replies by email';
  static const teamAwayRightNow = 'Team away right now';

  /// The "Talk to us" card's line (web replyTime.ts homeLine). A
  /// [HomeLine.hidden] line means take it away (the owner chose Hide); null
  /// keeps the old line.
  static HomeLine? homeLine(dynamic rt, {bool agent = false, DateTime? now, String locale = 'en_US'}) {
    if (rt is Map && rt['mode'] == 'hide') return agent ? null : HomeLine.hidden;
    if (!_live(rt) || rt['handover'] != true) return null;
    final m = rt as Map;
    final when = backWhen(m['backAt'], now: now, locale: locale);
    final fixed = _fixedOf(m);
    final words = fixed.isNotEmpty ? fixed : _phraseOf(m);
    final state = m['state'];
    if (agent) {
      // The AI answers whatever the hour; say when people are around.
      if (state == 'away') return HomeLine(answersInstantly + (when.isNotEmpty ? '${sep}team back $when' : ''), away: true);
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
  static HomeLine homePeople(dynamic rt, {bool agent = false, DateTime? now, String locale = 'en_US'}) {
    final line = homeLine(rt, agent: agent, now: now, locale: locale);
    if (agent) return line != null && !line.hide ? HomeLine(line.text, away: line.away) : const HomeLine(answersAlways);
    if (line != null && line.hide) return const HomeLine('');
    if (!_live(rt) || rt['handover'] != true) return const HomeLine(answersAlways);
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
