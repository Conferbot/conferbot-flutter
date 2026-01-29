import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import '../../theme/conferbot_theme.dart';
import '../../theme/default_theme.dart';
import 'markdown_theme.dart';
import 'link_handler.dart';
import 'code_block.dart';

/// Widget for rendering markdown content with full support for:
/// - Bold, italic, strikethrough text
/// - Headers (h1-h6)
/// - Links (URLs, mailto:, tel:)
/// - Code blocks with syntax highlighting
/// - Inline code
/// - Lists (ordered and unordered)
/// - Blockquotes
/// - Tables
/// - Horizontal rules
/// - Images
class MarkdownMessage extends StatelessWidget {
  /// The markdown content to render
  final String content;

  /// Theme configuration for styling
  final ConferBotTheme? theme;

  /// Custom markdown theme configuration
  final MarkdownThemeConfig? markdownTheme;

  /// Custom link handler for handling taps on links
  final MarkdownLinkHandler? linkHandler;

  /// Whether to enable selectable text
  final bool selectable;

  /// Whether to shrink wrap the content
  final bool shrinkWrap;

  /// Callback when a link is tapped (if not using custom handler)
  final void Function(String url)? onLinkTap;

  /// Callback when code is copied from a code block
  final void Function(String code)? onCodeCopied;

  /// Whether to show copy button on code blocks
  final bool showCodeCopyButton;

  /// Whether to show line numbers in code blocks
  final bool showCodeLineNumbers;

  /// Maximum height for code blocks (enables scrolling)
  final double? codeBlockMaxHeight;

  /// Custom image builder
  final Widget Function(Uri uri, String? title, String? alt)? imageBuilder;

  /// Physics for scrollable code blocks
  final ScrollPhysics? physics;

  /// Padding around the markdown content
  final EdgeInsets? padding;

  /// Text alignment for markdown content
  final WrapAlignment textAlignment;

  const MarkdownMessage({
    super.key,
    required this.content,
    this.theme,
    this.markdownTheme,
    this.linkHandler,
    this.selectable = false,
    this.shrinkWrap = true,
    this.onLinkTap,
    this.onCodeCopied,
    this.showCodeCopyButton = true,
    this.showCodeLineNumbers = true,
    this.codeBlockMaxHeight = 300,
    this.imageBuilder,
    this.physics,
    this.padding,
    this.textAlignment = WrapAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = theme ?? defaultTheme;
    final effectiveMarkdownTheme =
        markdownTheme ?? MarkdownThemeConfig.fromBotTheme(effectiveTheme);
    final styleSheet = effectiveMarkdownTheme.toStyleSheet(effectiveTheme);

    // Use scope-based handler if available, otherwise use provided or default
    final effectiveLinkHandler = linkHandler ??
        LinkHandlerScope.of(context) ??
        const MarkdownLinkHandler();

    final markdownWidget = MarkdownBody(
      data: content,
      selectable: selectable,
      shrinkWrap: shrinkWrap,
      styleSheet: styleSheet,
      onTapLink: (text, href, title) => _handleLinkTap(context, href, effectiveLinkHandler),
      extensionSet: md.ExtensionSet(
        md.ExtensionSet.gitHubFlavored.blockSyntaxes,
        [
          md.EmojiSyntax(),
          ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
        ],
      ),
      builders: {
        'code': _CodeBlockBuilder(
          theme: effectiveTheme,
          codeTheme: effectiveMarkdownTheme,
          showCopyButton: showCodeCopyButton,
          showLineNumbers: showCodeLineNumbers,
          maxHeight: codeBlockMaxHeight,
          onCopied: onCodeCopied,
        ),
        'pre': _PreBlockBuilder(
          theme: effectiveTheme,
          codeTheme: effectiveMarkdownTheme,
          showCopyButton: showCodeCopyButton,
          showLineNumbers: showCodeLineNumbers,
          maxHeight: codeBlockMaxHeight,
          onCopied: onCodeCopied,
        ),
      },
      imageBuilder: imageBuilder ?? _defaultImageBuilder,
      fitContent: true,
      softLineBreak: true,
    );

    if (padding != null) {
      return Padding(
        padding: padding!,
        child: markdownWidget,
      );
    }

    return markdownWidget;
  }

  void _handleLinkTap(
    BuildContext context,
    String? href,
    MarkdownLinkHandler handler,
  ) {
    if (href == null || href.isEmpty) return;

    // Call custom callback if provided
    onLinkTap?.call(href);

    // Use link handler
    handler.handleLink(context, href);
  }

  Widget _defaultImageBuilder(Uri uri, String? title, String? alt) {
    return Image.network(
      uri.toString(),
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                alt ?? 'Image failed to load',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        );
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          padding: const EdgeInsets.all(16),
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                : null,
            strokeWidth: 2,
          ),
        );
      },
    );
  }
}

/// Builder for inline code elements
class _CodeBlockBuilder extends MarkdownElementBuilder {
  final ConferBotTheme theme;
  final MarkdownThemeConfig codeTheme;
  final bool showCopyButton;
  final bool showLineNumbers;
  final double? maxHeight;
  final void Function(String code)? onCopied;

  _CodeBlockBuilder({
    required this.theme,
    required this.codeTheme,
    this.showCopyButton = true,
    this.showLineNumbers = true,
    this.maxHeight,
    this.onCopied,
  });

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final code = element.textContent;

    // For inline code, use simple styling
    if (!code.contains('\n') && code.length < 50) {
      return InlineCode(
        text: code,
        theme: theme,
        backgroundColor: codeTheme.codeBackgroundColor,
        textColor: codeTheme.codeTextColor,
      );
    }

    // For multi-line code, detect language from class
    String? language;
    if (element.attributes['class'] != null) {
      final classes = element.attributes['class']!.split(' ');
      for (final cls in classes) {
        if (cls.startsWith('language-')) {
          language = cls.substring(9);
          break;
        }
      }
    }

    return CodeBlock(
      code: code.trim(),
      language: language,
      showCopyButton: showCopyButton,
      showLineNumbers: showLineNumbers,
      maxHeight: maxHeight,
      theme: theme,
      onCopied: () => onCopied?.call(code),
    );
  }
}

/// Builder for pre (code block) elements
class _PreBlockBuilder extends MarkdownElementBuilder {
  final ConferBotTheme theme;
  final MarkdownThemeConfig codeTheme;
  final bool showCopyButton;
  final bool showLineNumbers;
  final double? maxHeight;
  final void Function(String code)? onCopied;

  _PreBlockBuilder({
    required this.theme,
    required this.codeTheme,
    this.showCopyButton = true,
    this.showLineNumbers = true,
    this.maxHeight,
    this.onCopied,
  });

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final code = element.textContent;

    // Detect language from code element inside pre
    String? language;
    for (final child in element.children ?? []) {
      if (child is md.Element && child.tag == 'code') {
        if (child.attributes['class'] != null) {
          final classes = child.attributes['class']!.split(' ');
          for (final cls in classes) {
            if (cls.startsWith('language-')) {
              language = cls.substring(9);
              break;
            }
          }
        }
      }
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.xs),
      child: CodeBlock(
        code: code.trim(),
        language: language,
        showCopyButton: showCopyButton,
        showLineNumbers: showLineNumbers,
        maxHeight: maxHeight,
        theme: theme,
        onCopied: () => onCopied?.call(code),
      ),
    );
  }
}

/// Utility class for detecting markdown content in text
class MarkdownDetector {
  /// Common markdown patterns to detect
  static final List<RegExp> _markdownPatterns = [
    // Headers
    RegExp(r'^#{1,6}\s+.+$', multiLine: true),
    // Bold
    RegExp(r'\*\*[^*]+\*\*'),
    RegExp(r'__[^_]+__'),
    // Italic
    RegExp(r'\*[^*]+\*'),
    RegExp(r'_[^_]+_'),
    // Strikethrough
    RegExp(r'~~[^~]+~~'),
    // Code blocks
    RegExp(r'```[\s\S]*?```'),
    // Inline code
    RegExp(r'`[^`]+`'),
    // Links
    RegExp(r'\[([^\]]+)\]\(([^)]+)\)'),
    // Images
    RegExp(r'!\[([^\]]*)\]\(([^)]+)\)'),
    // Unordered lists
    RegExp(r'^[\s]*[-*+]\s+.+$', multiLine: true),
    // Ordered lists
    RegExp(r'^[\s]*\d+\.\s+.+$', multiLine: true),
    // Blockquotes
    RegExp(r'^>\s+.+$', multiLine: true),
    // Horizontal rules
    RegExp(r'^(-{3,}|\*{3,}|_{3,})$', multiLine: true),
    // Tables
    RegExp(r'\|.+\|'),
  ];

  /// Check if text contains markdown formatting
  static bool containsMarkdown(String text) {
    if (text.isEmpty) return false;

    for (final pattern in _markdownPatterns) {
      if (pattern.hasMatch(text)) {
        return true;
      }
    }
    return false;
  }

  /// Check if text contains code blocks specifically
  static bool containsCodeBlock(String text) {
    return RegExp(r'```[\s\S]*?```').hasMatch(text) ||
        RegExp(r'`[^`]+`').hasMatch(text);
  }

  /// Check if text contains links
  static bool containsLinks(String text) {
    return RegExp(r'\[([^\]]+)\]\(([^)]+)\)').hasMatch(text) ||
        RegExp(r'https?://[^\s]+').hasMatch(text);
  }

  /// Get the complexity score of markdown (0-10)
  /// Higher score means more complex markdown formatting
  static int getMarkdownComplexity(String text) {
    if (text.isEmpty) return 0;

    int complexity = 0;
    for (final pattern in _markdownPatterns) {
      if (pattern.hasMatch(text)) {
        complexity++;
      }
    }
    return complexity.clamp(0, 10);
  }

  /// Extract all links from markdown text
  static List<String> extractLinks(String text) {
    final links = <String>[];

    // Markdown links [text](url)
    final markdownLinkPattern = RegExp(r'\[([^\]]+)\]\(([^)]+)\)');
    for (final match in markdownLinkPattern.allMatches(text)) {
      if (match.group(2) != null) {
        links.add(match.group(2)!);
      }
    }

    // Plain URLs
    final urlPattern = RegExp(r'https?://[^\s\)]+');
    for (final match in urlPattern.allMatches(text)) {
      final url = match.group(0)!;
      if (!links.contains(url)) {
        links.add(url);
      }
    }

    return links;
  }

  /// Extract code blocks from markdown
  static List<CodeBlockInfo> extractCodeBlocks(String text) {
    final blocks = <CodeBlockInfo>[];

    final pattern = RegExp(r'```(\w*)\n?([\s\S]*?)```');
    for (final match in pattern.allMatches(text)) {
      blocks.add(CodeBlockInfo(
        language: match.group(1)?.isNotEmpty == true ? match.group(1) : null,
        code: match.group(2) ?? '',
      ));
    }

    return blocks;
  }
}

/// Information about an extracted code block
class CodeBlockInfo {
  final String? language;
  final String code;

  const CodeBlockInfo({
    this.language,
    required this.code,
  });
}

/// A simplified markdown message widget that auto-detects
/// whether content needs markdown rendering
class SmartMarkdownMessage extends StatelessWidget {
  /// The content to render
  final String content;

  /// ConferBotTheme for styling
  final ConferBotTheme? theme;

  /// Markdown theme configuration
  final MarkdownThemeConfig? markdownTheme;

  /// Link handler for tap callbacks
  final MarkdownLinkHandler? linkHandler;

  /// Minimum complexity threshold to use markdown rendering
  final int markdownThreshold;

  /// Style for plain text rendering
  final TextStyle? plainTextStyle;

  /// Whether to always use markdown rendering regardless of complexity
  final bool forceMarkdown;

  const SmartMarkdownMessage({
    super.key,
    required this.content,
    this.theme,
    this.markdownTheme,
    this.linkHandler,
    this.markdownThreshold = 1,
    this.plainTextStyle,
    this.forceMarkdown = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = theme ?? defaultTheme;

    // Check if we should use markdown rendering
    final shouldUseMarkdown = forceMarkdown ||
        MarkdownDetector.getMarkdownComplexity(content) >= markdownThreshold;

    if (!shouldUseMarkdown) {
      // Render as plain text
      return Text(
        content,
        style: plainTextStyle ??
            TextStyle(
              fontSize: effectiveTheme.typography.fontSizeMd,
              color: effectiveTheme.colors.text,
              height: effectiveTheme.typography.lineHeightNormal,
            ),
      );
    }

    // Render as markdown
    return MarkdownMessage(
      content: content,
      theme: effectiveTheme,
      markdownTheme: markdownTheme,
      linkHandler: linkHandler,
    );
  }
}

/// Selective text widget that handles both plain and markdown text
/// with proper selection support
class SelectableMarkdownMessage extends StatelessWidget {
  final String content;
  final ConferBotTheme? theme;
  final MarkdownThemeConfig? markdownTheme;
  final MarkdownLinkHandler? linkHandler;
  final void Function(String)? onSelectionChanged;

  const SelectableMarkdownMessage({
    super.key,
    required this.content,
    this.theme,
    this.markdownTheme,
    this.linkHandler,
    this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return MarkdownMessage(
      content: content,
      theme: theme,
      markdownTheme: markdownTheme,
      linkHandler: linkHandler,
      selectable: true,
    );
  }
}
