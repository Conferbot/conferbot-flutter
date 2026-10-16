// Booked calendar slots (web displayStep.ts daySlotsFor, nodeLogic.ts
// isDayFullyBooked), the React Native SDK's AdvancedInputHandlers.test.ts
// "booked slots" cases ported: a taken slot shown booked and refused, a
// fully booked day not offered, the bot's bookings and the node's own, on
// the bot's clock, for this node only.
import 'package:conferbot_flutter/src/core/flow/calendar.dart';
import 'package:conferbot_flutter/src/core/flow/flow_context.dart';
import 'package:conferbot_flutter/src/core/nodes/node_handler.dart';
import 'package:conferbot_flutter/src/core/nodes/node_handler_registry.dart';
import 'package:conferbot_flutter/src/core/nodes/node_ui_state.dart';
import 'package:conferbot_flutter/src/core/state/chat_state.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 10, 15, 10);

FlowContext _ctx(List<dynamic> bookings) => FlowContext(
      botId: 'b1',
      sessionId: 's1',
      api: (path, body, {timeoutMs}) async => const ApiReply(ok: false, status: 0, error: 'network'),
      upload: (_) async => const UploadResult(ok: false),
      emit: (_, __) => true,
      on: (_, __) => () {},
      typing: (_) async {},
      delay: (_) async {},
      edges: () => const [],
      edgesOf: (_) => const [],
      wired: (_) => false,
      random: () => 0.5,
      now: () => _now,
      visitorTimeZone: 'UTC',
      calendarBookings: bookings,
      respond: (_) {},
      shown: () {},
      isStale: () => false,
      node: (_) => null,
    );

const _days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
final _data = <String, dynamic>{
  'timeZone': 'Asia/Dubai',
  'showTimeSelection': true,
  'slotDuration': 30,
  'weeklyHours': [
    for (final d in _days)
      {
        'dayName': d,
        'available': true,
        'slots': [
          {'start': '09:00', 'end': '10:00'},
        ],
      },
  ],
  'answerVariable': 'meeting',
};

/// A day [n] days ahead, on the bot's clock.
String _ahead(int n) => dayKeyInZone(_now.add(Duration(days: n)), 'Asia/Dubai');

Map<String, dynamic> _booking(String day, String slot, [Map<String, dynamic> extra = const {}]) =>
    {'date': '${day}T08:00:00.000Z', 'timeSlotSelected': slot, ...extra};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final handler = NodeHandlerRegistry.withAll().getHandler('calendar-node')!;
  final state = ChatState.instance;

  setUp(() {
    state.reset();
    state.initialize(chatSessionId: 's1', visitorId: 'v1', botId: 'b1');
  });

  test("shows a taken slot as booked and refuses it; another node's booking does not count", () async {
    final day = _ahead(3);
    final node = FlowNode(
      id: 'cal',
      type: 'calendar-node',
      data: _data,
      ctx: _ctx([_booking(day, '09:00 - 09:30'), _booking(day, '09:30 - 10:00', {'nodeId': 'other'})]),
    );
    final ui = ((await handler.handle(node, state)) as DisplayUIResult).uiState as CalendarUIState;
    expect(ui.availableSlots![day], ['09:00', '09:30']);
    expect(ui.bookedSlots![day], ['09:00']);
    expect(await handler.handleResponse({'date': day, 'slot': '09:00'}, node, state), isA<DisplayUIResult>());
    expect(state.getAnswer('meeting'), isNull);
    expect(await handler.handleResponse({'date': day, 'slot': '09:30'}, node, state), isNot(isA<DisplayUIResult>()));
  });

  test("leaves out a day with every slot taken (the node's own bookings count too)", () async {
    final day = _ahead(4);
    final node = FlowNode(
      id: 'cal',
      type: 'calendar-node',
      data: {
        ..._data,
        'bookings': [_booking(day, '09:30 - 10:00')],
      },
      ctx: _ctx([_booking(day, '09:00 - 09:30', {'nodeId': 'cal'})]),
    );
    final ui = ((await handler.handle(node, state)) as DisplayUIResult).uiState as CalendarUIState;
    expect(ui.availableSlots!.containsKey(day), isFalse);
    expect(ui.availableSlots!.containsKey(_ahead(5)), isTrue);
    expect(ui.bookedSlots, isNull);
  });

  test("reads bookings on the bot's clock, for this node only", () {
    final bookings = [
      {'date': '2026-11-02T21:30:00.000Z', 'timeSlotSelected': '09:00 - 09:30'}, // 01:30 on the 3rd in Dubai
      {'date': '2026-11-03T08:00:00.000Z', 'timeSlotSelected': '10:00 - 10:30', 'nodeId': 'cal'},
      {'date': '2026-11-03T08:00:00.000Z', 'timeSlotSelected': '11:00 - 11:30', 'nodeId': 'x'},
      null,
    ];
    expect(bookedLabels(bookings, 'cal', const {}, '2026-11-03', 'Asia/Dubai'), ['09:00 - 09:30', '10:00 - 10:30']);
    expect(bookedLabels(bookings, 'cal', const {}, '2026-11-02', 'UTC'), ['09:00 - 09:30']);
    expect(isDayFullyBooked(const [CalendarSlot(start: '09:00', end: '09:30')], ['09:00 - 09:30']), isTrue);
    expect(isDayFullyBooked(const [], const []), isFalse);
  });
}
