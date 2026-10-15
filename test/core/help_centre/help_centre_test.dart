// The help centre rules (web core/helpCentre.ts) and the server's payloads,
// read from real captures in test/fixtures/kb_payloads.json.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:conferbot_flutter/src/core/help_centre/help_centre.dart';
import 'package:conferbot_flutter/src/models/knowledge_base.dart';

Map<String, dynamic> fixture(String name) =>
    (jsonDecode(File('test/fixtures/kb_payloads.json').readAsStringSync()) as Map<String, dynamic>)[name]
        as Map<String, dynamic>;

void main() {
  group('KnowledgeBaseData from the socket (fetched-chatbot-data)', () {
    final payload = fixture('socket_fetched_chatbot_data');
    final kb = KnowledgeBaseData.fromJson(payload['knowledgeBaseData'] as Map<String, dynamic>);

    test('reads categories with their articles and the recent list', () {
      expect(kb.categories, isNotEmpty);
      expect(kb.recentArticles, hasLength(4));
      expect(kb.categories.first.name, 'Chatbot Essentials');
      expect(kb.categories.first.articleCount, kb.articlesByCategory[kb.categories.first.id]!.length);
      expect(kb.isNotEmpty, isTrue);
    });

    test('articles in a category carry a bare category id; the name comes from the category', () {
      final first = kb.articlesByCategory[kb.categories.first.id]!.first;
      expect(first.categoryId, kb.categories.first.id);
      expect(first.categoryName, 'Chatbot Essentials');
      expect(first.authorName, 'admin');
      expect(first.summary, isNotEmpty);
      expect(first.readTimeMinutes, 2);
    });

    test('no bodies on connect: the article view must fetch them', () {
      expect(kb.allArticles.every((a) => !a.hasContent), isTrue);
    });

    test('allArticles lists every article once', () {
      final ids = kb.allArticles.map((a) => a.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final recent in kb.recentArticles) {
        expect(ids, contains(recent.id));
      }
    });

    test('find looks in categories, then recent articles', () {
      final recent = kb.recentArticles.first;
      expect(kb.find(recent.id)?.title, recent.title);
      expect(kb.find('000000000000000000000000'), isNull);
      expect(kb.find(null), isNull);
    });

    test('withArticle fills in one body everywhere it appears', () {
      final full = KnowledgeBaseArticle.fromJson(
          fixture('socket_get_kb_article')['article'] as Map<String, dynamic>);
      final merged = kb.withArticle(full);
      expect(merged.find(full.id)!.hasContent, isTrue);
      expect(merged.recentArticles.firstWhere((a) => a.id == full.id).content, startsWith('<p>'));
    });
  });

  group('KnowledgeBaseData from REST', () {
    test('GET /mobile/chatbot/:id/kb: {success, data: {chatbotData, knowledgeBaseData}}', () {
      final kb = KnowledgeBaseData.fromJson(fixture('rest_chatbot_kb'));
      expect(kb.categories, hasLength(2));
      expect(kb.recentArticles, hasLength(4));
      expect(kb.allArticles.every((a) => a.hasContent), isTrue);
    });

    test('GET /mobile/knowledge-base/articles: {success, data: {recentArticles, categories}}', () {
      final kb = KnowledgeBaseData.fromJson(fixture('rest_kb_articles'));
      expect(kb.categories, hasLength(2));
      expect(kb.allArticles.first.content, contains('<'));
    });

    test('an empty help centre counts as empty', () {
      expect(KnowledgeBaseData.fromJson({'recentArticles': [], 'categories': []}).isEmpty, isTrue);
      expect(KnowledgeBaseData.fromJson(null).isEmpty, isTrue);
    });

    test('drafts are dropped', () {
      final kb = KnowledgeBaseData.fromJson({
        'recentArticles': [
          {'_id': 'a1', 'title': 'Live', 'reviewStatus': 'published'},
          {'_id': 'a2', 'title': 'Draft', 'reviewStatus': 'draft'},
        ],
        'categories': [],
      });
      expect(kb.recentArticles.map((a) => a.id), ['a1']);
    });
  });

  group('KnowledgeBaseArticle.fromJson on the server article', () {
    test('a full article (get-kb-article / articles/:id)', () {
      final a = KnowledgeBaseArticle.fromJson(fixture('rest_kb_article')['data'] as Map<String, dynamic>);
      expect(a.id, '6ab7ac0bb03f13ff22412c87');
      expect(a.title, "How to Use Conferbot's AI Chatbot Builder");
      expect(a.summary, "Learn to create chatbots quickly with Conferbot's AI builder.");
      expect(a.categoryName, 'Chatbot Creation');
      expect(a.categoryId, '6ab7abfcb03f13ff22412c38');
      expect(a.readTimeMinutes, 2);
      expect(a.viewCount, 4);
      expect(a.createdAt, DateTime.parse('2026-09-27T06:31:04.520Z'));
      expect(a.hasContent, isTrue);
    });

    test('a search row (socket) uses its snippet as the summary when there is no description', () {
      final row = Map<String, dynamic>.from(
          (fixture('socket_search_kb_articles')['articles'] as List).first as Map)
        ..remove('description');
      expect(KnowledgeBaseArticle.fromJson(row).summary, startsWith('Live chat with AI chatbot handoff'));
    });
  });

  group('HelpCentre rules', () {
    final kb = KnowledgeBaseData.fromJson(
        fixture('socket_fetched_chatbot_data')['knowledgeBaseData'] as Map<String, dynamic>);
    const on = {'enableKnowledgeBase': true};
    const off = {'enableKnowledgeBase': false};

    test('on only when enableKnowledgeBase is true', () {
      expect(HelpCentre.isOn(on), isTrue);
      expect(HelpCentre.isOn(off), isFalse);
      expect(HelpCentre.isOn({}), isFalse);
      expect(HelpCentre.isOn({'enableKnowledgeBase': 'true'}), isFalse);
      expect(HelpCentre.isOn(null), isFalse);
    });

    test('follows the server by default, and needs a published article', () {
      expect(HelpCentre.isVisible(customizations: on, data: kb), isTrue);
      expect(HelpCentre.isVisible(customizations: off, data: kb), isFalse);
      expect(HelpCentre.isVisible(customizations: on, data: KnowledgeBaseData.empty), isFalse);
      expect(HelpCentre.isVisible(customizations: null, data: kb), isFalse);
    });

    test("the app's override wins: false hides, true shows", () {
      expect(HelpCentre.isVisible(override: false, customizations: on, data: kb), isFalse);
      expect(HelpCentre.isVisible(override: true, customizations: off, data: KnowledgeBaseData.empty), isTrue);
    });

    test('recent articles show unless hideRecentArticles', () {
      expect(HelpCentre.showsRecentArticles(on, kb.recentArticles), isTrue);
      expect(HelpCentre.showsRecentArticles({...on, 'hideRecentArticles': true}, kb.recentArticles), isFalse);
      expect(HelpCentre.showsRecentArticles(on, const []), isFalse);
    });

    test('an article opens only while the help centre is offered', () {
      expect(HelpCentre.canOpenArticle(visible: true, articleId: 'abc'), isTrue);
      expect(HelpCentre.canOpenArticle(visible: false, articleId: 'abc'), isFalse);
      expect(HelpCentre.canOpenArticle(visible: true, articleId: ''), isFalse);
      expect(HelpCentre.canOpenArticle(visible: true), isFalse);
    });
  });
}
