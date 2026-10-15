/// IANA time zones for the flow steps that read a clock (business hours,
/// calendar slots, date limits), as the web widget reads them through
/// `Intl.DateTimeFormat({timeZone})`. Backed by package:timezone.
library;

import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

bool _loaded = false;

void _ensureLoaded() {
  if (_loaded) return;
  tzdata.initializeTimeZones();
  _loaded = true;
}

/// The zone by IANA name ("UTC" and "GMT" included), or null when unknown.
tz.Location? zoneNamed(dynamic name) {
  final z = (name ?? '').toString().trim();
  if (z.isEmpty) return null;
  _ensureLoaded();
  if (z.toUpperCase() == 'UTC' || z.toUpperCase() == 'GMT') return tz.UTC;
  try {
    return tz.getLocation(z);
  } catch (_) {
    return null;
  }
}

/// Whether `name` is a zone the clock can read.
bool isValidZone(dynamic name) => zoneNamed(name) != null;

/// The wall clock of an instant in a zone.
class ZonedParts {
  final int year;
  final int month;
  final int day;
  final int hour;
  final int minute;
  final int second;

  /// 0 = Sunday ... 6 = Saturday (JavaScript `getDay()`).
  final int weekday;

  const ZonedParts(this.year, this.month, this.day, this.hour, this.minute, this.second, this.weekday);

  String get ymd => '${_pad4(year)}-${_pad2(month)}-${_pad2(day)}';
  String get hhmm => '${_pad2(hour)}:${_pad2(minute)}';
}

String _pad2(int n) => n.toString().padLeft(2, '0');
String _pad4(int n) => n.toString().padLeft(4, '0');

/// The wall clock of `instant` in `zone` (UTC when the zone is unknown).
ZonedParts partsIn(DateTime instant, dynamic zone) {
  final loc = zoneNamed(zone) ?? zoneNamed('UTC')!;
  final t = tz.TZDateTime.from(instant.toUtc(), loc);
  return ZonedParts(t.year, t.month, t.day, t.hour, t.minute, t.second, t.weekday % 7);
}

/// How far (ms) the zone's clock is ahead of UTC at `epochMs`.
int zoneOffsetMs(int epochMs, dynamic zone) {
  final loc = zoneNamed(zone);
  if (loc == null) return 0;
  return loc.timeZone(epochMs).offset.inMilliseconds;
}

/// The device's zone as an IANA name: a fixed-offset "Etc/GMT" zone for a
/// whole-hour offset (Dart does not expose the device's zone name), else UTC.
String deviceTimeZone([DateTime? now]) {
  final offset = (now ?? DateTime.now()).timeZoneOffset;
  if (offset.inMinutes == 0) return 'UTC';
  if (offset.inMinutes % 60 != 0) return 'UTC';
  final h = offset.inHours;
  // "Etc/GMT-5" is UTC+5 (POSIX signs are inverted).
  return h > 0 ? 'Etc/GMT-$h' : 'Etc/GMT+${-h}';
}
