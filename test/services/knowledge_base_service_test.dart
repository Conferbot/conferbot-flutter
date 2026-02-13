import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:conferbot_flutter/src/services/knowledge_base_service.dart';
import 'package:conferbot_flutter/src/config/constants.dart';

void main() {
  late KnowledgeBaseService kbService;

  group('KnowledgeBaseService Construction', () {
    test('should create with required parameters', () {
      kbService = KnowledgeBaseService(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
      );

      expect(kbService.apiKey, 'test_api_key');
      expect(kbService.botId, 'test_bot_id');
      expect(kbService.baseUrl, ConferBotConstants.defaultApiBaseUrl);
    });

    test('should create with custom base URL', () {
      kbService = KnowledgeBaseService(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        baseUrl: 'https://custom.api.com',
      );

      expect(kbService.baseUrl, 'https://custom.api.com');
    });
  });

  group('KnowledgeBaseService.fetchArticles', () {
    test('should successfully fetch articles with pagination', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, contains('/knowledge-base/articles'));
        expect(request.url.queryParameters['botId'], 'chatbot_123');
        expect(request.url.queryParameters['page'], '1');
        expect(request.url.queryParameters['limit'], '10');
        expect(request.headers[ConferBotConstants.headerApiKey], 'test_api_key');

        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'articles': [
                {
                  '_id': 'article_1',
                  'title': 'Getting Started',
                  'content': 'Welcome to our platform...',
                  'categoryId': 'cat_1',
                  'viewCount': 100,
                  'createdAt': '2024-01-01T00:00:00Z',
                  'updatedAt': '2024-01-15T00:00:00Z',
                },
                {
                  '_id': 'article_2',
                  'title': 'Advanced Features',
                  'content': 'Learn about advanced...',
                  'categoryId': 'cat_2',
                  'viewCount': 50,
                  'createdAt': '2024-01-05T00:00:00Z',
                  'updatedAt': '2024-01-20T00:00:00Z',
                },
              ],
              'page': 1,
              'limit': 10,
              'totalItems': 25,
              'totalPages': 3,
              'hasNextPage': true,
              'hasPreviousPage': false,
            },
          }),
          200,
        );
      });

      kbService = KnowledgeBaseService(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        client: mockClient,
      );

      final response = await kbService.fetchArticles('chatbot_123');

      expect(response.success, true);
      expect(response.data, isNotNull);
      expect(response.data!.articles.length, 2);
      expect(response.data!.articles[0].title, 'Getting Started');
      expect(response.data!.pagination.page, 1);
      expect(response.data!.pagination.totalItems, 25);
      expect(response.data!.pagination.hasNextPage, true);
    });

    test('should fetch articles with category filter', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters['category'], 'cat_1');

        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'articles': [],
              'page': 1,
              'limit': 10,
              'totalItems': 0,
            },
          }),
          200,
        );
      });

      kbService = KnowledgeBaseService(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        client: mockClient,
      );

      await kbService.fetchArticles('chatbot_123', category: 'cat_1');
    });

    test('should fetch articles with search query', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters['search'], 'getting started');

        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'articles': [],
              'page': 1,
              'limit': 10,
              'totalItems': 0,
            },
          }),
          200,
        );
      });

      kbService = KnowledgeBaseService(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        client: mockClient,
      );

      await kbService.fetchArticles('chatbot_123', search: 'getting started');
    });

    test('should fetch articles with sorting', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters['sortBy'], 'viewCount');
        expect(request.url.queryParameters['sortOrder'], 'desc');

        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'articles': [],
              'page': 1,
              'limit': 10,
              'totalItems': 0,
            },
          }),
          200,
        );
      });

      kbService = KnowledgeBaseService(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        client: mockClient,
      );

      await kbService.fetchArticles(
        'chatbot_123',
        sortBy: 'viewCount',
        sortOrder: 'desc',
      );
    });

    test('should fetch articles with tags filter', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters['tags'], 'tag1,tag2');

        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'articles': [],
              'page': 1,
              'limit': 10,
              'totalItems': 0,
            },
          }),
          200,
        );
      });

      kbService = KnowledgeBaseService(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        client: mockClient,
      );

      await kbService.fetchArticles('chatbot_123', tags: ['tag1', 'tag2']);
    });

    test('should handle fetch articles failure', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'error': 'Invalid chatbot ID',
          }),
          400,
        );
      });

      kbService = KnowledgeBaseService(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        client: mockClient,
      );

      final response = await kbService.fetchArticles('invalid_id');

      expect(response.success, false);
      expect(response.error, 'Invalid chatbot ID');
    });

    test('should handle network error', () async {
      final mockClient = MockClient((request) async {
        throw Exception('Network error');
      });

      kbService = KnowledgeBaseService(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        client: mockClient,
      );

      final response = await kbService.fetchArticles('chatbot_123');

      expect(response.success, false);
      expect(response.error, contains('Exception'));
    });
  });

  group('KnowledgeBaseService.fetchCategories', () {
    test('should successfully fetch categories', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, contains('/knowledge-base/categories'));
        expect(request.url.queryParameters['botId'], 'chatbot_123');

        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {
                '_id': 'cat_1',
                'name': 'Getting Started',
                'description': 'Beginner guides',
                'articleCount': 10,
                'sortOrder': 0,
              },
              {
                '_id': 'cat_2',
                'name': 'Advanced',
                'description': 'Advanced topics',
                'articleCount': 5,
                'sortOrder': 1,
              },
            ],
          }),
          200,
        );
      });

      kbService = KnowledgeBaseService(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        client: mockClient,
      );

      final response = await kbService.fetchCategories('chatbot_123');

      expect(response.success, true);
      expect(response.data, isNotNull);
      expect(response.data!.length, 2);
      expect(response.data![0].name, 'Getting Started');
      expect(response.data![1].name, 'Advanced');
    });

    test('should sort categories by sort order', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {'_id': 'cat_2', 'name': 'Second', 'sortOrder': 2},
              {'_id': 'cat_1', 'name': 'First', 'sortOrder': 1},
              {'_id': 'cat_3', 'name': 'Third', 'sortOrder': 3},
            ],
          }),
          200,
        );
      });

      kbService = KnowledgeBaseService(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        client: mockClient,
      );

      final response = await kbService.fetchCategories('chatbot_123');

      expect(response.data![0].sortOrder, 1);
      expect(response.data![1].sortOrder, 2);
      expect(response.data![2].sortOrder, 3);
    });

    test('should include empty categories if requested', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters['includeEmpty'], 'true');

        return http.Response(
          jsonEncode({'success': true, 'data': []}),
          200,
        );
      });

      kbService = KnowledgeBaseService(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        client: mockClient,
      );

      await kbService.fetchCategories('chatbot_123', includeEmpty: true);
    });

    test('should handle fetch categories failure', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'error': 'Access denied',
          }),
          403,
        );
      });

      kbService = KnowledgeBaseService(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        client: mockClient,
      );

      final response = await kbService.fetchCategories('chatbot_123');

      expect(response.success, false);
      expect(response.error, 'Access denied');
    });
  });

  group('KnowledgeBaseService.fetchArticle', () {
    test('should successfully fetch single article', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, contains('/knowledge-base/articles/article_123'));

        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              '_id': 'article_123',
              'title': 'How to Use Feature X',
              'content': 'This guide explains how to...',
              'summary': 'A comprehensive guide',
              'categoryId': 'cat_1',
              'tags': ['feature', 'tutorial'],
              'viewCount': 150,
              'averageRating': 4.5,
              'ratingCount': 20,
              'readTimeMinutes': 5,
              'createdAt': '2024-01-01T00:00:00Z',
              'updatedAt': '2024-01-15T00:00:00Z',
              'relatedArticles': [
                {'_id': 'article_456', 'title': 'Related Guide'},
              ],
            },
          }),
          200,
        );
      });

      kbService = KnowledgeBaseService(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        client: mockClient,
      );

      final response = await kbService.fetchArticle('article_123');

      expect(response.success, true);
      expect(response.data, isNotNull);
      expect(response.data!.id, 'article_123');
      expect(response.data!.title, 'How to Use Feature X');
      expect(response.data!.tags, contains('feature'));
      expect(response.data!.averageRating, 4.5);
      expect(response.data!.relatedArticles, isNotNull);
      expect(response.data!.relatedArticles!.length, 1);
    });

    test('should handle article not found', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'error': 'Article not found',
          }),
          404,
        );
      });

      kbService = KnowledgeBaseService(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        client: mockClient,
      );

      final response = await kbService.fetchArticle('invalid_id');

      expect(response.success, false);
      expect(response.error, 'Article not found');
    });
  });

  group('KnowledgeBaseService.rateArticle', () {
    test('should successfully submit article rating', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, contains('/knowledge-base/articles/article_123/rate'));

        final body = jsonDecode(request.body);
        expect(body['articleId'], 'article_123');
        expect(body['rating'], 5);
        expect(body['visitorId'], 'visitor_456');

        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              '_id': 'rating_789',
              'articleId': 'article_123',
              'rating': 5,
              'visitorId': 'visitor_456',
              'createdAt': '2024-01-15T00:00:00Z',
            },
          }),
          201,
        );
      });

      kbService = KnowledgeBaseService(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        client: mockClient,
      );

      final response = await kbService.rateArticle('article_123', 5, 'visitor_456');

      expect(response.success, true);
      expect(response.data, isNotNull);
      expect(response.data!.rating, 5);
      expect(response.message, 'Thank you for your feedback!');
    });

    test('should include feedback if provided', () async {
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body);
        expect(body['feedback'], 'Very helpful article!');

        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'articleId': 'article_123',
              'rating': 5,
              'visitorId': 'visitor_456',
              'feedback': 'Very helpful article!',
              'createdAt': '2024-01-15T00:00:00Z',
            },
          }),
          200,
        );
      });

      kbService = KnowledgeBaseService(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        client: mockClient,
      );

      await kbService.rateArticle(
        'article_123',
        5,
        'visitor_456',
        feedback: 'Very helpful article!',
      );
    });

    test('should reject invalid rating values', () async {
      kbService = KnowledgeBaseService(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
      );

      final responseLow = await kbService.rateArticle('article_123', 0, 'visitor_456');
      expect(responseLow.success, false);
      expect(responseLow.error, 'Rating must be between 1 and 5');

      final responseHigh = await kbService.rateArticle('article_123', 6, 'visitor_456');
      expect(responseHigh.success, false);
      expect(responseHigh.error, 'Rating must be between 1 and 5');
    });

    test('should handle rating submission failure', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'error': 'Already rated this article',
          }),
          400,
        );
      });

      kbService = KnowledgeBaseService(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        client: mockClient,
      );

      final response = await kbService.rateArticle('article_123', 5, 'visitor_456');

      expect(response.success, false);
      expect(response.error, 'Already rated this article');
    });
  });

  group('KnowledgeBaseService.trackArticleView', () {
    test('should successfully track article view', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, contains('/knowledge-base/articles/article_123/view'));

        final body = jsonDecode(request.body);
        expect(body['articleId'], 'article_123');
        expect(body['visitorId'], 'visitor_456');
        expect(body['viewedAt'], isNotNull);

        return http.Response('', 204);
      });

      kbService = KnowledgeBaseService(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        client: mockClient,
      );

      final response = await kbService.trackArticleView('article_123', 'visitor_456');

      expect(response.success, true);
    });

    test('should include chat session ID if provided', () async {
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body);
        expect(body['chatSessionId'], 'session_789');

        return http.Response('', 200);
      });

      kbService = KnowledgeBaseService(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        client: mockClient,
      );

      await kbService.trackArticleView(
        'article_123',
        'visitor_456',
        chatSessionId: 'session_789',
      );
    });

    test('should silently handle view tracking failure', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'Internal error'}),
          500,
        );
      });

      kbService = KnowledgeBaseService(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        client: mockClient,
      );

      // View tracking failures should not propagate as errors
      final response = await kbService.trackArticleView('article_123', 'visitor_456');
      expect(response.success, true);
    });

    test('should silently handle network error', () async {
      final mockClient = MockClient((request) async {
        throw Exception('Network error');
      });

      kbService = KnowledgeBaseService(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        client: mockClient,
      );

      final response = await kbService.trackArticleView('article_123', 'visitor_456');
      expect(response.success, true);
    });
  });

  group('KnowledgeBaseService.searchArticles', () {
    test('should successfully search articles', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, contains('/knowledge-base/search'));
        expect(request.url.queryParameters['q'], 'how to');
        expect(request.url.queryParameters['botId'], 'chatbot_123');

        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {
                'article': {
                  '_id': 'article_1',
                  'title': 'How to Get Started',
                  'content': 'Learn how to...',
                  'createdAt': '2024-01-01T00:00:00Z',
                  'updatedAt': '2024-01-15T00:00:00Z',
                },
                'relevanceScore': 0.95,
                'matchedFields': ['title', 'content'],
                'highlightedTitle': '<em>How to</em> Get Started',
              },
            ],
          }),
          200,
        );
      });

      kbService = KnowledgeBaseService(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        client: mockClient,
      );

      final response = await kbService.searchArticles('chatbot_123', 'how to');

      expect(response.success, true);
      expect(response.data, isNotNull);
      expect(response.data!.length, 1);
      expect(response.data![0].relevanceScore, 0.95);
      expect(response.data![0].matchedFields, contains('title'));
    });

    test('should return empty results for empty query', () async {
      kbService = KnowledgeBaseService(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
      );

      final response = await kbService.searchArticles('chatbot_123', '   ');

      expect(response.success, true);
      expect(response.data, isEmpty);
    });

    test('should support pagination in search', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters['page'], '2');
        expect(request.url.queryParameters['limit'], '20');

        return http.Response(
          jsonEncode({'success': true, 'data': []}),
          200,
        );
      });

      kbService = KnowledgeBaseService(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        client: mockClient,
      );

      await kbService.searchArticles('chatbot_123', 'test', page: 2, limit: 20);
    });

    test('should handle search failure', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'error': 'Search service unavailable',
          }),
          503,
        );
      });

      kbService = KnowledgeBaseService(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        client: mockClient,
      );

      final response = await kbService.searchArticles('chatbot_123', 'test');

      expect(response.success, false);
      expect(response.error, 'Search service unavailable');
    });
  });

  group('KnowledgeBaseService.fetchPopularArticles', () {
    test('should fetch articles sorted by view count', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters['sortBy'], 'viewCount');
        expect(request.url.queryParameters['sortOrder'], 'desc');
        expect(request.url.queryParameters['limit'], '5');

        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'articles': [
                {
                  '_id': 'article_1',
                  'title': 'Most Popular',
                  'content': '...',
                  'viewCount': 1000,
                  'createdAt': '2024-01-01T00:00:00Z',
                  'updatedAt': '2024-01-15T00:00:00Z',
                },
              ],
              'page': 1,
              'limit': 5,
              'totalItems': 1,
            },
          }),
          200,
        );
      });

      kbService = KnowledgeBaseService(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        client: mockClient,
      );

      final response = await kbService.fetchPopularArticles('chatbot_123');

      expect(response.success, true);
      expect(response.data, isNotNull);
    });
  });

  group('KnowledgeBaseService.fetchRecentArticles', () {
    test('should fetch articles sorted by updated date', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters['sortBy'], 'updatedAt');
        expect(request.url.queryParameters['sortOrder'], 'desc');

        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'articles': [],
              'page': 1,
              'limit': 5,
              'totalItems': 0,
            },
          }),
          200,
        );
      });

      kbService = KnowledgeBaseService(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        client: mockClient,
      );

      await kbService.fetchRecentArticles('chatbot_123');
    });
  });

  group('KnowledgeBaseService.fetchVisitorRatings', () {
    test('should fetch visitor ratings', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, contains('/knowledge-base/visitor/ratings'));
        expect(request.url.queryParameters['visitorId'], 'visitor_456');

        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'article_1': 5,
              'article_2': 4,
              'article_3': {'rating': 3},
            },
          }),
          200,
        );
      });

      kbService = KnowledgeBaseService(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        client: mockClient,
      );

      final response = await kbService.fetchVisitorRatings('chatbot_123', 'visitor_456');

      expect(response.success, true);
      expect(response.data, isNotNull);
      expect(response.data!['article_1'], 5);
      expect(response.data!['article_2'], 4);
      expect(response.data!['article_3'], 3);
    });

    test('should handle fetch ratings failure', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'success': false, 'error': 'Not found'}),
          404,
        );
      });

      kbService = KnowledgeBaseService(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        client: mockClient,
      );

      final response = await kbService.fetchVisitorRatings('chatbot_123', 'visitor_456');

      expect(response.success, false);
    });
  });

  group('KBApiResponse', () {
    test('should create success response', () {
      final response = KBApiResponse<String>.success('data', message: 'OK');

      expect(response.success, true);
      expect(response.data, 'data');
      expect(response.message, 'OK');
      expect(response.error, isNull);
    });

    test('should create failure response', () {
      final response = KBApiResponse<String>.failure('Error occurred', message: 'Details');

      expect(response.success, false);
      expect(response.error, 'Error occurred');
      expect(response.message, 'Details');
      expect(response.data, isNull);
    });
  });

  group('KnowledgeBaseService.dispose', () {
    test('should dispose client', () {
      final mockClient = MockClient((request) async {
        return http.Response('', 200);
      });

      kbService = KnowledgeBaseService(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        client: mockClient,
      );

      expect(() => kbService.dispose(), returnsNormally);
    });
  });
}
