// The help centre over the chat's socket (#59, #60): the search inside
// article bodies (search-kb-articles, with snippets; REST when the socket
// does not answer), helpful / not helpful (rate-article; REST without a
// socket) and the reading time and depth (track-article-engagement).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:conferbot_flutter/src/core/help_centre/article_engagement.dart';
import 'package:conferbot_flutter/src/models/knowledge_base.dart';
import 'package:conferbot_flutter/src/providers/knowledge_base_provider.dart';
import 'package:conferbot_flutter/src/services/knowledge_base_service.dart';

const bot = '6ab686f8d47ff029b76892f7';
final fixtures = jsonDecode(File('test/fixtures/kb_payloads.json').readAsStringSync()) as Map<String, dynamic>;
KnowledgeBaseData socketData() => KnowledgeBaseData.fromJson(
    fixtures['socket_fetched_chatbot_data']['knowledgeBaseData'] as Map<String, dynamic>);
List<Map<String, dynamic>> searchRows() => [
      for (final a in fixtures['socket_search_kb_articles']['articles'] as List) Map<String, dynamic>.from(a as Map),
    ];

class _Fake {
  bool connected = true;
  List<Map<String, dynamic>>? Function(String query) answer = (_) => searchRows();
  final searched = <String>[];
  final sent = <(String, Map<String, dynamic>)>[];
  final rest = <http.Request>[];

  HelpCentreLink get link => HelpCentreLink(
        emit: (event, payload) {
          if (!connected) return false;
          sent.add((event, payload));
          return true;
        },
        search: (q) async {
          searched.add(q);
          return answer(q);
        },
        sessionId: () => 'cs_9',
      );

  KnowledgeBaseProvider provider({required int Function() now, bool withLink = true}) {
    final client = MockClient((request) async {
      rest.add(request);
      final path = request.url.path;
      if (path.endsWith('/knowledge-base/search')) return http.Response(jsonEncode(fixtures['rest_kb_search']), 200);
      if (path.contains('/knowledge-base/articles/') && path.endsWith('/view')) return http.Response('{"success":true}', 200);
      if (path.contains('/knowledge-base/articles/') && path.endsWith('/rate')) return http.Response('{"success":true,"data":{"rating":5}}', 200);
      if (path.contains('/knowledge-base/articles/')) {
        final article = Map<String, dynamic>.from(fixtures['rest_kb_article']['data'] as Map)..['_id'] = path.split('/').last;
        return http.Response(jsonEncode({'success': true, 'data': article}), 200);
      }
      if (path.endsWith('/visitor/ratings')) return http.Response('{"success":true,"data":{}}', 200);
      return http.Response('{"success":false}', 404);
    });
    return KnowledgeBaseProvider(
      botId: bot,
      apiKey: 'k',
      visitorId: 'v_9',
      initialData: socketData(),
      service: KnowledgeBaseService(apiKey: 'k', botId: bot, baseUrl: 'http://localhost:8001/api/v1/mobile', client: client),
      link: withLink ? link : null,
      now: now,
    );
  }
}

Future<void> settle() async {
  await Future<void>.delayed(const Duration(milliseconds: 400));
  await pumpEventQueue();
}

void main() {
  late _Fake fake;
  var clock = 0;
  setUp(() {
    fake = _Fake();
    clock = 5000000;
  });

  group('search (#60)', () {
    test('over the socket: local matches first, then the server rows once each, no REST', () async {
      final kb = fake.provider(now: () => clock);
      await kb.initialize();
      kb.search('chat');
      await settle();
      expect(fake.searched, ['chat']);
      expect(fake.rest.where((r) => r.url.path.endsWith('/search')), isEmpty);
      final ids = kb.articles.map((a) => a.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final row in searchRows()) {
        expect(ids, contains(row['_id']));
      }
      expect(kb.searchError, isNull);
    });

    test("a match only in the body shows the server's snippet", () async {
      fake.answer = (_) => [
            {
              '_id': '6ab7ac19b03f13ff2241ffff',
              'title': 'Billing',
              'description': 'Plans and invoices',
              'category': {'_id': 'c1', 'name': 'Account'},
              'snippet': 'Refunds are sent within five days…',
            },
          ];
      final kb = fake.provider(now: () => clock);
      await kb.initialize();
      kb.search('refunds');
      await settle();
      final hit = kb.searchResults.singleWhere((r) => r.article.id == '6ab7ac19b03f13ff2241ffff');
      expect(hit.article.summary, 'Refunds are sent within five days…');
      expect(hit.article.categoryName, 'Account');
      expect(hit.highlightedContent, 'Refunds are sent within five days…');
    });

    test('the socket does not answer: REST, as before', () async {
      fake.answer = (_) => null;
      final kb = fake.provider(now: () => clock);
      await kb.initialize();
      kb.search('live chat');
      await settle();
      expect(fake.searched, ['live chat']);
      expect(fake.rest.where((r) => r.url.path.endsWith('/knowledge-base/search')), hasLength(1));
      expect(kb.articles.map((a) => a.title), contains('How to Set Up Live Chat with AI Chatbot Handoff'));
    });

    test('no link (the standalone help centre): REST', () async {
      final kb = fake.provider(now: () => clock, withLink: false);
      await kb.initialize();
      kb.search('live chat');
      await settle();
      expect(fake.rest.where((r) => r.url.path.endsWith('/knowledge-base/search')), hasLength(1));
    });
  });

  group('helpful / not helpful (#59)', () {
    test('rate-article on the socket, once, no REST', () async {
      final kb = fake.provider(now: () => clock);
      await kb.initialize();
      final id = kb.articles.first.id;
      expect(kb.articleHelpful(id), isNull);
      expect(await kb.rateHelpful(id, false), isTrue);
      expect(kb.articleHelpful(id), isFalse);
      expect(await kb.rateHelpful(id, true), isFalse);
      final votes = fake.sent.where((s) => s.$1 == 'rate-article').toList();
      expect(votes.single.$2, {'articleId': id, 'visitorId': 'v_9', 'sessionId': 'cs_9', 'helpful': false, 'rating': 1, 'device': 'mobile'});
      expect(fake.rest.where((r) => r.url.path.endsWith('/rate')), isEmpty);
    });

    test('not connected: the same vote over REST (5 for helpful)', () async {
      fake.connected = false;
      final kb = fake.provider(now: () => clock);
      await kb.initialize();
      final id = kb.articles.first.id;
      expect(await kb.rateHelpful(id, true), isTrue);
      final rate = fake.rest.singleWhere((r) => r.url.path.endsWith('/rate'));
      expect(jsonDecode(rate.body)['rating'], 5);
      expect(kb.articleHelpful(id), isTrue);
    });
  });

  group('reading time and depth (#59)', () {
    test('open, scroll, back: track-article-engagement with the time and depth', () async {
      final kb = fake.provider(now: () => clock);
      await kb.initialize();
      final article = kb.articles.first;
      kb.selectArticle(article);
      await pumpEventQueue();
      kb.articleScrolled(55);
      kb.articleScrolled(93);
      clock += 30000;
      kb.clearSelectedArticle();
      final sent = fake.sent.singleWhere((s) => s.$1 == 'track-article-engagement').$2;
      expect(sent, {
        'articleId': article.id,
        'visitorId': 'v_9',
        'sessionId': 'cs_9',
        'timeSpent': 30,
        'scrollDepth': 93,
        'isCompleted': true,
        'device': 'mobile',
      });
    });

    test('another article from the related list sends the first; closing sends the last', () async {
      final kb = fake.provider(now: () => clock);
      await kb.initialize();
      final a = kb.articles[0];
      final b = kb.articles[1];
      kb.selectArticle(a);
      clock += 4000;
      await kb.fetchArticle(b.id);
      clock += 6000;
      kb.dispose();
      final reads = fake.sent.where((s) => s.$1 == 'track-article-engagement').map((s) => (s.$2['articleId'], s.$2['timeSpent'])).toList();
      expect(reads, [(a.id, 4), (b.id, 6)]);
    });
  });
}
