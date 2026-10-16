/// "Use my location" on the address card (#48): drawn only with the app's
/// location provider and while the owner allows it; the point goes to the
/// step as {action: locate, lat, lng}, the address it answers is confirmed
/// on the map as a pick; a refusal or no position is said on the card.
library;

import 'dart:async';

import 'package:conferbot_flutter/conferbot_flutter.dart' show ConferBotLatLng, ConferBotLocationDenied, ConferBotLocationProvider;
import 'package:conferbot_flutter/src/core/nodes/node_ui_state.dart';
import 'package:conferbot_flutter/src/theme/default_theme.dart';
import 'package:conferbot_flutter/src/ui/widgets/node_widgets.dart';
import 'package:flutter/material.dart' hide TextInputType;
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<dynamic> answers;

  Widget card(AddressUIState state, {ConferBotLocationProvider? location, String? error}) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NodeRenderer(
              uiState: state,
              onResponse: answers.add,
              theme: defaultTheme,
              stepKey: 1,
              error: error,
              locationProvider: location,
            ),
          ),
        ),
      );

  setUp(() => answers = []);

  testWidgets('no location provider: no button (no plugin in the SDK)', (tester) async {
    await tester.pumpWidget(card(const AddressUIState(nodeId: 'ad', extra: {'allowMyLocation': true})));
    expect(find.text('Use my location'), findsNothing);
    expect(find.text('Enter it manually'), findsOneWidget);
  });

  testWidgets("the owner's allowMyLocation off: no button", (tester) async {
    await tester.pumpWidget(card(const AddressUIState(nodeId: 'ad', extra: {'allowMyLocation': false}),
        location: () async => const ConferBotLatLng(1, 2)));
    expect(find.text('Use my location'), findsNothing);
  });

  testWidgets('the point goes to the step; the address it answers is confirmed as a pick', (tester) async {
    final gps = Completer<ConferBotLatLng?>();
    await tester.pumpWidget(card(const AddressUIState(nodeId: 'ad', extra: {'allowMyLocation': true, 'showMap': false}),
        location: () => gps.future));
    await tester.tap(find.text('Use my location'));
    await tester.pump();
    expect(find.text('Finding your location…'), findsOneWidget);
    gps.complete(const ConferBotLatLng(25.08, 55.14));
    await tester.pump();
    expect(answers.single, {'action': 'locate', 'lat': 25.08, 'lng': 55.14});

    await tester.pumpWidget(card(
      const AddressUIState(
        nodeId: 'ad',
        results: [
          {'formatted': '1 Marina Walk, Dubai', 'lat': 25.08, 'lng': 55.14},
        ],
        extra: {'allowMyLocation': true, 'showMap': false, 'located': true},
      ),
      location: () => gps.future,
    ));
    await tester.pump();
    expect(find.text('1 Marina Walk'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ad-confirm')));
    expect(answers.last, {'action': 'pick', 'index': 0, 'label': '1 Marina Walk, Dubai'});
  });

  testWidgets('access refused: "location access is turned off", type it instead', (tester) async {
    await tester.pumpWidget(card(const AddressUIState(nodeId: 'ad', extra: {'allowMyLocation': true}),
        location: () async => throw const ConferBotLocationDenied()));
    await tester.tap(find.text('Use my location'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('location access is turned off'), findsOneWidget);
    expect(answers, isEmpty);
    // Typing clears it.
    await tester.enterText(find.byKey(const ValueKey('ad-input')), 'ma');
    await tester.pump();
    expect(find.textContaining('location access is turned off'), findsNothing);
  });

  testWidgets('no position: "We couldn\'t find your location"', (tester) async {
    await tester.pumpWidget(card(const AddressUIState(nodeId: 'ad', extra: {'allowMyLocation': true}),
        location: () async => null));
    await tester.tap(find.text('Use my location'));
    await tester.pump();
    await tester.pump();
    expect(find.text("We couldn't find your location. Type your address instead."), findsOneWidget);
    expect(answers, isEmpty);
  });

  testWidgets("the server's refusal stays on the search", (tester) async {
    await tester.pumpWidget(card(const AddressUIState(nodeId: 'ad', extra: {'allowMyLocation': true}),
        location: () async => const ConferBotLatLng(1, 2)));
    await tester.tap(find.text('Use my location'));
    await tester.pump();
    await tester.pumpWidget(card(const AddressUIState(nodeId: 'ad', extra: {'allowMyLocation': true}),
        location: () async => const ConferBotLatLng(1, 2), error: 'Address search is busy right now.'));
    await tester.pump();
    expect(find.text('Address search is busy right now.'), findsOneWidget);
    expect(find.byKey(const ValueKey('ad-input')), findsOneWidget);
    expect(find.byKey(const ValueKey('ad-confirm')), findsNothing);
  });
}
