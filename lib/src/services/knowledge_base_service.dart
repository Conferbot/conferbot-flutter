import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/knowledge_base.dart';
import '../utils/logger.dart';

/// API response wrapper for Knowledge Base operations
class KBApiResponse<T> {
  final bool success;
  final T? data;
  final String? error;
  final String? message;

  const KBApiResponse({
    required this.success,
    this.data,
    this.error,
    this.message,
  });

  factory KBApiResponse.success(T data, {String? message}) {
    return KBApiResponse<T>(
      success: true,
      data: data,
      message: message,
    );
  }

  factory KBApiResponse.failure(String error, {String? message}) {
    return KBApiResponse<T>(
      success: false,
      error: error,
      message: message,
    );
  }
}

/// Knowledge Base Service
/// Handles all API interactions for the knowledge base feature
class KnowledgeBaseService {
  final String apiKey;
  final String botId;
  final String baseUrl;
  final http.Client _client;

  KnowledgeBaseService({
    required this.apiKey,
    required this.botId,
    this.baseUrl = ConferBotConstants.defaultApiBaseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Standard headers for API requests
  Map<String, String> get _headers => {
        ConferBotConstants.headerApiKey: apiKey,
        ConferBotConstants.headerBotId: botId,
        ConferBotConstants.headerPlatform: ConferBotConstants.platformIdentifier,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  /// Fetch paginated list of articles with optional filters
  ///
  /// [chatbotId] - The chatbot/bot ID
  /// [category] - Optional category ID to filter by
  /// [search] - Optional search query
  /// [page] - Page number (1-indexed)
  /// [limit] - Items per page
  /// [sortBy] - Sort field (createdAt, updatedAt, viewCount, rating)
  /// [sortOrder] - Sort direction (asc, desc)
  Future<KBApiResponse<ArticleListResponse>> fetchArticles(
    String chatbotId, {
    String? category,
    String? search,
    int page = 1,
    int limit = 10,
    String? sortBy,
    String? sortOrder,
    List<String>? tags,
  }) async {
    try {
      final queryParams = <String, String>{
        'botId': chatbotId,
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (category != null && category.isNotEmpty) {
        queryParams['category'] = category;
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (sortBy != null && sortBy.isNotEmpty) {
        queryParams['sortBy'] = sortBy;
      }
      if (sortOrder != null && sortOrder.isNotEmpty) {
        queryParams['sortOrder'] = sortOrder;
      }
      if (tags != null && tags.isNotEmpty) {
        queryParams['tags'] = tags.join(',');
      }

      final uri = Uri.parse('$baseUrl/knowledge-base/articles')
          .replace(queryParameters: queryParams);

      kbLogger.debug('Fetching articles', uri.toString());

      final response = await _client
          .get(uri, headers: _headers)
          .timeout(Duration(milliseconds: ConferBotConstants.apiTimeout));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        final data = jsonData['data'] as Map<String, dynamic>? ?? jsonData;
        return KBApiResponse.success(ArticleListResponse.fromJson(data));
      } else {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        return KBApiResponse.failure(
          jsonData['error'] as String? ?? 'Failed to fetch articles',
          message: jsonData['message'] as String?,
        );
      }
    } catch (e) {
      kbLogger.error('Error fetching articles', e);
      return KBApiResponse.failure(e.toString());
    }
  }

  /// Fetch all categories for a chatbot
  ///
  /// [chatbotId] - The chatbot/bot ID
  /// [includeEmpty] - Whether to include categories with no articles
  Future<KBApiResponse<List<KnowledgeBaseCategory>>> fetchCategories(
    String chatbotId, {
    bool includeEmpty = false,
  }) async {
    try {
      final queryParams = <String, String>{
        'botId': chatbotId,
        'includeEmpty': includeEmpty.toString(),
      };

      final uri = Uri.parse('$baseUrl/knowledge-base/categories')
          .replace(queryParameters: queryParams);

      kbLogger.debug('Fetching categories', uri.toString());

      final response = await _client
          .get(uri, headers: _headers)
          .timeout(Duration(milliseconds: ConferBotConstants.apiTimeout));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        final categoriesData = jsonData['data'] as List<dynamic>? ??
            jsonData['categories'] as List<dynamic>? ?? [];

        final categories = categoriesData
            .map((c) => KnowledgeBaseCategory.fromJson(c as Map<String, dynamic>))
            .toList();

        // Sort by sortOrder
        categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

        return KBApiResponse.success(categories);
      } else {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        return KBApiResponse.failure(
          jsonData['error'] as String? ?? 'Failed to fetch categories',
          message: jsonData['message'] as String?,
        );
      }
    } catch (e) {
      kbLogger.error('Error fetching categories', e);
      return KBApiResponse.failure(e.toString());
    }
  }

  /// Fetch a single article by ID
  ///
  /// [articleId] - The article ID to fetch
  Future<KBApiResponse<KnowledgeBaseArticle>> fetchArticle(String articleId) async {
    try {
      final uri = Uri.parse('$baseUrl/knowledge-base/articles/$articleId');

      kbLogger.debug('Fetching article', uri.toString());

      final response = await _client
          .get(uri, headers: _headers)
          .timeout(Duration(milliseconds: ConferBotConstants.apiTimeout));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        final articleData = jsonData['data'] as Map<String, dynamic>? ?? jsonData;
        return KBApiResponse.success(KnowledgeBaseArticle.fromJson(articleData));
      } else if (response.statusCode == 404) {
        return KBApiResponse.failure('Article not found');
      } else {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        return KBApiResponse.failure(
          jsonData['error'] as String? ?? 'Failed to fetch article',
          message: jsonData['message'] as String?,
        );
      }
    } catch (e) {
      kbLogger.error('Error fetching article', e);
      return KBApiResponse.failure(e.toString());
    }
  }

  /// Rate an article
  ///
  /// [articleId] - The article ID to rate
  /// [rating] - Rating value (1-5)
  /// [visitorId] - The visitor/user ID
  /// [feedback] - Optional feedback text
  Future<KBApiResponse<ArticleRating>> rateArticle(
    String articleId,
    int rating,
    String visitorId, {
    String? feedback,
  }) async {
    try {
      if (rating < 1 || rating > 5) {
        return KBApiResponse.failure('Rating must be between 1 and 5');
      }

      final uri = Uri.parse('$baseUrl/knowledge-base/articles/$articleId/rate');

      final body = {
        'articleId': articleId,
        'rating': rating,
        'visitorId': visitorId,
        if (feedback != null && feedback.isNotEmpty) 'feedback': feedback,
      };

      kbLogger.debug('Rating article', uri.toString());

      final response = await _client
          .post(
            uri,
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(Duration(milliseconds: ConferBotConstants.apiTimeout));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        final ratingData = jsonData['data'] as Map<String, dynamic>? ?? jsonData;

        return KBApiResponse.success(
          ArticleRating.fromJson(ratingData),
          message: 'Thank you for your feedback!',
        );
      } else {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        return KBApiResponse.failure(
          jsonData['error'] as String? ?? 'Failed to submit rating',
          message: jsonData['message'] as String?,
        );
      }
    } catch (e) {
      kbLogger.error('Error rating article', e);
      return KBApiResponse.failure(e.toString());
    }
  }

  /// Track an article view
  ///
  /// [articleId] - The article ID viewed
  /// [visitorId] - The visitor/user ID
  /// [chatSessionId] - Optional chat session ID
  Future<KBApiResponse<void>> trackArticleView(
    String articleId,
    String visitorId, {
    String? chatSessionId,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/knowledge-base/articles/$articleId/view');

      final body = {
        'articleId': articleId,
        'visitorId': visitorId,
        if (chatSessionId != null) 'chatSessionId': chatSessionId,
        'viewedAt': DateTime.now().toIso8601String(),
      };

      kbLogger.debug('Tracking article view', uri.toString());

      final response = await _client
          .post(
            uri,
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(Duration(milliseconds: ConferBotConstants.apiTimeout));

      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) {
        return const KBApiResponse(success: true);
      } else {
        // View tracking failures should be silent
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        kbLogger.warning('View tracking failed', jsonData['error']);
        return const KBApiResponse(success: true); // Don't fail for analytics
      }
    } catch (e) {
      kbLogger.warning('Error tracking view', e);
      return const KBApiResponse(success: true); // Don't fail for analytics
    }
  }

  /// Search articles with full-text search
  ///
  /// [chatbotId] - The chatbot/bot ID
  /// [query] - Search query string
  /// [page] - Page number
  /// [limit] - Items per page
  Future<KBApiResponse<List<ArticleSearchResult>>> searchArticles(
    String chatbotId,
    String query, {
    int page = 1,
    int limit = 10,
  }) async {
    try {
      if (query.trim().isEmpty) {
        return KBApiResponse.success(const []);
      }

      final queryParams = <String, String>{
        'botId': chatbotId,
        'q': query,
        'page': page.toString(),
        'limit': limit.toString(),
      };

      final uri = Uri.parse('$baseUrl/knowledge-base/search')
          .replace(queryParameters: queryParams);

      kbLogger.debug('Searching articles', uri.toString());

      final response = await _client
          .get(uri, headers: _headers)
          .timeout(Duration(milliseconds: ConferBotConstants.apiTimeout));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        final resultsData = jsonData['data'] as List<dynamic>? ??
            jsonData['results'] as List<dynamic>? ?? [];

        final results = resultsData
            .map((r) => ArticleSearchResult.fromJson(r as Map<String, dynamic>))
            .toList();

        return KBApiResponse.success(results);
      } else {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        return KBApiResponse.failure(
          jsonData['error'] as String? ?? 'Search failed',
          message: jsonData['message'] as String?,
        );
      }
    } catch (e) {
      kbLogger.error('Error searching articles', e);
      return KBApiResponse.failure(e.toString());
    }
  }

  /// Get popular/trending articles
  ///
  /// [chatbotId] - The chatbot/bot ID
  /// [limit] - Number of articles to fetch
  Future<KBApiResponse<List<KnowledgeBaseArticle>>> fetchPopularArticles(
    String chatbotId, {
    int limit = 5,
  }) async {
    return fetchArticles(
      chatbotId,
      limit: limit,
      sortBy: 'viewCount',
      sortOrder: 'desc',
    ).then((response) {
      if (response.success && response.data != null) {
        return KBApiResponse.success(response.data!.articles);
      }
      return KBApiResponse.failure(response.error ?? 'Failed to fetch popular articles');
    });
  }

  /// Get recently updated articles
  ///
  /// [chatbotId] - The chatbot/bot ID
  /// [limit] - Number of articles to fetch
  Future<KBApiResponse<List<KnowledgeBaseArticle>>> fetchRecentArticles(
    String chatbotId, {
    int limit = 5,
  }) async {
    return fetchArticles(
      chatbotId,
      limit: limit,
      sortBy: 'updatedAt',
      sortOrder: 'desc',
    ).then((response) {
      if (response.success && response.data != null) {
        return KBApiResponse.success(response.data!.articles);
      }
      return KBApiResponse.failure(response.error ?? 'Failed to fetch recent articles');
    });
  }

  /// Get visitor's previously rated articles
  ///
  /// [chatbotId] - The chatbot/bot ID
  /// [visitorId] - The visitor/user ID
  Future<KBApiResponse<Map<String, int>>> fetchVisitorRatings(
    String chatbotId,
    String visitorId,
  ) async {
    try {
      final queryParams = <String, String>{
        'botId': chatbotId,
        'visitorId': visitorId,
      };

      final uri = Uri.parse('$baseUrl/knowledge-base/visitor/ratings')
          .replace(queryParameters: queryParams);

      final response = await _client
          .get(uri, headers: _headers)
          .timeout(Duration(milliseconds: ConferBotConstants.apiTimeout));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        final ratingsData = jsonData['data'] as Map<String, dynamic>? ?? {};

        final ratings = <String, int>{};
        ratingsData.forEach((key, value) {
          if (value is int) {
            ratings[key] = value;
          } else if (value is Map && value['rating'] is int) {
            ratings[key] = value['rating'] as int;
          }
        });

        return KBApiResponse.success(ratings);
      } else {
        return KBApiResponse.failure('Failed to fetch ratings');
      }
    } catch (e) {
      kbLogger.error('Error fetching visitor ratings', e);
      return KBApiResponse.failure(e.toString());
    }
  }

  /// Dispose the HTTP client
  void dispose() {
    _client.close();
  }
}
