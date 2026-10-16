import 'dart:async';
import 'package:flutter/foundation.dart';
import '../config/constants.dart';
import '../core/i18n/i18n.dart';
import '../models/knowledge_base.dart';
import '../services/knowledge_base_service.dart';
import '../utils/logger.dart';

/// Knowledge Base Provider for state management
/// Manages articles, categories, search, and user interactions
class KnowledgeBaseProvider with ChangeNotifier {
  final KnowledgeBaseService _service;
  final String botId;
  String? _visitorId;

  // Articles state
  List<KnowledgeBaseArticle> _articles = [];
  ArticlePagination _pagination = ArticlePagination.empty();
  bool _isLoadingArticles = false;
  bool _isLoadingMore = false;
  String? _articlesError;

  // Categories state
  List<KnowledgeBaseCategory> _categories = [];
  bool _isLoadingCategories = false;
  String? _categoriesError;
  String? _selectedCategoryId;

  // Selected article state
  KnowledgeBaseArticle? _selectedArticle;
  bool _isLoadingArticle = false;
  String? _articleError;

  // Search state
  String _searchQuery = '';
  List<ArticleSearchResult> _searchResults = [];
  bool _isSearching = false;
  String? _searchError;
  Timer? _searchDebounce;

  // Rating state
  Map<String, int> _visitorRatings = {};
  bool _isRating = false;
  String? _ratingError;
  String? _ratingSuccess;

  // Navigation history for back navigation
  final List<String> _navigationHistory = [];

  // The help centre as the server sent it (categories with their articles,
  // recent articles). Seeded from the socket's fetched-chatbot-data when the
  // chat has it (no bodies), else loaded over REST (bodies included).
  KnowledgeBaseData _data;
  bool _dataLoaded;
  Future<bool>? _loadingData;

  /// Whether the owner shows "Recent articles" (`!hideRecentArticles`).
  bool showRecentArticles;

  KnowledgeBaseProvider({
    required this.botId,
    required String apiKey,
    String? baseUrl,
    String? visitorId,
    KnowledgeBaseData? initialData,
    this.showRecentArticles = true,
    KnowledgeBaseService? service,
  })  : _visitorId = visitorId,
        _data = initialData ?? KnowledgeBaseData.empty,
        _dataLoaded = initialData != null && initialData.isNotEmpty,
        _service = service ??
            KnowledgeBaseService(
              apiKey: apiKey,
              botId: botId,
              // The app's configured server (ConferBotEndpoints), never a
              // hard-coded production URL.
              baseUrl: baseUrl ?? ConferBotEndpoints.apiBaseUrl,
            );

  /// The server this help centre reads from.
  String get baseUrl => _service.baseUrl;

  /// The help centre data in use.
  KnowledgeBaseData get data => _data;

  /// Replace the seed (a newer fetched-chatbot-data).
  void setInitialData(KnowledgeBaseData data) {
    if (data.isEmpty) return;
    _data = data;
    _dataLoaded = true;
    _categories = data.categories;
    _articles = data.articlesIn(_selectedCategoryId);
    notifyListeners();
  }

  /// The Recent articles list: empty when the owner hides it.
  List<KnowledgeBaseArticle> get recentArticles =>
      showRecentArticles ? _data.recentArticles : const [];

  /// Loads the help centre once over REST when no seed was given.
  Future<bool> _ensureData({bool force = false}) {
    if (_dataLoaded && !force) return Future.value(true);
    return _loadingData ??= () async {
      try {
        final response = await _service.fetchHelpCentre();
        if (response.success && response.data != null) {
          _data = response.data!;
          _dataLoaded = true;
          return true;
        }
        _articlesError = response.error ?? t('sdk.kb.articlesLoadFailed');
        return false;
      } finally {
        _loadingData = null;
      }
    }();
  }

  // Getters
  List<KnowledgeBaseArticle> get articles => List.unmodifiable(_articles);
  ArticlePagination get pagination => _pagination;
  bool get isLoadingArticles => _isLoadingArticles;
  bool get isLoadingMore => _isLoadingMore;
  String? get articlesError => _articlesError;

  List<KnowledgeBaseCategory> get categories => List.unmodifiable(_categories);
  bool get isLoadingCategories => _isLoadingCategories;
  String? get categoriesError => _categoriesError;
  String? get selectedCategoryId => _selectedCategoryId;
  KnowledgeBaseCategory? get selectedCategory =>
      _selectedCategoryId != null
          ? _categories.firstWhere(
              (c) => c.id == _selectedCategoryId,
              orElse: () => KnowledgeBaseCategory(id: '', name: t('sdk.kb.all')),
            )
          : null;

  KnowledgeBaseArticle? get selectedArticle => _selectedArticle;
  bool get isLoadingArticle => _isLoadingArticle;
  String? get articleError => _articleError;

  String get searchQuery => _searchQuery;
  List<ArticleSearchResult> get searchResults => List.unmodifiable(_searchResults);
  bool get isSearching => _isSearching;
  String? get searchError => _searchError;
  bool get hasSearchQuery => _searchQuery.trim().isNotEmpty;

  Map<String, int> get visitorRatings => Map.unmodifiable(_visitorRatings);
  bool get isRating => _isRating;
  String? get ratingError => _ratingError;
  String? get ratingSuccess => _ratingSuccess;

  bool get hasError => _articlesError != null || _categoriesError != null || _articleError != null;
  bool get isLoading => _isLoadingArticles || _isLoadingCategories || _isLoadingArticle;

  bool get canGoBack => _navigationHistory.isNotEmpty;
  bool get hasMoreArticles => _pagination.hasNextPage;

  /// Set visitor ID for tracking and ratings
  void setVisitorId(String visitorId) {
    _visitorId = visitorId;
  }

  /// Initialize the knowledge base (load categories and initial articles)
  Future<void> initialize() async {
    _isLoadingArticles = !_dataLoaded;
    _isLoadingCategories = !_dataLoaded;
    _articlesError = null;
    _categoriesError = null;
    notifyListeners();

    final ok = await _ensureData();
    if (ok) {
      _categories = _data.categories;
      _articles = _data.articlesIn(_selectedCategoryId);
      _pagination = _onePage(_articles.length);
    } else {
      _categoriesError = _articlesError;
    }
    _isLoadingArticles = false;
    _isLoadingCategories = false;
    notifyListeners();

    // Load visitor ratings if visitor ID is set
    if (_visitorId != null && _visitorId!.isNotEmpty) {
      await _loadVisitorRatings();
    }
  }

  ArticlePagination _onePage(int count) => ArticlePagination(
        page: 1,
        limit: count,
        totalItems: count,
        totalPages: count == 0 ? 0 : 1,
        hasNextPage: false,
        hasPreviousPage: false,
      );

  /// Load categories
  Future<void> loadCategories() async {
    _isLoadingCategories = true;
    _categoriesError = null;
    notifyListeners();

    if (await _ensureData()) {
      _categories = _data.categories;
    } else {
      _categoriesError = _articlesError ?? t('sdk.kb.categoriesLoadFailed');
    }

    _isLoadingCategories = false;
    notifyListeners();
  }

  /// Load articles with optional filters. The server sends the whole help
  /// centre at once, so a category is filtered here.
  Future<void> loadArticles({
    String? categoryId,
    bool refresh = false,
  }) async {
    if (_isLoadingArticles && _dataLoaded) return;

    _isLoadingArticles = true;
    _articlesError = null;
    notifyListeners();

    if (await _ensureData(force: refresh && _data.isEmpty)) {
      _articles = _data.articlesIn(categoryId ?? _selectedCategoryId);
      _pagination = _onePage(_articles.length);
    } else {
      _articlesError ??= t('sdk.kb.articlesLoadFailed');
    }

    _isLoadingArticles = false;
    notifyListeners();
  }

  /// Load more articles (pagination)
  Future<void> loadMoreArticles() async {
    if (_isLoadingMore || !_pagination.hasNextPage) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final response = await _service.fetchArticles(
        botId,
        category: _selectedCategoryId,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        page: _pagination.page + 1,
        limit: _pagination.limit,
      );

      if (response.success && response.data != null) {
        _articles.addAll(response.data!.articles);
        _pagination = response.data!.pagination;
      }
    } catch (e) {
      kbLogger.error('Error loading more articles', e);
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  /// Select a category and reload articles
  Future<void> selectCategory(String? categoryId) async {
    if (_selectedCategoryId == categoryId) return;

    _selectedCategoryId = categoryId;
    _searchQuery = '';
    _searchResults.clear();
    notifyListeners();

    await loadArticles(categoryId: categoryId, refresh: true);
  }

  /// Clear category selection
  Future<void> clearCategorySelection() async {
    await selectCategory(null);
  }

  /// Open an article by id: from the help centre when it is there (its
  /// body fetched if the list came without), else from the server, which
  /// answers for this bot's published articles only.
  Future<void> fetchArticle(String articleId) async {
    final known = _data.find(articleId);
    if (known != null) {
      selectArticle(known);
      return;
    }
    await _loadBody(articleId, select: true);
  }

  /// Open an article by id, as an AI source or a rich article card asks.
  Future<void> openArticle(String articleId) async {
    if (!_dataLoaded) await _ensureData();
    await fetchArticle(articleId);
  }

  Future<void> _loadBody(String articleId, {bool select = false}) async {
    _isLoadingArticle = true;
    _articleError = null;
    notifyListeners();

    try {
      final response = await _service.fetchArticle(articleId);

      if (response.success && response.data != null) {
        final full = response.data!;
        _data = _data.withArticle(full);
        final merged = _data.find(articleId) ?? full;
        if (select || _selectedArticle?.id == articleId) {
          if (_selectedArticle?.id != articleId) {
            _navigationHistory.add(articleId);
            _trackView(articleId);
          }
          _selectedArticle = merged;
        }
        _articles = _articles.map((a) => a.id == articleId ? merged : a).toList();
      } else {
        _articleError = response.error ?? t('sdk.kb.articleNotFound');
      }
    } catch (e) {
      _articleError = e.toString();
      kbLogger.error('Error fetching article', e);
    }

    _isLoadingArticle = false;
    notifyListeners();
  }

  void _trackView(String articleId) {
    if (_visitorId != null && _visitorId!.isNotEmpty) {
      _service.trackArticleView(articleId, _visitorId!);
    }
  }

  /// Select an article from the list. A list sent without bodies has the
  /// title and description only: the body is fetched now.
  void selectArticle(KnowledgeBaseArticle article) {
    _selectedArticle = article;
    _articleError = null;
    _navigationHistory.add(article.id);
    _trackView(article.id);
    notifyListeners();

    if (!article.hasContent) _loadBody(article.id);
  }

  /// Clear selected article (go back to list)
  void clearSelectedArticle() {
    _selectedArticle = null;
    _articleError = null;
    if (_navigationHistory.isNotEmpty) {
      _navigationHistory.removeLast();
    }
    notifyListeners();
  }

  /// Navigate back
  bool goBack() {
    if (_selectedArticle != null) {
      clearSelectedArticle();
      return true;
    }
    if (_selectedCategoryId != null) {
      selectCategory(null);
      return true;
    }
    if (_searchQuery.isNotEmpty) {
      clearSearch();
      return true;
    }
    return false;
  }

  /// Search articles with debouncing
  void search(String query) {
    _searchQuery = query;
    _searchError = null;

    // Cancel previous debounce timer
    _searchDebounce?.cancel();

    if (query.trim().isEmpty) {
      _searchResults.clear();
      _isSearching = false;
      notifyListeners();
      loadArticles(refresh: true);
      return;
    }

    notifyListeners();

    // Debounce search for 300ms
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  /// Perform the actual search
  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    _isSearching = true;
    notifyListeners();

    try {
      final response = await _service.searchArticles(botId, query);
      // Titles and descriptions match here at once; the server adds matches
      // inside article bodies (as the web widget merges them).
      final local = _localMatches(query);

      if (response.success && response.data != null) {
        final seen = local.map((r) => r.article.id).toSet();
        _searchResults = [
          ...local,
          ...response.data!.where((r) => seen.add(r.article.id)),
        ];
        _searchError = null;

        // Also update articles list with search results
        _articles = _searchResults.map((r) => r.article).toList();
        _pagination = ArticlePagination(
          page: 1,
          limit: _searchResults.length,
          totalItems: _searchResults.length,
          totalPages: 1,
          hasNextPage: false,
          hasPreviousPage: false,
        );
      } else if (local.isNotEmpty) {
        _searchResults = local;
        _articles = local.map((r) => r.article).toList();
        _pagination = _onePage(_articles.length);
      } else {
        _searchError = response.error ?? t('sdk.kb.searchFailed');
      }
    } catch (e) {
      _searchError = e.toString();
      kbLogger.error('Search error', e);
    }

    _isSearching = false;
    notifyListeners();
  }

  List<ArticleSearchResult> _localMatches(String query) {
    final terms = query.toLowerCase().split(RegExp(r'\s+')).where((t) => t.length >= 2).toList();
    if (terms.isEmpty) return [];
    return _data.allArticles
        .where((a) {
          final text = '${a.title} ${a.summary ?? ''}'.toLowerCase();
          return terms.every(text.contains);
        })
        .map((a) => ArticleSearchResult(article: a))
        .toList();
  }

  /// Clear search and reload all articles
  Future<void> clearSearch() async {
    _searchQuery = '';
    _searchResults.clear();
    _searchError = null;
    _searchDebounce?.cancel();
    notifyListeners();

    await loadArticles(refresh: true);
  }

  /// Rate an article
  Future<bool> rateArticle(String articleId, int rating, {String? feedback}) async {
    if (_visitorId == null) {
      _ratingError = 'Visitor ID not set';
      notifyListeners();
      return false;
    }

    if (rating < 1 || rating > 5) {
      _ratingError = t('sdk.kb.invalidRating');
      notifyListeners();
      return false;
    }

    _isRating = true;
    _ratingError = null;
    _ratingSuccess = null;
    notifyListeners();

    try {
      final response = await _service.rateArticle(
        articleId,
        rating,
        _visitorId!,
        feedback: feedback,
      );

      if (response.success) {
        _visitorRatings[articleId] = rating;
        _ratingSuccess = response.message ?? t('csat.thanks');

        // Update selected article if it matches
        if (_selectedArticle?.id == articleId) {
          _selectedArticle = _selectedArticle!.copyWith(
            averageRating: _calculateNewRating(_selectedArticle!, rating),
            ratingCount: _selectedArticle!.ratingCount + 1,
          );
        }

        _isRating = false;
        notifyListeners();
        return true;
      } else {
        _ratingError = response.error ?? t('sdk.kb.rateFailed');
      }
    } catch (e) {
      _ratingError = e.toString();
      kbLogger.error('Rating error', e);
    }

    _isRating = false;
    notifyListeners();
    return false;
  }

  /// Calculate new average rating
  double _calculateNewRating(KnowledgeBaseArticle article, int newRating) {
    final currentAvg = article.averageRating ?? 0;
    final count = article.ratingCount;
    return ((currentAvg * count) + newRating) / (count + 1);
  }

  /// Get visitor's rating for an article
  int? getArticleRating(String articleId) {
    return _visitorRatings[articleId];
  }

  /// Check if visitor has rated an article
  bool hasRatedArticle(String articleId) {
    return _visitorRatings.containsKey(articleId);
  }

  /// Load visitor's previous ratings
  Future<void> _loadVisitorRatings() async {
    if (_visitorId == null) return;

    try {
      final response = await _service.fetchVisitorRatings(botId, _visitorId!);
      if (response.success && response.data != null) {
        _visitorRatings = response.data!;
        notifyListeners();
      }
    } catch (e) {
      kbLogger.error('Error loading visitor ratings', e);
    }
  }

  /// Clear rating messages
  void clearRatingMessages() {
    _ratingError = null;
    _ratingSuccess = null;
    notifyListeners();
  }

  /// Clear all errors
  void clearErrors() {
    _articlesError = null;
    _categoriesError = null;
    _articleError = null;
    _searchError = null;
    _ratingError = null;
    notifyListeners();
  }

  /// Refresh all data
  Future<void> refresh() async {
    _selectedArticle = null;
    _selectedCategoryId = null;
    _searchQuery = '';
    _searchResults.clear();
    _navigationHistory.clear();
    clearErrors();
    // Pull to refresh asks the server again.
    _dataLoaded = false;

    await initialize();
  }

  /// Get articles by category (from loaded list)
  List<KnowledgeBaseArticle> getArticlesByCategory(String categoryId) {
    return _articles.where((a) => a.categoryId == categoryId).toList();
  }

  /// Get category by ID
  KnowledgeBaseCategory? getCategoryById(String categoryId) {
    try {
      return _categories.firstWhere((c) => c.id == categoryId);
    } catch (_) {
      return null;
    }
  }

  /// Filter articles by tags
  List<KnowledgeBaseArticle> filterByTags(List<String> tags) {
    if (tags.isEmpty) return _articles;
    return _articles.where((a) => tags.any((t) => a.tags.contains(t))).toList();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _service.dispose();
    super.dispose();
  }
}
