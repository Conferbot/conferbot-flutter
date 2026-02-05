import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:conferbot_flutter/conferbot_flutter.dart';
import 'package:conferbot_flutter/src/widgets/knowledge_base/search_bar.dart';

void main() {
  group('KBSearchBar', () {
    group('Basic rendering', () {
      testWidgets('renders text field', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: KBSearchBar(
                onSearch: (query) {},
              ),
            ),
          ),
        );

        expect(find.byType(TextField), findsOneWidget);
      });

      testWidgets('renders search icon', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: KBSearchBar(
                onSearch: (query) {},
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.search), findsOneWidget);
      });

      testWidgets('renders default placeholder', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: KBSearchBar(
                onSearch: (query) {},
              ),
            ),
          ),
        );

        expect(find.text('Search articles...'), findsOneWidget);
      });

      testWidgets('renders custom placeholder', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: KBSearchBar(
                onSearch: (query) {},
                placeholder: 'Find help topics',
              ),
            ),
          ),
        );

        expect(find.text('Find help topics'), findsOneWidget);
      });
    });

    group('Initial value', () {
      testWidgets('shows initial value', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: KBSearchBar(
                onSearch: (query) {},
                initialValue: 'Initial search',
              ),
            ),
          ),
        );

        expect(find.text('Initial search'), findsOneWidget);
      });
    });

    group('Text input', () {
      testWidgets('can enter search text', (WidgetTester tester) async {
        String searchQuery = '';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: KBSearchBar(
                onSearch: (query) {
                  searchQuery = query;
                },
              ),
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), 'test query');
        await tester.pump();

        expect(searchQuery, equals('test query'));
      });

      testWidgets('calls onSearch on text change', (WidgetTester tester) async {
        List<String> searchCalls = [];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: KBSearchBar(
                onSearch: (query) {
                  searchCalls.add(query);
                },
              ),
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), 'a');
        await tester.pump();

        await tester.enterText(find.byType(TextField), 'ab');
        await tester.pump();

        expect(searchCalls.length, greaterThanOrEqualTo(1));
      });
    });

    group('Clear button', () {
      testWidgets('shows clear button when text is present',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: KBSearchBar(
                onSearch: (query) {},
                initialValue: 'some text',
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.close), findsOneWidget);
      });

      testWidgets('hides clear button when text is empty',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: KBSearchBar(
                onSearch: (query) {},
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.close), findsNothing);
      });

      testWidgets('clears text when clear button is tapped',
          (WidgetTester tester) async {
        String searchQuery = 'initial';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: KBSearchBar(
                onSearch: (query) {
                  searchQuery = query;
                },
                initialValue: 'initial',
              ),
            ),
          ),
        );

        await tester.tap(find.byIcon(Icons.close));
        await tester.pump();

        expect(searchQuery, isEmpty);
      });

      testWidgets('calls onClear when clear button is tapped',
          (WidgetTester tester) async {
        bool clearCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: KBSearchBar(
                onSearch: (query) {},
                onClear: () {
                  clearCalled = true;
                },
                initialValue: 'text',
              ),
            ),
          ),
        );

        await tester.tap(find.byIcon(Icons.close));
        await tester.pump();

        expect(clearCalled, isTrue);
      });
    });

    group('Disabled state', () {
      testWidgets('text field is disabled when enabled is false',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: KBSearchBar(
                onSearch: (query) {},
                enabled: false,
              ),
            ),
          ),
        );

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.enabled, isFalse);
      });
    });

    group('Autofocus', () {
      testWidgets('autofocuses when autofocus is true',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: KBSearchBar(
                onSearch: (query) {},
                autofocus: true,
              ),
            ),
          ),
        );

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.autofocus, isTrue);
      });
    });

    group('Theme integration', () {
      testWidgets('uses default theme when no theme provided',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: KBSearchBar(
                onSearch: (query) {},
              ),
            ),
          ),
        );

        expect(find.byType(KBSearchBar), findsOneWidget);
      });

      testWidgets('uses custom theme when provided',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: KBSearchBar(
                onSearch: (query) {},
                theme: defaultTheme,
              ),
            ),
          ),
        );

        expect(find.byType(KBSearchBar), findsOneWidget);
      });
    });

    group('Disposal', () {
      testWidgets('disposes properly', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: KBSearchBar(
                onSearch: (query) {},
              ),
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

  group('KBCompactSearchBar', () {
    testWidgets('renders search icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KBCompactSearchBar(
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('renders default placeholder', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KBCompactSearchBar(
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Search...'), findsOneWidget);
    });

    testWidgets('renders custom placeholder', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KBCompactSearchBar(
              onTap: () {},
              placeholder: 'Quick search',
            ),
          ),
        ),
      );

      expect(find.text('Quick search'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KBCompactSearchBar(
              onTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('uses custom theme when provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KBCompactSearchBar(
              onTap: () {},
              theme: defaultTheme,
            ),
          ),
        ),
      );

      expect(find.byType(KBCompactSearchBar), findsOneWidget);
    });
  });
}
