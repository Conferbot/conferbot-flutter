import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/knowledge_base.dart';
import '../../theme/conferbot_theme.dart';
import '../../theme/default_theme.dart';

/// Full article detail view with rating support
class ArticleDetail extends StatefulWidget {
  final KnowledgeBaseArticle article;
  final VoidCallback? onBack;
  final ValueChanged<KnowledgeBaseArticle>? onRelatedArticleTap;
  final Future<bool> Function(int rating, {String? feedback})? onRate;
  final int? userRating;
  final bool isRating;
  final String? ratingError;
  final String? ratingSuccess;
  final VoidCallback? onInsertToChat;
  final ConferBotTheme? theme;

  const ArticleDetail({
    super.key,
    required this.article,
    this.onBack,
    this.onRelatedArticleTap,
    this.onRate,
    this.userRating,
    this.isRating = false,
    this.ratingError,
    this.ratingSuccess,
    this.onInsertToChat,
    this.theme,
  });

  @override
  State<ArticleDetail> createState() => _ArticleDetailState();
}

class _ArticleDetailState extends State<ArticleDetail> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = widget.theme ?? defaultTheme;

    return Scaffold(
      backgroundColor: effectiveTheme.colors.background,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildAppBar(effectiveTheme),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(effectiveTheme.spacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(effectiveTheme),
                  SizedBox(height: effectiveTheme.spacing.lg),
                  _buildContent(effectiveTheme),
                  SizedBox(height: effectiveTheme.spacing.xl),
                  _buildRatingSection(effectiveTheme),
                  if (widget.article.relatedArticles != null &&
                      widget.article.relatedArticles!.isNotEmpty) ...[
                    SizedBox(height: effectiveTheme.spacing.xl),
                    _buildRelatedArticles(effectiveTheme),
                  ],
                  SizedBox(height: effectiveTheme.spacing.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: widget.onInsertToChat != null
          ? FloatingActionButton.extended(
              onPressed: widget.onInsertToChat,
              backgroundColor: effectiveTheme.colors.primary,
              foregroundColor: effectiveTheme.colors.surface,
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Share in Chat'),
            )
          : null,
    );
  }

  Widget _buildAppBar(ConferBotTheme theme) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: theme.colors.surface,
      foregroundColor: theme.colors.text,
      elevation: 0,
      leading: widget.onBack != null
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: widget.onBack,
            )
          : null,
      actions: [
        IconButton(
          icon: const Icon(Icons.share_outlined),
          onPressed: _shareArticle,
          tooltip: 'Share',
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: theme.colors.border,
        ),
      ),
    );
  }

  Widget _buildHeader(ConferBotTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.article.categoryName != null) ...[
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacing.sm,
              vertical: theme.spacing.xs,
            ),
            decoration: BoxDecoration(
              color: theme.colors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(theme.borderRadius.sm),
            ),
            child: Text(
              widget.article.categoryName!,
              style: TextStyle(
                fontSize: theme.typography.fontSizeXs,
                fontWeight: theme.typography.fontWeightMedium,
                color: theme.colors.primary,
              ),
            ),
          ),
          SizedBox(height: theme.spacing.sm),
        ],
        Text(
          widget.article.title,
          style: TextStyle(
            fontSize: theme.typography.fontSizeXxl,
            fontWeight: theme.typography.fontWeightBold,
            color: theme.colors.text,
            height: 1.3,
          ),
        ),
        SizedBox(height: theme.spacing.md),
        _buildMetadataRow(theme),
      ],
    );
  }

  Widget _buildMetadataRow(ConferBotTheme theme) {
    return Wrap(
      spacing: theme.spacing.md,
      runSpacing: theme.spacing.sm,
      children: [
        if (widget.article.authorName != null)
          _MetadataChip(
            icon: Icons.person_outline,
            text: widget.article.authorName!,
            theme: theme,
          ),
        if (widget.article.readTimeMinutes != null)
          _MetadataChip(
            icon: Icons.schedule_outlined,
            text: widget.article.formattedReadTime,
            theme: theme,
          ),
        if (widget.article.averageRating != null)
          _MetadataChip(
            icon: Icons.star,
            iconColor: Colors.amber,
            text: widget.article.formattedRating,
            theme: theme,
          ),
        _MetadataChip(
          icon: Icons.visibility_outlined,
          text: '${widget.article.viewCount} views',
          theme: theme,
        ),
      ],
    );
  }

  Widget _buildContent(ConferBotTheme theme) {
    // Parse and render content
    // For now, treating content as plain text with basic formatting
    return SelectableText(
      widget.article.content,
      style: TextStyle(
        fontSize: theme.typography.fontSizeMd,
        color: theme.colors.text,
        height: theme.typography.lineHeightRelaxed,
      ),
    );
  }

  Widget _buildRatingSection(ConferBotTheme theme) {
    final hasRated = widget.userRating != null;

    return Container(
      padding: EdgeInsets.all(theme.spacing.md),
      decoration: BoxDecoration(
        color: theme.colors.surface,
        borderRadius: BorderRadius.circular(theme.borderRadius.md),
        border: Border.all(color: theme.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasRated ? 'Thank you for your feedback!' : 'Was this article helpful?',
            style: TextStyle(
              fontSize: theme.typography.fontSizeMd,
              fontWeight: theme.typography.fontWeightMedium,
              color: theme.colors.text,
            ),
          ),
          SizedBox(height: theme.spacing.md),
          ArticleRatingWidget(
            currentRating: widget.userRating,
            isLoading: widget.isRating,
            onRate: widget.onRate != null
                ? (rating) => widget.onRate!(rating)
                : null,
            theme: theme,
          ),
          if (widget.ratingError != null) ...[
            SizedBox(height: theme.spacing.sm),
            Text(
              widget.ratingError!,
              style: TextStyle(
                fontSize: theme.typography.fontSizeSm,
                color: theme.colors.error,
              ),
            ),
          ],
          if (widget.ratingSuccess != null) ...[
            SizedBox(height: theme.spacing.sm),
            Text(
              widget.ratingSuccess!,
              style: TextStyle(
                fontSize: theme.typography.fontSizeSm,
                color: theme.colors.success,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRelatedArticles(ConferBotTheme theme) {
    final relatedArticles = widget.article.relatedArticles!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Related Articles',
          style: TextStyle(
            fontSize: theme.typography.fontSizeLg,
            fontWeight: theme.typography.fontWeightSemiBold,
            color: theme.colors.text,
          ),
        ),
        SizedBox(height: theme.spacing.md),
        ...relatedArticles.map((related) => _RelatedArticleItem(
              article: related,
              onTap: () {
                if (widget.onRelatedArticleTap != null) {
                  widget.onRelatedArticleTap!(KnowledgeBaseArticle(
                    id: related.id,
                    title: related.title,
                    content: '',
                    summary: related.summary,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  ));
                }
              },
              theme: theme,
            )),
      ],
    );
  }

  void _shareArticle() async {
    // For now, just copy the title. In a real app, you'd share a link.
    final text = 'Check out this article: ${widget.article.title}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Share: $text')),
    );
  }
}

class _MetadataChip extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String text;
  final ConferBotTheme theme;

  const _MetadataChip({
    required this.icon,
    this.iconColor,
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
          size: 16,
          color: iconColor ?? theme.colors.textSecondary,
        ),
        SizedBox(width: theme.spacing.xs),
        Text(
          text,
          style: TextStyle(
            fontSize: theme.typography.fontSizeSm,
            color: theme.colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _RelatedArticleItem extends StatelessWidget {
  final RelatedArticle article;
  final VoidCallback onTap;
  final ConferBotTheme theme;

  const _RelatedArticleItem({
    required this.article,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(theme.borderRadius.sm),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: theme.spacing.sm,
          ),
          child: Row(
            children: [
              Icon(
                Icons.article_outlined,
                size: 20,
                color: theme.colors.primary,
              ),
              SizedBox(width: theme.spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      style: TextStyle(
                        fontSize: theme.typography.fontSizeSm,
                        fontWeight: theme.typography.fontWeightMedium,
                        color: theme.colors.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (article.summary != null) ...[
                      SizedBox(height: 2),
                      Text(
                        article.summary!,
                        style: TextStyle(
                          fontSize: theme.typography.fontSizeXs,
                          color: theme.colors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: theme.colors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Star rating widget for article feedback
class ArticleRatingWidget extends StatefulWidget {
  final int? currentRating;
  final bool isLoading;
  final Future<bool> Function(int rating)? onRate;
  final ConferBotTheme theme;

  const ArticleRatingWidget({
    super.key,
    this.currentRating,
    this.isLoading = false,
    this.onRate,
    required this.theme,
  });

  @override
  State<ArticleRatingWidget> createState() => _ArticleRatingWidgetState();
}

class _ArticleRatingWidgetState extends State<ArticleRatingWidget> {
  int? _hoverRating;
  int? _selectedRating;

  @override
  void initState() {
    super.initState();
    _selectedRating = widget.currentRating;
  }

  @override
  void didUpdateWidget(ArticleRatingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentRating != oldWidget.currentRating) {
      _selectedRating = widget.currentRating;
    }
  }

  void _onStarTap(int rating) async {
    if (widget.isLoading || widget.onRate == null) return;

    setState(() {
      _selectedRating = rating;
    });

    final success = await widget.onRate!(rating);
    if (!success && mounted) {
      setState(() {
        _selectedRating = widget.currentRating;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayRating = _hoverRating ?? _selectedRating ?? 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (index) {
          final starRating = index + 1;
          final isFilled = starRating <= displayRating;

          return GestureDetector(
            onTap: () => _onStarTap(starRating),
            onTapDown: (_) => setState(() => _hoverRating = starRating),
            onTapCancel: () => setState(() => _hoverRating = null),
            onTapUp: (_) => setState(() => _hoverRating = null),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.theme.spacing.xs),
              child: AnimatedSwitcher(
                duration: widget.theme.animations.fast,
                child: widget.isLoading && _selectedRating == starRating
                    ? SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                            widget.theme.colors.primary,
                          ),
                        ),
                      )
                    : Icon(
                        isFilled ? Icons.star : Icons.star_border,
                        color: isFilled ? Colors.amber : widget.theme.colors.textSecondary,
                        size: 32,
                        key: ValueKey('$starRating-$isFilled'),
                      ),
              ),
            ),
          );
        }),
        if (_selectedRating != null) ...[
          SizedBox(width: widget.theme.spacing.md),
          Text(
            _getRatingLabel(_selectedRating!),
            style: TextStyle(
              fontSize: widget.theme.typography.fontSizeSm,
              color: widget.theme.colors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }

  String _getRatingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }
}

/// Thumbs up/down rating widget alternative
class ArticleThumbsRating extends StatelessWidget {
  final bool? isHelpful;
  final bool isLoading;
  final ValueChanged<bool>? onRate;
  final ConferBotTheme theme;

  const ArticleThumbsRating({
    super.key,
    this.isHelpful,
    this.isLoading = false,
    this.onRate,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ThumbButton(
          icon: Icons.thumb_up_outlined,
          activeIcon: Icons.thumb_up,
          isActive: isHelpful == true,
          isLoading: isLoading && isHelpful == true,
          onTap: onRate != null ? () => onRate!(true) : null,
          theme: theme,
        ),
        SizedBox(width: theme.spacing.md),
        _ThumbButton(
          icon: Icons.thumb_down_outlined,
          activeIcon: Icons.thumb_down,
          isActive: isHelpful == false,
          isLoading: isLoading && isHelpful == false,
          onTap: onRate != null ? () => onRate!(false) : null,
          theme: theme,
        ),
      ],
    );
  }
}

class _ThumbButton extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final bool isActive;
  final bool isLoading;
  final VoidCallback? onTap;
  final ConferBotTheme theme;

  const _ThumbButton({
    required this.icon,
    required this.activeIcon,
    required this.isActive,
    required this.isLoading,
    this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(theme.borderRadius.full),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isActive
                ? theme.colors.primary.withOpacity(0.1)
                : theme.colors.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? theme.colors.primary : theme.colors.border,
            ),
          ),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(theme.colors.primary),
                    ),
                  )
                : Icon(
                    isActive ? activeIcon : icon,
                    color: isActive
                        ? theme.colors.primary
                        : theme.colors.textSecondary,
                    size: 24,
                  ),
          ),
        ),
      ),
    );
  }
}
