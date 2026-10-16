// The home screen in the chat, with the real provider: greet by name filled
// before anything reads the settings (and again on identify, #78), the chat
// opening on the home only while the owner has one, Talk to us to the
// conversation, the header's back and the system back to the home, the help
// centre from the home and back, a greeting card's send going past the home.
import 'dart:io';

import 'package:conferbot_flutter/src/core/home/home.dart';
import 'package:conferbot_flutter/src/models/user.dart';
import 'package:conferbot_flutter/src/core/state/chat_state.dart';
import 'package:conferbot_flutter/src/providers/conferbot_provider.dart';
import 'package:conferbot_flutter/src/services/storage_service.dart';
import 'package:conferbot_flutter/src/widgets/chat_widget.dart';
import 'package:conferbot_flutter/src/widgets/knowledge_base/knowledge_base_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TempPaths extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _TempPaths(this.dir);
  final String dir;
  @override
  Future<String?> getApplicationDocumentsPath() async => dir;
  @override
  Future<String?> getApplicationSupportPath() async => dir;
  @override
  Future<String?> getTemporaryPath() async => dir;
}

Map<String, dynamic> _customizations(Map<String, dynamic> extra) => {
      'enableInitialPage': true,
      'logoText': 'Acme',
      'initialPageTitle': 'Hi {{first_name|there}} 👋',
      'chatIconCtaText': 'Hey {{first_name|you}}',
      'greetingRules': [
        {'text': 'Hi {{name|there}}, need a hand?'},
      ],
      ...extra,
    };

Map<String, dynamic> _payload(Map<String, dynamic> c) => {
      'chatbotData': {
        'elements': [
          {'nodes': [], 'edges': []},
        ],
        'customizations': c,
      },
      'knowledgeBaseData': {
        'categories': [
          {
            '_id': 'c1',
            'name': 'Billing',
            'articles': [
              {'_id': 'a1', 'title': 'Changing your plan', 'description': 'Upgrade or cancel.'},
            ],
          },
        ],
        'recentArticles': [],
      },
    };

ConferBotProvider _provider({Map<String, dynamic> extra = const {}, ConferBotUser? user}) {
  final p = ConferBotProvider(apiKey: 'k', botId: 'home-bot', config: const ConferBotConfig(autoConnect: false), user: user);
  p.debugHandleChatbotData(_payload(_customizations(extra)));
  return p;
}

Future<void> _pumpChat(WidgetTester tester, ConferBotProvider p) async {
  await tester.pumpWidget(MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(size: Size(390, 844), disableAnimations: true),
      child: ChangeNotifierProvider.value(value: p, child: const ChatWidget()),
    ),
  ));
  await tester.pump();
  _drain(tester);
}

/// The chat's own start-up (no network in tests) reports errors that have
/// nothing to do with the home screen; they are dropped here.
void _drain(WidgetTester tester) {
  while (tester.takeException() != null) {}
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(minutes: 1));
  }
  _drain(tester);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    PathProviderPlatform.instance = _TempPaths(Directory.systemTemp.createTempSync('cb_home_').path);
    await StorageService.init();
  });

  tearDown(() => ChatState.instance.visitorContext = null);

  group('greet by name (#78)', () {
    test("the owner's texts are filled before anything reads them: home, greeting card, launcher", () {
      final p = _provider(user: const ConferBotUser(id: 'u1', name: 'Ada Lovelace'));
      final c = p.serverCustomizations!;
      expect(c['initialPageTitle'], 'Hi Ada 👋');
      expect(c['chatIconCtaText'], 'Hey Ada');
      expect((c['greetingRules'] as List).first['text'], 'Hi Ada Lovelace, need a hand?');
      expect(p.homeModel!.title, 'Hi Ada 👋');
      p.dispose();
    });

    test('nobody signed in: the fallback; identify fills it again, sign-out puts it back', () {
      final p = _provider();
      expect(p.homeModel!.title, 'Hi there 👋');
      expect(p.serverCustomizations!['chatIconCtaText'], 'Hey you');
      p.identify(const ConferBotUser(id: 'u2', metadata: {'firstName': 'Bob'}));
      expect(p.homeModel!.title, 'Hi Bob 👋');
      expect((p.serverCustomizations!['greetingRules'] as List).first['text'], 'Hi Bob, need a hand?');
      p.identify(null);
      expect(p.homeModel!.title, 'Hi there 👋');
      p.dispose();
    });
  });

  group('the home screen in the chat', () {
    testWidgets('opens on the home; Talk to us, the header back and the system back', (tester) async {
      final p = _provider();
      await _pumpChat(tester, p);
      expect(find.byKey(const ValueKey('cb-home')), findsOneWidget);
      expect(find.text('Hi there 👋'), findsOneWidget);
      expect(find.byType(ChatHeaderWithKB), findsNothing);

      await tester.tap(find.byKey(const ValueKey('cb-home-talk-button')));
      await tester.pump();
      _drain(tester);
      expect(p.home.view, HomeView.chat);
      expect(find.byType(ChatHeaderWithKB), findsOneWidget);
      expect(find.byKey(const ValueKey('cb-home')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('cb-header-back')));
      await tester.pump();
      expect(p.home.view, HomeView.home);
      expect(find.byKey(const ValueKey('cb-home')), findsOneWidget);

      // Android's back: the conversation goes to the home.
      p.home.showChat();
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(p.home.view, HomeView.home);

      await _finish(tester);
      p.dispose();
    });

    testWidgets('the help centre from the home (See all, a topic), Back returns to the home', (tester) async {
      final p = _provider(extra: {'enableKnowledgeBase': true});
      await _pumpChat(tester, p);
      expect(find.byKey(const ValueKey('cb-home-help')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('cb-home-topic-c1')));
      await tester.pump();
      await tester.pump();
      _drain(tester);
      expect(p.home.view, HomeView.help);
      expect(find.byType(KnowledgeBaseScreen), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump();
      _drain(tester);
      // A topic: back to its list, then to the home.
      if (p.home.view == HomeView.help) {
        await tester.binding.handlePopRoute();
        await tester.pump();
      }
      expect(p.home.view, HomeView.home);
      expect(find.byKey(const ValueKey('cb-home')), findsOneWidget);
      await _finish(tester);
      p.dispose();
    });

    testWidgets("a greeting card's send goes past the home to the conversation", (tester) async {
      final p = _provider();
      p.home.showChat('Do you ship to Canada?');
      await _pumpChat(tester, p);
      expect(find.byType(ChatHeaderWithKB), findsOneWidget);
      expect(find.byKey(const ValueKey('cb-home')), findsNothing);
      await _finish(tester);
      p.dispose();
    });

    testWidgets('no home screen while the owner has it off: the conversation, no back', (tester) async {
      final p = _provider(extra: {'enableInitialPage': false});
      expect(p.homeModel, isNull);
      await _pumpChat(tester, p);
      expect(find.byType(ChatHeaderWithKB), findsOneWidget);
      expect(find.byKey(const ValueKey('cb-header-back')), findsNothing);
      await _finish(tester);
      p.dispose();
    });
  });
}
