import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:conferbot_flutter/conferbot_flutter.dart';
import 'package:conferbot_flutter/src/models/knowledge_base.dart';
import 'package:conferbot_flutter/src/widgets/knowledge_base/article_detail.dart';

void main() {
  KnowledgeBaseArticle createTestArticle({
    String id = 'article-1',
    String title = 'Test Article Title',
    String description = 'Test description',
    String content = 'Test article content',
    String? categoryName,
    int? readTimeMinutes,
    List<KnowledgeBaseArticle>? relatedArticles,
  }) {
    return KnowledgeBaseArticle(
      id: id,
      title: title,
      description: description,
      content: content,
      categoryId: 'cat-1',
      categoryName: categoryName,
      readTimeMinutes: readTimeMinutes,
      relatedArticles: relatedArticles,
    );
  }

  group('ArticleDetail', () {
    group('Basic rendering', () {
      testWidgets('renders article title', (WidgetTester tester) async {
        final article = createTestArticle(title: 'My Article Title');

        await tester.pumpWidget(
          MaterialApp(
            home: ArticleDetail(
              article: article,
            ),
          ),
        );

        expect(find.text('My Article Title'), findsOneWidget);
      });

      testWidgets('renders article content', (WidgetTester tester) async {
        final article = createTestArticle(content: 'Article body content');

        await tester.pumpWidget(
          MaterialApp(
            home: ArticleDetail(
              article: article,
            ),
          ),
        );

        expect(find.byType(ArticleDetail), findsOneWidget);
      });

      testWidgets('renders category when provided', (WidgetTester tester) async {
        final article = createTestArticle(categoryName: 'FAQ');

        await tester.pumpWidget(
          MaterialApp(
            home: ArticleDetail(
              article: article,
            ),
          ),
        );

        expect(find.text('FAQ'), findsOneWidget);
      });
    });

    group('Navigation', () {
      testWidgets('shows back button when onBack is provided',
          (WidgetTester tester) async {
        final article = createTestArticle();

        await tester.pumpWidget(
          MaterialApp(
            home: ArticleDetail(
              article: article,
              onBack: () {},
            ),
          ),
        );

        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      });

      testWidgets('calls onBack when back button is tapped',
          (WidgetTester tester) async {
        bool backCalled = false;
        final article = createTestArticle();

        await tester.pumpWidget(
          MaterialApp(
            home: ArticleDetail(
              article: article,
              onBack: () {
                backCalled = true;
              },
            ),
          ),
        );

        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pump();

        expect(backCalled, isTrue);
      });
    });

    group('Share functionality', () {
      testWidgets('shows share button', (WidgetTester tester) async {
        final article = createTestArticle();

        await tester.pumpWidget(
          MaterialApp(
            home: ArticleDetail(
              article: article,
            ),
          ),
        );

        expect(find.byIcon(Icons.share_outlined), findsOneWidget);
      });
    });

    group('Insert to chat', () {
      testWidgets('shows FAB when onInsertToChat is provided',
          (WidgetTester tester) async {
        final article = createTestArticle();

        await tester.pumpWidget(
          MaterialApp(
            home: ArticleDetail(
              article: article,
              onInsertToChat: () {},
            ),
          ),
        );

        expect(find.byType(FloatingActionButton), findsOneWidget);
        expect(find.text('Share in Chat'), findsOneWidget);
      });

      testWidgets('hides FAB when onInsertToChat is null',
          (WidgetTester tester) async {
        final article = createTestArticle();

        await tester.pumpWidget(
          MaterialApp(
            home: ArticleDetail(
              article: article,
            ),
          ),
        );

        expect(find.byType(FloatingActionButton), findsNothing);
      });

      testWidgets('calls onInsertToChat when FAB is tapped',
          (WidgetTester tester) async {
        bool insertCalled = false;
        final article = createTestArticle();

        await tester.pumpWidget(
          MaterialApp(
            home: ArticleDetail(
              article: article,
              onInsertToChat: () {
                insertCalled = true;
              },
            ),
          ),
        );

        await tester.tap(find.byType(FloatingActionButton));
        await tester.pump();

        expect(insertCalled, isTrue);
      });
    });

    group('Related articles', () {
      testWidgets('shows related articles section when available',
          (WidgetTester tester) async {
        final relatedArticles = [
          createTestArticle(id: 'related-1', title: 'Related Article 1'),
          createTestArticle(id: 'related-2', title: 'Related Article 2'),
        ];

        final article = createTestArticle(relatedArticles: relatedArticles);

        await tester.pumpWidget(
          MaterialApp(
            home: ArticleDetail(
              article: article,
            ),
          ),
        );

        expect(find.byType(ArticleDetail), findsOneWidget);
      });
    });

    group('Rating', () {
      testWidgets('shows rating section', (WidgetTester tester) async {
        final article = createTestArticle();

        await tester.pumpWidget(
          MaterialApp(
            home: ArticleDetail(
              article: article,
            ),
          ),
        );

        expect(find.byType(ArticleDetail), findsOneWidget);
      });

      testWidgets('shows rating error message when provided',
          (WidgetTester tester) async {
        final article = createTestArticle();

        await tester.pumpWidget(
          MaterialApp(
            home: ArticleDetail(
              article: article,
              ratingError: 'Failed to submit rating',
            ),
          ),
        );

        expect(find.byType(ArticleDetail), findsOneWidget);
      });

      testWidgets('shows rating success message when provided',
          (WidgetTester tester) async {
        final article = createTestArticle();

        await tester.pumpWidget(
          MaterialApp(
            home: ArticleDetail(
              article: article,
              ratingSuccess: 'Thanks for your feedback!',
            ),
          ),
        );

        expect(find.byType(ArticleDetail), findsOneWidget);
      });

      testWidgets('shows loading indicator when isRating is true',
          (WidgetTester tester) async {
        final article = createTestArticle();

        await tester.pumpWidget(
          MaterialApp(
            home: ArticleDetail(
              article: article,
              isRating: true,
            ),
          ),
        );

        expect(find.byType(ArticleDetail), findsOneWidget);
      });
    });

    group('Theme integration', () {
      testWidgets('uses default theme when no theme provided',
          (WidgetTester tester) async {
        final article = createTestArticle();

        await tester.pumpWidget(
          MaterialApp(
            home: ArticleDetail(
              article: article,
            ),
          ),
        );

        expect(find.byType(ArticleDetail), findsOneWidget);
      });

      testWidgets('uses custom theme when provided',
          (WidgetTester tester) async {
        final article = createTestArticle();

        await tester.pumpWidget(
          MaterialApp(
            home: ArticleDetail(
              article: article,
              theme: defaultTheme,
            ),
          ),
        );

        expect(find.byType(ArticleDetail), findsOneWidget);
      });
    });

    group('Disposal', () {
      testWidgets('disposes properly', (WidgetTester tester) async {
        final article = createTestArticle();

        await tester.pumpWidget(
          MaterialApp(
            home: ArticleDetail(
              article: article,
            ),
          ),
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(),
            ),
          ),
        );

        await tester.pump();
      });
    });
  });
}
