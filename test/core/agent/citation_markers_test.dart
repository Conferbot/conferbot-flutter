// Placeholder citation markers in AI answers (#104), the cases of
// embed-server utils/citationMarkers.js stripPlaceholderMarkers.
import 'package:conferbot_flutter/src/core/agent/citation_markers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('placeholders go, with the space before them', () {
    expect(stripPlaceholderMarkers('Wie Sie zit. [n] Als Kunde'), 'Wie Sie zit. Als Kunde');
    expect(stripPlaceholderMarkers('zit. [n] Als'), 'zit. Als');
    expect(stripPlaceholderMarkers('Plans start at \$9 [1, n].'), 'Plans start at \$9.');
    expect(stripPlaceholderMarkers('Yes [N].'), 'Yes.');
    expect(stripPlaceholderMarkers('See the guide [source].'), 'See the guide.');
    expect(stripPlaceholderMarkers('Open daily [web:2], weekends too'), 'Open daily, weekends too');
  });

  test('numbers, words, links and checkboxes stay', () {
    expect(stripPlaceholderMarkers('[Klik hier]'), '[Klik hier]');
    expect(stripPlaceholderMarkers('See step [2].'), 'See step [2].');
    expect(stripPlaceholderMarkers('[n](https://x)'), '[n](https://x)');
    expect(stripPlaceholderMarkers('- [x] done'), '- [x] done');
    expect(stripPlaceholderMarkers('Nothing here . really'), 'Nothing here . really');
  });
}
