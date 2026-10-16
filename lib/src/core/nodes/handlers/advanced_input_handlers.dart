/// calendar-node and ask-multiple-questions-node (React Native
/// src/core/nodes/handlers/AdvancedInputHandlers.ts), per the flow-node
/// spec and the web widget (ts/chat/displayStep.ts calendar-node,
/// handlers/askQuestions.ts _handleAskMultipleQuestions*).
library;

import '../../flow/calendar.dart';
import '../../flow/inputs.dart' show en, isValidEmail, isValidPhone, normalizePhone, ownerTextOr, phoneErrorText;
import '../../flow/js.dart' show jsIsoString, jsNumber, jsString;
import '../../flow/text.dart' show fillVariables;
import '../../state/chat_state.dart';
import '../node_handler.dart';
import '../node_ui_state.dart';
import 'flow_kit.dart';

/// Days offered ahead of today.
const int _calendarDays = 90;

/// calendar-node: a month calendar on the bot's clock (data.timeZone,
/// default UTC). Without time selection the picked day is saved as the
/// visitor's long date ("Tuesday, October 20, 2026"); with it, the day's
/// weeklyHours cut into slotDuration slots, and the saved value names both
/// clocks. Moves on 400 ms after the pick. Answer: {date: "YYYY-MM-DD",
/// slot?: "HH:MM"} (slot start on the bot's clock; `time` is read the same).
class CalendarHandler extends BaseNodeHandler {
  @override
  String get nodeType => 'calendar-node';

  String _zone(Map<String, dynamic> data) {
    final z = data['timeZone'];
    return z == null || z == '' ? 'UTC' : jsString(z);
  }

  /// A day's bookable slots on the bot's clock.
  List<CalendarSlot> _slotsFor(Map<String, dynamic> data, String dayKey, DateTime now) {
    final zone = _zone(data);
    final dayName = dayNameInZone(noonInZone(dayKey, zone), zone);
    final weekly = data['weeklyHours'] is List ? data['weeklyHours'] as List : const [];
    Map? schedule;
    for (final d in weekly) {
      if (d is Map && d['dayName'] == dayName) {
        schedule = d;
        break;
      }
    }
    final available = schedule?['available'];
    if (available == null || available == false || available == 0 || available == '') return const [];
    return futureSlots(expandSlots(schedule!['slots'], data['slotDuration'], data['bufferMinutes']), dayKey, zone, now);
  }

  bool _dayOpen(Map<String, dynamic> data, String dayKey) {
    final zone = _zone(data);
    final dayName = dayNameInZone(noonInZone(dayKey, zone), zone);
    final excludedDays =
        (data['excludeDays'] is List ? data['excludeDays'] as List : const []).map((d) => jsString(d).toLowerCase()).toList();
    final excludedDates = (data['excludeDates'] is List ? data['excludeDates'] as List : const []).map(jsString).toList();
    return !excludedDays.contains(dayName.toLowerCase()) && !excludedDates.contains(dayKey);
  }

  /// The day's taken slots ("HH:MM - HH:MM", bot's clock): the bot's
  /// bookings and the node's own (web displayStep.ts daySlotsFor).
  List<String> _booked(FlowNode node, String dayKey) =>
      bookedLabels(node.ctx.calendarBookings, node.id, node.data, dayKey, _zone(node.data));

  CalendarUIState _ui(FlowNode node, ChatState state) {
    final data = node.data;
    final zone = _zone(data);
    final now = node.ctx.now();
    final today = dayKeyInZone(now, zone);
    final showTime = data['showTimeSelection'] != null &&
        data['showTimeSelection'] != false &&
        data['showTimeSelection'] != 0 &&
        data['showTimeSelection'] != '';
    final availableSlots = <String, List<String>>{};
    final bookedSlots = <String, List<String>>{};
    if (showTime) {
      final base = noonInZone(today, zone);
      for (var i = 0; i < _calendarDays; i++) {
        final key = dayKeyInZone(base.add(Duration(days: i)), zone);
        if (!_dayOpen(data, key)) continue;
        final slots = _slotsFor(data, key, now);
        final booked = _booked(node, key);
        // Every slot taken: the day is not offered (web: greyed out as "fully booked").
        if (slots.isEmpty || isDayFullyBooked(slots, booked)) continue;
        availableSlots[key] = slots.map((s) => s.start).toList();
        final taken = slots.where((s) => booked.contains(slotLabel(s))).map((s) => s.start).toList();
        if (taken.isNotEmpty) bookedSlots[key] = taken;
      }
    }
    final showPast = data['showPastDates'] == true;
    return CalendarUIState(
      questionText: shownText(state, data['calendarPrompt']),
      showTimeSelection: showTime,
      mode: showTime ? 'datetime' : 'date',
      minDate: showPast ? null : DateTime.tryParse('${today}T00:00:00Z'),
      timezone: zone,
      answerKey: data['answerVariable']?.toString(),
      availableSlots: showTime ? availableSlots : null,
      bookedSlots: showTime && bookedSlots.isNotEmpty ? bookedSlots : null,
      extra: {if (!showPast) 'minDate': today},
      nodeId: node.id,
    );
  }

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final u = _ui(node, state);
    botSay(state, u.questionText ?? '', node.id, nodeType);
    return NodeResult.displayUI(u);
  }

  @override
  Future<NodeResult> handleResponse(dynamic response, FlowNode node, ChatState state) async {
    final data = node.data;
    final r = response is Map ? response : const {};
    final botZone = _zone(data);
    final visitorZone = node.ctx.visitorTimeZone.isNotEmpty ? node.ctx.visitorTimeZone : visitorTimeZone();
    final rawDate = _firstTruthy([r['date'], r['selectedDate']]) ?? '';
    final dateString = rawDate.length > 10 ? rawDate.substring(0, 10) : rawDate;
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateString)) return NodeResult.displayUI(_ui(node, state));

    final showTime = data['showTimeSelection'] != null &&
        data['showTimeSelection'] != false &&
        data['showTimeSelection'] != 0 &&
        data['showTimeSelection'] != '';
    final slotStart = (_firstTruthy([r['slot'], r['time']]) ?? '').trim();
    final ctx = node.ctx;

    String value;
    Map<String, dynamic> record;
    if (!showTime) {
      final botDate = noonInZone(dateString, botZone);
      final visitorDate = noonInZone(dateString, visitorZone);
      final date = longDate(botDate, botZone);
      final localDate = longDate(visitorDate, visitorZone, visitorLocale());
      final shown = localDate.isNotEmpty ? localDate : date;
      record = {
        'date': shown,
        'selectedDate': dateString,
        'botTimeZone': botZone,
        'visitorTimeZone': visitorZone,
        'showTimeSelection': false,
      };
      value = shown;
      userSay(state, value, node.id);
    } else {
      final slots = _slotsFor(data, dateString, ctx.now());
      CalendarSlot? slot;
      for (final s in slots) {
        if (s.start == slotStart) {
          slot = s;
          break;
        }
      }
      // A taken slot cannot be booked again (web: its button is disabled).
      if (slot == null || _booked(node, dateString).contains(slotLabel(slot))) return NodeResult.displayUI(_ui(node, state));
      final botDate = noonInZone(dateString, botZone);
      final visitorDate = noonInZone(dayKeyInZone(botDate, botZone), visitorZone);
      final date = longDate(botDate, botZone);
      final localDate = longDate(visitorDate, visitorZone, visitorLocale());
      final visitorStart = hhmmInZone(wallTimeInZone(dateString, slot.start, botZone), visitorZone);
      final visitorEnd = hhmmInZone(wallTimeInZone(dateString, slot.end, botZone), visitorZone);
      final timeSlotSelected = slotLabel(slot);
      final visitorTime = '$visitorStart - $visitorEnd';
      final shown = localDate.isNotEmpty ? localDate : date;
      record = {
        'date': shown,
        'selectedDate': jsIsoString(botDate),
        'botTimeZone': botZone,
        'visitorTimeZone': visitorZone,
        'showTimeSelection': true,
        'timeSlotSelected': timeSlotSelected,
        'visitorTime': visitorTime,
      };
      value = "$shown $visitorTime (Visitor's local time) / $timeSlotSelected (Bot's time)";
      userSay(state, '$localDate, $visitorTime (Your local time)', node.id);
      final visitor = state.getVariable('_visitorId');
      ctx.emit('calendar-slot-selection-record', {
        'visitorId': visitor != null && visitor != '' ? visitor : (state.visitorId ?? state.chatSessionId),
        'chatbotId': state.botId,
        'nodeId': node.id,
        'selectedDate': record['selectedDate'],
        'botTimeZone': botZone,
        'visitorTimeZone': visitorZone,
        'timeSlotSelected': timeSlotSelected,
        'visitorTime': visitorTime,
      });
    }
    pushAnswer(state, {'id': node.id, 'shape': 'user-calendar-selection', 'data': record}, ctx.now());
    state.setAnswerVariable(node.id, value);
    return NodeResult.delayedProceed(null, 400);
  }
}

/// ask-multiple-questions-node: data.message, then each of data.questions
/// in turn after 2000 ms of typing. An "email" answer is checked as an
/// e-mail, "phone" / "mobile" as a phone (saved normalised). Each answer
/// fills the variable registered as nodeId + index and is recorded as
/// "<nodeId>:<questionId>". After the last one, the first edge.
class MultipleQuestionsHandler extends BaseNodeHandler {
  @override
  String get nodeType => 'ask-multiple-questions-node';

  List<Map<String, dynamic>> _questions(FlowNode node) {
    final q = node.data['questions'];
    if (q is! List) return const [];
    return q.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}).toList();
  }

  String _indexKey(FlowNode node) => '_mq_${node.id}';

  Map<String, dynamic> _q(FlowNode node, int index) {
    final qs = _questions(node);
    return index >= 0 && index < qs.length ? qs[index] : <String, dynamic>{};
  }

  TextInputUIState _ui(FlowNode node, ChatState state, int index) {
    final q = _q(node, index);
    final variable = (q['answerVariable'] ?? '').toString().toLowerCase();
    final inputType = variable == 'email'
        ? TextInputType.email
        : variable == 'phone' || variable == 'mobile'
            ? TextInputType.phone
            : TextInputType.text;
    return TextInputUIState(
      questionText: shownText(state, q['questionText']),
      inputType: inputType,
      answerKey: (q['answerVariable'] ?? '').toString(),
      nodeId: node.id,
    );
  }

  /// Ask question `index` (2000 ms of typing first).
  Future<NodeResult> _ask(FlowNode node, ChatState state, int index) async {
    final questions = _questions(node);
    final q = _q(node, index);
    await node.ctx.typing(2000);
    state.setVariable(_indexKey(node), index);
    final label = questions.length > 1 ? 'Question ${index + 1} of ${questions.length}\n' : '';
    botSay(state, '$label${shownText(state, q['questionText'])}', node.id, nodeType);
    final qid = q['id'] ?? index;
    state.addRecord({
      '_id': '${node.id}:${jsString(qid)}',
      'id': '${node.id}:${jsString(qid)}',
      'nodeId': node.id,
      'questionId': q['id'] ?? '$index',
      'answerVariable': q['answerVariable'],
      'shape': 'ask-multiple-questions-question',
      'type': 'ask-multiple-questions-question',
      'questionText': q['questionText'],
      'renderedText': fillVariables(q['questionText'], state.lookupVariable),
      'time': jsIsoString(node.ctx.now()),
    });
    return NodeResult.displayUI(_ui(node, state, index), awaitInput: true);
  }

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final message = shownText(state, node.data['message']);
    if (message.isNotEmpty) botSay(state, message, node.id, nodeType);
    node.ctx.shown();
    if (_questions(node).isEmpty) return NodeResult.next();
    return _ask(node, state, 0);
  }

  @override
  Future<NodeResult> handleResponse(dynamic response, FlowNode node, ChatState state) async {
    final questions = _questions(node);
    final stored = jsNumber(state.getVariable(_indexKey(node)) ?? 0);
    final index = stored.isFinite ? stored.toInt() : 0;
    final q = _q(node, index);
    var value = typedText(response);
    if (value.isEmpty) return NodeResult.displayUI(_ui(node, state, index), awaitInput: true);
    final variable = (q['answerVariable'] ?? '').toString();
    if (variable == 'email' && !isValidEmail(value)) {
      return NodeResult.invalid(
        ownerTextOr(node.data['incorrectEmailResponse'], en.emailInvalid, const ['Please enter a valid email']),
        uiState: _ui(node, state, index),
      );
    }
    if (variable == 'mobile' || variable == 'phone') {
      if (!isValidPhone(value)) return NodeResult.invalid(phoneErrorText(node.data), uiState: _ui(node, state, index));
      value = normalizePhone(value);
    }
    if (variable == 'name') state.setUserName(value);
    if (variable == 'email') state.setUserEmail(value);
    if (variable == 'phone' || variable == 'mobile') state.setUserPhone(value);

    final qid = q['id'] ?? index;
    pushAnswer(
      state,
      {
        'id': '${node.id}:${jsString(qid)}',
        'nodeId': node.id,
        'questionId': q['id'] ?? '$index',
        'answerVariable': q['answerVariable'],
        'shape': 'user-ask-multiple-questions-question-response',
        'type': 'user-ask-multiple-questions-question-response',
        'text': value,
      },
      node.ctx.now(),
    );
    state.setAnswerVariable('${node.id}$index', value);
    userSay(state, value, node.id);

    if (index + 1 < questions.length) return _ask(node, state, index + 1);
    state.deleteVariable(_indexKey(node));
    return NodeResult.next();
  }
}

String? _firstTruthy(List<dynamic> values) {
  for (final v in values) {
    if (v != null && v != '' && v != false && v != 0) return jsString(v);
  }
  return null;
}

/// The calendar and multiple-question steps.
final List<NodeHandler> advancedInputHandlers = [CalendarHandler(), MultipleQuestionsHandler()];
