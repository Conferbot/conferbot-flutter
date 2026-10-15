// The help centre's state against captured server payloads
// (test/fixtures/kb_payloads.json).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:conferbot_flutter/src/config/constants.dart';
import 'package:conferbot_flutter/src/models/knowledge_base.dart';
import 'package:conferbot_flutter/src/providers/knowledge_base_provider.dart';
import 'package:conferbot_flutter/src/services/knowledge_base_service.dart';

const bot = '6ab686f8d47ff029b76892f7';
final fixtures = jsonDecode(File('test/fixtures/kb_payloads.json').readAsStringSync()) as Map<String, dynamic>;
String body(String name) => jsonEncode(fixtures[name]);

KnowledgeBaseData socketData() => KnowledgeBaseData.fromJson(
    fixtures['socket_fetched_chatbot_data']['knowledgeBaseData'] as Map<String, dynamic>);

/// A provider on a fake server that records the paths it was asked for.
(KnowledgeBaseProvider, List<Uri>) providerWith({KnowledgeBaseData? seed, bool showRecent = true}) {
  final calls = <Uri>[];
  final client = MockClient((request) async {
    calls.add(request.url);
    final path = request.url.path;
    if (path.endsWith('/knowledge-base/articles')) return http.Response(body('rest_kb_articles'), 200);
    if (path.contains('/knowledge-base/articles/') && path.endsWith('/view')) return http.Response('{"success":true}', 200);
    if (path.contains('/knowledge-base/articles/')) {
      final id = path.split('/').last;
      final article = Map<String, dynamic>.from(fixtures['rest_kb_article']['data'] as Map)..['_id'] = id;
      return http.Response(jsonEncode({'success': true, 'data': article}), 200);
    }
    if (path.endsWith('/knowledge-base/search')) {
      return request.url.queryParameters['query'] == null
          ? http.Response(body('rest_kb_search_missing_query'), 400)
          : http.Response(body('rest_kb_search'), 200);
    }
    if (path.endsWith('/visitor/ratings')) return http.Response('{"success":true,"data":{}}', 200);
    return http.Response('{"success":false}', 404);
  });
  final service = KnowledgeBaseService(apiKey: 'k', botId: bot, baseUrl: 'http://localhost:8001/api/v1/mobile', client: client);
  return (
    KnowledgeBaseProvider(botId: bot, apiKey: 'k', service: service, initialData: seed, showRecentArticles: showRecent),
    calls,
  );
}

void main() {
  test('seeded from the socket: no list request, categories and articles at once', () async {
    final (kb, calls) = providerWith(seed: socketData());
    await kb.initialize();
    expect(calls.where((u) => u.path.endsWith('/knowledge-base/articles')), isEmpty);
    expect(kb.categories, isNotEmpty);
    expect(kb.articles, isNotEmpty);
    expect(kb.recentArticles, hasLength(4));
    expect(kb.hasError, isFalse);
  });

  test('without a seed it loads the help centre over REST (it never loaded, #53)', () async {
    final (kb, calls) = providerWith();
    await kb.initialize();
    expect(calls.single.path, '/api/v1/mobile/knowledge-base/articles');
    expect(kb.categories.map((c) => c.name), ['Chatbot Essentials', 'Chatbot Creation']);
    expect(kb.articles, isNotEmpty);
    expect(kb.hasError, isFalse);
  });

  test('a category filters locally', () async {
    final (kb, calls) = providerWith(seed: socketData());
    await kb.initialize();
    final category = kb.categories.first;
    await kb.selectCategory(category.id);
    expect(kb.articles.every((a) => a.categoryId == category.id), isTrue);
    expect(kb.articles, hasLength(category.articleCount));
    expect(calls.where((u) => u.path.endsWith('/knowledge-base/articles')), isEmpty);
  });

  test('opening an article without a body fetches it', () async {
    final (kb, calls) = providerWith(seed: socketData());
    await kb.initialize();
    final article = kb.recentArticles.first;
    expect(article.hasContent, isFalse);
    kb.selectArticle(article);
    expect(kb.selectedArticle!.title, article.title);
    expect(kb.isLoadingArticle, isTrue);
    await pumpEventQueue();
    expect(kb.isLoadingArticle, isFalse);
    expect(kb.selectedArticle!.content, startsWith('<p>'));
    expect(calls.map((u) => u.path), contains('/api/v1/mobile/knowledge-base/articles/${article.id}'));
    // The body is kept: opening it again asks for nothing.
    kb.clearSelectedArticle();
    final before = calls.length;
    kb.selectArticle(kb.data.find(article.id)!);
    await pumpEventQueue();
    expect(calls.length, before);
  });

  test('openArticle by id (an AI source) opens a known article and fetches its body', () async {
    final (kb, _) = providerWith(seed: socketData());
    final id = socketData().categories.first.id;
    final articleId = socketData().articlesIn(id).first.id;
    await kb.openArticle(articleId);
    await pumpEventQueue();
    expect(kb.selectedArticle!.id, articleId);
    expect(kb.selectedArticle!.hasContent, isTrue);
    // The fake server answers with one fixture article; its own topic wins.
    expect(kb.selectedArticle!.categoryName, isNotNull);
  });

  test('openArticle by an id the list does not hold asks the server', () async {
    final (kb, calls) = providerWith(seed: socketData());
    await kb.openArticle('6ab7ac0bb03f13ff22412fff');
    expect(kb.selectedArticle!.id, '6ab7ac0bb03f13ff22412fff');
    expect(calls.map((u) => u.path), contains('/api/v1/mobile/knowledge-base/articles/6ab7ac0bb03f13ff22412fff'));
  });

  test('search sends query and merges local title matches with server matches (#54)', () async {
    final (kb, calls) = providerWith(seed: socketData());
    await kb.initialize();
    kb.search('live chat');
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await pumpEventQueue();
    final search = calls.lastWhere((u) => u.path.endsWith('/knowledge-base/search'));
    expect(search.queryParameters['query'], 'live chat');
    expect(kb.searchError, isNull);
    expect(kb.articles.map((a) => a.title), contains('How to Set Up Live Chat with AI Chatbot Handoff'));
    final ids = kb.articles.map((a) => a.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('hideRecentArticles empties the Recent articles list', () async {
    final (kb, _) = providerWith(seed: socketData(), showRecent: false);
    await kb.initialize();
    expect(kb.recentArticles, isEmpty);
    expect(kb.articles, isNotEmpty);
  });

  test('the default server is the configured one, not production (#56)', () {
    ConferBotEndpoints.configure(apiBaseUrl: 'http://localhost:8001/api/v1/mobile');
    addTearDown(ConferBotEndpoints.reset);
    expect(KnowledgeBaseProvider(botId: bot, apiKey: 'k').baseUrl, 'http://localhost:8001/api/v1/mobile');
    expect(KnowledgeBaseProvider(botId: bot, apiKey: 'k', baseUrl: 'https://staging.example/api/v1/mobile').baseUrl,
        'https://staging.example/api/v1/mobile');
  });
}
