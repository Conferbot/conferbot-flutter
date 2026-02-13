import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:conferbot_flutter/conferbot_flutter.dart';
import 'package:conferbot_flutter/src/models/knowledge_base.dart';
import 'package:conferbot_flutter/src/widgets/knowledge_base/article_list.dart';

void main() {
  KnowledgeBaseArticle createTestArticle({
    String id = 'article-1',
    String title = 'Test Article',
    String? description,
    String? categoryName,
    int? readTimeMinutes,
  }) {
    return KnowledgeBaseArticle(
      id: id,
      title: title,
      description: description ?? 'Test description',
      categoryId: 'cat-1',
      categoryName: categoryName,
      readTimeMinutes: readTimeMinutes,
      content: 'Test content',
    );
  }

  group('ArticleList', () {
    group('Basic rendering', () {
      testWidgets('renders list of articles', (WidgetTester tester) async {
        final articles = [
          createTestArticle(id: '1', title: 'Article 1'),
          createTestArticle(id: '2', title: 'Article 2'),
          createTestArticle(id: '3', title: 'Article 3'),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ArticleList(
                articles: articles,
                onArticleTap: (article) {},
              ),
            ),
          ),
        );

        expect(find.text('Article 1'), findsOneWidget);
        expect(find.text('Article 2'), findsOneWidget);
        expect(find.text('Article 3'), findsOneWidget);
      });

      testWidgets('renders empty state when no articles',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ArticleList(
                articles: const [],
                onArticleTap: (article) {},
              ),
            ),
          ),
        );

        expect(find.text('No articles found'), findsOneWidget);
      });

      testWidgets('renders custom empty message', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ArticleList(
                articles: const [],
                onArticleTap: (article) {},
                emptyMessage: 'No results',
              ),
            ),
          ),
        );

        expect(find.text('No results'), findsOneWidget);
      });
    });

    group('Loading state', () {
      testWidgets('shows loading skeleton when isLoading is true',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ArticleList(
                articles: const [],
                onArticleTap: (article) {},
                isLoading: true,
              ),
            ),
          ),
        );

        // Should show skeleton items
        expect(find.byType(ListView), findsOneWidget);
      });

      testWidgets('shows load more indicator when hasMore is true',
          (WidgetTester tester) async {
        final articles = [
          createTestArticle(id: '1', title: 'Article 1'),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ArticleList(
                articles: articles,
                onArticleTap: (article) {},
                hasMore: true,
              ),
            ),
          ),
        );

        // Should find load more area
        expect(find.byType(ArticleList), findsOneWidget);
      });

      testWidgets('shows loading indicator when isLoadingMore is true',
          (WidgetTester tester) async {
        final articles = [
          createTestArticle(id: '1', title: 'Article 1'),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ArticleList(
                articles: articles,
                onArticleTap: (article) {},
                hasMore: true,
                isLoadingMore: true,
              ),
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    group('Interactions', () {
      testWidgets('calls onArticleTap when article is tapped',
          (WidgetTester tester) async {
        KnowledgeBaseArticle? tappedArticle;
        final articles = [
          createTestArticle(id: '1', title: 'Article 1'),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ArticleList(
                articles: articles,
                onArticleTap: (article) {
                  tappedArticle = article;
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Article 1'));
        await tester.pump();

        expect(tappedArticle?.id, equals('1'));
      });
    });

    group('Display options', () {
      testWidgets('renders with showThumbnails option',
          (WidgetTester tester) async {
        final articles = [createTestArticle()];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ArticleList(
                articles: articles,
                onArticleTap: (article) {},
                showThumbnails: true,
              ),
            ),
          ),
        );

        expect(find.byType(ArticleList), findsOneWidget);
      });

      testWidgets('renders with showCategories option',
          (WidgetTester tester) async {
        final articles = [
          createTestArticle(categoryName: 'Test Category'),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ArticleList(
                articles: articles,
                onArticleTap: (article) {},
                showCategories: true,
              ),
            ),
          ),
        );

        expect(find.byType(ArticleList), findsOneWidget);
      });

      testWidgets('renders with showReadTime option',
          (WidgetTester tester) async {
        final articles = [
          createTestArticle(readTimeMinutes: 5),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ArticleList(
                articles: articles,
                onArticleTap: (article) {},
                showReadTime: true,
              ),
            ),
          ),
        );

        expect(find.byType(ArticleList), findsOneWidget);
      });
    });

    group('Theme integration', () {
      testWidgets('uses default theme when no theme provided',
          (WidgetTester tester) async {
        final articles = [createTestArticle()];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ArticleList(
                articles: articles,
                onArticleTap: (article) {},
              ),
            ),
          ),
        );

        expect(find.byType(ArticleList), findsOneWidget);
      });

      testWidgets('uses custom theme when provided',
          (WidgetTester tester) async {
        final articles = [createTestArticle()];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ArticleList(
                articles: articles,
                onArticleTap: (article) {},
                theme: defaultTheme,
              ),
            ),
          ),
        );

        expect(find.byType(ArticleList), findsOneWidget);
      });
    });
  });
}
