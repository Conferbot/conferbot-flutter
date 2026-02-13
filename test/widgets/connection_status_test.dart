import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:conferbot_flutter/conferbot_flutter.dart';

/// Mock ConferBotProvider for testing connection status
class MockConferBotProvider extends ChangeNotifier implements ConferBotProvider {
  bool _isConnected = false;

  @override
  bool get isConnected => _isConnected;

  void setConnected(bool value) {
    _isConnected = value;
    notifyListeners();
  }

  // Stub implementations for other required members
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late MockConferBotProvider mockProvider;

  setUp(() {
    mockProvider = MockConferBotProvider();
  });

  Widget buildTestWidget({
    required Widget child,
    MockConferBotProvider? provider,
  }) {
    return MaterialApp(
      home: ChangeNotifierProvider<ConferBotProvider>.value(
        value: provider ?? mockProvider,
        child: Scaffold(body: child),
      ),
    );
  }

  group('ConnectionStatus', () {
    group('Visibility behavior', () {
      testWidgets('shows nothing when online and showWhenOnline is false',
          (WidgetTester tester) async {
        mockProvider.setConnected(true);

        await tester.pumpWidget(
          buildTestWidget(
            child: const ConnectionStatus(
              showWhenOnline: false,
            ),
          ),
        );

        // Should find SizedBox.shrink
        final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
        expect(sizedBox.width, isNull);
        expect(sizedBox.height, isNull);
      });

      testWidgets('shows indicator when online and showWhenOnline is true',
          (WidgetTester tester) async {
        mockProvider.setConnected(true);

        await tester.pumpWidget(
          buildTestWidget(
            child: const ConnectionStatus(
              showWhenOnline: true,
              variant: ConnectionStatusVariant.badge,
            ),
          ),
        );

        expect(find.text('Online'), findsOneWidget);
      });

      testWidgets('shows indicator when offline regardless of showWhenOnline',
          (WidgetTester tester) async {
        mockProvider.setConnected(false);

        await tester.pumpWidget(
          buildTestWidget(
            child: const ConnectionStatus(
              showWhenOnline: false,
              variant: ConnectionStatusVariant.badge,
            ),
          ),
        );

        expect(find.text('Offline'), findsOneWidget);
      });
    });

    group('Dot variant', () {
      testWidgets('renders dot variant correctly when offline',
          (WidgetTester tester) async {
        mockProvider.setConnected(false);

        await tester.pumpWidget(
          buildTestWidget(
            child: const ConnectionStatus(
              variant: ConnectionStatusVariant.dot,
            ),
          ),
        );

        // Should find a Container with circle decoration
        final containers = tester.widgetList<Container>(find.byType(Container));
        final dotContainer = containers.firstWhere(
          (c) =>
              c.decoration is BoxDecoration &&
              (c.decoration as BoxDecoration).shape == BoxShape.circle,
        );

        expect(dotContainer, isNotNull);
        expect(
          (dotContainer.decoration as BoxDecoration).color,
          equals(defaultTheme.colors.offline),
        );
      });

      testWidgets('renders dot variant with online color when connected',
          (WidgetTester tester) async {
        mockProvider.setConnected(true);

        await tester.pumpWidget(
          buildTestWidget(
            child: const ConnectionStatus(
              variant: ConnectionStatusVariant.dot,
              showWhenOnline: true,
            ),
          ),
        );

        final containers = tester.widgetList<Container>(find.byType(Container));
        final dotContainer = containers.firstWhere(
          (c) =>
              c.decoration is BoxDecoration &&
              (c.decoration as BoxDecoration).shape == BoxShape.circle,
        );

        expect(
          (dotContainer.decoration as BoxDecoration).color,
          equals(defaultTheme.colors.online),
        );
      });

      testWidgets('dot has correct size', (WidgetTester tester) async {
        mockProvider.setConnected(false);

        await tester.pumpWidget(
          buildTestWidget(
            child: const ConnectionStatus(
              variant: ConnectionStatusVariant.dot,
            ),
          ),
        );

        final containers = tester.widgetList<Container>(find.byType(Container));
        final dotContainer = containers.firstWhere(
          (c) =>
              c.decoration is BoxDecoration &&
              (c.decoration as BoxDecoration).shape == BoxShape.circle,
        );

        expect(dotContainer.constraints?.maxWidth, equals(8));
        expect(dotContainer.constraints?.maxHeight, equals(8));
      });
    });

    group('Badge variant', () {
      testWidgets('renders badge variant with label when offline',
          (WidgetTester tester) async {
        mockProvider.setConnected(false);

        await tester.pumpWidget(
          buildTestWidget(
            child: const ConnectionStatus(
              variant: ConnectionStatusVariant.badge,
            ),
          ),
        );

        expect(find.text('Offline'), findsOneWidget);
        expect(find.byType(Row), findsOneWidget);
      });

      testWidgets('renders badge variant with custom offline label',
          (WidgetTester tester) async {
        mockProvider.setConnected(false);

        await tester.pumpWidget(
          buildTestWidget(
            child: const ConnectionStatus(
              variant: ConnectionStatusVariant.badge,
              offlineLabel: 'Disconnected',
            ),
          ),
        );

        expect(find.text('Disconnected'), findsOneWidget);
        expect(find.text('Offline'), findsNothing);
      });

      testWidgets('renders badge variant with custom online label',
          (WidgetTester tester) async {
        mockProvider.setConnected(true);

        await tester.pumpWidget(
          buildTestWidget(
            child: const ConnectionStatus(
              variant: ConnectionStatusVariant.badge,
              showWhenOnline: true,
              onlineLabel: 'Connected',
            ),
          ),
        );

        expect(find.text('Connected'), findsOneWidget);
        expect(find.text('Online'), findsNothing);
      });

      testWidgets('badge contains small dot indicator',
          (WidgetTester tester) async {
        mockProvider.setConnected(false);

        await tester.pumpWidget(
          buildTestWidget(
            child: const ConnectionStatus(
              variant: ConnectionStatusVariant.badge,
            ),
          ),
        );

        final row = tester.widget<Row>(find.byType(Row));
        expect(row.children.length, greaterThan(1));
      });
    });

    group('Text variant', () {
      testWidgets('renders text variant when offline',
          (WidgetTester tester) async {
        mockProvider.setConnected(false);

        await tester.pumpWidget(
          buildTestWidget(
            child: const ConnectionStatus(
              variant: ConnectionStatusVariant.text,
            ),
          ),
        );

        expect(find.text('Offline'), findsOneWidget);
      });

      testWidgets('renders text variant with custom label',
          (WidgetTester tester) async {
        mockProvider.setConnected(false);

        await tester.pumpWidget(
          buildTestWidget(
            child: const ConnectionStatus(
              variant: ConnectionStatusVariant.text,
              offlineLabel: 'No Connection',
            ),
          ),
        );

        expect(find.text('No Connection'), findsOneWidget);
      });

      testWidgets('renders text variant when online with showWhenOnline',
          (WidgetTester tester) async {
        mockProvider.setConnected(true);

        await tester.pumpWidget(
          buildTestWidget(
            child: const ConnectionStatus(
              variant: ConnectionStatusVariant.text,
              showWhenOnline: true,
            ),
          ),
        );

        expect(find.text('Online'), findsOneWidget);
      });
    });

    group('Theme integration', () {
      testWidgets('uses default theme when no theme provided',
          (WidgetTester tester) async {
        mockProvider.setConnected(false);

        await tester.pumpWidget(
          buildTestWidget(
            child: const ConnectionStatus(
              variant: ConnectionStatusVariant.badge,
            ),
          ),
        );

        // Widget should render without errors
        expect(find.byType(ConnectionStatus), findsOneWidget);
      });

      testWidgets('uses custom theme when provided',
          (WidgetTester tester) async {
        mockProvider.setConnected(false);

        await tester.pumpWidget(
          buildTestWidget(
            child: ConnectionStatus(
              variant: ConnectionStatusVariant.badge,
              theme: defaultTheme,
            ),
          ),
        );

        expect(find.byType(ConnectionStatus), findsOneWidget);
      });
    });

    group('State changes', () {
      testWidgets('updates when connection status changes',
          (WidgetTester tester) async {
        mockProvider.setConnected(false);

        await tester.pumpWidget(
          buildTestWidget(
            child: const ConnectionStatus(
              variant: ConnectionStatusVariant.badge,
              showWhenOnline: true,
            ),
          ),
        );

        expect(find.text('Offline'), findsOneWidget);

        // Change connection status
        mockProvider.setConnected(true);
        await tester.pump();

        expect(find.text('Online'), findsOneWidget);
        expect(find.text('Offline'), findsNothing);
      });

      testWidgets('hides when becoming online if showWhenOnline is false',
          (WidgetTester tester) async {
        mockProvider.setConnected(false);

        await tester.pumpWidget(
          buildTestWidget(
            child: const ConnectionStatus(
              variant: ConnectionStatusVariant.badge,
              showWhenOnline: false,
            ),
          ),
        );

        expect(find.text('Offline'), findsOneWidget);

        // Change to online
        mockProvider.setConnected(true);
        await tester.pump();

        // Should hide
        expect(find.text('Offline'), findsNothing);
        expect(find.text('Online'), findsNothing);
      });
    });
  });

  group('ConnectionStatusVariant enum', () {
    test('has all expected values', () {
      expect(ConnectionStatusVariant.values.length, equals(3));
      expect(ConnectionStatusVariant.values, contains(ConnectionStatusVariant.dot));
      expect(ConnectionStatusVariant.values, contains(ConnectionStatusVariant.badge));
      expect(ConnectionStatusVariant.values, contains(ConnectionStatusVariant.text));
    });
  });
}
