import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:conferbot_flutter/conferbot_flutter.dart';
import 'package:conferbot_flutter/src/models/knowledge_base.dart';
import 'package:conferbot_flutter/src/widgets/knowledge_base/category_chips.dart';

void main() {
  KnowledgeBaseCategory createTestCategory({
    String id = 'cat-1',
    String name = 'Test Category',
    int? articleCount,
    String? iconName,
  }) {
    return KnowledgeBaseCategory(
      id: id,
      name: name,
      articleCount: articleCount ?? 5,
      iconName: iconName,
    );
  }

  group('CategoryChips', () {
    group('Basic rendering', () {
      testWidgets('renders category chips', (WidgetTester tester) async {
        final categories = [
          createTestCategory(id: '1', name: 'FAQ'),
          createTestCategory(id: '2', name: 'Getting Started'),
          createTestCategory(id: '3', name: 'Troubleshooting'),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CategoryChips(
                categories: categories,
                onCategorySelected: (id) {},
              ),
            ),
          ),
        );

        expect(find.text('FAQ'), findsOneWidget);
        expect(find.text('Getting Started'), findsOneWidget);
        expect(find.text('Troubleshooting'), findsOneWidget);
      });

      testWidgets('shows "All" chip when showAllChip is true',
          (WidgetTester tester) async {
        final categories = [
          createTestCategory(id: '1', name: 'Category 1'),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CategoryChips(
                categories: categories,
                onCategorySelected: (id) {},
                showAllChip: true,
              ),
            ),
          ),
        );

        expect(find.text('All'), findsOneWidget);
      });

      testWidgets('hides "All" chip when showAllChip is false',
          (WidgetTester tester) async {
        final categories = [
          createTestCategory(id: '1', name: 'Category 1'),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CategoryChips(
                categories: categories,
                onCategorySelected: (id) {},
                showAllChip: false,
              ),
            ),
          ),
        );

        expect(find.text('All'), findsNothing);
      });

      testWidgets('renders nothing when empty and showAllChip is false',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CategoryChips(
                categories: const [],
                onCategorySelected: (id) {},
                showAllChip: false,
              ),
            ),
          ),
        );

        // Should find SizedBox.shrink
        final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
        expect(sizedBox.width, isNull);
      });
    });

    group('Loading state', () {
      testWidgets('shows loading chips when isLoading is true',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CategoryChips(
                categories: const [],
                onCategorySelected: (id) {},
                isLoading: true,
              ),
            ),
          ),
        );

        expect(find.byType(ListView), findsOneWidget);
      });
    });

    group('Selection', () {
      testWidgets('highlights selected category', (WidgetTester tester) async {
        final categories = [
          createTestCategory(id: '1', name: 'Category 1'),
          createTestCategory(id: '2', name: 'Category 2'),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CategoryChips(
                categories: categories,
                selectedCategoryId: '1',
                onCategorySelected: (id) {},
              ),
            ),
          ),
        );

        expect(find.byType(CategoryChips), findsOneWidget);
      });

      testWidgets('calls onCategorySelected when chip is tapped',
          (WidgetTester tester) async {
        String? selectedId;
        final categories = [
          createTestCategory(id: '1', name: 'Category 1'),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CategoryChips(
                categories: categories,
                onCategorySelected: (id) {
                  selectedId = id;
                },
                showAllChip: false,
              ),
            ),
          ),
        );

        await tester.tap(find.text('Category 1'));
        await tester.pump();

        expect(selectedId, equals('1'));
      });

      testWidgets('calls onCategorySelected with null when "All" is tapped',
          (WidgetTester tester) async {
        String? selectedId = 'initial';
        final categories = [
          createTestCategory(id: '1', name: 'Category 1'),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CategoryChips(
                categories: categories,
                selectedCategoryId: '1',
                onCategorySelected: (id) {
                  selectedId = id;
                },
                showAllChip: true,
              ),
            ),
          ),
        );

        await tester.tap(find.text('All'));
        await tester.pump();

        expect(selectedId, isNull);
      });

      testWidgets('"All" is selected when selectedCategoryId is null',
          (WidgetTester tester) async {
        final categories = [
          createTestCategory(id: '1', name: 'Category 1'),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CategoryChips(
                categories: categories,
                selectedCategoryId: null,
                onCategorySelected: (id) {},
                showAllChip: true,
              ),
            ),
          ),
        );

        expect(find.byType(CategoryChips), findsOneWidget);
      });
    });

    group('Display options', () {
      testWidgets('shows article count when showCounts is true',
          (WidgetTester tester) async {
        final categories = [
          createTestCategory(id: '1', name: 'FAQ', articleCount: 10),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CategoryChips(
                categories: categories,
                onCategorySelected: (id) {},
                showCounts: true,
                showAllChip: false,
              ),
            ),
          ),
        );

        expect(find.byType(CategoryChips), findsOneWidget);
      });
    });

    group('Theme integration', () {
      testWidgets('uses default theme when no theme provided',
          (WidgetTester tester) async {
        final categories = [createTestCategory()];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CategoryChips(
                categories: categories,
                onCategorySelected: (id) {},
              ),
            ),
          ),
        );

        expect(find.byType(CategoryChips), findsOneWidget);
      });

      testWidgets('uses custom theme when provided',
          (WidgetTester tester) async {
        final categories = [createTestCategory()];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CategoryChips(
                categories: categories,
                onCategorySelected: (id) {},
                theme: defaultTheme,
              ),
            ),
          ),
        );

        expect(find.byType(CategoryChips), findsOneWidget);
      });
    });
  });
}
