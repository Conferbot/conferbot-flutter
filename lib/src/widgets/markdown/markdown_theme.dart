import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../theme/conferbot_theme.dart';

/// Markdown theme configuration for styling markdown elements
/// Integrates with ConferBotTheme for consistent styling
class MarkdownThemeConfig {
  /// Text color for all markdown text
  final Color textColor;

  /// Background color for code blocks
  final Color codeBackgroundColor;

  /// Text color for inline code
  final Color codeTextColor;

  /// Border color for blockquotes
  final Color blockquoteBorderColor;

  /// Background color for blockquotes
  final Color blockquoteBackgroundColor;

  /// Color for links
  final Color linkColor;

  /// Color for horizontal rules
  final Color horizontalRuleColor;

  /// Background color for table headers
  final Color tableHeaderBackgroundColor;

  /// Border color for tables
  final Color tableBorderColor;

  /// Whether to use custom code block styling
  final bool useCustomCodeBlock;

  /// Base text style
  final TextStyle? baseTextStyle;

  const MarkdownThemeConfig({
    required this.textColor,
    required this.codeBackgroundColor,
    required this.codeTextColor,
    required this.blockquoteBorderColor,
    required this.blockquoteBackgroundColor,
    required this.linkColor,
    required this.horizontalRuleColor,
    required this.tableHeaderBackgroundColor,
    required this.tableBorderColor,
    this.useCustomCodeBlock = true,
    this.baseTextStyle,
  });

  /// Create a theme config from ConferBotTheme for bot messages
  factory MarkdownThemeConfig.fromBotTheme(ConferBotTheme theme) {
    return MarkdownThemeConfig(
      textColor: theme.colors.botBubbleText,
      codeBackgroundColor: theme.colors.surface.withOpacity(0.5),
      codeTextColor: theme.colors.botBubbleText,
      blockquoteBorderColor: theme.colors.primary.withOpacity(0.5),
      blockquoteBackgroundColor: theme.colors.surface.withOpacity(0.3),
      linkColor: theme.colors.primary,
      horizontalRuleColor: theme.colors.border,
      tableHeaderBackgroundColor: theme.colors.surface.withOpacity(0.5),
      tableBorderColor: theme.colors.border,
      baseTextStyle: TextStyle(
        fontSize: theme.typography.fontSizeMd,
        color: theme.colors.botBubbleText,
        height: theme.typography.lineHeightNormal,
      ),
    );
  }

  /// Create a theme config from ConferBotTheme for user messages
  factory MarkdownThemeConfig.fromUserTheme(ConferBotTheme theme) {
    return MarkdownThemeConfig(
      textColor: theme.colors.userBubbleText,
      codeBackgroundColor: Colors.white.withOpacity(0.15),
      codeTextColor: theme.colors.userBubbleText,
      blockquoteBorderColor: Colors.white.withOpacity(0.5),
      blockquoteBackgroundColor: Colors.white.withOpacity(0.1),
      linkColor: Colors.white,
      horizontalRuleColor: Colors.white.withOpacity(0.3),
      tableHeaderBackgroundColor: Colors.white.withOpacity(0.15),
      tableBorderColor: Colors.white.withOpacity(0.3),
      baseTextStyle: TextStyle(
        fontSize: theme.typography.fontSizeMd,
        color: theme.colors.userBubbleText,
        height: theme.typography.lineHeightNormal,
      ),
    );
  }

  /// Create a theme config from ConferBotTheme for agent messages
  factory MarkdownThemeConfig.fromAgentTheme(ConferBotTheme theme) {
    return MarkdownThemeConfig(
      textColor: theme.colors.agentBubbleText,
      codeBackgroundColor: Colors.white.withOpacity(0.15),
      codeTextColor: theme.colors.agentBubbleText,
      blockquoteBorderColor: Colors.white.withOpacity(0.5),
      blockquoteBackgroundColor: Colors.white.withOpacity(0.1),
      linkColor: Colors.white,
      horizontalRuleColor: Colors.white.withOpacity(0.3),
      tableHeaderBackgroundColor: Colors.white.withOpacity(0.15),
      tableBorderColor: Colors.white.withOpacity(0.3),
      baseTextStyle: TextStyle(
        fontSize: theme.typography.fontSizeMd,
        color: theme.colors.agentBubbleText,
        height: theme.typography.lineHeightNormal,
      ),
    );
  }

  /// Create a theme config from ConferBotTheme for system messages
  factory MarkdownThemeConfig.fromSystemTheme(ConferBotTheme theme) {
    return MarkdownThemeConfig(
      textColor: theme.colors.systemBubbleText,
      codeBackgroundColor: theme.colors.surface.withOpacity(0.5),
      codeTextColor: theme.colors.systemBubbleText,
      blockquoteBorderColor: theme.colors.primary.withOpacity(0.3),
      blockquoteBackgroundColor: theme.colors.surface.withOpacity(0.3),
      linkColor: theme.colors.primary,
      horizontalRuleColor: theme.colors.border,
      tableHeaderBackgroundColor: theme.colors.surface.withOpacity(0.5),
      tableBorderColor: theme.colors.border,
      baseTextStyle: TextStyle(
        fontSize: theme.typography.fontSizeSm,
        color: theme.colors.systemBubbleText,
        fontStyle: FontStyle.italic,
        height: theme.typography.lineHeightNormal,
      ),
    );
  }

  /// Convert to MarkdownStyleSheet for flutter_markdown
  MarkdownStyleSheet toStyleSheet(ConferBotTheme theme) {
    final baseFontSize = theme.typography.fontSizeMd;

    return MarkdownStyleSheet(
      // Paragraph styling
      p: baseTextStyle ??
          TextStyle(
            fontSize: baseFontSize,
            color: textColor,
            height: theme.typography.lineHeightNormal,
          ),
      pPadding: EdgeInsets.only(bottom: theme.spacing.xs),

      // Headers
      h1: TextStyle(
        fontSize: theme.typography.fontSizeXxl,
        fontWeight: theme.typography.fontWeightBold,
        color: textColor,
        height: theme.typography.lineHeightNormal,
      ),
      h1Padding: EdgeInsets.only(bottom: theme.spacing.sm),
      h2: TextStyle(
        fontSize: theme.typography.fontSizeXl,
        fontWeight: theme.typography.fontWeightBold,
        color: textColor,
        height: theme.typography.lineHeightNormal,
      ),
      h2Padding: EdgeInsets.only(bottom: theme.spacing.sm),
      h3: TextStyle(
        fontSize: theme.typography.fontSizeLg,
        fontWeight: theme.typography.fontWeightSemiBold,
        color: textColor,
        height: theme.typography.lineHeightNormal,
      ),
      h3Padding: EdgeInsets.only(bottom: theme.spacing.xs),
      h4: TextStyle(
        fontSize: baseFontSize,
        fontWeight: theme.typography.fontWeightSemiBold,
        color: textColor,
        height: theme.typography.lineHeightNormal,
      ),
      h4Padding: EdgeInsets.only(bottom: theme.spacing.xs),
      h5: TextStyle(
        fontSize: theme.typography.fontSizeSm,
        fontWeight: theme.typography.fontWeightSemiBold,
        color: textColor,
        height: theme.typography.lineHeightNormal,
      ),
      h5Padding: EdgeInsets.only(bottom: theme.spacing.xs),
      h6: TextStyle(
        fontSize: theme.typography.fontSizeXs,
        fontWeight: theme.typography.fontWeightSemiBold,
        color: textColor.withOpacity(0.8),
        height: theme.typography.lineHeightNormal,
      ),
      h6Padding: EdgeInsets.only(bottom: theme.spacing.xs),

      // Emphasis
      strong: TextStyle(
        fontWeight: theme.typography.fontWeightBold,
        color: textColor,
      ),
      em: TextStyle(
        fontStyle: FontStyle.italic,
        color: textColor,
      ),
      del: TextStyle(
        decoration: TextDecoration.lineThrough,
        color: textColor.withOpacity(0.7),
      ),

      // Links
      a: TextStyle(
        color: linkColor,
        decoration: TextDecoration.underline,
        decorationColor: linkColor.withOpacity(0.5),
      ),

      // Inline code
      code: TextStyle(
        fontFamily: 'monospace',
        fontSize: baseFontSize * 0.9,
        color: codeTextColor,
        backgroundColor: codeBackgroundColor,
      ),
      codeblockPadding: EdgeInsets.all(theme.spacing.sm),
      codeblockDecoration: BoxDecoration(
        color: codeBackgroundColor,
        borderRadius: BorderRadius.circular(theme.borderRadius.sm),
      ),

      // Blockquote
      blockquote: TextStyle(
        fontSize: baseFontSize,
        color: textColor.withOpacity(0.9),
        fontStyle: FontStyle.italic,
        height: theme.typography.lineHeightNormal,
      ),
      blockquotePadding: EdgeInsets.symmetric(
        horizontal: theme.spacing.md,
        vertical: theme.spacing.sm,
      ),
      blockquoteDecoration: BoxDecoration(
        color: blockquoteBackgroundColor,
        border: Border(
          left: BorderSide(
            color: blockquoteBorderColor,
            width: 4,
          ),
        ),
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(theme.borderRadius.sm),
          bottomRight: Radius.circular(theme.borderRadius.sm),
        ),
      ),

      // Lists
      listBullet: TextStyle(
        fontSize: baseFontSize,
        color: textColor,
      ),
      listIndent: theme.spacing.md,
      listBulletPadding: EdgeInsets.only(right: theme.spacing.sm),

      // Table
      tableHead: TextStyle(
        fontWeight: theme.typography.fontWeightSemiBold,
        color: textColor,
      ),
      tableBody: TextStyle(
        fontSize: baseFontSize,
        color: textColor,
      ),
      tableCellsPadding: EdgeInsets.all(theme.spacing.sm),
      tableBorder: TableBorder.all(
        color: tableBorderColor,
        width: 1,
        borderRadius: BorderRadius.circular(theme.borderRadius.sm),
      ),
      tableHeadAlign: TextAlign.left,
      tableColumnWidth: const IntrinsicColumnWidth(),

      // Horizontal rule
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: horizontalRuleColor,
            width: 1,
          ),
        ),
      ),

      // Images
      img: TextStyle(
        fontSize: baseFontSize,
        color: textColor,
      ),

      // Checkbox
      checkbox: TextStyle(
        color: linkColor,
      ),
    );
  }

  /// Create a copy with modified values
  MarkdownThemeConfig copyWith({
    Color? textColor,
    Color? codeBackgroundColor,
    Color? codeTextColor,
    Color? blockquoteBorderColor,
    Color? blockquoteBackgroundColor,
    Color? linkColor,
    Color? horizontalRuleColor,
    Color? tableHeaderBackgroundColor,
    Color? tableBorderColor,
    bool? useCustomCodeBlock,
    TextStyle? baseTextStyle,
  }) {
    return MarkdownThemeConfig(
      textColor: textColor ?? this.textColor,
      codeBackgroundColor: codeBackgroundColor ?? this.codeBackgroundColor,
      codeTextColor: codeTextColor ?? this.codeTextColor,
      blockquoteBorderColor:
          blockquoteBorderColor ?? this.blockquoteBorderColor,
      blockquoteBackgroundColor:
          blockquoteBackgroundColor ?? this.blockquoteBackgroundColor,
      linkColor: linkColor ?? this.linkColor,
      horizontalRuleColor: horizontalRuleColor ?? this.horizontalRuleColor,
      tableHeaderBackgroundColor:
          tableHeaderBackgroundColor ?? this.tableHeaderBackgroundColor,
      tableBorderColor: tableBorderColor ?? this.tableBorderColor,
      useCustomCodeBlock: useCustomCodeBlock ?? this.useCustomCodeBlock,
      baseTextStyle: baseTextStyle ?? this.baseTextStyle,
    );
  }
}
