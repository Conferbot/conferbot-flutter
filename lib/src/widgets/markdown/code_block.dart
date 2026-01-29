import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/conferbot_theme.dart';
import '../../theme/default_theme.dart';

/// Syntax highlighting color scheme
class CodeTheme {
  final Color background;
  final Color defaultText;
  final Color keyword;
  final Color string;
  final Color number;
  final Color comment;
  final Color function;
  final Color className;
  final Color variable;
  final Color operator;
  final Color punctuation;
  final Color attribute;
  final Color tag;

  const CodeTheme({
    required this.background,
    required this.defaultText,
    required this.keyword,
    required this.string,
    required this.number,
    required this.comment,
    required this.function,
    required this.className,
    required this.variable,
    required this.operator,
    required this.punctuation,
    required this.attribute,
    required this.tag,
  });

  /// Light theme for code blocks
  factory CodeTheme.light() {
    return const CodeTheme(
      background: Color(0xFFF5F5F5),
      defaultText: Color(0xFF333333),
      keyword: Color(0xFF0000FF),
      string: Color(0xFF008000),
      number: Color(0xFF098658),
      comment: Color(0xFF6A9955),
      function: Color(0xFF795E26),
      className: Color(0xFF267F99),
      variable: Color(0xFF001080),
      operator: Color(0xFF000000),
      punctuation: Color(0xFF333333),
      attribute: Color(0xFF0451A5),
      tag: Color(0xFF800000),
    );
  }

  /// Dark theme for code blocks
  factory CodeTheme.dark() {
    return const CodeTheme(
      background: Color(0xFF1E1E1E),
      defaultText: Color(0xFFD4D4D4),
      keyword: Color(0xFF569CD6),
      string: Color(0xFFCE9178),
      number: Color(0xFFB5CEA8),
      comment: Color(0xFF6A9955),
      function: Color(0xFFDCDCAA),
      className: Color(0xFF4EC9B0),
      variable: Color(0xFF9CDCFE),
      operator: Color(0xFFD4D4D4),
      punctuation: Color(0xFFD4D4D4),
      attribute: Color(0xFF9CDCFE),
      tag: Color(0xFF569CD6),
    );
  }

  /// Create from ConferBotTheme
  factory CodeTheme.fromTheme(ConferBotTheme theme) {
    if (theme.brightness == Brightness.dark) {
      return CodeTheme.dark();
    }
    return CodeTheme.light();
  }
}

/// Code block widget with syntax highlighting and copy functionality
class CodeBlock extends StatefulWidget {
  /// The code content
  final String code;

  /// The programming language (for syntax highlighting)
  final String? language;

  /// Whether to show line numbers
  final bool showLineNumbers;

  /// Whether to show copy button
  final bool showCopyButton;

  /// Whether to wrap long lines
  final bool wrapLines;

  /// Maximum height (enables scrolling if exceeded)
  final double? maxHeight;

  /// Custom code theme
  final CodeTheme? codeTheme;

  /// ConferBotTheme for styling
  final ConferBotTheme? theme;

  /// Callback when code is copied
  final VoidCallback? onCopied;

  const CodeBlock({
    super.key,
    required this.code,
    this.language,
    this.showLineNumbers = true,
    this.showCopyButton = true,
    this.wrapLines = false,
    this.maxHeight,
    this.codeTheme,
    this.theme,
    this.onCopied,
  });

  @override
  State<CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<CodeBlock> {
  bool _copied = false;
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = widget.theme ?? defaultTheme;
    final effectiveCodeTheme =
        widget.codeTheme ?? CodeTheme.fromTheme(effectiveTheme);

    return Container(
      constraints: widget.maxHeight != null
          ? BoxConstraints(maxHeight: widget.maxHeight!)
          : null,
      decoration: BoxDecoration(
        color: effectiveCodeTheme.background,
        borderRadius: BorderRadius.circular(effectiveTheme.borderRadius.md),
        border: Border.all(
          color: effectiveTheme.colors.border,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with language and copy button
          if (widget.language != null || widget.showCopyButton)
            _buildHeader(effectiveTheme, effectiveCodeTheme),

          // Code content
          Flexible(
            child: _buildCodeContent(effectiveTheme, effectiveCodeTheme),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ConferBotTheme theme, CodeTheme codeTheme) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.xs,
      ),
      decoration: BoxDecoration(
        color: codeTheme.background.withOpacity(0.7),
        border: Border(
          bottom: BorderSide(
            color: theme.colors.border,
            width: 1,
          ),
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(theme.borderRadius.md),
          topRight: Radius.circular(theme.borderRadius.md),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Language label
          if (widget.language != null)
            Text(
              _formatLanguageName(widget.language!),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: theme.typography.fontSizeXs,
                color: codeTheme.defaultText.withOpacity(0.7),
              ),
            )
          else
            const SizedBox.shrink(),

          // Copy button
          if (widget.showCopyButton) _buildCopyButton(theme, codeTheme),
        ],
      ),
    );
  }

  Widget _buildCopyButton(ConferBotTheme theme, CodeTheme codeTheme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _copyToClipboard,
        borderRadius: BorderRadius.circular(theme.borderRadius.sm),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.sm,
            vertical: theme.spacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _copied ? Icons.check : Icons.copy,
                size: 14,
                color: _copied
                    ? theme.colors.success
                    : codeTheme.defaultText.withOpacity(0.7),
              ),
              SizedBox(width: theme.spacing.xs),
              Text(
                _copied ? 'Copied!' : 'Copy',
                style: TextStyle(
                  fontSize: theme.typography.fontSizeXs,
                  color: _copied
                      ? theme.colors.success
                      : codeTheme.defaultText.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCodeContent(ConferBotTheme theme, CodeTheme codeTheme) {
    final lines = widget.code.split('\n');
    final lineCount = lines.length;
    final lineNumberWidth = lineCount.toString().length * 10.0 + 16;

    return Scrollbar(
      controller: _verticalController,
      child: SingleChildScrollView(
        controller: _verticalController,
        child: SingleChildScrollView(
          controller: _horizontalController,
          scrollDirection: Axis.horizontal,
          child: IntrinsicWidth(
            child: Padding(
              padding: EdgeInsets.all(theme.spacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Line numbers
                  if (widget.showLineNumbers)
                    Container(
                      width: lineNumberWidth,
                      padding: EdgeInsets.only(right: theme.spacing.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(
                          lineCount,
                          (index) => Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: theme.typography.fontSizeSm,
                              color: codeTheme.defaultText.withOpacity(0.4),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Divider
                  if (widget.showLineNumbers)
                    Container(
                      width: 1,
                      height: lineCount * theme.typography.fontSizeSm * 1.5,
                      color: theme.colors.border,
                      margin: EdgeInsets.only(right: theme.spacing.sm),
                    ),

                  // Code
                  Flexible(
                    child: SelectableText.rich(
                      TextSpan(
                        children: _highlightCode(lines, codeTheme, theme),
                      ),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: theme.typography.fontSizeSm,
                        color: codeTheme.defaultText,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<InlineSpan> _highlightCode(
    List<String> lines,
    CodeTheme codeTheme,
    ConferBotTheme theme,
  ) {
    final spans = <InlineSpan>[];
    final language = widget.language?.toLowerCase();

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (language != null) {
        spans.addAll(_highlightLine(line, language, codeTheme));
      } else {
        spans.add(TextSpan(text: line));
      }

      // Add newline except for last line
      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return spans;
  }

  List<InlineSpan> _highlightLine(
    String line,
    String language,
    CodeTheme codeTheme,
  ) {
    final spans = <InlineSpan>[];

    // Simple regex-based syntax highlighting
    final patterns = _getPatterns(language, codeTheme);

    if (patterns.isEmpty) {
      return [TextSpan(text: line)];
    }

    int currentIndex = 0;
    final matches = <_SyntaxMatch>[];

    // Find all matches
    for (final pattern in patterns) {
      final regex = pattern.pattern;
      for (final match in regex.allMatches(line)) {
        matches.add(_SyntaxMatch(
          start: match.start,
          end: match.end,
          text: match.group(0)!,
          color: pattern.color,
        ));
      }
    }

    // Sort by start position
    matches.sort((a, b) => a.start.compareTo(b.start));

    // Remove overlapping matches (keep the first one)
    final filteredMatches = <_SyntaxMatch>[];
    int lastEnd = 0;
    for (final match in matches) {
      if (match.start >= lastEnd) {
        filteredMatches.add(match);
        lastEnd = match.end;
      }
    }

    // Build spans
    for (final match in filteredMatches) {
      // Add text before match
      if (match.start > currentIndex) {
        spans.add(TextSpan(text: line.substring(currentIndex, match.start)));
      }
      // Add highlighted match
      spans.add(TextSpan(
        text: match.text,
        style: TextStyle(color: match.color),
      ));
      currentIndex = match.end;
    }

    // Add remaining text
    if (currentIndex < line.length) {
      spans.add(TextSpan(text: line.substring(currentIndex)));
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: line));
    }

    return spans;
  }

  List<_SyntaxPattern> _getPatterns(String language, CodeTheme theme) {
    switch (language) {
      case 'dart':
      case 'java':
      case 'kotlin':
      case 'swift':
      case 'typescript':
      case 'javascript':
      case 'js':
      case 'ts':
        return _getCStylePatterns(theme);

      case 'python':
      case 'py':
        return _getPythonPatterns(theme);

      case 'html':
      case 'xml':
        return _getHtmlPatterns(theme);

      case 'css':
      case 'scss':
      case 'sass':
        return _getCssPatterns(theme);

      case 'json':
        return _getJsonPatterns(theme);

      case 'yaml':
      case 'yml':
        return _getYamlPatterns(theme);

      case 'sql':
        return _getSqlPatterns(theme);

      case 'bash':
      case 'sh':
      case 'shell':
        return _getBashPatterns(theme);

      case 'go':
        return _getGoPatterns(theme);

      case 'rust':
        return _getRustPatterns(theme);

      default:
        return _getGenericPatterns(theme);
    }
  }

  List<_SyntaxPattern> _getCStylePatterns(CodeTheme theme) {
    return [
      // Comments
      _SyntaxPattern(RegExp(r'//.*$'), theme.comment),
      _SyntaxPattern(RegExp(r'/\*[\s\S]*?\*/'), theme.comment),

      // Strings
      _SyntaxPattern(RegExp(r'"(?:[^"\\]|\\.)*"'), theme.string),
      _SyntaxPattern(RegExp(r"'(?:[^'\\]|\\.)*'"), theme.string),
      _SyntaxPattern(RegExp(r'`(?:[^`\\]|\\.)*`'), theme.string),

      // Numbers
      _SyntaxPattern(
          RegExp(r'\b\d+\.?\d*([eE][+-]?\d+)?\b'), theme.number),

      // Keywords
      _SyntaxPattern(
        RegExp(
            r'\b(abstract|as|assert|async|await|break|case|catch|class|const|continue|default|do|else|enum|export|extends|false|final|finally|for|function|get|if|implements|import|in|instanceof|interface|is|let|library|new|null|operator|part|rethrow|return|set|static|super|switch|sync|this|throw|true|try|typedef|var|void|while|with|yield)\b'),
        theme.keyword,
      ),

      // Types
      _SyntaxPattern(
        RegExp(r'\b(String|int|double|bool|List|Map|Set|Future|Stream|dynamic|Object|num|Function|void)\b'),
        theme.className,
      ),

      // Functions
      _SyntaxPattern(RegExp(r'\b([a-zA-Z_]\w*)\s*\('), theme.function),
    ];
  }

  List<_SyntaxPattern> _getPythonPatterns(CodeTheme theme) {
    return [
      // Comments
      _SyntaxPattern(RegExp(r'#.*$'), theme.comment),

      // Strings
      _SyntaxPattern(RegExp(r'"""[\s\S]*?"""'), theme.string),
      _SyntaxPattern(RegExp(r"'''[\s\S]*?'''"), theme.string),
      _SyntaxPattern(RegExp(r'"(?:[^"\\]|\\.)*"'), theme.string),
      _SyntaxPattern(RegExp(r"'(?:[^'\\]|\\.)*'"), theme.string),

      // Numbers
      _SyntaxPattern(RegExp(r'\b\d+\.?\d*\b'), theme.number),

      // Keywords
      _SyntaxPattern(
        RegExp(
            r'\b(and|as|assert|async|await|break|class|continue|def|del|elif|else|except|False|finally|for|from|global|if|import|in|is|lambda|None|nonlocal|not|or|pass|raise|return|True|try|while|with|yield)\b'),
        theme.keyword,
      ),

      // Built-in functions
      _SyntaxPattern(
        RegExp(
            r'\b(print|len|range|str|int|float|list|dict|set|tuple|type|isinstance|hasattr|getattr|setattr)\b'),
        theme.function,
      ),
    ];
  }

  List<_SyntaxPattern> _getHtmlPatterns(CodeTheme theme) {
    return [
      // Comments
      _SyntaxPattern(RegExp(r'<!--[\s\S]*?-->'), theme.comment),

      // Tags
      _SyntaxPattern(RegExp(r'<\/?[a-zA-Z][a-zA-Z0-9]*'), theme.tag),
      _SyntaxPattern(RegExp(r'\/??>'), theme.tag),

      // Attributes
      _SyntaxPattern(RegExp(r'\b[a-zA-Z\-]+(?==)'), theme.attribute),

      // Strings
      _SyntaxPattern(RegExp(r'"[^"]*"'), theme.string),
      _SyntaxPattern(RegExp(r"'[^']*'"), theme.string),
    ];
  }

  List<_SyntaxPattern> _getCssPatterns(CodeTheme theme) {
    return [
      // Comments
      _SyntaxPattern(RegExp(r'/\*[\s\S]*?\*/'), theme.comment),

      // Selectors
      _SyntaxPattern(RegExp(r'[.#][a-zA-Z_][a-zA-Z0-9_-]*'), theme.className),

      // Properties
      _SyntaxPattern(RegExp(r'\b[a-zA-Z-]+(?=\s*:)'), theme.attribute),

      // Values
      _SyntaxPattern(RegExp(r'#[0-9a-fA-F]{3,8}'), theme.number),
      _SyntaxPattern(RegExp(r'\b\d+\.?\d*(px|em|rem|%|vh|vw)?\b'), theme.number),

      // Strings
      _SyntaxPattern(RegExp(r'"[^"]*"'), theme.string),
      _SyntaxPattern(RegExp(r"'[^']*'"), theme.string),
    ];
  }

  List<_SyntaxPattern> _getJsonPatterns(CodeTheme theme) {
    return [
      // Keys
      _SyntaxPattern(RegExp(r'"[^"]*"(?=\s*:)'), theme.attribute),

      // Strings
      _SyntaxPattern(RegExp(r'"[^"]*"'), theme.string),

      // Numbers
      _SyntaxPattern(RegExp(r'-?\b\d+\.?\d*([eE][+-]?\d+)?\b'), theme.number),

      // Booleans and null
      _SyntaxPattern(RegExp(r'\b(true|false|null)\b'), theme.keyword),
    ];
  }

  List<_SyntaxPattern> _getYamlPatterns(CodeTheme theme) {
    return [
      // Comments
      _SyntaxPattern(RegExp(r'#.*$'), theme.comment),

      // Keys
      _SyntaxPattern(RegExp(r'^[\s]*[a-zA-Z_][a-zA-Z0-9_]*(?=\s*:)'), theme.attribute),

      // Strings
      _SyntaxPattern(RegExp(r'"[^"]*"'), theme.string),
      _SyntaxPattern(RegExp(r"'[^']*'"), theme.string),

      // Numbers
      _SyntaxPattern(RegExp(r'\b\d+\.?\d*\b'), theme.number),

      // Booleans
      _SyntaxPattern(RegExp(r'\b(true|false|yes|no|null)\b'), theme.keyword),
    ];
  }

  List<_SyntaxPattern> _getSqlPatterns(CodeTheme theme) {
    return [
      // Comments
      _SyntaxPattern(RegExp(r'--.*$'), theme.comment),
      _SyntaxPattern(RegExp(r'/\*[\s\S]*?\*/'), theme.comment),

      // Strings
      _SyntaxPattern(RegExp(r"'[^']*'"), theme.string),

      // Numbers
      _SyntaxPattern(RegExp(r'\b\d+\.?\d*\b'), theme.number),

      // Keywords
      _SyntaxPattern(
        RegExp(
            r'\b(SELECT|FROM|WHERE|INSERT|UPDATE|DELETE|CREATE|DROP|ALTER|TABLE|INDEX|JOIN|LEFT|RIGHT|INNER|OUTER|ON|AND|OR|NOT|IN|IS|NULL|AS|ORDER|BY|GROUP|HAVING|LIMIT|OFFSET|UNION|ALL|DISTINCT|COUNT|SUM|AVG|MAX|MIN|BETWEEN|LIKE|EXISTS|CASE|WHEN|THEN|ELSE|END|INTO|VALUES|SET)\b',
            caseSensitive: false),
        theme.keyword,
      ),
    ];
  }

  List<_SyntaxPattern> _getBashPatterns(CodeTheme theme) {
    return [
      // Comments
      _SyntaxPattern(RegExp(r'#.*$'), theme.comment),

      // Strings
      _SyntaxPattern(RegExp(r'"[^"]*"'), theme.string),
      _SyntaxPattern(RegExp(r"'[^']*'"), theme.string),

      // Variables
      _SyntaxPattern(RegExp(r'\$[a-zA-Z_][a-zA-Z0-9_]*'), theme.variable),
      _SyntaxPattern(RegExp(r'\$\{[^}]+\}'), theme.variable),

      // Keywords
      _SyntaxPattern(
        RegExp(
            r'\b(if|then|else|elif|fi|for|do|done|while|until|case|esac|function|return|exit|break|continue|export|source|alias|unset|local|readonly|declare)\b'),
        theme.keyword,
      ),
    ];
  }

  List<_SyntaxPattern> _getGoPatterns(CodeTheme theme) {
    return [
      // Comments
      _SyntaxPattern(RegExp(r'//.*$'), theme.comment),
      _SyntaxPattern(RegExp(r'/\*[\s\S]*?\*/'), theme.comment),

      // Strings
      _SyntaxPattern(RegExp(r'"[^"]*"'), theme.string),
      _SyntaxPattern(RegExp(r'`[^`]*`'), theme.string),

      // Numbers
      _SyntaxPattern(RegExp(r'\b\d+\.?\d*\b'), theme.number),

      // Keywords
      _SyntaxPattern(
        RegExp(
            r'\b(break|case|chan|const|continue|default|defer|else|fallthrough|for|func|go|goto|if|import|interface|map|package|range|return|select|struct|switch|type|var)\b'),
        theme.keyword,
      ),

      // Types
      _SyntaxPattern(
        RegExp(
            r'\b(bool|byte|complex64|complex128|error|float32|float64|int|int8|int16|int32|int64|rune|string|uint|uint8|uint16|uint32|uint64|uintptr)\b'),
        theme.className,
      ),
    ];
  }

  List<_SyntaxPattern> _getRustPatterns(CodeTheme theme) {
    return [
      // Comments
      _SyntaxPattern(RegExp(r'//.*$'), theme.comment),
      _SyntaxPattern(RegExp(r'/\*[\s\S]*?\*/'), theme.comment),

      // Strings
      _SyntaxPattern(RegExp(r'"[^"]*"'), theme.string),

      // Numbers
      _SyntaxPattern(RegExp(r'\b\d+\.?\d*\b'), theme.number),

      // Keywords
      _SyntaxPattern(
        RegExp(
            r'\b(as|async|await|break|const|continue|crate|dyn|else|enum|extern|false|fn|for|if|impl|in|let|loop|match|mod|move|mut|pub|ref|return|self|Self|static|struct|super|trait|true|type|union|unsafe|use|where|while)\b'),
        theme.keyword,
      ),

      // Types
      _SyntaxPattern(
        RegExp(
            r'\b(bool|char|f32|f64|i8|i16|i32|i64|i128|isize|str|u8|u16|u32|u64|u128|usize|String|Vec|Option|Result|Box)\b'),
        theme.className,
      ),
    ];
  }

  List<_SyntaxPattern> _getGenericPatterns(CodeTheme theme) {
    return [
      // Comments (common styles)
      _SyntaxPattern(RegExp(r'//.*$'), theme.comment),
      _SyntaxPattern(RegExp(r'#.*$'), theme.comment),
      _SyntaxPattern(RegExp(r'/\*[\s\S]*?\*/'), theme.comment),

      // Strings
      _SyntaxPattern(RegExp(r'"[^"]*"'), theme.string),
      _SyntaxPattern(RegExp(r"'[^']*'"), theme.string),

      // Numbers
      _SyntaxPattern(RegExp(r'\b\d+\.?\d*\b'), theme.number),
    ];
  }

  String _formatLanguageName(String language) {
    final languageNames = {
      'js': 'JavaScript',
      'ts': 'TypeScript',
      'py': 'Python',
      'rb': 'Ruby',
      'sh': 'Shell',
      'yml': 'YAML',
      'md': 'Markdown',
    };
    return languageNames[language.toLowerCase()] ??
        language.substring(0, 1).toUpperCase() + language.substring(1);
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: widget.code));

    setState(() {
      _copied = true;
    });

    widget.onCopied?.call();

    // Reset after delay
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _copied = false;
      });
    }
  }
}

/// Internal class for syntax pattern matching
class _SyntaxPattern {
  final RegExp pattern;
  final Color color;

  _SyntaxPattern(this.pattern, this.color);
}

/// Internal class for storing syntax matches
class _SyntaxMatch {
  final int start;
  final int end;
  final String text;
  final Color color;

  _SyntaxMatch({
    required this.start,
    required this.end,
    required this.text,
    required this.color,
  });
}

/// Inline code widget (for inline code within text)
class InlineCode extends StatelessWidget {
  final String text;
  final ConferBotTheme? theme;
  final Color? backgroundColor;
  final Color? textColor;

  const InlineCode({
    super.key,
    required this.text,
    this.theme,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = theme ?? defaultTheme;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: effectiveTheme.spacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: backgroundColor ??
            effectiveTheme.colors.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(effectiveTheme.borderRadius.sm),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: effectiveTheme.typography.fontSizeSm,
          color: textColor ?? effectiveTheme.colors.text,
        ),
      ),
    );
  }
}
