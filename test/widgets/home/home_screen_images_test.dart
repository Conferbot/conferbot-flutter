// Images of the home screen (lib/src/widgets/home/home_screen_view.dart):
// HOME_IMAGES_DIR=/abs/dir flutter test --update-goldens test/widgets/home/home_screen_images_test.dart
// writes one PNG per case (a 390 x 844 screen) to that directory, outside
// the repo. Roboto from the Flutter SDK; the logos, faces and covers are
// drawn here (no network in tests). Without the variable the group is skipped.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:conferbot_flutter/src/core/home/home.dart';
import 'package:conferbot_flutter/src/core/requests/requests.dart';
import 'package:conferbot_flutter/src/widgets/home/home_screen_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show debugDisableShadows;
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';

const now = 1800000000000;

Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? '';
  final loader = FontLoader('Roboto');
  for (final w in ['Regular', 'Medium', 'Bold']) {
    final f = File('$root/bin/cache/artifacts/material_fonts/Roboto-$w.ttf');
    if (f.existsSync()) loader.addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
  }
  await loader.load();
}

/// A drawn image: a face (a circle on a colour) or a wordmark-like bar.
Future<Uint8List> _png(Color bg, {bool face = false, int w = 96, int h = 96}) async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  if (face) {
    c.drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..color = bg);
    c.drawCircle(Offset(w / 2, h * 0.4), w * 0.18, Paint()..color = const Color(0xFFFDE68A));
    c.drawOval(Rect.fromCenter(center: Offset(w / 2, h * 0.95), width: w * 0.7, height: h * 0.6), Paint()..color = const Color(0xFFFDE68A));
  } else {
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, h * 0.3, w * 0.25, h * 0.4), const Radius.circular(6)), Paint()..color = bg);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.32, h * 0.38, w * 0.66, h * 0.24), const Radius.circular(4)), Paint()..color = bg);
  }
  final img = await rec.endRecording().toImage(w, h);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

final cats = [
  {
    '_id': 'c1',
    'name': 'Billing',
    'articles': [
      {'_id': '3', 'title': 'Changing your plan', 'description': 'Upgrade, downgrade or cancel at any time.'},
      {'_id': '4', 'title': 'Downloading invoices', 'description': 'Find every invoice in one place.'},
    ],
  },
  {
    '_id': 'c2',
    'name': 'Getting started',
    'articles': [
      {'_id': '1', 'title': 'How to build your first bot', 'description': 'A step by step guide.'},
    ],
  },
];
final recent = [
  {'_id': '2', 'title': 'Embedding the widget on your website', 'description': 'Copy one script tag into your site.'},
  {'_id': '5', 'title': 'Connecting WhatsApp', 'description': 'Answer WhatsApp messages from the same inbox.', 'coverImage': 'https://img/cover.png'},
];

RequestSummary _req(String id, String title, int at, String from, {String status = 'open'}) => RequestSummary(
    id: id, title: title, status: status, lastFrom: from, lastAt: DateTime.fromMillisecondsSinceEpoch(at).toIso8601String(), lastText: '', teamName: 'Ada');

Map<String, dynamic> _base(Map<String, dynamic> extra) => {
      'enableInitialPage': true,
      'logo': 'https://img/logo.png',
      'logoText': 'Acme',
      'initialPageTitle': 'Hi Sam 👋',
      'initialPageDescription': 'Questions about your order, billing or setup? Ask away.',
      'widgetIconThemeType': 'Gradient',
      'widgetGradientBgOne': '#0808EE',
      'widgetGradientBgTwo': '#6366F1',
      'replyTime': {'mode': 'auto', 'handover': true, 'state': 'online', 'bucket': 'few_minutes'},
      ...extra,
    };

void main() {
  final dir = Platform.environment['HOME_IMAGES_DIR'];

  group('home screen images', () {
    late Map<String, Uint8List> images;
    setUpAll(_loadFonts);

    final cases = <String, (HomeModel, HomePalette)>{
      'flow-bot-help-centre': (
        homeModel(
          c: _base({
            'enableKnowledgeBase': true,
            'homeTeamPhotos': ['https://img/f1.png', 'https://img/f2.png', 'https://img/f3.png'],
            'homeRating': {'average': 4.83, 'count': 1320},
            'homeTrustLogos': ['https://img/l1.png', 'https://img/l2.png', 'https://img/l3.png'],
            'homeTrustLabel': 'Trusted by 2,000+ teams',
          }),
          botName: 'Acme',
          categories: cats,
          recentArticles: recent,
          requests: [_req('a', 'Refund for order #1042', now - 3 * 3600000, 'you'), _req('b', 'Invoice address', now - 26 * 3600000, 'team', status: 'solved')],
          seen: {'b': now},
          now: now,
          hour: 10,
        )!,
        classicHomePalette
      ),
      'agent-welcome-back-new-reply': (
        homeModel(
          c: _base({'initialPageTitle': 'How can we help?'}),
          agent: const HomeAgent(displayName: 'Ava', starters: ['What does Pro cost?', 'Do you integrate with Shopify?', 'How do refunds work?']),
          memory: const VisitorMemory(at: now - 2 * 3600000, name: 'Jamie', topic: 'Do you support Shopify stores?', session: 's1'),
          chatSessionId: 's1',
          requests: [_req('a', 'Refund for order #1042', now - 20 * 60000, 'team'), _req('b', 'Invoice address', now - 3 * 3600000, 'you')],
          now: now,
        )!,
        classicHomePalette
      ),
      'dark-theme-ask-off-hidden-status': (
        homeModel(
          c: _base({
            'enableKnowledgeBase': true,
            'homeAskBox': false,
            'hideRecentArticles': true,
            'hideOnlineStatus': true,
            'widgetIconThemeType': 'Solid',
            'widgetIconBgColor': '#0EA5E9',
            'initialPageCardTagline': 'Mon-Fri, 9-5',
          }),
          categories: cats,
          now: now,
          hour: 20,
        )!,
        homePalette(bg2: '#101014', card: '#18181d', card2: '#222228', ink: '#f4f4f5', muted: '#a1a1aa', line: '#2a2a31')
      ),
    };

    for (final e in cases.entries) {
      testWidgets(e.key, (tester) async {
        await tester.runAsync(() async {
          images = {
            'https://img/logo.png': await _png(const Color(0xFFFFFFFF)),
            'https://img/f1.png': await _png(const Color(0xFF6366F1), face: true),
            'https://img/f2.png': await _png(const Color(0xFF0EA5E9), face: true),
            'https://img/f3.png': await _png(const Color(0xFFF97316), face: true),
            'https://img/cover.png': await _png(const Color(0xFF22C55E), face: true),
            'https://img/l1.png': await _png(const Color(0xFF334155), w: 176, h: 44),
            'https://img/l2.png': await _png(const Color(0xFF334155), w: 176, h: 44),
            'https://img/l3.png': await _png(const Color(0xFF334155), w: 176, h: 44),
          };
          // The card's face: the Conferbot logo URL, drawn here too.
          images[e.value.$1.talk.avatar] = await _png(const Color(0xFF0808EE), face: true);
        });
        // Soft shadows as on a device (tests draw them unblurred by default).
        debugDisableShadows = false;
        tester.view.physicalSize = const Size(780, 1688);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        await tester.pumpWidget(MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Roboto'),
          home: RepaintBoundary(
            key: key,
            child: HomeScreenView(
              model: e.value.$1,
              palette: e.value.$2,
              fontFamily: 'Roboto',
              onClose: () {},
              onShowChat: ([_]) {},
              onOpenArticle: (_) {},
              onShowHelp: ([_]) {},
              onOpenRequests: ([_]) {},
              imageFor: (url) => MemoryImage(images[url] ?? images['https://img/logo.png']!),
            ),
          ),
        ));
        for (final el in find.byType(Image).evaluate()) {
          await tester.runAsync(() => precacheImage((el.widget as Image).image, el));
        }
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        try {
          await expectLater(find.byKey(key), matchesGoldenFile(Uri.file('$dir/${e.key}.png')));
        } finally {
          // Put back before the test ends (the binding checks it).
          debugDisableShadows = true;
        }
      });
    }
  }, skip: dir == null || dir.isEmpty);
}
