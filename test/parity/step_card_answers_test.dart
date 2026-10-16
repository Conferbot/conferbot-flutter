/// The visitor's answer to a step whose own card takes it (a date, a rating,
/// a scale, a slider, a picture) is the visitor's bubble, as on the web
/// (every answer shows as the visitor's message; RN #73 echoes them in
/// useFlowEngine.ts). This SDK's handlers say it themselves; here every
/// fixture with such a step is played and its visitor lines compared with
/// the web's transcript.
library;

import 'package:flutter_test/flutter_test.dart';

import 'flow_driver.dart';

/// Steps whose card takes the answer (RN ECHOED_STEPS).
const _echoed = {
  'calendar-node',
  'rating-choice-node',
  'opinion-scale-choice-node',
  'user-rating-node',
  'slider-node',
  'datetime-node',
  'image-choice-node',
};

/// Where the SDKs word it on purpose as one line (RN, iOS and this SDK's
/// CalendarHandler): a picked slot is one bubble in the visitor's own time,
/// "<date>, <from> - <to> (Your local time)", where the web's transcript
/// has the date and then "Selected time: <the bot's slot>".
const _oneLine = {'calendar.with-slots.json': ['Wednesday, October 21, 2026, 05:30 - 06:00 (Your local time)']};

List<String> _visitorLines(dynamic transcript) =>
    [for (final e in (transcript as List? ?? const [])) if (e is Map && e['by'] == 'user') '${e['message']}'];

void main() {
  final cases = [
    for (final c in fixtureIndex())
      if ((loadFixture('${c['file']}')['flow']['nodes'] as List).any((n) => _echoed.contains(n['type']))) '${c['file']}',
  ];

  test('there are fixtures with such steps', () => expect(cases.length, greaterThanOrEqualTo(7)));

  for (final file in cases) {
    test('$file: the answer is the visitor\'s bubble, in the web\'s words', () async {
      final fx = loadFixture(file);
      final want = _oneLine[file] ?? _visitorLines(fx['expect']['transcript']);
      expect(want, isNotEmpty);
      final got = await runFixture(fx);
      expect(_visitorLines(got.outcome['transcript']), want);
    });
  }
}
