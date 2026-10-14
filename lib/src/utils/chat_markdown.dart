/// Agent message text for a native bubble. AI replies arrive as markdown
/// wrapped in <p> (embed-server aiAgentHandlerService), a person's as the
/// inbox editor's HTML. Both become one small markdown subset - paragraphs,
/// "- " / "1." lists, **bold**, _italic_, `code`, [links](https://...) and
/// bare links - parsed into blocks of inline runs. Never HTML on screen:
/// only http(s), mailto and tel links survive. Pure Dart.
library;

enum InlineKind { plain, bold, italic, code, link }

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

enum BlockKind { paragraph, bullet, numbered }

class ChatBlock {
  final BlockKind kind;
  final List<ChatInline> inlines;
  final int number;
  const ChatBlock(this.kind, this.inlines, [this.number = 0]);
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

  /// The message as markdown: the inbox's HTML tags turned into their markdown.
  static String htmlToMarkdown(String? html) {
    if (html == null || html.isEmpty) return '';
    var s = html.replaceAll(RegExp(r'\r\n?'), '\n');
    s = s.replaceAllMapped(
      RegExp(r'''<a\s[^>]*href\s*=\s*["']([^"']+)["'][^>]*>(.*?)</a>''', caseSensitive: false, dotAll: true),
      (m) {
        final url = m.group(1)!;
        final label = m.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').trim();
        return safeLinkUrl(url) != null ? '[${label.isEmpty ? url : label}]($url)' : label;
      },
    );
    s = s.replaceAllMapped(RegExp(r'<(strong|b)>(.*?)</\1>', caseSensitive: false, dotAll: true), (m) => '**${m.group(2)}**');
    s = s.replaceAllMapped(RegExp(r'<(em|i)>(.*?)</\1>', caseSensitive: false, dotAll: true), (m) => '_${m.group(2)}_');
    s = s.replaceAllMapped(RegExp(r'<code>(.*?)</code>', caseSensitive: false, dotAll: true), (m) => '`${m.group(1)}`');
    s = s.replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '\n- ');
    s = s.replaceAll(RegExp(r'</(li|ul|ol)>', caseSensitive: false), '\n');
    s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    s = s.replaceAll(RegExp(r'</p>\s*<p[^>]*>', caseSensitive: false), '\n\n');
    s = s.replaceAll(RegExp(r'</?(p|div|ul|ol)[^>]*>', caseSensitive: false), '\n');
    s = s.replaceAll(RegExp(r'<[^>]+>'), '');
    s = _decode(s);
    s = s.replaceAll(RegExp(r'[ \t]+\n'), '\n');
    s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return s.trim();
  }

  // An italic's leading character is captured (group 6) and given back as text.
  static final _inline = RegExp(
    r'''\*\*([^*]+)\*\*|__([^_]+)__|`([^`]+)`|\[([^\]]+)\]\(([^)\s]+)\)|(^|[^\w*])[*_]([^*_\n]+)[*_](?![\w*])|(https?://[^\s<>()]+[^\s<>().,;:!?'"])''',
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
      }
    }
    push(line.substring(last));
    return out;
  }

  /// The text as blocks: list items, and paragraphs (a single newline is a line break).
  static List<ChatBlock> parse(String? markdown) {
    final blocks = <ChatBlock>[];
    final para = <String>[];
    void flush() {
      if (para.isNotEmpty) blocks.add(ChatBlock(BlockKind.paragraph, parseInline(para.join('\n'))));
      para.clear();
    }

    for (final raw in (markdown ?? '').split('\n')) {
      final line = raw.trim();
      final bullet = RegExp(r'^[-*•]\s+(.*)$').firstMatch(line);
      final numbered = RegExp(r'^(\d{1,3})[.)]\s+(.*)$').firstMatch(line);
      if (bullet != null) {
        flush();
        blocks.add(ChatBlock(BlockKind.bullet, parseInline(bullet.group(1)!)));
      } else if (numbered != null) {
        flush();
        blocks.add(ChatBlock(BlockKind.numbered, parseInline(numbered.group(2)!), int.parse(numbered.group(1)!)));
      } else if (line.isEmpty) {
        flush();
      } else {
        para.add(line.replaceFirst(RegExp(r'^#{1,6}\s+'), ''));
      }
    }
    flush();
    return blocks;
  }

  /// Plain text of the blocks (accessibility, transcript, notifications).
  static String plainText(List<ChatBlock> blocks) => blocks.map((b) {
        final text = b.inlines.map((i) => i.text).join();
        return switch (b.kind) {
          BlockKind.bullet => '• $text',
          BlockKind.numbered => '${b.number}. $text',
          BlockKind.paragraph => text,
        };
      }).join('\n');
}
