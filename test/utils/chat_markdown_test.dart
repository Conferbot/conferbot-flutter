// Markdown as the web's utils/agentHtml.ts draws an agent's reply (#52):
// tables, h3-h6, blockquote, pre and strikethrough. The cases of the React
// Native SDK's __tests__/utils/chatMarkdown.test.ts.
import 'package:conferbot_flutter/src/utils/chat_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

const _p = InlineKind.plain;

void main() {
  test('headings: # and ## drawn as level 4 (the web folds h1/h2), 3-6 keep theirs', () {
    final levels = ChatMarkdown.parse('# A\n## B\n### C\n#### D\n##### E\n###### F').map((b) => b.level).toList();
    expect(levels, [4, 4, 3, 4, 5, 6]);
    expect(ChatMarkdown.htmlToMarkdown('<h2>Plans</h2><h3>Pro</h3><h6>small</h6>'), '#### Plans\n\n### Pro\n\n###### small');
    expect(ChatMarkdown.parse('#hashtag').first.kind, BlockKind.paragraph);
  });

  test('tables, as the web draws markdown tables', () {
    final t = ChatMarkdown.parse('| Plan | Price |\n|---|:---:|\n| **Pro** | \$49 |\n| Team |').single;
    expect(t.kind, BlockKind.table);
    expect(t.head, const [
      [ChatInline(_p, 'Plan')],
      [ChatInline(_p, 'Price')],
    ]);
    expect(t.rows, const [
      [
        [ChatInline(InlineKind.bold, 'Pro')],
        [ChatInline(_p, '\$49')],
      ],
      // A short row is filled to the head's width.
      [
        [ChatInline(_p, 'Team')],
        <ChatInline>[],
      ],
    ]);
    // A row without its rule is not a table.
    expect(ChatMarkdown.parse('| a | b |\n| c | d |').first.kind, BlockKind.paragraph);
  });

  test("a person's HTML table, its cells' pipes kept", () {
    final md = ChatMarkdown.htmlToMarkdown(
        '<table><thead><tr><th>Plan</th><th>Note</th></tr></thead><tbody><tr><td><b>Pro</b></td><td>a | b</td></tr></tbody></table>');
    expect(md, '| Plan | Note |\n| --- | --- |\n| **Pro** | a \\| b |');
    final t = ChatMarkdown.parse(md).single;
    expect(t.rows[0][1], const [ChatInline(_p, 'a | b')]);
  });

  test("blockquote, pre and strikethrough from a person's HTML", () {
    expect(ChatMarkdown.htmlToMarkdown('<blockquote><p>Quoted</p><p>twice</p></blockquote><p>After</p>'), '> Quoted\n> twice\n\nAfter');
    expect(ChatMarkdown.htmlToMarkdown('<pre>npm i\n  **x**</pre>'), '```\nnpm i\n  **x**\n```');
    expect(ChatMarkdown.htmlToMarkdown('<p><s>\$59</s> <del>old</del> \$49</p>'), '~~\$59~~ ~~old~~ \$49');
    final blocks = ChatMarkdown.parse('> Quoted\n> twice\n\n```\nnpm i\n  **x**\n```\nok ~~no~~');
    expect(blocks.map((b) => b.kind).toList(), [BlockKind.quote, BlockKind.pre, BlockKind.paragraph]);
    expect(blocks[0].inlines, const [ChatInline(_p, 'Quoted\ntwice')]);
    expect(blocks[1].text, 'npm i\n  **x**');
    expect(blocks[2].inlines, const [ChatInline(_p, 'ok '), ChatInline(InlineKind.strike, 'no')]);
    expect(ChatMarkdown.plainText(blocks), 'Quoted\ntwice\nnpm i\n  **x**\nok no');
  });

  test('splits a reply into its tables and the text around them, never inside a code fence', () {
    final parts = ChatMarkdown.splitTables('Our plans:\n\n| Plan | Price |\n| --- | --- |\n| Pro | \$49 |\n\nAsk me more.');
    expect(parts.length, 3);
    expect(parts[0], 'Our plans:');
    expect((parts[1] as ChatBlock).kind, BlockKind.table);
    expect(parts[2], 'Ask me more.');
    final fenced = ChatMarkdown.splitTables('```\n| a | b |\n| --- | --- |\n```');
    expect(fenced.single, isA<String>());
  });
}
