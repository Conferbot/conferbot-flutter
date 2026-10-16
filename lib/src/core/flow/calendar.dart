/// Calendar step rules, ported from the web widget
/// (conferbot-widget/src/ts/chat/nodeLogic.ts: expandSlots, futureSlots,
/// dayKeyInZone, noonInZone; displayStep.ts calendar-node) via the React
/// Native SDK (src/core/flow/calendar.ts). Slot times are the bot's clock
/// (data.timeZone); the visitor sees their own.
library;

import 'package:intl/intl.dart';

import 'i18n_en.dart';
import 'js.dart';
import 'zones.dart';

class CalendarSlot {
  final String start;
  final String end;
  const CalendarSlot({required this.start, required this.end});

  Map<String, dynamic> toJson() => {'start': start, 'end': end};

  @override
  bool operator ==(Object other) => other is CalendarSlot && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

int? _toMinutes(dynamic hhmm) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(hhmm == null ? '' : jsString(hhmm));
  if (m == null) return null;
  return int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
}

String _toHhmm(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

int _floorOrZero(dynamic v) {
  final n = jsNumber(v);
  if (!n.isFinite || n == 0) return 0;
  return n.floor();
}

dynamic _field(dynamic w, String key) => w is Map ? w[key] : null;

/// A day's windows cut into slotDuration-minute slots with bufferMinutes between.
List<CalendarSlot> expandSlots(dynamic windows, [dynamic slotDuration, dynamic bufferMinutes]) {
  final list = windows is List ? windows : const [];
  final length = _floorOrZero(slotDuration);
  final buffer = _floorOrZero(bufferMinutes) < 0 ? 0 : _floorOrZero(bufferMinutes);
  if (length <= 0) {
    return list
        .where((w) => jsTruthy(_field(w, 'start')) && jsTruthy(_field(w, 'end')))
        .map((w) => CalendarSlot(start: jsString(_field(w, 'start')), end: jsString(_field(w, 'end'))))
        .toList();
  }
  final out = <CalendarSlot>[];
  for (final w in list) {
    final from = _toMinutes(_field(w, 'start'));
    final to = _toMinutes(_field(w, 'end'));
    if (from == null || to == null || to <= from) continue;
    for (var t = from; t + length <= to; t += length + buffer) {
      out.add(CalendarSlot(start: _toHhmm(t), end: _toHhmm(t + length)));
    }
  }
  return out;
}

String slotLabel(CalendarSlot slot) => '${slot.start} - ${slot.end}';

/// "YYYY-MM-DD" of an instant on a zone's clock.
String dayKeyInZone(DateTime? date, String timeZone) {
  if (date == null) return '';
  if (!isValidZone(timeZone)) return jsIsoString(date).substring(0, 10);
  return partsIn(date, timeZone).ymd;
}

/// Today's slots that have not started yet (bot's clock); other days keep all.
List<CalendarSlot> futureSlots(List<CalendarSlot> slots, String dayKey, String timeZone, [DateTime? now]) {
  if (!isValidZone(timeZone)) return slots;
  final p = partsIn(now ?? DateTime.now(), timeZone);
  if (dayKey != p.ymd) return slots;
  final nowMin = _toMinutes(p.hhmm) ?? 0;
  return slots.where((s) => (_toMinutes(s.start) ?? 0) > nowMin).toList();
}

/// The instant it is hh:mm on `dateString` on `timeZone`'s clock.
DateTime wallTimeInZone(String dateString, String hhmm, String timeZone) {
  final parts = dateString.split('-').map((s) => jsNumber(s)).toList();
  int at(int i, int fallback) {
    if (i >= parts.length) return fallback;
    final v = parts[i];
    return v.isFinite && v != 0 ? v.toInt() : fallback;
  }

  final y = parts.isNotEmpty && parts[0].isFinite ? parts[0].toInt() : 1970;
  final m = at(1, 1);
  final d = at(2, 1);
  final mins = _toMinutes(hhmm) ?? 12 * 60;
  final guess = DateTime.utc(y, m, d, mins ~/ 60, mins % 60).millisecondsSinceEpoch;
  var t = guess - zoneOffsetMs(guess, timeZone);
  t = guess - zoneOffsetMs(t, timeZone);
  return DateTime.fromMillisecondsSinceEpoch(t, isUtc: true);
}

/// 12:00 on that day on that zone's clock (the picked day, read the same everywhere).
DateTime noonInZone(String dateString, String timeZone) => wallTimeInZone(dateString, '12:00', timeZone);

/// "HH:MM" of an instant on a zone's clock.
String hhmmInZone(DateTime date, String timeZone) => partsIn(date, timeZone).hhmm;

/// The owner's day names (weeklyHours.dayName, excludeDays) are English: kept so here.
const List<String> _dayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const List<String> _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// "Tuesday, October 20, 2026" (en-US); another [locale] (an intl locale such
/// as "nl" or "fr_BE") writes it that language's way: "dinsdag 20 oktober 2026".
String longDate(DateTime date, String timeZone, [String locale = 'en-US']) {
  final p = partsIn(date, timeZone);
  if (locale != 'en-US') {
    return DateFormat.yMMMMEEEEd(locale).format(DateTime.utc(p.year, p.month, p.day, 12));
  }
  return '${_dayNames[p.weekday]}, ${_monthNames[p.month - 1]} ${p.day}, ${p.year}';
}

/// The locale a visitor's own date is written in: the widget's (web
/// displayStep.ts formattedVisitorDate uses widgetLocale()), "en-US" for
/// English. The bot's date stays en-US, as the web keeps it.
String visitorLocale() => I18n.language == I18n.en ? 'en-US' : I18n.intlLocale;

/// The weekday name of a day on the bot's clock.
String dayNameInZone(DateTime date, String timeZone) => _dayNames[partsIn(date, timeZone).weekday];

/// The visitor's own time zone (UTC when unknown).
String visitorTimeZone() => deviceTimeZone();

/// A booking's instant: an ISO string ("2026-11-03T08:00:00.000Z"; a bare
/// date is UTC midnight, as JavaScript reads it) or a time in ms.
DateTime? _bookingDate(dynamic v) {
  if (v is num && v.isFinite) return DateTime.fromMillisecondsSinceEpoch(v.toInt(), isUtc: true);
  if (v is! String || v.trim().isEmpty) return null;
  final s = v.trim();
  final bare = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s);
  return DateTime.tryParse(bare ? '${s}T00:00:00Z' : s);
}

/// The slots already taken on a day, as "HH:MM - HH:MM" on the bot's clock
/// (web displayStep.ts daySlotsFor `booked`): the bot's bookings (the bot
/// data's calendarBookings, populated by the server) plus any the node
/// carries itself (data.bookings), for this node only (a booking with no
/// nodeId counts for every calendar), on this day in the bot's zone.
List<String> bookedLabels(dynamic calendarBookings, String? nodeId, Map<String, dynamic>? nodeData, String dayKey, String timeZone) {
  final own = nodeData?['bookings'];
  final nodeBookings = (own is List ? own : const []).where((b) => b is Map && jsTruthy(b['date']));
  return [...(calendarBookings is List ? calendarBookings : const []), ...nodeBookings]
      .whereType<Map>()
      .where((b) => !jsTruthy(b['nodeId']) || b['nodeId'] == nodeId)
      .where((b) => dayKeyInZone(_bookingDate(b['date']), timeZone) == dayKey)
      .map((b) => (b['timeSlotSelected'] == null ? '' : jsString(b['timeSlotSelected'])).trim())
      .toList();
}

/// Every slot of the day taken (web nodeLogic.ts isDayFullyBooked): the day greys out.
bool isDayFullyBooked(List<CalendarSlot> slots, List<String> booked) {
  if (slots.isEmpty) return false;
  final taken = booked.map((l) => l.trim()).toSet();
  return slots.every((s) => taken.contains(slotLabel(s)));
}
