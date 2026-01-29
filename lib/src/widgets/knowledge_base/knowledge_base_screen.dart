import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/knowledge_base.dart';
import '../../providers/knowledge_base_provider.dart';
import '../../theme/conferbot_theme.dart';
import '../../theme/default_theme.dart';
import 'article_detail.dart';
import 'article_list.dart';
import 'category_chips.dart';
import 'search_bar.dart';

/// Main Knowledge Base screen with search, categories, and article list
class KnowledgeBaseScreen extends StatefulWidget {
  final String? title;
  final String? searchPlaceholder;
  final VoidCallback? onClose;
  final ValueChanged<KnowledgeBaseArticle>? onArticleInsertToChat;
  final bool showCategories;
  final bool showSearch;
  final ConferBotTheme? theme;

  const KnowledgeBaseScreen({
    super.key,
    this.title,
    this.searchPlaceholder,
    this.onClose,
    this.onArticleInsertToChat,
    this.showCategories = true,
    this.showSearch = true,
    this.theme,
  });

  @override
  State<KnowledgeBaseScreen> createState() => _KnowledgeBaseScreenState();
}

class _KnowledgeBaseScreenState extends State<KnowledgeBaseScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<KnowledgeBaseProvider>();
      if (provider.articles.isEmpty && !provider.isLoading) {
        provider.initialize();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = widget.theme ?? defaultTheme;
    final provider = context.watch<KnowledgeBaseProvider>();

    // Show article detail if one is selected
    if (provider.selectedArticle != null) {
      return ArticleDetail(
        article: provider.selectedArticle!,
        onBack: () => provider.clearSelectedArticle(),
        onRelatedArticleTap: (article) => provider.fetchArticle(article.id),
        onRate: (rating, {String? feedback}) =>
            provider.rateArticle(provider.selectedArticle!.id, rating, feedback: feedback),
        userRating: provider.getArticleRating(provider.selectedArticle!.id),
        isRating: provider.isRating,
        ratingError: provider.ratingError,
        ratingSuccess: provider.ratingSuccess,
        onInsertToChat: widget.onArticleInsertToChat != null
            ? () => widget.onArticleInsertToChat!(provider.selectedArticle!)
            : null,
        theme: effectiveTheme,
      );
    }

    return Scaffold(
      backgroundColor: effectiveTheme.colors.background,
      body: Column(
        children: [
          _buildHeader(effectiveTheme, provider),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => provider.refresh(),
              color: effectiveTheme.colors.primary,
              child: _buildContent(effectiveTheme, provider),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ConferBotTheme theme, KnowledgeBaseProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colors.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colors.border,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title bar
            Container(
              height: theme.layout.headerHeight,
              padding: EdgeInsets.symmetric(horizontal: theme.spacing.md),
              child: Row(
                children: [
                  if (provider.canGoBack || widget.onClose != null)
                    IconButton(
                      icon: Icon(
                        provider.canGoBack ? Icons.arrow_back : Icons.close,
                        color: theme.colors.text,
                      ),
                      onPressed: () {
                        if (provider.canGoBack) {
                          provider.goBack();
                        } else {
                          widget.onClose?.call();
                        }
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  SizedBox(width: theme.spacing.md),
                  Expanded(
                    child: Text(
                      _getTitle(provider),
                      style: TextStyle(
                        fontSize: theme.typography.fontSizeLg,
                        fontWeight: theme.typography.fontWeightSemiBold,
                        color: theme.colors.text,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (provider.hasSearchQuery)
                    TextButton(
                      onPressed: () => provider.clearSearch(),
                      child: Text(
                        'Clear',
                        style: TextStyle(
                          color: theme.colors.primary,
                          fontSize: theme.typography.fontSizeSm,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Search bar
            if (widget.showSearch)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  theme.spacing.md,
                  0,
                  theme.spacing.md,
                  theme.spacing.sm,
                ),
                child: KBSearchBar(
                  placeholder: widget.searchPlaceholder ?? 'Search articles...',
                  initialValue: provider.searchQuery,
                  onSearch: (query) => provider.search(query),
                  onClear: () => provider.clearSearch(),
                  theme: theme,
                ),
              ),
            // Category chips
            if (widget.showCategories && provider.categories.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: theme.spacing.sm),
                child: CategoryChips(
                  categories: provider.categories,
                  selectedCategoryId: provider.selectedCategoryId,
                  onCategorySelected: (categoryId) =>
                      provider.selectCategory(categoryId),
                  isLoading: provider.isLoadingCategories,
                  theme: theme,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ConferBotTheme theme, KnowledgeBaseProvider provider) {
    // Show error state
    if (provider.hasError && provider.articles.isEmpty) {
      return _buildErrorState(theme, provider);
    }

    // Show loading state
    if (provider.isLoadingArticles && provider.articles.isEmpty) {
      return ArticleList(
        articles: const [],
        onArticleTap: (_) {},
        isLoading: true,
        theme: theme,
      );
    }

    // Show search results or article list
    return ArticleList(
      articles: provider.articles,
      onArticleTap: (article) => provider.selectArticle(article),
      isLoading: provider.isLoadingArticles,
      isLoadingMore: provider.isLoadingMore,
      hasMore: provider.hasMoreArticles,
      onLoadMore: () => provider.loadMoreArticles(),
      emptyMessage: provider.hasSearchQuery
          ? 'No articles found for "${provider.searchQuery}"'
          : provider.selectedCategoryId != null
              ? 'No articles in this category'
              : 'No articles available',
      theme: theme,
    );
  }

  Widget _buildErrorState(ConferBotTheme theme, KnowledgeBaseProvider provider) {
    final error = provider.articlesError ?? provider.categoriesError ?? 'An error occurred';

    return Center(
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colors.error.withOpacity(0.5),
            ),
            SizedBox(height: theme.spacing.md),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: theme.typography.fontSizeLg,
                fontWeight: theme.typography.fontWeightMedium,
                color: theme.colors.text,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: theme.spacing.sm),
            Text(
              error,
              style: TextStyle(
                fontSize: theme.typography.fontSizeSm,
                color: theme.colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: theme.spacing.lg),
            ElevatedButton.icon(
              onPressed: () => provider.refresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colors.primary,
                foregroundColor: theme.colors.surface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTitle(KnowledgeBaseProvider provider) {
    if (provider.hasSearchQuery) {
      return 'Search Results';
    }
    if (provider.selectedCategory != null) {
      return provider.selectedCategory!.name;
    }
    return widget.title ?? 'Help Center';
  }
}

/// Standalone Knowledge Base widget that creates its own provider
class KnowledgeBaseWidget extends StatelessWidget {
  final String apiKey;
  final String botId;
  final String? visitorId;
  final String? title;
  final VoidCallback? onClose;
  final ValueChanged<KnowledgeBaseArticle>? onArticleInsertToChat;
  final ConferBotTheme? theme;

  const KnowledgeBaseWidget({
    super.key,
    required this.apiKey,
    required this.botId,
    this.visitorId,
    this.title,
    this.onClose,
    this.onArticleInsertToChat,
    this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => KnowledgeBaseProvider(
        apiKey: apiKey,
        botId: botId,
        visitorId: visitorId,
      ),
      child: KnowledgeBaseScreen(
        title: title,
        onClose: onClose,
        onArticleInsertToChat: onArticleInsertToChat,
        theme: theme,
      ),
    );
  }
}

/// Modal sheet wrapper for showing Knowledge Base
class KnowledgeBaseBottomSheet extends StatelessWidget {
  final KnowledgeBaseProvider provider;
  final ValueChanged<KnowledgeBaseArticle>? onArticleInsertToChat;
  final ConferBotTheme? theme;

  const KnowledgeBaseBottomSheet({
    super.key,
    required this.provider,
    this.onArticleInsertToChat,
    this.theme,
  });

  static Future<void> show(
    BuildContext context, {
    required KnowledgeBaseProvider provider,
    ValueChanged<KnowledgeBaseArticle>? onArticleInsertToChat,
    ConferBotTheme? theme,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => KnowledgeBaseBottomSheet(
        provider: provider,
        onArticleInsertToChat: onArticleInsertToChat,
        theme: theme,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = theme ?? defaultTheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: effectiveTheme.colors.background,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(effectiveTheme.borderRadius.lg),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(effectiveTheme.borderRadius.lg),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.symmetric(vertical: effectiveTheme.spacing.sm),
              decoration: BoxDecoration(
                color: effectiveTheme.colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ChangeNotifierProvider.value(
                value: provider,
                child: KnowledgeBaseScreen(
                  onClose: () => Navigator.of(context).pop(),
                  onArticleInsertToChat: onArticleInsertToChat != null
                      ? (article) {
                          onArticleInsertToChat!(article);
                          Navigator.of(context).pop();
                        }
                      : null,
                  theme: effectiveTheme,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Floating action button for opening Knowledge Base
class KnowledgeBaseFloatingButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String? tooltip;
  final ConferBotTheme? theme;

  const KnowledgeBaseFloatingButton({
    super.key,
    required this.onPressed,
    this.tooltip,
    this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = theme ?? defaultTheme;

    return FloatingActionButton(
      onPressed: onPressed,
      tooltip: tooltip ?? 'Help Center',
      backgroundColor: effectiveTheme.colors.primary,
      foregroundColor: effectiveTheme.colors.surface,
      child: const Icon(Icons.help_outline),
    );
  }
}
