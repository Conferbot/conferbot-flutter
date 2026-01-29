import 'package:flutter/material.dart';
import '../../models/knowledge_base.dart';
import '../../theme/conferbot_theme.dart';
import '../../theme/default_theme.dart';

/// Horizontal scrollable category chips for filtering articles
class CategoryChips extends StatelessWidget {
  final List<KnowledgeBaseCategory> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onCategorySelected;
  final bool showAllChip;
  final bool showCounts;
  final bool isLoading;
  final ConferBotTheme? theme;

  const CategoryChips({
    super.key,
    required this.categories,
    this.selectedCategoryId,
    required this.onCategorySelected,
    this.showAllChip = true,
    this.showCounts = true,
    this.isLoading = false,
    this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = theme ?? defaultTheme;

    if (isLoading) {
      return SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: effectiveTheme.spacing.md),
          itemCount: 5,
          separatorBuilder: (_, __) => SizedBox(width: effectiveTheme.spacing.sm),
          itemBuilder: (_, __) => _buildLoadingChip(effectiveTheme),
        ),
      );
    }

    if (categories.isEmpty && !showAllChip) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: effectiveTheme.spacing.md),
        itemCount: categories.length + (showAllChip ? 1 : 0),
        separatorBuilder: (_, __) => SizedBox(width: effectiveTheme.spacing.sm),
        itemBuilder: (context, index) {
          if (showAllChip && index == 0) {
            return _CategoryChip(
              label: 'All',
              count: null,
              isSelected: selectedCategoryId == null,
              onTap: () => onCategorySelected(null),
              showCount: false,
              theme: effectiveTheme,
            );
          }

          final category = categories[showAllChip ? index - 1 : index];
          return _CategoryChip(
            label: category.name,
            count: category.articleCount,
            iconName: category.iconName,
            isSelected: selectedCategoryId == category.id,
            onTap: () => onCategorySelected(category.id),
            showCount: showCounts,
            theme: effectiveTheme,
          );
        },
      ),
    );
  }

  Widget _buildLoadingChip(ConferBotTheme theme) {
    return Container(
      width: 80,
      height: 36,
      decoration: BoxDecoration(
        color: theme.colors.surface,
        borderRadius: BorderRadius.circular(theme.borderRadius.full),
        border: Border.all(color: theme.colors.border),
      ),
      child: Center(
        child: Container(
          width: 50,
          height: 12,
          decoration: BoxDecoration(
            color: theme.colors.border,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final int? count;
  final String? iconName;
  final bool isSelected;
  final VoidCallback onTap;
  final bool showCount;
  final ConferBotTheme theme;

  const _CategoryChip({
    required this.label,
    this.count,
    this.iconName,
    required this.isSelected,
    required this.onTap,
    this.showCount = true,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(theme.borderRadius.full),
        child: AnimatedContainer(
          duration: theme.animations.fast,
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.md,
            vertical: theme.spacing.sm,
          ),
          decoration: BoxDecoration(
            color: isSelected ? theme.colors.primary : theme.colors.surface,
            borderRadius: BorderRadius.circular(theme.borderRadius.full),
            border: Border.all(
              color: isSelected ? theme.colors.primary : theme.colors.border,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (iconName != null) ...[
                Icon(
                  _getIconData(iconName!),
                  size: 16,
                  color: isSelected
                      ? theme.colors.surface
                      : theme.colors.textSecondary,
                ),
                SizedBox(width: theme.spacing.xs),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: theme.typography.fontSizeSm,
                  fontWeight: isSelected
                      ? theme.typography.fontWeightMedium
                      : theme.typography.fontWeightRegular,
                  color: isSelected ? theme.colors.surface : theme.colors.text,
                ),
              ),
              if (showCount && count != null && count! > 0) ...[
                SizedBox(width: theme.spacing.xs),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: theme.spacing.xs + 2,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colors.surface.withOpacity(0.2)
                        : theme.colors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(theme.borderRadius.sm),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: theme.typography.fontSizeXs,
                      fontWeight: theme.typography.fontWeightMedium,
                      color: isSelected
                          ? theme.colors.surface
                          : theme.colors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    // Map common icon names to Material icons
    switch (iconName.toLowerCase()) {
      case 'home':
        return Icons.home_outlined;
      case 'settings':
        return Icons.settings_outlined;
      case 'account':
      case 'user':
        return Icons.person_outline;
      case 'billing':
      case 'payment':
        return Icons.payment_outlined;
      case 'security':
        return Icons.security_outlined;
      case 'help':
        return Icons.help_outline;
      case 'api':
      case 'developer':
        return Icons.code_outlined;
      case 'integration':
        return Icons.extension_outlined;
      case 'start':
      case 'getting_started':
        return Icons.rocket_launch_outlined;
      case 'faq':
        return Icons.quiz_outlined;
      case 'troubleshoot':
        return Icons.build_outlined;
      case 'feature':
        return Icons.star_outline;
      case 'guide':
      case 'tutorial':
        return Icons.menu_book_outlined;
      case 'pricing':
        return Icons.attach_money_outlined;
      case 'contact':
        return Icons.contact_support_outlined;
      default:
        return Icons.folder_outlined;
    }
  }
}

/// Category grid for displaying categories in a grid layout
class CategoryGrid extends StatelessWidget {
  final List<KnowledgeBaseCategory> categories;
  final ValueChanged<String> onCategorySelected;
  final int crossAxisCount;
  final bool isLoading;
  final ConferBotTheme? theme;

  const CategoryGrid({
    super.key,
    required this.categories,
    required this.onCategorySelected,
    this.crossAxisCount = 2,
    this.isLoading = false,
    this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = theme ?? defaultTheme;

    if (isLoading) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.all(effectiveTheme.spacing.md),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: effectiveTheme.spacing.md,
          mainAxisSpacing: effectiveTheme.spacing.md,
          childAspectRatio: 1.5,
        ),
        itemCount: 4,
        itemBuilder: (_, __) => _buildLoadingCard(effectiveTheme),
      );
    }

    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.all(effectiveTheme.spacing.md),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: effectiveTheme.spacing.md,
        mainAxisSpacing: effectiveTheme.spacing.md,
        childAspectRatio: 1.5,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return _CategoryCard(
          category: category,
          onTap: () => onCategorySelected(category.id),
          theme: effectiveTheme,
        );
      },
    );
  }

  Widget _buildLoadingCard(ConferBotTheme theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colors.surface,
        borderRadius: BorderRadius.circular(theme.borderRadius.md),
        border: Border.all(color: theme.colors.border),
      ),
      padding: EdgeInsets.all(theme.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: theme.colors.border,
              borderRadius: BorderRadius.circular(theme.borderRadius.sm),
            ),
          ),
          const Spacer(),
          Container(
            width: double.infinity,
            height: 16,
            decoration: BoxDecoration(
              color: theme.colors.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          SizedBox(height: theme.spacing.xs),
          Container(
            width: 60,
            height: 12,
            decoration: BoxDecoration(
              color: theme.colors.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final KnowledgeBaseCategory category;
  final VoidCallback onTap;
  final ConferBotTheme theme;

  const _CategoryCard({
    required this.category,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(theme.borderRadius.md),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colors.surface,
            borderRadius: BorderRadius.circular(theme.borderRadius.md),
            border: Border.all(color: theme.colors.border),
          ),
          padding: EdgeInsets.all(theme.spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: theme.colors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(theme.borderRadius.sm),
                ),
                child: Icon(
                  _getIconData(category.iconName ?? 'folder'),
                  size: 20,
                  color: theme.colors.primary,
                ),
              ),
              const Spacer(),
              Text(
                category.name,
                style: TextStyle(
                  fontSize: theme.typography.fontSizeMd,
                  fontWeight: theme.typography.fontWeightMedium,
                  color: theme.colors.text,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: theme.spacing.xs),
              Text(
                '${category.articleCount} article${category.articleCount == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: theme.typography.fontSizeSm,
                  color: theme.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'home':
        return Icons.home_outlined;
      case 'settings':
        return Icons.settings_outlined;
      case 'account':
      case 'user':
        return Icons.person_outline;
      case 'billing':
      case 'payment':
        return Icons.payment_outlined;
      case 'security':
        return Icons.security_outlined;
      case 'help':
        return Icons.help_outline;
      case 'api':
      case 'developer':
        return Icons.code_outlined;
      case 'integration':
        return Icons.extension_outlined;
      case 'start':
      case 'getting_started':
        return Icons.rocket_launch_outlined;
      case 'faq':
        return Icons.quiz_outlined;
      case 'troubleshoot':
        return Icons.build_outlined;
      case 'feature':
        return Icons.star_outline;
      case 'guide':
      case 'tutorial':
        return Icons.menu_book_outlined;
      case 'pricing':
        return Icons.attach_money_outlined;
      case 'contact':
        return Icons.contact_support_outlined;
      default:
        return Icons.folder_outlined;
    }
  }
}
