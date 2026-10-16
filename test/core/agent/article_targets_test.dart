// Where an AI reply's sources and the agent's rich article card open
// (lib/src/core/agent/agent_bot.dart), the React Native SDK's
// __tests__/core/articleTargets.test.ts ported: the web widget's
// agentSources.ts chip and agentRich.ts - a help article in the app when the
// help centre can show it, else its public page (#86).
import 'package:conferbot_flutter/src/core/agent/agent_bot.dart';
import 'package:flutter_test/flutter_test.dart';

const id = '64b7f0c2a1b2c3d4e5f60718';

void main() {
  group('sourceTarget', () {
    test('an article opens in the app when it can', () {
      expect(AgentBotParser.sourceTarget(const AgentSource(title: 'Refunds', articleId: id), true), const OpenTarget.article(id, 'Refunds'));
    });
    test('in the app before its public page', () {
      expect(AgentBotParser.sourceTarget(const AgentSource(title: 'Refunds', articleId: id, url: 'https://help.example.com/refunds'), true),
          const OpenTarget.article(id, 'Refunds'));
    });
    test('help centre off: its public page, else nowhere', () {
      expect(AgentBotParser.sourceTarget(const AgentSource(title: 'Refunds', articleId: id, url: 'https://help.example.com/refunds'), false),
          const OpenTarget.url('https://help.example.com/refunds'));
      expect(AgentBotParser.sourceTarget(const AgentSource(title: 'Refunds', articleId: id), false), isNull);
    });
    test('a page opens its url', () {
      expect(AgentBotParser.sourceTarget(const AgentSource(title: 'Pricing', url: 'https://example.com/pricing'), true),
          const OpenTarget.url('https://example.com/pricing'));
    });
    test('a bad id or url opens nothing', () {
      expect(AgentBotParser.sourceTarget(const AgentSource(title: 'x', articleId: 'nope'), true), isNull);
      expect(AgentBotParser.sourceTarget(const AgentSource(title: 'x', url: 'javascript:alert(1)'), true), isNull);
      expect(AgentBotParser.sourceTarget(null, true), isNull);
    });
    test("the server's sources, as normalized", () {
      final s = AgentBotParser.normalizeSources([
        {'title': 'Refunds', 'articleId': id, 'url': null}
      ]).single;
      expect(AgentBotParser.sourceTarget(s, true), const OpenTarget.article(id, 'Refunds'));
    });
  });

  group('richArticleTarget', () {
    RichArticle rich(Map<String, dynamic> m) => AgentBotParser.safeRich({'kind': 'article', ...m}) as RichArticle;

    test('its public page first', () {
      expect(AgentBotParser.richArticleTarget(rich({'articleId': id, 'title': 'Refunds', 'url': 'https://help.example.com/refunds'}), true),
          const OpenTarget.url('https://help.example.com/refunds'));
    });
    test('no public page: the article in the app', () {
      expect(AgentBotParser.richArticleTarget(rich({'articleId': id, 'title': 'Refunds', 'url': null}), true), const OpenTarget.article(id, 'Refunds'));
    });
    test('no public page and the help centre off: nothing', () {
      expect(AgentBotParser.richArticleTarget(rich({'articleId': id, 'title': 'Refunds'}), false), isNull);
    });
    test('an id that is not an ObjectId: nothing to open in the app', () {
      expect(AgentBotParser.richArticleTarget(rich({'articleId': 'refunds', 'title': 'Refunds'}), true), isNull);
    });
    test('none', () {
      expect(AgentBotParser.richArticleTarget(null, true), isNull);
    });
  });
}
