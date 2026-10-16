/// Knowledge Base models for Conferbot Flutter SDK
/// Provides article, category, and rating data structures
library;

import '../core/i18n/i18n.dart';

/// Knowledge Base Article model
/// Represents a single help article with content and metadata
class KnowledgeBaseArticle {
  final String id;
  final String title;
  final String content;
  final String? summary;
  final String? categoryId;
  final String? categoryName;
  final List<String> tags;
  final String? thumbnailUrl;
  final String? authorName;
  final int viewCount;
  final double? averageRating;
  final int ratingCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPublished;
  final int? readTimeMinutes;
  final List<RelatedArticle>? relatedArticles;

  const KnowledgeBaseArticle({
    required this.id,
    required this.title,
    required this.content,
    this.summary,
    this.categoryId,
    this.categoryName,
    this.tags = const [],
    this.thumbnailUrl,
    this.authorName,
    this.viewCount = 0,
    this.averageRating,
    this.ratingCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.isPublished = true,
    this.readTimeMinutes,
    this.relatedArticles,
  });

  /// Reads the server's article (`embed-server` knowledgeBaseArticleService):
  /// `description`, `coverImage`, `readingTime`, `publishedDate`, and
  /// `category` / `author` either populated (`{_id, name}`) or a bare id, as
  /// the articles inside a category are sent. `content` is HTML, and is empty
  /// when the list was sent without bodies (the socket payload): the article
  /// view fetches it on open.
  factory KnowledgeBaseArticle.fromJson(Map<String, dynamic> json) {
    final category = json['category'];
    final author = json['author'];
    return KnowledgeBaseArticle(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      summary: _string(json['summary']) ?? _string(json['description']) ?? _string(json['snippet']),
      categoryId: json['categoryId']?.toString() ??
          (category is Map ? category['_id']?.toString() : category is String ? category : null),
      categoryName: _string(json['categoryName']) ?? (category is Map ? _string(category['name']) : null),
      tags: _parseStringList(json['tags']),
      thumbnailUrl: _string(json['thumbnailUrl']) ?? _string(json['thumbnail']) ?? _string(json['coverImage']),
      authorName: _string(json['authorName']) ?? (author is Map ? _string(author['name']) : null),
      viewCount: _parseInt(json['viewCount']) ?? _parseInt(json['views']) ?? 0,
      averageRating: _parseDouble(json['averageRating']) ?? _parseDouble(json['rating']),
      ratingCount: _parseInt(json['ratingCount']) ?? _parseInt(json['totalRatings']) ?? _parseInt(json['ratings']) ?? 0,
      createdAt: _parseDateTime(json['createdAt']) ?? _parseDateTime(json['publishedDate']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updatedAt']) ?? DateTime.now(),
      isPublished: json['reviewStatus'] is String
          ? json['reviewStatus'] == 'published'
          : json['isPublished'] as bool? ?? json['published'] as bool? ?? true,
      readTimeMinutes: _parseInt(json['readTimeMinutes']) ?? _parseInt(json['readTime']) ?? _parseInt(json['readingTime']),
      relatedArticles: _parseRelatedArticles(json['relatedArticles']),
    );
  }

  /// False for an article from a list sent without bodies.
  bool get hasContent => content.trim().isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'title': title,
      'content': content,
      if (summary != null) 'summary': summary,
      if (categoryId != null) 'categoryId': categoryId,
      if (categoryName != null) 'categoryName': categoryName,
      'tags': tags,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      if (authorName != null) 'authorName': authorName,
      'viewCount': viewCount,
      if (averageRating != null) 'averageRating': averageRating,
      'ratingCount': ratingCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isPublished': isPublished,
      if (readTimeMinutes != null) 'readTimeMinutes': readTimeMinutes,
      if (relatedArticles != null)
        'relatedArticles': relatedArticles!.map((r) => r.toJson()).toList(),
    };
  }

  KnowledgeBaseArticle copyWith({
    String? id,
    String? title,
    String? content,
    String? summary,
    String? categoryId,
    String? categoryName,
    List<String>? tags,
    String? thumbnailUrl,
    String? authorName,
    int? viewCount,
    double? averageRating,
    int? ratingCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPublished,
    int? readTimeMinutes,
    List<RelatedArticle>? relatedArticles,
  }) {
    return KnowledgeBaseArticle(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      summary: summary ?? this.summary,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      tags: tags ?? this.tags,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      authorName: authorName ?? this.authorName,
      viewCount: viewCount ?? this.viewCount,
      averageRating: averageRating ?? this.averageRating,
      ratingCount: ratingCount ?? this.ratingCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPublished: isPublished ?? this.isPublished,
      readTimeMinutes: readTimeMinutes ?? this.readTimeMinutes,
      relatedArticles: relatedArticles ?? this.relatedArticles,
    );
  }

  /// Get formatted read time string
  String get formattedReadTime {
    if (readTimeMinutes == null) return '';
    if (readTimeMinutes! < 1) return t('sdk.kb.lessThanMinRead');
    return t('kb.minRead', {'n': readTimeMinutes});
  }

  /// Get formatted rating string
  String get formattedRating {
    if (averageRating == null) return t('sdk.kb.noRatings');
    return '${averageRating!.toStringAsFixed(1)} ($ratingCount)';
  }
}

/// Related article reference (lightweight version for lists)
class RelatedArticle {
  final String id;
  final String title;
  final String? summary;

  const RelatedArticle({
    required this.id,
    required this.title,
    this.summary,
  });

  factory RelatedArticle.fromJson(Map<String, dynamic> json) {
    return RelatedArticle(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'title': title,
      if (summary != null) 'summary': summary,
    };
  }
}

/// Knowledge Base Category model
/// Groups articles into logical categories
class KnowledgeBaseCategory {
  final String id;
  final String name;
  final String? description;
  final String? iconName;
  final String? iconUrl;
  final int articleCount;
  final int sortOrder;
  final String? parentId;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const KnowledgeBaseCategory({
    required this.id,
    required this.name,
    this.description,
    this.iconName,
    this.iconUrl,
    this.articleCount = 0,
    this.sortOrder = 0,
    this.parentId,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory KnowledgeBaseCategory.fromJson(Map<String, dynamic> json) {
    return KnowledgeBaseCategory(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      iconName: json['iconName'] as String? ?? json['icon'] as String?,
      iconUrl: json['iconUrl'] as String?,
      articleCount: _parseInt(json['articleCount']) ??
          _parseInt(json['count']) ??
          (json['articles'] is List ? (json['articles'] as List).length : 0),
      sortOrder: _parseInt(json['sortOrder']) ?? _parseInt(json['order']) ?? 0,
      parentId: json['parentId']?.toString(),
      isActive: json['isActive'] as bool? ?? json['active'] as bool? ?? true,
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      if (description != null) 'description': description,
      if (iconName != null) 'iconName': iconName,
      if (iconUrl != null) 'iconUrl': iconUrl,
      'articleCount': articleCount,
      'sortOrder': sortOrder,
      if (parentId != null) 'parentId': parentId,
      'isActive': isActive,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  KnowledgeBaseCategory copyWith({
    String? id,
    String? name,
    String? description,
    String? iconName,
    String? iconUrl,
    int? articleCount,
    int? sortOrder,
    String? parentId,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return KnowledgeBaseCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconName: iconName ?? this.iconName,
      iconUrl: iconUrl ?? this.iconUrl,
      articleCount: articleCount ?? this.articleCount,
      sortOrder: sortOrder ?? this.sortOrder,
      parentId: parentId ?? this.parentId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Article Rating model
/// Represents a user's rating of an article
class ArticleRating {
  final String? id;
  final String articleId;
  final int rating;
  final String visitorId;
  final String? feedback;
  final DateTime createdAt;

  const ArticleRating({
    this.id,
    required this.articleId,
    required this.rating,
    required this.visitorId,
    this.feedback,
    required this.createdAt,
  });

  factory ArticleRating.fromJson(Map<String, dynamic> json) {
    return ArticleRating(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      articleId: json['articleId']?.toString() ?? '',
      rating: _parseInt(json['rating']) ?? 0,
      visitorId: json['visitorId']?.toString() ?? '',
      feedback: json['feedback'] as String?,
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'articleId': articleId,
      'rating': rating,
      'visitorId': visitorId,
      if (feedback != null) 'feedback': feedback,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Check if the rating is positive (4-5 stars)
  bool get isPositive => rating >= 4;

  /// Check if the rating is negative (1-2 stars)
  bool get isNegative => rating <= 2;

  /// Check if the rating is neutral (3 stars)
  bool get isNeutral => rating == 3;
}

/// Article view tracking
class ArticleView {
  final String articleId;
  final String visitorId;
  final String? chatSessionId;
  final DateTime viewedAt;
  final int? readDurationSeconds;

  const ArticleView({
    required this.articleId,
    required this.visitorId,
    this.chatSessionId,
    required this.viewedAt,
    this.readDurationSeconds,
  });

  factory ArticleView.fromJson(Map<String, dynamic> json) {
    return ArticleView(
      articleId: json['articleId']?.toString() ?? '',
      visitorId: json['visitorId']?.toString() ?? '',
      chatSessionId: json['chatSessionId']?.toString(),
      viewedAt: _parseDateTime(json['viewedAt']) ?? DateTime.now(),
      readDurationSeconds: _parseInt(json['readDurationSeconds']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'articleId': articleId,
      'visitorId': visitorId,
      if (chatSessionId != null) 'chatSessionId': chatSessionId,
      'viewedAt': viewedAt.toIso8601String(),
      if (readDurationSeconds != null) 'readDurationSeconds': readDurationSeconds,
    };
  }
}

/// Search result with highlighted matches
class ArticleSearchResult {
  final KnowledgeBaseArticle article;
  final double relevanceScore;
  final List<String> matchedFields;
  final String? highlightedTitle;
  final String? highlightedContent;

  const ArticleSearchResult({
    required this.article,
    this.relevanceScore = 0.0,
    this.matchedFields = const [],
    this.highlightedTitle,
    this.highlightedContent,
  });

  factory ArticleSearchResult.fromJson(Map<String, dynamic> json) {
    return ArticleSearchResult(
      article: KnowledgeBaseArticle.fromJson(json['article'] as Map<String, dynamic>? ?? json),
      relevanceScore: _parseDouble(json['relevanceScore']) ?? _parseDouble(json['score']) ?? 0.0,
      matchedFields: _parseStringList(json['matchedFields']),
      highlightedTitle: json['highlightedTitle'] as String? ?? json['highlight']?['title'] as String?,
      highlightedContent: json['highlightedContent'] as String? ?? json['highlight']?['content'] as String?,
    );
  }
}

/// Pagination metadata for article lists
class ArticlePagination {
  final int page;
  final int limit;
  final int totalItems;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPreviousPage;

  const ArticlePagination({
    required this.page,
    required this.limit,
    required this.totalItems,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPreviousPage,
  });

  factory ArticlePagination.fromJson(Map<String, dynamic> json) {
    final page = _parseInt(json['page']) ?? _parseInt(json['currentPage']) ?? 1;
    final limit = _parseInt(json['limit']) ?? _parseInt(json['perPage']) ?? 10;
    final totalItems = _parseInt(json['totalItems']) ?? _parseInt(json['total']) ?? 0;
    final totalPages = _parseInt(json['totalPages']) ??
        (totalItems > 0 ? (totalItems / limit).ceil() : 0);

    return ArticlePagination(
      page: page,
      limit: limit,
      totalItems: totalItems,
      totalPages: totalPages,
      hasNextPage: json['hasNextPage'] as bool? ?? page < totalPages,
      hasPreviousPage: json['hasPreviousPage'] as bool? ?? page > 1,
    );
  }

  factory ArticlePagination.empty() {
    return const ArticlePagination(
      page: 1,
      limit: 10,
      totalItems: 0,
      totalPages: 0,
      hasNextPage: false,
      hasPreviousPage: false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'page': page,
      'limit': limit,
      'totalItems': totalItems,
      'totalPages': totalPages,
      'hasNextPage': hasNextPage,
      'hasPreviousPage': hasPreviousPage,
    };
  }
}

/// Response wrapper for paginated article list
class ArticleListResponse {
  final List<KnowledgeBaseArticle> articles;
  final ArticlePagination pagination;

  const ArticleListResponse({
    required this.articles,
    required this.pagination,
  });

  factory ArticleListResponse.fromJson(Map<String, dynamic> json) {
    // The server's list: {recentArticles, categories: [{..., articles}]}.
    if (json['categories'] is List || json['recentArticles'] is List) {
      final articles = KnowledgeBaseData.fromJson(json).allArticles;
      return ArticleListResponse(
        articles: articles,
        pagination: ArticlePagination(
          page: 1,
          limit: articles.length,
          totalItems: articles.length,
          totalPages: articles.isEmpty ? 0 : 1,
          hasNextPage: false,
          hasPreviousPage: false,
        ),
      );
    }
    final articlesData = json['articles'] as List<dynamic>? ??
        json['data'] as List<dynamic>? ??
        json['items'] as List<dynamic>? ?? [];

    return ArticleListResponse(
      articles: articlesData
          .map((a) => KnowledgeBaseArticle.fromJson(a as Map<String, dynamic>))
          .toList(),
      pagination: ArticlePagination.fromJson(
        json['pagination'] as Map<String, dynamic>? ??
        json['meta'] as Map<String, dynamic>? ??
        json,
      ),
    );
  }

  factory ArticleListResponse.empty() {
    return ArticleListResponse(
      articles: const [],
      pagination: ArticlePagination.empty(),
    );
  }
}

/// The help centre as the server sends it: categories, each with its
/// published articles, and the most recent articles.
///
/// The same shape arrives three ways: `fetched-chatbot-data.knowledgeBaseData`
/// on the socket (no bodies), `GET /mobile/chatbot/:id/kb` as
/// `data.knowledgeBaseData`, and `GET /mobile/knowledge-base/articles` as
/// `data` (both with bodies). [KnowledgeBaseData.fromJson] reads any of them.
class KnowledgeBaseData {
  /// The owner's categories in their dashboard order, empty ones left out.
  final List<KnowledgeBaseCategory> categories;

  /// Each category's published articles, by category id.
  final Map<String, List<KnowledgeBaseArticle>> articlesByCategory;

  /// The latest published articles (the server sends four).
  final List<KnowledgeBaseArticle> recentArticles;

  const KnowledgeBaseData({
    this.categories = const [],
    this.articlesByCategory = const {},
    this.recentArticles = const [],
  });

  static const empty = KnowledgeBaseData();

  factory KnowledgeBaseData.fromJson(Map<String, dynamic>? json) {
    if (json == null) return empty;
    // Accept the REST envelope ({success, data}) and the /kb wrapper.
    final data = json['data'];
    if (data is Map && !json.containsKey('categories') && !json.containsKey('recentArticles')) {
      return KnowledgeBaseData.fromJson(Map<String, dynamic>.from(data));
    }
    final wrapped = json['knowledgeBaseData'];
    if (wrapped is Map) return KnowledgeBaseData.fromJson(Map<String, dynamic>.from(wrapped));

    final categories = <KnowledgeBaseCategory>[];
    final byCategory = <String, List<KnowledgeBaseArticle>>{};
    for (final raw in (json['categories'] is List ? json['categories'] as List : const [])) {
      if (raw is! Map) continue;
      final category = KnowledgeBaseCategory.fromJson(Map<String, dynamic>.from(raw));
      if (category.id.isEmpty) continue;
      final articles = _publishedArticles(raw['articles'])
          .map((a) => a.copyWith(
                categoryId: a.categoryId ?? category.id,
                categoryName: a.categoryName ?? category.name,
              ))
          .toList();
      if (articles.isEmpty && raw['articles'] is List) continue;
      categories.add(category.copyWith(articleCount: articles.length));
      byCategory[category.id] = articles;
    }
    final names = {for (final c in categories) c.id: c.name};
    final recent = _publishedArticles(json['recentArticles'])
        .map((a) => a.categoryName == null && names[a.categoryId] != null
            ? a.copyWith(categoryName: names[a.categoryId])
            : a)
        .toList();
    return KnowledgeBaseData(
      categories: categories,
      articlesByCategory: byCategory,
      recentArticles: recent,
    );
  }

  /// No published article anywhere: the help centre counts as off.
  bool get isEmpty =>
      recentArticles.isEmpty && articlesByCategory.values.every((list) => list.isEmpty);

  bool get isNotEmpty => !isEmpty;

  /// Every article once: by category in the owner's order, then any recent
  /// article no category holds.
  List<KnowledgeBaseArticle> get allArticles {
    final seen = <String>{};
    final out = <KnowledgeBaseArticle>[];
    for (final category in categories) {
      for (final article in articlesByCategory[category.id] ?? const <KnowledgeBaseArticle>[]) {
        if (seen.add(article.id)) out.add(article);
      }
    }
    for (final article in recentArticles) {
      if (seen.add(article.id)) out.add(article);
    }
    return out;
  }

  /// One category's articles (all of them for null).
  List<KnowledgeBaseArticle> articlesIn(String? categoryId) =>
      categoryId == null ? allArticles : (articlesByCategory[categoryId] ?? const []);

  /// An article by id: in a category first, then the recent list
  /// (web `findArticle`, core/helpCentre.ts).
  KnowledgeBaseArticle? find(String? articleId) {
    if (articleId == null || articleId.isEmpty) return null;
    for (final category in categories) {
      for (final article in articlesByCategory[category.id] ?? const <KnowledgeBaseArticle>[]) {
        if (article.id == articleId) return article;
      }
    }
    for (final article in recentArticles) {
      if (article.id == articleId) return article;
    }
    return null;
  }

  /// The same help centre with one article's body filled in.
  KnowledgeBaseData withArticle(KnowledgeBaseArticle full) {
    KnowledgeBaseArticle merge(KnowledgeBaseArticle a) => a.id == full.id
        ? full.copyWith(categoryId: full.categoryId ?? a.categoryId, categoryName: full.categoryName ?? a.categoryName)
        : a;
    return KnowledgeBaseData(
      categories: categories,
      articlesByCategory: {
        for (final entry in articlesByCategory.entries) entry.key: entry.value.map(merge).toList(),
      },
      recentArticles: recentArticles.map(merge).toList(),
    );
  }
}

/// Published articles only, as the web widget keeps them (`publishedArticles`).
List<KnowledgeBaseArticle> _publishedArticles(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((m) => KnowledgeBaseArticle.fromJson(Map<String, dynamic>.from(m)))
      .where((a) => a.id.isNotEmpty && a.isPublished)
      .toList();
}

// Helper functions for parsing

String? _string(dynamic value) => value is String && value.isNotEmpty ? value : null;

List<String> _parseStringList(dynamic value) {
  if (value == null) return [];
  if (value is List) {
    return value.map((e) => e.toString()).toList();
  }
  return [];
}

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  return null;
}

List<RelatedArticle>? _parseRelatedArticles(dynamic value) {
  if (value == null) return null;
  if (value is List) {
    return value
        .map((e) => RelatedArticle.fromJson(e as Map<String, dynamic>))
        .toList();
  }
  return null;
}
