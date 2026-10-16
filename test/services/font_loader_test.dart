// The chat's web font fetched and registered (lib/src/services/font_loader.dart;
// RN utils/fontLoader.ts, hooks/useChatFont.ts): Google Fonts' TrueType
// faces downloaded once and kept on the device, every upright weight in one
// "CB Font <family>", a failure leaving the platform font and tried again,
// and the chat's body and display families.
import 'dart:io';
import 'dart:typed_data';

import 'package:conferbot_flutter/src/core/customization/owner_font.dart';
import 'package:conferbot_flutter/src/services/font_loader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _css = '''
@font-face { font-family: 'Inter'; font-style: normal; font-weight: 400; src: url(https://fonts.test/a.ttf) format('truetype'); }
@font-face { font-family: 'Inter'; font-style: normal; font-weight: 700; src: url(https://fonts.test/b.ttf) format('truetype'); }
@font-face { font-family: 'Inter'; font-style: italic; font-weight: 400; src: url(https://fonts.test/c.ttf) format('truetype'); }
''';

void main() {
  late Directory dir;
  late List<String> fetched;
  late List<(String, int)> registered;
  var online = true;

  MockClient client() => MockClient((req) async {
        fetched.add(req.url.toString());
        if (!online) return http.Response('', 503);
        if (req.url.host == 'fonts.googleapis.com') return http.Response(_css, 200);
        return http.Response.bytes(Uint8List.fromList([1, 2, 3, req.url.path.codeUnitAt(1)]), 200);
      });

  ChatFontLoader loader() => ChatFontLoader(
        client: client(),
        cacheDir: () async => dir,
        register: (family, faces) async => registered.add((family, faces.length)),
      );

  setUp(() {
    dir = Directory.systemTemp.createTempSync('cb_fonts_');
    fetched = [];
    registered = [];
    online = true;
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('fetches the upright faces and registers them as one family', () async {
    final weights = await loader().load(const FontPick('Inter', 'Inter:wght@400;700'));
    expect(weights, [400, 700]);
    expect(fetched.first, 'https://fonts.googleapis.com/css2?family=Inter:wght@400;700&display=swap');
    expect(fetched, isNot(contains('https://fonts.test/c.ttf')));
    expect(registered, [('CB Font Inter', 2)]);
  });

  test('keeps the faces on the device: the next launch needs no network', () async {
    await loader().load(const FontPick('Inter', 'Inter:wght@400;700'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(dir.listSync().map((e) => e.uri.pathSegments.last).toSet(), {'Inter.json', 'Inter-400.ttf', 'Inter-700.ttf'});
    fetched.clear();
    online = false;
    expect(await loader().load(const FontPick('Inter', 'Inter:wght@400;700')), [400, 700]);
    expect(fetched, isEmpty);
  });

  test('offline: nothing registered, and a later try fetches again', () async {
    online = false;
    final l = loader();
    expect(await l.load(const FontPick('Inter', 'Inter')), isEmpty);
    expect(registered, isEmpty);
    online = true;
    expect(await l.load(const FontPick('Inter', 'Inter')), [400, 700]);
  });

  test('a system font, or none, loads nothing', () async {
    expect(await loader().load(const FontPick('Georgia', null)), isEmpty);
    expect(await loader().load(null), isEmpty);
    expect(fetched, isEmpty);
  });

  test("the chat's families: the owner's over the theme's, the platform font until loaded", () async {
    final font = ChatFont(loader: loader());
    var changes = 0;
    font.addListener(() => changes++);
    font.update('Inter', themeFont: 'Fraunces', themeFontRole: 'display');
    expect(font.body, isNull); // not loaded yet
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(font.body, 'CB Font Inter');
    expect(font.display, 'CB Font Inter');
    expect(changes, greaterThan(0));
    font.update('Georgia');
    expect(font.body, 'Georgia');
    font.update('', themeFont: 'Fraunces', themeFontRole: 'display');
    expect(font.body, isNull);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(font.display, 'CB Font Fraunces');
    font.dispose();
  });
}
