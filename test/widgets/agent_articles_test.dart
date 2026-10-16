// AI sources and rich article cards on screen (widgets/agent_reply.dart):
// in the app's help centre only while it is on, else the public page, else
// drawn without a tap; an article card's public page first (#86). The cases
// of the React Native SDK's __tests__/components/AgentArticles.test.tsx.
import 'dart:convert';
import 'dart:io';

import 'package:conferbot_flutter/src/core/agent/agent_bot.dart';
import 'package:conferbot_flutter/src/models/message.dart';
import 'package:conferbot_flutter/src/providers/conferbot_provider.dart';
import 'package:conferbot_flutter/src/theme/default_theme.dart';
import 'package:conferbot_flutter/src/widgets/agent_reply.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const bot = '6ab686f8d47ff029b76892f7';
const id = '64b7f0c2a1b2c3d4e5f60718';
final fixtures = jsonDecode(File('test/fixtures/kb_payloads.json').readAsStringSync()) as Map<String, dynamic>;

ConferBotProvider chatProvider({required bool enableKnowledgeBase}) {
  final provider = ConferBotProvider(apiKey: 'k', botId: bot, config: const ConferBotConfig(autoConnect: false, enablePersistence: false));
  final payload = jsonDecode(jsonEncode(fixtures['socket_fetched_chatbot_data'])) as Map<String, dynamic>;
  (payload['chatbotData'] as Map)['customizations'] = {'enableKnowledgeBase': enableKnowledgeBase};
  if (!enableKnowledgeBase) payload['knowledgeBaseData'] = {'recentArticles': [], 'categories': []};
  provider.debugHandleChatbotData(payload);
  return provider;
}

AgentMessageRecord reply(List<Map<String, dynamic>> sources) => AgentMessageRecord(
      id: '0123456789abcdef01234567',
      time: DateTime(2026),
      text: 'Here is how.',
      agentDetails: AgentDetails.fromJson(const {'_id': 'ai-agent-a1', 'isAIAgent': true, 'name': 'Ava'}),
      extras: AgentBotParser.aiReplyExtrasOf({
        'agentDetails': {'_id': 'ai-agent-a1', 'isAIAgent': true},
        'sources': sources,
      }),
    );

AgentRichMessageRecord card({String? url}) => AgentRichMessageRecord(
      id: 'r1',
      time: DateTime(2026),
      rich: RichArticle(articleId: id, title: 'Refunds', snippet: 'How refunds work.', url: url),
    );

Widget host(ConferBotProvider provider, Widget child) => MaterialApp(
      home: Scaffold(body: ChangeNotifierProvider.value(value: provider, child: child)),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('help centre on: a cited article says "Help article" and opens in the app', (tester) async {
    final provider = chatProvider(enableKnowledgeBase: true);
    final opened = <String>[];
    provider.articleOpener = opened.add;
    await tester.pumpWidget(host(provider, AgentReplyExtras(message: reply([{'title': 'Refunds', 'articleId': id, 'url': 'https://help.example.com/refunds'}]), theme: defaultTheme)));
    expect(find.text('Help article'), findsOneWidget);
    expect(find.text('help.example.com'), findsNothing);
    await tester.tap(find.text('Refunds'));
    expect(opened, [id]);
  });

  testWidgets('help centre off: its public page ("host ↗"), never a dead "Help article"', (tester) async {
    final provider = chatProvider(enableKnowledgeBase: false);
    final opened = <String>[];
    provider.articleOpener = opened.add;
    await tester.pumpWidget(host(provider, AgentReplyExtras(message: reply([{'title': 'Refunds', 'articleId': id, 'url': 'https://help.example.com/refunds'}]), theme: defaultTheme)));
    expect(find.text('Help article'), findsNothing);
    expect(find.text('help.example.com'), findsOneWidget);
    expect(provider.canOpenArticles, isFalse);
    expect(provider.openArticle(id), isFalse);
    expect(opened, isEmpty);
  });

  testWidgets('help centre off and no public page: drawn, not tappable', (tester) async {
    final provider = chatProvider(enableKnowledgeBase: false);
    provider.articleOpener = (_) {};
    await tester.pumpWidget(host(provider, AgentReplyExtras(message: reply([{'title': 'Refunds', 'articleId': id}]), theme: defaultTheme)));
    expect(find.text('Refunds'), findsOneWidget);
    expect(find.text('Help article'), findsNothing);
    final ink = tester.widget<InkWell>(find.ancestor(of: find.text('Refunds'), matching: find.byType(InkWell)).first);
    expect(ink.onTap, isNull);
  });

  testWidgets("the chat's own switch (ChatWidget.showKnowledgeBase) wins over the owner's", (tester) async {
    final provider = chatProvider(enableKnowledgeBase: true);
    provider.articleOpener = (_) {};
    provider.articlesShown = () => false;
    expect(provider.canOpenArticles, isFalse);
    provider.articlesShown = () => true;
    final off = chatProvider(enableKnowledgeBase: false)
      ..articleOpener = (_) {}
      ..articlesShown = () => true;
    expect(provider.canOpenArticles, isTrue);
    expect(off.canOpenArticles, isTrue);
  });

  testWidgets('an article card opens its public page first', (tester) async {
    final provider = chatProvider(enableKnowledgeBase: true);
    final opened = <String>[];
    provider.articleOpener = opened.add;
    await tester.pumpWidget(host(provider, RichAgentMessage(message: card(url: 'https://help.example.com/refunds'), theme: defaultTheme, avatar: const SizedBox.shrink())));
    expect(find.byKey(const ValueKey('agent-rich-article-open')), findsNothing);
    expect(find.byIcon(Icons.north_east), findsOneWidget);
  });

  testWidgets('an article card without a public page opens in the app, only while the help centre is on', (tester) async {
    final on = chatProvider(enableKnowledgeBase: true);
    final opened = <String>[];
    on.articleOpener = opened.add;
    await tester.pumpWidget(host(on, RichAgentMessage(message: card(), theme: defaultTheme, avatar: const SizedBox.shrink())));
    await tester.tap(find.byKey(const ValueKey('agent-rich-article-open')));
    expect(opened, [id]);

    final off = chatProvider(enableKnowledgeBase: false)..articleOpener = opened.add;
    await tester.pumpWidget(host(off, RichAgentMessage(message: card(), theme: defaultTheme, avatar: const SizedBox.shrink())));
    expect(find.byKey(const ValueKey('agent-rich-article-open')), findsNothing);
    expect(find.text('Read article'), findsNothing);
  });
}
