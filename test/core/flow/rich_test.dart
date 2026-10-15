import 'package:flutter_test/flutter_test.dart';
import 'package:conferbot_flutter/src/core/flow/rich.dart';

void main() {
  test('dynamicOptions reads labels, values, repeats and the cap', () {
    final opts = dynamicOptions(
      {'listPath': 'data.items', 'maxOptions': 2},
      '{"data":{"items":[{"name":"<b>A</b>","id":1},{"name":"A","id":1},"B",null,"C"]}}',
    );
    expect(opts.map((o) => o.label), ['A', 'B']);
    expect(opts.map((o) => o.value), [1, 'B']);
    expect(opts.map((o) => o.id), ['opt-0', 'opt-1']);
    expect(dynamicOptions({}, 'nope'), isEmpty);
    expect(dynamicOptions({}, ['x', 2, true]).map((o) => o.label), ['x', '2', 'true']);
  });

  test('sliderConfig and snapToStep', () {
    final c = sliderConfig({'min': 0, 'max': 50, 'step': 5, 'unit': 'people'});
    expect([c.min, c.max, c.step, c.start, c.unitPosition], [0, 50, 5, 25, 'suffix']);
    expect(snapToStep(0.33, min: 0, max: 1, step: 0.1), 0.3);
    expect(snapToStep(7, min: 0, max: 10, step: 5), 5);
    expect(sliderLabel(25, unit: 'people', unitPosition: 'suffix'), '25 people');
    expect(sliderConfig({'min': 10, 'max': 5}).max, 11);
  });

  test('dateTimeError and display', () {
    final today = DateTime.utc(2026, 10, 15);
    expect(dateTimeError({'minDate': 'today'}, '2026-10-14', today), 'Please pick a date on or after 2026-10-15.');
    expect(dateTimeError({'disabledWeekdays': [0, 6]}, '2026-10-18', today), "Sundays aren't available. Please pick another day.");
    expect(dateTimeError({}, '2026-02-30', today), 'Please pick a date.');
    expect(dateTimeError({'mode': 'time', 'minTime': '09:00'}, '08:00', today), 'Please pick a time from 09:00.');
    expect(dateTimeError({'maxDate': '+7'}, '2026-10-22', today), isNull);
    expect(dateTimeDisplay({}, '2026-10-19'), 'Oct 19, 2026');
    expect(dateTimeDisplay({'mode': 'time'}, '14:30'), '2:30 PM');
    expect(dateTimeDisplay({'mode': 'datetime'}, '2026-10-19T00:05'), 'Oct 19, 2026, 12:05 AM');
  });

  test('matrix helpers', () {
    final data = {
      'rows': [
        {'id': 'r1', 'text': 'Speed'},
        {'id': 'r2', 'text': 'Price'},
      ],
      'columns': [
        {'id': 'c1', 'text': 'Good'},
        {'id': 'c2', 'text': 'Fair'},
      ],
    };
    final rows = matrixRows(data);
    final cols = matrixColumns(data);
    var sel = matrixToggle({}, 'r1', 'c1', 'single');
    expect(matrixError(sel, rows, true), 'Answer every row - 1 left');
    expect(matrixError(sel, rows, false), '');
    sel = matrixToggle(sel, 'r2', 'c2', 'multiple');
    sel = matrixToggle(sel, 'r2', 'c1', 'multiple');
    final value = matrixValue(sel, rows, cols, 'multiple');
    expect(value, {
      'Speed': ['Good'],
      'Price': ['Good', 'Fair'],
    });
    expect(matrixDisplay(matrixValue(sel, rows, cols, 'single')), 'Speed: Good · Price: Good');
    expect(matrixProgress(sel, rows), '2 of 2 answered');
  });

  test('paymentAmountText in en-US', () {
    expect(paymentAmountText(2500, 'usd'), r'$25.00');
    expect(paymentAmountText(1250, 'USD'), r'$12.50');
    expect(paymentAmountText(999, 'eur'), '€9.99');
    expect(paymentAmountText(500, 'jpy'), '¥500');
    expect(paymentAmountText(123456789, 'usd'), r'$1,234,567.89');
    expect(paymentAmountText(2500, 'aed'), 'AED 25.00');
    expect(paymentAmountText(2500, 'xx'), '');
    expect(paymentMinorOf('19.99', 'usd'), 1999);
  });

  test('ai route variables and results', () {
    final r = aiRouteResultOf({'intentId': 'i1', 'intent': 'billing', 'confidence': 0.876});
    expect(aiRouteVariables({'answerVariable': 'topic'}, r), {'topic': 'billing', 'topic_confidence': 0.88});
    final none = aiRouteResultOf({'fallback': true, 'confidence': 0.2});
    expect(none.fallback, isTrue);
    expect(none.error, 'no_match');
    expect(aiRouteVariables({'answerVariable': 'topic'}, none), {'topic': '', 'topic_confidence': 0.2});
    expect(aiRouteResultOf(null, 'network').error, 'network');
  });

  test('kbResultOf keeps safe sources', () {
    final r = kbResultOf(
      {'maxSources': 1},
      {
        'found': true,
        'answer': '<p>Reset it in settings.</p>',
        'sources': [
          {'title': '', 'url': 'javascript:x'},
          {'title': '', 'url': 'https://help.example/a'},
          {'title': 'Other', 'url': 'https://help.example/b'},
        ],
      },
    );
    expect(r.found, isTrue);
    expect(r.answer, 'Reset it in settings.');
    expect(r.sources.map((s) => s.toJson()), [
      {'title': 'help.example/a', 'url': 'https://help.example/a', 'type': 'page'},
    ]);
    expect(kbResultOf({}, {'found': false}).error, 'not_found');
    expect(kbVariables({'answerVariable': 'kb'}, r)['kb_sources'], [
      {'title': 'help.example/a', 'url': 'https://help.example/a'},
    ]);
  });

  test('otpErrorText', () {
    expect(otpErrorText('wrong_code', {'attemptsLeft': 1}), "That code isn't right. 1 try left.");
    expect(otpErrorText('wrong_code', {'attemptsLeft': 3}), "That code isn't right. 3 tries left.");
    expect(otpErrorText('wrong_code'), "That code isn't right.");
    expect(otpErrorText('resend_wait'), 'Please wait 30 seconds before asking for a new code.');
    expect(otpErrorText('invalid_code'), 'Enter all 6 digits.');
    expect(otpErrorText('zzz'), 'Something went wrong. Please try again.');
  });

  test('normalizeAddress and formatAddress', () {
    final a = normalizeAddress({'line1': ' 12  Main St ', 'city': 'Dubai', 'region': 'Dubai', 'postal': '00000', 'country': 'UAE', 'countryCode': 'AE', 'lat': '25.1', 'lng': 200});
    expect(a.formatted, '12 Main St, Dubai, 00000, UAE');
    expect(a.countryCode, 'ae');
    expect(a.lat, isNull);
    expect(addressVariables('addr', a), {
      'addr': '12 Main St, Dubai, 00000, UAE',
      'addr_line1': '12 Main St',
      'addr_city': 'Dubai',
      'addr_region': 'Dubai',
      'addr_postal': '00000',
      'addr_country': 'UAE',
      'addr_country_code': 'ae',
    });
    expect(manualAddress({'city': 'X'}), isNull);
    expect(formatAddress({'line1': 'A', 'city': 'B', 'region': 'C', 'postal': '1'}), 'A, B, C 1');
  });
}
