/// Calendar step rules, ported from the web widget
/// (conferbot-widget/src/ts/chat/nodeLogic.ts: expandSlots, futureSlots,
/// dayKeyInZone, noonInZone; displayStep.ts calendar-node) via the React
/// Native SDK (src/core/flow/calendar.ts). Slot times are the bot's clock
/// (data.timeZone); the visitor sees their own.
library;

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

const List<String> _dayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const List<String> _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// "Tuesday, October 20, 2026" (en-US; other locales are not supported).
String longDate(DateTime date, String timeZone, [String locale = 'en-US']) {
  final p = partsIn(date, timeZone);
  return '${_dayNames[p.weekday]}, ${_monthNames[p.month - 1]} ${p.day}, ${p.year}';
}

/// The weekday name of a day on the bot's clock.
String dayNameInZone(DateTime date, String timeZone) => _dayNames[partsIn(date, timeZone).weekday];

/// The visitor's own time zone (UTC when unknown).
String visitorTimeZone() => deviceTimeZone();
