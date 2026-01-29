import 'package:flutter/material.dart';
import '../../models/knowledge_base.dart';
import '../../theme/conferbot_theme.dart';
import '../../theme/default_theme.dart';

/// Article list widget with optional thumbnails
class ArticleList extends StatelessWidget {
  final List<KnowledgeBaseArticle> articles;
  final ValueChanged<KnowledgeBaseArticle> onArticleTap;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final VoidCallback? onLoadMore;
  final String? emptyMessage;
  final bool showThumbnails;
  final bool showCategories;
  final bool showReadTime;
  final bool showRatings;
  final ConferBotTheme? theme;

  const ArticleList({
    super.key,
    required this.articles,
    required this.onArticleTap,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.onLoadMore,
    this.emptyMessage,
    this.showThumbnails = true,
    this.showCategories = true,
    this.showReadTime = true,
    this.showRatings = true,
    this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = theme ?? defaultTheme;

    if (isLoading) {
      return _buildLoadingState(effectiveTheme);
    }

    if (articles.isEmpty) {
      return _buildEmptyState(effectiveTheme);
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.extentAfter < 100 &&
            hasMore &&
            !isLoadingMore &&
            onLoadMore != null) {
          onLoadMore!();
        }
        return false;
      },
      child: ListView.separated(
        padding: EdgeInsets.symmetric(vertical: effectiveTheme.spacing.sm),
        itemCount: articles.length + (isLoadingMore || hasMore ? 1 : 0),
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: effectiveTheme.colors.divider,
          indent: effectiveTheme.spacing.md,
          endIndent: effectiveTheme.spacing.md,
        ),
        itemBuilder: (context, index) {
          if (index == articles.length) {
            return _buildLoadMoreIndicator(effectiveTheme);
          }

          final article = articles[index];
          return ArticleListItem(
            article: article,
            onTap: () => onArticleTap(article),
            showThumbnail: showThumbnails,
            showCategory: showCategories,
            showReadTime: showReadTime,
            showRating: showRatings,
            theme: effectiveTheme,
          );
        },
      ),
    );
  }

  Widget _buildLoadingState(ConferBotTheme theme) {
    return ListView.separated(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.sm),
      itemCount: 5,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: theme.colors.divider,
        indent: theme.spacing.md,
        endIndent: theme.spacing.md,
      ),
      itemBuilder: (_, __) => _ArticleListItemSkeleton(theme: theme),
    );
  }

  Widget _buildEmptyState(ConferBotTheme theme) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size: 64,
              color: theme.colors.textSecondary.withOpacity(0.5),
            ),
            SizedBox(height: theme.spacing.md),
            Text(
              emptyMessage ?? 'No articles found',
              style: TextStyle(
                fontSize: theme.typography.fontSizeLg,
                fontWeight: theme.typography.fontWeightMedium,
                color: theme.colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: theme.spacing.sm),
            Text(
              'Try adjusting your search or filters',
              style: TextStyle(
                fontSize: theme.typography.fontSizeSm,
                color: theme.colors.textDisabled,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMoreIndicator(ConferBotTheme theme) {
    return Padding(
      padding: EdgeInsets.all(theme.spacing.md),
      child: Center(
        child: isLoadingMore
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(theme.colors.primary),
                ),
              )
            : TextButton(
                onPressed: onLoadMore,
                child: Text(
                  'Load more',
                  style: TextStyle(
                    color: theme.colors.primary,
                    fontWeight: theme.typography.fontWeightMedium,
                  ),
                ),
              ),
      ),
    );
  }
}

/// Single article list item
class ArticleListItem extends StatelessWidget {
  final KnowledgeBaseArticle article;
  final VoidCallback onTap;
  final bool showThumbnail;
  final bool showCategory;
  final bool showReadTime;
  final bool showRating;
  final ConferBotTheme theme;

  const ArticleListItem({
    super.key,
    required this.article,
    required this.onTap,
    this.showThumbnail = true,
    this.showCategory = true,
    this.showReadTime = true,
    this.showRating = true,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.md,
            vertical: theme.spacing.sm + 4,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showThumbnail && article.thumbnailUrl != null) ...[
                _buildThumbnail(),
                SizedBox(width: theme.spacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTitle(),
                    if (article.summary != null) ...[
                      SizedBox(height: theme.spacing.xs),
                      _buildSummary(),
                    ],
                    SizedBox(height: theme.spacing.sm),
                    _buildMetadata(),
                  ],
                ),
              ),
              SizedBox(width: theme.spacing.sm),
              Icon(
                Icons.chevron_right,
                color: theme.colors.textSecondary,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(theme.borderRadius.sm),
      child: Container(
        width: 64,
        height: 64,
        color: theme.colors.surface,
        child: Image.network(
          article.thumbnailUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: theme.colors.primary.withOpacity(0.1),
            child: Icon(
              Icons.article_outlined,
              color: theme.colors.primary,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      article.title,
      style: TextStyle(
        fontSize: theme.typography.fontSizeMd,
        fontWeight: theme.typography.fontWeightMedium,
        color: theme.colors.text,
        height: 1.3,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildSummary() {
    return Text(
      article.summary!,
      style: TextStyle(
        fontSize: theme.typography.fontSizeSm,
        color: theme.colors.textSecondary,
        height: 1.4,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildMetadata() {
    final items = <Widget>[];

    if (showCategory && article.categoryName != null) {
      items.add(_MetadataItem(
        icon: Icons.folder_outlined,
        text: article.categoryName!,
        theme: theme,
      ));
    }

    if (showReadTime && article.readTimeMinutes != null) {
      items.add(_MetadataItem(
        icon: Icons.schedule_outlined,
        text: article.formattedReadTime,
        theme: theme,
      ));
    }

    if (showRating && article.averageRating != null) {
      items.add(_RatingIndicator(
        rating: article.averageRating!,
        count: article.ratingCount,
        theme: theme,
      ));
    }

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: theme.spacing.md,
      runSpacing: theme.spacing.xs,
      children: items,
    );
  }
}

class _MetadataItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final ConferBotTheme theme;

  const _MetadataItem({
    required this.icon,
    required this.text,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: theme.colors.textSecondary,
        ),
        SizedBox(width: theme.spacing.xs),
        Text(
          text,
          style: TextStyle(
            fontSize: theme.typography.fontSizeXs,
            color: theme.colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _RatingIndicator extends StatelessWidget {
  final double rating;
  final int count;
  final ConferBotTheme theme;

  const _RatingIndicator({
    required this.rating,
    required this.count,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.star,
          size: 14,
          color: Colors.amber,
        ),
        SizedBox(width: theme.spacing.xs),
        Text(
          '${rating.toStringAsFixed(1)} ($count)',
          style: TextStyle(
            fontSize: theme.typography.fontSizeXs,
            color: theme.colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ArticleListItemSkeleton extends StatelessWidget {
  final ConferBotTheme theme;

  const _ArticleListItemSkeleton({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.md,
        vertical: theme.spacing.sm + 4,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: theme.colors.border,
              borderRadius: BorderRadius.circular(theme.borderRadius.sm),
            ),
          ),
          SizedBox(width: theme.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 18,
                  decoration: BoxDecoration(
                    color: theme.colors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                SizedBox(height: theme.spacing.sm),
                Container(
                  width: double.infinity,
                  height: 14,
                  decoration: BoxDecoration(
                    color: theme.colors.border.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                SizedBox(height: theme.spacing.xs),
                Container(
                  width: 150,
                  height: 14,
                  decoration: BoxDecoration(
                    color: theme.colors.border.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                SizedBox(height: theme.spacing.sm),
                Row(
                  children: [
                    Container(
                      width: 80,
                      height: 12,
                      decoration: BoxDecoration(
                        color: theme.colors.border.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    SizedBox(width: theme.spacing.md),
                    Container(
                      width: 60,
                      height: 12,
                      decoration: BoxDecoration(
                        color: theme.colors.border.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact article card for grid layouts
class ArticleCard extends StatelessWidget {
  final KnowledgeBaseArticle article;
  final VoidCallback onTap;
  final ConferBotTheme? theme;

  const ArticleCard({
    super.key,
    required this.article,
    required this.onTap,
    this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = theme ?? defaultTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(effectiveTheme.borderRadius.md),
        child: Container(
          decoration: BoxDecoration(
            color: effectiveTheme.colors.surface,
            borderRadius: BorderRadius.circular(effectiveTheme.borderRadius.md),
            border: Border.all(color: effectiveTheme.colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (article.thumbnailUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(effectiveTheme.borderRadius.md),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      article.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: effectiveTheme.colors.primary.withOpacity(0.1),
                        child: Icon(
                          Icons.article_outlined,
                          color: effectiveTheme.colors.primary,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: effectiveTheme.colors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(effectiveTheme.borderRadius.md),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.article_outlined,
                      color: effectiveTheme.colors.primary,
                      size: 36,
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.all(effectiveTheme.spacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      style: TextStyle(
                        fontSize: effectiveTheme.typography.fontSizeSm,
                        fontWeight: effectiveTheme.typography.fontWeightMedium,
                        color: effectiveTheme.colors.text,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (article.categoryName != null) ...[
                      SizedBox(height: effectiveTheme.spacing.xs),
                      Text(
                        article.categoryName!,
                        style: TextStyle(
                          fontSize: effectiveTheme.typography.fontSizeXs,
                          color: effectiveTheme.colors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
