import 'dart:async';
import 'package:flutter/foundation.dart';
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

  KnowledgeBaseProvider({
    required this.botId,
    required String apiKey,
    String? baseUrl,
    String? visitorId,
  })  : _visitorId = visitorId,
        _service = KnowledgeBaseService(
          apiKey: apiKey,
          botId: botId,
          baseUrl: baseUrl ?? 'https://wdt.conferbot.com/api/v1/mobile',
        );

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
              orElse: () => KnowledgeBaseCategory(id: '', name: 'All'),
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
    await Future.wait([
      loadCategories(),
      loadArticles(),
    ]);

    // Load visitor ratings if visitor ID is set
    if (_visitorId != null) {
      await _loadVisitorRatings();
    }
  }

  /// Load categories
  Future<void> loadCategories() async {
    _isLoadingCategories = true;
    _categoriesError = null;
    notifyListeners();

    try {
      final response = await _service.fetchCategories(botId);

      if (response.success && response.data != null) {
        _categories = response.data!;
        _categoriesError = null;
      } else {
        _categoriesError = response.error ?? 'Failed to load categories';
      }
    } catch (e) {
      _categoriesError = e.toString();
      kbLogger.error('Error loading categories', e);
    }

    _isLoadingCategories = false;
    notifyListeners();
  }

  /// Load articles with optional filters
  Future<void> loadArticles({
    String? categoryId,
    bool refresh = false,
  }) async {
    if (_isLoadingArticles) return;

    _isLoadingArticles = true;
    _articlesError = null;
    if (refresh) {
      _articles.clear();
    }
    notifyListeners();

    try {
      final response = await _service.fetchArticles(
        botId,
        category: categoryId ?? _selectedCategoryId,
        page: 1,
        limit: 10,
      );

      if (response.success && response.data != null) {
        _articles = response.data!.articles;
        _pagination = response.data!.pagination;
        _articlesError = null;
      } else {
        _articlesError = response.error ?? 'Failed to load articles';
      }
    } catch (e) {
      _articlesError = e.toString();
      kbLogger.error('Error loading articles', e);
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

  /// Fetch a single article
  Future<void> fetchArticle(String articleId) async {
    _isLoadingArticle = true;
    _articleError = null;
    notifyListeners();

    try {
      final response = await _service.fetchArticle(articleId);

      if (response.success && response.data != null) {
        _selectedArticle = response.data;
        _articleError = null;

        // Add to navigation history
        _navigationHistory.add(articleId);

        // Track view
        if (_visitorId != null) {
          _service.trackArticleView(articleId, _visitorId!);
        }
      } else {
        _articleError = response.error ?? 'Article not found';
      }
    } catch (e) {
      _articleError = e.toString();
      kbLogger.error('Error fetching article', e);
    }

    _isLoadingArticle = false;
    notifyListeners();
  }

  /// Select an article from the list
  void selectArticle(KnowledgeBaseArticle article) {
    _selectedArticle = article;
    _navigationHistory.add(article.id);

    // Track view
    if (_visitorId != null) {
      _service.trackArticleView(article.id, _visitorId!);
    }

    notifyListeners();
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

      if (response.success && response.data != null) {
        _searchResults = response.data!;
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
      } else {
        _searchError = response.error ?? 'Search failed';
      }
    } catch (e) {
      _searchError = e.toString();
      kbLogger.error('Search error', e);
    }

    _isSearching = false;
    notifyListeners();
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
      _ratingError = 'Invalid rating';
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
        _ratingSuccess = response.message ?? 'Thank you for your feedback!';

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
        _ratingError = response.error ?? 'Failed to submit rating';
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
