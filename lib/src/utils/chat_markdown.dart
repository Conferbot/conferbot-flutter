/// Agent message text for a native bubble. AI replies arrive as markdown
/// wrapped in <p> (embed-server aiAgentHandlerService), a person's as the
/// inbox editor's HTML. Both become one markdown subset, parsed into blocks
/// of inline runs. What the web's renderer (conferbot-widget
/// utils/agentHtml.ts) draws, as the React Native SDK's
/// src/utils/chatMarkdown.ts:
///
///   blocks   paragraphs, "- " / "1." lists, # headings (levels 3-6; # and
///            ## are drawn as 4, as the web folds h1/h2 into h4), | tables |
///            with a |---| rule, and from a person's HTML: <blockquote>
///            ("> " lines here) and <pre> (``` fences here)
///   inline   **bold**, _italic_, `code`, ~~strikethrough~~ (<s>, <del>),
///            [links](https://...) and bare links
///
/// Never HTML on screen: only http(s), mailto and tel links survive. Pure Dart.
library;

enum InlineKind { plain, bold, italic, code, strike, link }

class ChatInline {
  final InlineKind kind;
  final String text;
  final String? url;
  const ChatInline(this.kind, this.text, [this.url]);

  @override
  bool operator ==(Object other) => other is ChatInline && other.kind == kind && other.text == text && other.url == url;

  @override
  int get hashCode => Object.hash(kind, text, url);

  @override
  String toString() => '$kind($text${url != null ? ', $url' : ''})';
}

enum BlockKind { paragraph, bullet, numbered, heading, quote, pre, table }

class ChatBlock {
  final BlockKind kind;
  final List<ChatInline> inlines;
  final int number;

  /// A heading's level, 3 to 6.
  final int level;

  /// A pre block's lines, as they are.
  final String text;

  /// A table's head cells and rows (each row as wide as the head).
  final List<List<ChatInline>> head;
  final List<List<List<ChatInline>>> rows;

  const ChatBlock(
    this.kind,
    this.inlines, [
    this.number = 0,
  ])  : level = 0,
        text = '',
        head = const [],
        rows = const [];

  const ChatBlock.heading(this.level, this.inlines)
      : kind = BlockKind.heading,
        number = 0,
        text = '',
        head = const [],
        rows = const [];

  const ChatBlock.pre(this.text)
      : kind = BlockKind.pre,
        inlines = const [],
        number = 0,
        level = 0,
        head = const [],
        rows = const [];

  const ChatBlock.table(this.head, this.rows)
      : kind = BlockKind.table,
        inlines = const [],
        number = 0,
        level = 0,
        text = '';
}

class ChatMarkdown {
  ChatMarkdown._();

  static const _entities = {'&nbsp;': ' ', '&amp;': '&', '&lt;': '<', '&gt;': '>', '&quot;': '"', '&#39;': "'", '&#x27;': "'"};

  static String? safeLinkUrl(String url) {
    final u = url.trim();
    return RegExp(r'^(https?://|mailto:|tel:)', caseSensitive: false).hasMatch(u) ? u : null;
  }

  static String _decode(String s) =>
      s.replaceAllMapped(RegExp(r'&(nbsp|amp|lt|gt|quot|#39|#x27);'), (m) => _entities[m.group(0)] ?? m.group(0)!);

  static RegExp _re(String source) => RegExp(source, caseSensitive: false, dotAll: true);
  static final _tags = RegExp(r'<[^>]+>');
  static final _br = RegExp(r'<br\s*/?>', caseSensitive: false);

  // A cell's text: no tags, no line breaks, and its own "|" kept as text.
  static String _cellText(String html) =>
      html.replaceAll(_br, ' ').replaceAll(_tags, '').replaceAll(RegExp(r'\s+'), ' ').trim().replaceAll('|', r'\|');

  /// An HTML table as a markdown one: the first row is the head.
  static String _tableToMarkdown(String inner) {
    final rows = _re(r'<tr[^>]*>(.*?)</tr>')
        .allMatches(inner)
        .map((m) => _re(r'<t[hd][^>]*>(.*?)</t[hd]>').allMatches(m.group(1)!).map((c) => _cellText(c.group(1)!)).toList())
        .where((r) => r.isNotEmpty)
        .toList();
    if (rows.isEmpty) return '';
    String line(List<String> cells) => '| ${cells.join(' | ')} |';
    return '\n\n${[line(rows.first), line(rows.first.map((_) => '---').toList()), ...rows.skip(1).map(line)].join('\n')}\n\n';
  }

  /// The message as markdown: the inbox's HTML tags turned into their markdown.
  static String htmlToMarkdown(String? html) {
    if (html == null || html.isEmpty) return '';
    var s = html.replaceAll(RegExp(r'\r\n?'), '\n');
    // Preformatted text keeps its lines and nothing inside is formatted.
    s = s.replaceAllMapped(_re(r'<pre[^>]*>(.*?)</pre>'), (m) {
      final text = m.group(1)!.replaceAll(_br, '\n').replaceAll(_tags, '').replaceAll(RegExp(r'^\n+|\n+$'), '');
      return '\n\n```\n$text\n```\n\n';
    });
    s = s.replaceAllMapped(
      _re(r'''<a\s[^>]*href\s*=\s*["']([^"']+)["'][^>]*>(.*?)</a>'''),
      (m) {
        final url = m.group(1)!;
        final label = m.group(2)!.replaceAll(_tags, '').trim();
        return safeLinkUrl(url) != null ? '[${label.isEmpty ? url : label}]($url)' : label;
      },
    );
    s = s.replaceAllMapped(_re(r'<(strong|b)>(.*?)</\1>'), (m) => '**${m.group(2)}**');
    s = s.replaceAllMapped(_re(r'<(em|i)>(.*?)</\1>'), (m) => '_${m.group(2)}_');
    s = s.replaceAllMapped(_re(r'<code>(.*?)</code>'), (m) => '`${m.group(1)}`');
    s = s.replaceAllMapped(_re(r'<(s|del|strike)>(.*?)</\1>'), (m) => '~~${m.group(2)}~~');
    // h1 / h2 are drawn as h4, as the web's sanitizer folds them.
    s = s.replaceAllMapped(_re(r'<h([1-6])[^>]*>(.*?)</h\1>'), (m) {
      final n = int.parse(m.group(1)!);
      final level = n <= 2 ? 4 : n;
      final text = m.group(2)!.replaceAll(_tags, '').replaceAll(RegExp(r'\s+'), ' ').trim();
      return '\n\n${'#' * level} $text\n\n';
    });
    s = s.replaceAllMapped(_re(r'<table[^>]*>(.*?)</table>'), (m) => _tableToMarkdown(m.group(1)!));
    s = s.replaceAllMapped(_re(r'<blockquote[^>]*>(.*?)</blockquote>'), (m) {
      final lines = m
          .group(1)!
          .replaceAll(_br, '\n')
          .replaceAll(RegExp(r'</p>\s*<p[^>]*>', caseSensitive: false), '\n')
          .replaceAll(_tags, '')
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty);
      return '\n\n${lines.map((l) => '> $l').join('\n')}\n\n';
    });
    s = s.replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '\n- ');
    s = s.replaceAll(RegExp(r'</(li|ul|ol)>', caseSensitive: false), '\n');
    s = s.replaceAll(_br, '\n');
    s = s.replaceAll(RegExp(r'</p>\s*<p[^>]*>', caseSensitive: false), '\n\n');
    s = s.replaceAll(RegExp(r'</?(p|div|ul|ol)[^>]*>', caseSensitive: false), '\n');
    s = s.replaceAll(_tags, '');
    s = _decode(s);
    s = s.replaceAll(RegExp(r'[ \t]+\n'), '\n');
    s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return s.trim();
  }

  // An italic's leading character is captured (group 6) and given back as text.
  static final _inline = RegExp(
    r'''\*\*([^*]+)\*\*|__([^_]+)__|`([^`]+)`|\[([^\]]+)\]\(([^)\s]+)\)|(^|[^\w*])[*_]([^*_\n]+)[*_](?![\w*])|(https?://[^\s<>()]+[^\s<>().,;:!?'"])|~~([^~\n]+)~~''',
  );

  /// One line's inline runs.
  static List<ChatInline> parseInline(String line) {
    final out = <ChatInline>[];
    void push(String text) {
      if (text.isEmpty) return;
      if (out.isNotEmpty && out.last.kind == InlineKind.plain) {
        out[out.length - 1] = ChatInline(InlineKind.plain, out.last.text + text);
      } else {
        out.add(ChatInline(InlineKind.plain, text));
      }
    }

    var last = 0;
    for (final m in _inline.allMatches(line)) {
      push(line.substring(last, m.start));
      last = m.end;
      String g(int i) => m.group(i) ?? '';
      if (g(1).isNotEmpty || g(2).isNotEmpty) {
        out.add(ChatInline(InlineKind.bold, g(1).isNotEmpty ? g(1) : g(2)));
      } else if (g(3).isNotEmpty) {
        out.add(ChatInline(InlineKind.code, g(3)));
      } else if (g(4).isNotEmpty) {
        final url = safeLinkUrl(g(5));
        if (url != null) {
          out.add(ChatInline(InlineKind.link, g(4), url));
        } else {
          push(g(4));
        }
      } else if (g(7).isNotEmpty) {
        push(g(6));
        out.add(ChatInline(InlineKind.italic, g(7)));
      } else if (g(8).isNotEmpty) {
        out.add(ChatInline(InlineKind.link, g(8), g(8)));
      } else if (g(9).isNotEmpty) {
        out.add(ChatInline(InlineKind.strike, g(9)));
      }
    }
    push(line.substring(last));
    return out;
  }

  // A markdown table: a header row, a |---| rule, then rows (web agentHtml.ts).
  static final _tableRow = RegExp(r'^\s*\|.*\|\s*$');
  static final _tableRule = RegExp(r'^\s*\|?\s*:?-{2,}:?\s*(\|\s*:?-{2,}:?\s*)*\|?\s*$');
  static final _heading = RegExp(r'^#{1,6}\s+(.*?)\s*#*\s*$');

  /// Is the line at [i] the head of a table (a row with its rule under it)?
  static bool isTableStart(List<String> lines, int i) {
    final next = i + 1 < lines.length ? lines[i + 1] : '';
    return _tableRow.hasMatch(lines[i]) && _tableRule.hasMatch(next) && next.contains('-');
  }

  /// Is this line a table's row?
  static bool isTableRow(String line) => _tableRow.hasMatch(line);

  /// A row's cells; a "\|" inside a cell is its own text.
  static List<String> tableCells(String line) {
    final cells = <String>[];
    final cell = StringBuffer();
    final s = line.trim();
    for (var i = 0; i < s.length; i++) {
      if (s[i] == r'\' && i + 1 < s.length && s[i + 1] == '|') {
        cell.write('|');
        i++;
      } else if (s[i] == '|') {
        cells.add(cell.toString());
        cell.clear();
      } else {
        cell.write(s[i]);
      }
    }
    cells.add(cell.toString());
    // The outer pipes open and close the row.
    if (s.startsWith('|')) cells.removeAt(0);
    if (s.endsWith('|') && !s.endsWith(r'\|') && cells.isNotEmpty) cells.removeLast();
    return cells.map((c) => c.trim()).toList();
  }

  /// The table starting at line [i]: the block and the index of its last line.
  static (ChatBlock, int) _table(List<String> lines, int i) {
    final head = tableCells(lines[i]);
    i += 2;
    final rows = <List<List<ChatInline>>>[];
    while (i < lines.length && _tableRow.hasMatch(lines[i])) {
      final cells = tableCells(lines[i++]);
      rows.add([for (var k = 0; k < head.length; k++) parseInline(k < cells.length ? cells[k] : '')]);
    }
    return (ChatBlock.table(head.map(parseInline).toList(), rows), i - 1);
  }

  /// The text as blocks: list items, headings, tables, quotes, code and
  /// paragraphs (a single newline is a line break).
  static List<ChatBlock> parse(String? markdown) {
    final blocks = <ChatBlock>[];
    final para = <String>[];
    final quote = <String>[];
    void flushPara() {
      if (para.isNotEmpty) blocks.add(ChatBlock(BlockKind.paragraph, parseInline(para.join('\n'))));
      para.clear();
    }

    void flush() {
      flushPara();
      if (quote.isNotEmpty) blocks.add(ChatBlock(BlockKind.quote, parseInline(quote.join('\n'))));
      quote.clear();
    }

    final lines = (markdown ?? '').split('\n');
    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i];
      final line = raw.trim();
      // ``` fences: the lines as they are, nothing formatted.
      if (line.startsWith('```')) {
        flush();
        final body = <String>[];
        i++;
        while (i < lines.length && !RegExp(r'^```\s*$').hasMatch(lines[i].trim())) {
          body.add(lines[i++]);
        }
        blocks.add(ChatBlock.pre(body.join('\n')));
        continue;
      }
      // A table: this row, a rule under it, and every row after.
      if (isTableStart(lines, i)) {
        flush();
        final (table, end) = _table(lines, i);
        blocks.add(table);
        i = end;
        continue;
      }
      final quoted = RegExp(r'^>\s?(.*)$').firstMatch(line);
      if (quoted != null) {
        flushPara();
        quote.add(quoted.group(1)!);
        continue;
      }
      if (quote.isNotEmpty) flush();
      final bullet = RegExp(r'^[-*+•]\s+(.*)$').firstMatch(line);
      final numbered = RegExp(r'^(\d{1,3})[.)]\s+(.*)$').firstMatch(line);
      final heading = _heading.firstMatch(line);
      if (bullet != null) {
        flush();
        blocks.add(ChatBlock(BlockKind.bullet, parseInline(bullet.group(1)!)));
      } else if (numbered != null) {
        flush();
        blocks.add(ChatBlock(BlockKind.numbered, parseInline(numbered.group(2)!), int.parse(numbered.group(1)!)));
      } else if (heading != null) {
        flush();
        final hashes = RegExp(r'^#+').firstMatch(line)!.group(0)!.length;
        blocks.add(ChatBlock.heading(hashes <= 2 ? 4 : hashes, parseInline(heading.group(1)!)));
      } else if (line.isEmpty) {
        flush();
      } else {
        para.add(line);
      }
    }
    flush();
    return blocks;
  }

  /// The text cut into its tables and what lies between them, in order: a
  /// table as its block, the rest as markdown (a bubble draws the tables in
  /// a sideways scroll, the rest with its markdown renderer).
  static List<Object> splitTables(String markdown) {
    final out = <Object>[];
    final lines = markdown.split('\n');
    final rest = <String>[];
    var fenced = false;
    void flushRest() {
      final text = rest.join('\n').trim();
      if (text.isNotEmpty) out.add(text);
      rest.clear();
    }

    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trim().startsWith('```')) fenced = !fenced;
      if (!fenced && isTableStart(lines, i)) {
        flushRest();
        final (table, end) = _table(lines, i);
        out.add(table);
        i = end;
        continue;
      }
      rest.add(lines[i]);
    }
    flushRest();
    return out;
  }

  static String _inlineText(List<ChatInline> inlines) => inlines.map((i) => i.text).join();

  /// Plain text of the blocks (accessibility, transcript, notifications).
  static String plainText(List<ChatBlock> blocks) => blocks.map((b) {
        final text = _inlineText(b.inlines);
        return switch (b.kind) {
          BlockKind.bullet => '• $text',
          BlockKind.numbered => '${b.number}. $text',
          BlockKind.pre => b.text,
          BlockKind.table => [b.head, ...b.rows].map((r) => r.map(_inlineText).join(' | ')).join('\n'),
          _ => text,
        };
      }).join('\n');
}
