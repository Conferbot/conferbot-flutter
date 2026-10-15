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
/// bot's name. Pure.
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
}
