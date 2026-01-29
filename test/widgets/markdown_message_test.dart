import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:conferbot_flutter/conferbot_flutter.dart';

void main() {
  group('MarkdownDetector', () {
    test('detects bold text', () {
      expect(MarkdownDetector.containsMarkdown('**bold text**'), isTrue);
      expect(MarkdownDetector.containsMarkdown('__bold text__'), isTrue);
    });

    test('detects italic text', () {
      expect(MarkdownDetector.containsMarkdown('*italic text*'), isTrue);
      expect(MarkdownDetector.containsMarkdown('_italic text_'), isTrue);
    });

    test('detects headers', () {
      expect(MarkdownDetector.containsMarkdown('# Header 1'), isTrue);
      expect(MarkdownDetector.containsMarkdown('## Header 2'), isTrue);
      expect(MarkdownDetector.containsMarkdown('### Header 3'), isTrue);
    });

    test('detects code blocks', () {
      expect(MarkdownDetector.containsMarkdown('```dart\ncode\n```'), isTrue);
      expect(MarkdownDetector.containsMarkdown('`inline code`'), isTrue);
    });

    test('detects links', () {
      expect(MarkdownDetector.containsMarkdown('[link](https://example.com)'), isTrue);
    });

    test('detects lists', () {
      expect(MarkdownDetector.containsMarkdown('- item 1'), isTrue);
      expect(MarkdownDetector.containsMarkdown('* item 1'), isTrue);
      expect(MarkdownDetector.containsMarkdown('1. item 1'), isTrue);
    });

    test('detects blockquotes', () {
      expect(MarkdownDetector.containsMarkdown('> quoted text'), isTrue);
    });

    test('returns false for plain text', () {
      expect(MarkdownDetector.containsMarkdown('plain text'), isFalse);
      expect(MarkdownDetector.containsMarkdown('Hello, world!'), isFalse);
    });

    test('containsCodeBlock works correctly', () {
      expect(MarkdownDetector.containsCodeBlock('```dart\ncode\n```'), isTrue);
      expect(MarkdownDetector.containsCodeBlock('`inline code`'), isTrue);
      expect(MarkdownDetector.containsCodeBlock('no code here'), isFalse);
    });

    test('containsLinks works correctly', () {
      expect(MarkdownDetector.containsLinks('[link](https://example.com)'), isTrue);
      expect(MarkdownDetector.containsLinks('https://example.com'), isTrue);
      expect(MarkdownDetector.containsLinks('no links here'), isFalse);
    });

    test('getMarkdownComplexity returns correct score', () {
      expect(MarkdownDetector.getMarkdownComplexity('plain text'), equals(0));
      expect(MarkdownDetector.getMarkdownComplexity('**bold**'), greaterThan(0));
      expect(
        MarkdownDetector.getMarkdownComplexity(
          '# Header\n**bold** *italic*\n- list\n```code```',
        ),
        greaterThan(3),
      );
    });

    test('extractLinks returns all links', () {
      final text = 'Check [Google](https://google.com) and https://example.com';
      final links = MarkdownDetector.extractLinks(text);
      expect(links, contains('https://google.com'));
      expect(links, contains('https://example.com'));
    });

    test('extractCodeBlocks returns code blocks', () {
      final text = '''
```dart
void main() {
  print('Hello');
}
```

```javascript
console.log('Hi');
```
''';
      final blocks = MarkdownDetector.extractCodeBlocks(text);
      expect(blocks.length, equals(2));
      expect(blocks[0].language, equals('dart'));
      expect(blocks[1].language, equals('javascript'));
    });
  });

  group('MarkdownLinkHandler', () {
    test('detects email links', () {
      final handler = MarkdownLinkHandler();
      expect(
        MarkdownLinkHandler.parseEmailAddress('mailto:test@example.com'),
        equals('test@example.com'),
      );
    });

    test('detects phone links', () {
      expect(
        MarkdownLinkHandler.parsePhoneNumber('tel:+1234567890'),
        equals('+1234567890'),
      );
    });

    test('creates mailto URL', () {
      final url = MarkdownLinkHandler.createMailtoUrl(
        email: 'test@example.com',
        subject: 'Test Subject',
        body: 'Test Body',
      );
      expect(url, contains('mailto:test@example.com'));
      expect(url, contains('subject=Test%20Subject'));
      expect(url, contains('body=Test%20Body'));
    });

    test('creates tel URL', () {
      final url = MarkdownLinkHandler.createTelUrl('+1 (234) 567-890');
      expect(url, equals('tel:+1234567890'));
    });

    test('creates sms URL', () {
      final url = MarkdownLinkHandler.createSmsUrl('+1234567890', body: 'Hello');
      expect(url, contains('sms:+1234567890'));
      expect(url, contains('body=Hello'));
    });
  });

  group('MarkdownThemeConfig', () {
    test('creates from bot theme', () {
      final config = MarkdownThemeConfig.fromBotTheme(defaultTheme);
      expect(config.textColor, equals(defaultTheme.colors.botBubbleText));
      expect(config.linkColor, equals(defaultTheme.colors.primary));
    });

    test('creates from user theme', () {
      final config = MarkdownThemeConfig.fromUserTheme(defaultTheme);
      expect(config.textColor, equals(defaultTheme.colors.userBubbleText));
    });

    test('creates from agent theme', () {
      final config = MarkdownThemeConfig.fromAgentTheme(defaultTheme);
      expect(config.textColor, equals(defaultTheme.colors.agentBubbleText));
    });

    test('creates from system theme', () {
      final config = MarkdownThemeConfig.fromSystemTheme(defaultTheme);
      expect(config.textColor, equals(defaultTheme.colors.systemBubbleText));
    });

    test('copyWith creates new instance with updated values', () {
      final original = MarkdownThemeConfig.fromBotTheme(defaultTheme);
      final newColor = Colors.red;
      final copied = original.copyWith(textColor: newColor);

      expect(copied.textColor, equals(newColor));
      expect(copied.linkColor, equals(original.linkColor));
    });

    test('toStyleSheet creates valid MarkdownStyleSheet', () {
      final config = MarkdownThemeConfig.fromBotTheme(defaultTheme);
      final styleSheet = config.toStyleSheet(defaultTheme);

      expect(styleSheet.p, isNotNull);
      expect(styleSheet.h1, isNotNull);
      expect(styleSheet.code, isNotNull);
      expect(styleSheet.blockquote, isNotNull);
    });
  });

  group('CodeTheme', () {
    test('creates light theme', () {
      final theme = CodeTheme.light();
      expect(theme.background, equals(const Color(0xFFF5F5F5)));
    });

    test('creates dark theme', () {
      final theme = CodeTheme.dark();
      expect(theme.background, equals(const Color(0xFF1E1E1E)));
    });

    test('creates from ConferBotTheme', () {
      final lightTheme = defaultTheme;
      final codeTheme = CodeTheme.fromTheme(lightTheme);
      expect(codeTheme.background, equals(CodeTheme.light().background));
    });
  });

  group('MarkdownMessage Widget', () {
    testWidgets('renders plain text', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MarkdownMessage(
              content: 'Hello, world!',
            ),
          ),
        ),
      );

      expect(find.text('Hello, world!'), findsOneWidget);
    });

    testWidgets('renders bold text', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MarkdownMessage(
              content: '**bold text**',
            ),
          ),
        ),
      );

      expect(find.text('bold text'), findsOneWidget);
    });

    testWidgets('renders headers', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MarkdownMessage(
              content: '# Header 1',
            ),
          ),
        ),
      );

      expect(find.text('Header 1'), findsOneWidget);
    });

    testWidgets('renders code blocks', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MarkdownMessage(
                content: '```dart\nvoid main() {}\n```',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // CodeBlock widget should be present
      expect(find.byType(CodeBlock), findsOneWidget);
    });

    testWidgets('renders lists', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MarkdownMessage(
              content: '- Item 1\n- Item 2\n- Item 3',
            ),
          ),
        ),
      );

      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
      expect(find.text('Item 3'), findsOneWidget);
    });

    testWidgets('renders blockquotes', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MarkdownMessage(
              content: '> This is a quote',
            ),
          ),
        ),
      );

      expect(find.text('This is a quote'), findsOneWidget);
    });
  });

  group('SmartMarkdownMessage Widget', () {
    testWidgets('uses plain text for simple content', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SmartMarkdownMessage(
              content: 'Simple text without markdown',
            ),
          ),
        ),
      );

      expect(find.text('Simple text without markdown'), findsOneWidget);
      expect(find.byType(MarkdownMessage), findsNothing);
    });

    testWidgets('uses markdown for complex content', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SmartMarkdownMessage(
              content: '**Bold** and *italic*',
            ),
          ),
        ),
      );

      expect(find.byType(MarkdownMessage), findsOneWidget);
    });

    testWidgets('forces markdown when forceMarkdown is true', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SmartMarkdownMessage(
              content: 'Simple text',
              forceMarkdown: true,
            ),
          ),
        ),
      );

      expect(find.byType(MarkdownMessage), findsOneWidget);
    });
  });

  group('CodeBlock Widget', () {
    testWidgets('renders code content', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CodeBlock(
                code: 'print("Hello, World!");',
                language: 'dart',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Dart'), findsOneWidget);
      expect(find.textContaining('print'), findsWidgets);
    });

    testWidgets('shows copy button', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CodeBlock(
                code: 'test code',
                showCopyButton: true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Copy'), findsOneWidget);
    });

    testWidgets('hides copy button when disabled', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CodeBlock(
                code: 'test code',
                showCopyButton: false,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Copy'), findsNothing);
    });

    testWidgets('shows line numbers', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CodeBlock(
                code: 'line 1\nline 2\nline 3',
                showLineNumbers: true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });
  });

  group('InlineCode Widget', () {
    testWidgets('renders inline code', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InlineCode(
              text: 'inlineCode',
            ),
          ),
        ),
      );

      expect(find.text('inlineCode'), findsOneWidget);
    });
  });

  group('RichTextMessage Widget', () {
    testWidgets('renders with markdown when detected', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RichTextMessage(
              text: '**bold** text',
            ),
          ),
        ),
      );

      expect(find.byType(MarkdownMessage), findsOneWidget);
    });

    testWidgets('renders plain text when no markdown', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RichTextMessage(
              text: 'plain text',
            ),
          ),
        ),
      );

      expect(find.text('plain text'), findsOneWidget);
      expect(find.byType(MarkdownMessage), findsNothing);
    });

    testWidgets('uses selectable text when enabled', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RichTextMessage(
              text: 'plain text',
              selectable: true,
              autoDetectMarkdown: false,
              enableMarkdown: false,
            ),
          ),
        ),
      );

      expect(find.byType(SelectableText), findsOneWidget);
    });
  });

  group('MessageBubble with Markdown', () {
    testWidgets('renders markdown in bot messages', (WidgetTester tester) async {
      final message = BotMessageRecord(
        id: 'test-1',
        time: DateTime.now(),
        text: '**Bold** and *italic* text',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              message: message,
              enableMarkdown: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(MarkdownMessage), findsOneWidget);
    });

    testWidgets('disables markdown when enableMarkdown is false', (WidgetTester tester) async {
      final message = BotMessageRecord(
        id: 'test-1',
        time: DateTime.now(),
        text: '**Bold** text',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              message: message,
              enableMarkdown: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(MarkdownMessage), findsNothing);
      expect(find.text('**Bold** text'), findsOneWidget);
    });

    testWidgets('auto-detects markdown when autoDetectMarkdown is true', (WidgetTester tester) async {
      final plainMessage = BotMessageRecord(
        id: 'test-1',
        time: DateTime.now(),
        text: 'Plain text without any markdown',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              message: plainMessage,
              enableMarkdown: true,
              autoDetectMarkdown: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Plain text should not use markdown renderer
      expect(find.byType(MarkdownMessage), findsNothing);
    });
  });

  group('LinkHandlerScope', () {
    testWidgets('provides handler to descendants', (WidgetTester tester) async {
      final handler = MarkdownLinkHandler(
        onLinkTapped: (url, type) {},
      );

      late MarkdownLinkHandler? retrievedHandler;

      await tester.pumpWidget(
        MaterialApp(
          home: LinkHandlerScope(
            handler: handler,
            child: Builder(
              builder: (context) {
                retrievedHandler = LinkHandlerScope.of(context);
                return Container();
              },
            ),
          ),
        ),
      );

      expect(retrievedHandler, equals(handler));
    });
  });
}
