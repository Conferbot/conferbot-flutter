// The help centre on screen, against captured server payloads
// (test/fixtures/kb_payloads.json): the list with Recent articles, an
// article's HTML body, the owner's on/off switch, and AI sources and rich
// article cards opening an article by id.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:conferbot_flutter/src/core/agent/agent_bot.dart';
import 'package:conferbot_flutter/src/models/knowledge_base.dart';
import 'package:conferbot_flutter/src/models/message.dart';
import 'package:conferbot_flutter/src/providers/conferbot_provider.dart';
import 'package:conferbot_flutter/src/providers/knowledge_base_provider.dart';
import 'package:conferbot_flutter/src/services/knowledge_base_service.dart';
import 'package:conferbot_flutter/src/services/storage_service.dart';
import 'package:conferbot_flutter/src/theme/default_theme.dart';
import 'package:conferbot_flutter/src/widgets/agent_reply.dart';
import 'package:conferbot_flutter/src/widgets/chat_widget.dart';
import 'package:conferbot_flutter/src/widgets/knowledge_base/article_detail.dart';
import 'package:conferbot_flutter/src/widgets/knowledge_base/knowledge_base_screen.dart';

const bot = '6ab686f8d47ff029b76892f7';
final fixtures = jsonDecode(File('test/fixtures/kb_payloads.json').readAsStringSync()) as Map<String, dynamic>;
Map<String, dynamic> socketPayload() =>
    jsonDecode(jsonEncode(fixtures['socket_fetched_chatbot_data'])) as Map<String, dynamic>;
KnowledgeBaseData socketData() =>
    KnowledgeBaseData.fromJson(socketPayload()['knowledgeBaseData'] as Map<String, dynamic>);

KnowledgeBaseProvider kbProvider({bool showRecent = true}) {
  final client = MockClient((request) async {
    final path = request.url.path;
    if (path.endsWith('/view')) return http.Response('{"success":true}', 200);
    if (path.contains('/knowledge-base/articles/')) {
      final article = Map<String, dynamic>.from(fixtures['rest_kb_article']['data'] as Map)
        ..['_id'] = path.split('/').last;
      return http.Response(jsonEncode({'success': true, 'data': article}), 200);
    }
    return http.Response('{"success":true,"data":{}}', 200);
  });
  return KnowledgeBaseProvider(
    botId: bot,
    apiKey: 'k',
    initialData: socketData(),
    showRecentArticles: showRecent,
    service: KnowledgeBaseService(apiKey: 'k', botId: bot, client: client),
  );
}

Widget screen(KnowledgeBaseProvider kb) => MaterialApp(
      home: ChangeNotifierProvider.value(
        value: kb,
        child: KnowledgeBaseScreen(theme: defaultTheme, onClose: () {}),
      ),
    );

ConferBotProvider chatProvider({required bool enableKnowledgeBase, bool hideRecent = false}) {
  final provider = ConferBotProvider(
    apiKey: 'k',
    botId: bot,
    config: const ConferBotConfig(autoConnect: false),
  );
  final payload = socketPayload();
  (payload['chatbotData'] as Map)['customizations'] = {
    'enableKnowledgeBase': enableKnowledgeBase,
    'hideRecentArticles': hideRecent,
  };
  if (!enableKnowledgeBase) {
    // As the server sends it with the help centre off.
    payload['knowledgeBaseData'] = {'recentArticles': [], 'categories': []};
  }
  provider.debugHandleChatbotData(payload);
  return provider;
}

/// The chat's own start-up (no storage, no network in tests) and the
/// default logo image report errors that have nothing to do with the help
/// centre; they are dropped here.
Future<void> pumpChat(WidgetTester tester, ConferBotProvider provider, {bool? showKnowledgeBase}) async {
  await tester.pumpWidget(MaterialApp(
    home: ChangeNotifierProvider.value(
      value: provider,
      child: ChatWidget(showKnowledgeBase: showKnowledgeBase),
    ),
  ));
  await tester.pump();
  drain(tester);
}

/// The chat stores its session (Hive) under a temporary directory.
class _TempPaths extends PathProviderPlatform with MockPlatformInterfaceMixin {
  final String dir;
  _TempPaths(this.dir);
  @override
  Future<String?> getApplicationDocumentsPath() async => dir;
  @override
  Future<String?> getApplicationSupportPath() async => dir;
  @override
  Future<String?> getTemporaryPath() async => dir;
}

/// Lets the chat's start-up timers (connection, retries) run out.
Future<void> finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(minutes: 1));
  }
  drain(tester);
}

void drain(WidgetTester tester) {
  while (tester.takeException() != null) {}
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    PathProviderPlatform.instance = _TempPaths(Directory.systemTemp.createTempSync('cb_kb_').path);
    await StorageService.init();
  });

  group('Help centre screen', () {
    testWidgets('lists the topics, Recent articles and every article', (tester) async {
      final kb = kbProvider();
      await tester.pumpWidget(screen(kb));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('kb-recent-articles')), findsOneWidget);
      expect(find.text('Recent articles'), findsOneWidget);
      expect(find.text('Chatbot Essentials'), findsWidgets);
      expect(find.text(socketData().recentArticles.first.title), findsWidgets);
    });

    testWidgets('hideRecentArticles leaves the Recent articles out', (tester) async {
      await tester.pumpWidget(screen(kbProvider(showRecent: false)));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('kb-recent-articles')), findsNothing);
      expect(find.text('Recent articles'), findsNothing);
    });

    testWidgets('an article fetches its body and draws the HTML, not its tags (#57)', (tester) async {
      final kb = kbProvider();
      await tester.pumpWidget(screen(kb));
      await tester.pumpAndSettle();

      await tester.tap(find.text(socketData().recentArticles.first.title).first);
      await tester.pumpAndSettle();

      expect(find.byType(ArticleDetail), findsOneWidget);
      expect(kb.selectedArticle!.hasContent, isTrue);
      expect(find.textContaining('<p>', findRichText: true), findsNothing);
      expect(find.textContaining('Steps to Create a Chatbot', findRichText: true), findsOneWidget);
    });
  });

  group("The owner's switch (#36)", () {
    testWidgets('help button shown while enableKnowledgeBase is on', (tester) async {
      final provider = chatProvider(enableKnowledgeBase: true);
      await pumpChat(tester, provider);
      expect(find.byTooltip('Help centre'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('no help button while it is off', (tester) async {
      final provider = chatProvider(enableKnowledgeBase: false);
      await pumpChat(tester, provider);
      expect(find.byTooltip('Help centre'), findsNothing);
      await finish(tester);
    });

    testWidgets("the app's showKnowledgeBase overrides the server", (tester) async {
      final off = chatProvider(enableKnowledgeBase: false);
      await pumpChat(tester, off, showKnowledgeBase: true);
      expect(find.byTooltip('Help centre'), findsOneWidget);

      final on = chatProvider(enableKnowledgeBase: true);
      await pumpChat(tester, on, showKnowledgeBase: false);
      expect(find.byTooltip('Help centre'), findsNothing);
      await finish(tester);
    });

    testWidgets('the help button opens the help centre from the socket data', (tester) async {
      final provider = chatProvider(enableKnowledgeBase: true);
      await pumpChat(tester, provider);
      await tester.tap(find.byTooltip('Help centre'));
      await tester.pump();
      await tester.pump();
      drain(tester);
      expect(find.byType(KnowledgeBaseScreen), findsOneWidget);
      expect(find.text(socketData().recentArticles.first.title), findsWidgets);
      await finish(tester);
    });
  });

  group('AI sources and rich article cards (#45)', () {
    final articleId = socketData().recentArticles.first.id;

    AgentMessageRecord reply() => AgentMessageRecord(
          id: '0123456789abcdef01234567',
          time: DateTime(2026),
          text: 'Here is how.',
          agentDetails: AgentDetails.fromJson(const {'_id': 'ai-agent-a1', 'isAIAgent': true, 'name': 'Ava'}),
          extras: AgentBotParser.aiReplyExtrasOf({
            'agentDetails': {'_id': 'ai-agent-a1', 'isAIAgent': true},
            'sources': [
              {'title': "How to Use Conferbot's AI Chatbot Builder", 'articleId': articleId},
            ],
          }),
        );

    Widget host(ConferBotProvider provider, Widget child) => MaterialApp(
          home: Scaffold(body: ChangeNotifierProvider.value(value: provider, child: child)),
        );

    testWidgets('a source opens its article by id', (tester) async {
      final provider = chatProvider(enableKnowledgeBase: true);
      final opened = <String>[];
      provider.articleOpener = opened.add;
      await tester.pumpWidget(host(provider, AgentReplyExtras(message: reply(), theme: defaultTheme)));

      expect(find.text('Help article'), findsOneWidget);
      await tester.tap(find.text("How to Use Conferbot's AI Chatbot Builder"));
      expect(opened, [articleId]);
    });

    testWidgets('with no help centre on screen the source is plain text', (tester) async {
      final provider = chatProvider(enableKnowledgeBase: true);
      await tester.pumpWidget(host(provider, AgentReplyExtras(message: reply(), theme: defaultTheme)));
      expect(find.text('Help article'), findsNothing);
      await tester.tap(find.text("How to Use Conferbot's AI Chatbot Builder"));
      expect(provider.openArticle(articleId), isFalse);
    });

    testWidgets('a rich article card opens by id, with no public url', (tester) async {
      final provider = chatProvider(enableKnowledgeBase: true);
      final opened = <String>[];
      provider.articleOpener = opened.add;
      final rich = AgentRichMessageRecord(
        id: 'r1',
        time: DateTime(2026),
        rich: RichArticle(articleId: articleId, title: 'AI Chatbot Builder', snippet: 'Create chatbots quickly.'),
      );
      await tester.pumpWidget(host(provider, RichAgentMessage(message: rich, theme: defaultTheme, avatar: const SizedBox.shrink())));
      await tester.tap(find.byKey(const ValueKey('agent-rich-article-open')));
      expect(opened, [articleId]);
    });

    testWidgets('in the chat, a source opens the help centre on that article', (tester) async {
      final provider = chatProvider(enableKnowledgeBase: true);
      await pumpChat(tester, provider);
      expect(provider.openArticle(articleId), isTrue);
      await tester.pump();
      await tester.pump();
      drain(tester);
      expect(find.byType(ArticleDetail), findsOneWidget);
      expect(find.text(socketData().recentArticles.first.title), findsWidgets);
      await finish(tester);
    });
  });
}
