/// The date steps' cards.
///
/// - datetime-node (web richNodesView.ts dateCardHtml): a date, a time or
///   both picked with the phone's own picker, the closed days said up front,
///   then the step's button. Sends `{value}` ("2026-10-19", "14:30",
///   "2026-10-19T14:30"); the step refuses a closed day or a time out of hours.
/// - calendar-node (web displayStep.ts calendar): the month as a grid in the
///   bot's colour, days before today or without free times greyed, then the
///   day's free times as options. Sends `{date}` or `{date, slot}`.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/flow/i18n_en.dart';
import '../../core/nodes/node_ui_state.dart' as ui_state;
import '../../theme/conferbot_theme.dart';
import 'step_style.dart';

const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const _weekdaysShort = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

String _pad2(int n) => n.toString().padLeft(2, '0');
String dayKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_pad2(d.month)}-${_pad2(d.day)}';

DateTime? _parseDay(dynamic s) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch('${s ?? ''}');
  if (m == null) return null;
  return DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
}

/// "Mon, Oct 19, 2026"; another language writes it its own way ("ma 19 okt. 2026").
String _shownDate(DateTime d) => I18n.language == I18n.en
    ? '${_weekdaysShort[d.weekday % 7]}, ${_months[d.month - 1].substring(0, 3)} ${d.day}, ${d.year}'
    : DateFormat.yMMMEd(I18n.intlLocale).format(d);

// ==================== DATE / TIME ====================

class DateTimeStepWidget extends StatefulWidget {
  final ui_state.CalendarUIState state;
  final ValueChanged<dynamic> onResponse;
  final Color primaryColor;
  final ConferBotTheme theme;
  final String? error;

  const DateTimeStepWidget({
    super.key,
    required this.state,
    required this.onResponse,
    required this.primaryColor,
    required this.theme,
    this.error,
  });

  @override
  State<DateTimeStepWidget> createState() => _DateTimeStepWidgetState();
}

class _DateTimeStepWidgetState extends State<DateTimeStepWidget> {
  DateTime? _date;
  TimeOfDay? _time;
  bool _sent = false;

  String get _mode => widget.state.mode;
  Map<String, dynamic> get _extra => widget.state.extra;

  @override
  void didUpdateWidget(DateTimeStepWidget old) {
    super.didUpdateWidget(old);
    if (!identical(old.state, widget.state) || old.error != widget.error) _sent = false;
  }

  Future<void> _pickDate(StepLook style) async {
    final first = _parseDay(_extra['min']) ?? DateTime(1900);
    final last = _parseDay(_extra['max']) ?? DateTime(2100, 12, 31);
    final now = DateTime.now();
    var initial = _date ?? DateTime(now.year, now.month, now.day);
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last.isBefore(first) ? first : last,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: Theme.of(context).colorScheme.copyWith(primary: style.accent, onPrimary: style.ink)),
        child: child!,
      ),
    );
    if (d != null && mounted) setState(() => _date = d);
  }

  Future<void> _pickTime(StepLook style) async {
    final t0 = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: Theme.of(context).colorScheme.copyWith(primary: style.accent, onPrimary: style.ink)),
        child: child!,
      ),
    );
    if (t0 != null && mounted) setState(() => _time = t0);
  }

  String get _value {
    final d = _date == null ? '' : dayKey(_date!);
    final tm = _time == null ? '' : '${_pad2(_time!.hour)}:${_pad2(_time!.minute)}';
    if (_mode == 'time') return tm;
    if (_mode == 'datetime') return d.isEmpty && tm.isEmpty ? '' : '${d}T$tm';
    return d;
  }

  Widget _field(StepLook style, {required Key key, required IconData icon, required String text, required bool empty, required VoidCallback onTap}) {
    final invalid = (widget.error ?? '').isNotEmpty;
    return Material(
      color: style.text.withOpacity(0.04),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: invalid ? const Color(0xFFD92D20) : style.text.withOpacity(0.22)),
      ),
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(10),
        onTap: _sent ? null : onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 42),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(text, style: TextStyle(fontSize: 15, color: empty ? style.muted.withOpacity(0.8) : style.text)),
                ),
                Icon(icon, size: 18, color: style.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = StepLook.of(context, widget.theme, widget.primaryColor);
    final label = t(_mode == 'time' ? 'dates.time' : (_mode == 'datetime' ? 'dates.dateTime' : 'dates.date'));
    final submit = '${_extra['submitLabel'] ?? ''}'.trim();
    final note = '${_extra['note'] ?? ''}';
    final date = _field(
      style,
      key: const ValueKey('dt-date'),
      icon: Icons.calendar_today_outlined,
      text: _date == null ? (_mode == 'datetime' ? t('dates.date') : t('sdk.datetime.chooseDate')) : _shownDate(_date!),
      empty: _date == null,
      onTap: () => _pickDate(style),
    );
    final time = _field(
      style,
      key: const ValueKey('dt-time'),
      icon: Icons.schedule,
      text: _time == null ? (_mode == 'datetime' ? t('dates.time') : t('sdk.datetime.chooseTime')) : '${_pad2(_time!.hour)}:${_pad2(_time!.minute)}',
      empty: _time == null,
      onTap: () => _pickTime(style),
    );
    return Padding(
      padding: stepIndent(widget.theme),
      child: StepCard(
        style: style,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            StepLabel(label, style: style),
            if (_mode == 'datetime')
              Row(children: [Expanded(flex: 3, child: date), const SizedBox(width: 8), Expanded(flex: 2, child: time)])
            else if (_mode == 'time')
              time
            else
              date,
            StepStatus(style: style, hint: note, error: widget.error),
            StepActions(children: [
              StepButton(
                key: const ValueKey('dt-go'),
                label: submit.isNotEmpty ? submit : t('common.send'),
                style: style,
                primary: true,
                onPressed: _sent
                    ? null
                    : () {
                        final v = _value;
                        setState(() => _sent = true);
                        widget.onResponse({'value': v, 'label': v});
                      },
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ==================== CALENDAR ====================

class CalendarStepWidget extends StatefulWidget {
  final ui_state.CalendarUIState state;
  final ValueChanged<dynamic> onResponse;
  final Color primaryColor;
  final ConferBotTheme theme;

  /// Today, for the grid's start and the greyed past (tests pass their own).
  final DateTime? today;

  const CalendarStepWidget({
    super.key,
    required this.state,
    required this.onResponse,
    required this.primaryColor,
    required this.theme,
    this.today,
  });

  @override
  State<CalendarStepWidget> createState() => _CalendarStepWidgetState();
}

class _CalendarStepWidgetState extends State<CalendarStepWidget> {
  late DateTime _month;
  DateTime? _day;
  bool _sent = false;

  DateTime get _today {
    final n = widget.today ?? DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  DateTime? get _min {
    final m = _parseDay(widget.state.extra['minDate']);
    if (m != null) return m;
    final d = widget.state.minDate;
    return d == null ? null : DateTime(d.year, d.month, d.day);
  }

  /// The picked day's times already booked.
  Set<String> get _booked => _day == null ? const {} : (widget.state.bookedSlots?[dayKey(_day!)] ?? const []).toSet();

  Map<String, List<String>>? get _slots => widget.state.showTimeSelection ? widget.state.availableSlots : null;

  @override
  void initState() {
    super.initState();
    final start = _min ?? _today;
    _month = DateTime(start.year, start.month);
  }

  bool _open(DateTime d) {
    final min = _min;
    if (min != null && d.isBefore(min)) return false;
    final max = widget.state.maxDate;
    if (max != null && d.isAfter(DateTime(max.year, max.month, max.day))) return false;
    if (widget.state.disabledDays?.contains(d.weekday % 7) ?? false) return false;
    final slots = _slots;
    if (slots != null) return (slots[dayKey(d)] ?? const []).isNotEmpty;
    return true;
  }

  void _tapDay(DateTime d) {
    if (_sent) return;
    if (_slots == null) {
      setState(() {
        _day = d;
        _sent = true;
      });
      widget.onResponse({'date': dayKey(d), 'label': _shownDate(d)});
      return;
    }
    setState(() => _day = d);
  }

  Widget _header(StepLook style) {
    final fg = inkOn(style.accent);
    Widget nav(IconData icon, String tip, Key key, int by) => Material(
          color: fg.withOpacity(0.15),
          shape: const CircleBorder(),
          child: InkWell(
            key: key,
            customBorder: const CircleBorder(),
            onTap: _sent ? null : () => setState(() => _month = DateTime(_month.year, _month.month + by)),
            child: Padding(padding: const EdgeInsets.all(6), child: Icon(icon, size: 20, color: fg, semanticLabel: tip)),
          ),
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: style.accent,
      child: Row(
        children: [
          nav(Icons.chevron_left, t('calendar.prevMonth'), const ValueKey('cal-prev'), -1),
          Expanded(
            child: Text('${I18n.monthNames('long', _months)[_month.month - 1]} ${_month.year}',
                key: const ValueKey('cal-title'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: fg)),
          ),
          nav(Icons.chevron_right, t('calendar.nextMonth'), const ValueKey('cal-next'), 1),
        ],
      ),
    );
  }

  Widget _grid(StepLook style) {
    final first = DateTime(_month.year, _month.month, 1);
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final lead = first.weekday % 7;
    final cells = ((lead + days) / 7).ceil() * 7;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(
        children: [
          Row(children: [
            for (final w in I18n.weekdayNames('short', _weekdaysShort))
              Expanded(child: Center(child: Text(w, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))))),
          ]),
          const SizedBox(height: 4),
          for (var r = 0; r < cells ~/ 7; r++)
            Row(children: [
              for (var c = 0; c < 7; c++)
                Expanded(child: _cell(style, r * 7 + c - lead + 1, days)),
            ]),
        ],
      ),
    );
  }

  Widget _cell(StepLook style, int n, int days) {
    if (n < 1 || n > days) return const SizedBox(height: 38);
    final d = DateTime(_month.year, _month.month, n);
    final open = _open(d);
    final picked = _day != null && dayKey(_day!) == dayKey(d);
    final today = dayKey(d) == dayKey(_today);
    final enabled = open && !_sent;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: AspectRatio(
        aspectRatio: 1,
        child: Material(
          color: picked ? style.accent : Colors.transparent,
          shape: CircleBorder(side: today && !picked ? BorderSide(color: style.accent.withOpacity(0.6)) : BorderSide.none),
          child: InkWell(
            key: ValueKey('cal-day-${dayKey(d)}'),
            customBorder: const CircleBorder(),
            onTap: enabled ? () => _tapDay(d) : null,
            child: Center(
              child: Text(
                '$n',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: picked || today ? FontWeight.w700 : FontWeight.w500,
                  color: picked
                      ? inkOn(style.accent)
                      : (open ? const Color(0xFF111827) : const Color(0xFF111827).withOpacity(0.28)),
                  decoration: open ? null : TextDecoration.lineThrough,
                  decorationColor: const Color(0x55111827),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = StepLook.of(context, widget.theme, widget.primaryColor);
    final slots = _day == null ? null : _slots?[dayKey(_day!)];
    return Padding(
      padding: stepIndent(widget.theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  // The grid is white on the web whatever the theme, under the bot's colour.
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: style.line),
                  boxShadow: const [BoxShadow(color: Color(0x140F172A), blurRadius: 6, offset: Offset(0, 2), spreadRadius: -2)],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [_header(style), _grid(style)]),
              ),
            ),
          ),
          if (slots != null) ...[
            const SizedBox(height: 10),
            Text(t('calendar.chooseSlot'), style: TextStyle(fontSize: 13, color: style.muted)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in slots)
                  // Already booked: shown greyed out, not pickable (web displayStep.ts calendar-node).
                  if (_booked.contains(s))
                    Semantics(
                      label: t('sdk.calendar.slotBooked', {'time': s}),
                      excludeSemantics: true,
                      child: StepOption(key: ValueKey('cal-slot-$s'), label: s, style: style, icon: Icons.event_busy, onPressed: null),
                    )
                  else
                    StepOption(
                      key: ValueKey('cal-slot-$s'),
                      label: s,
                      style: style,
                      icon: Icons.schedule,
                      onPressed: _sent
                          ? null
                          : () {
                              setState(() => _sent = true);
                              widget.onResponse({'date': dayKey(_day!), 'slot': s, 'label': '${_shownDate(_day!)} $s'});
                            },
                    ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
