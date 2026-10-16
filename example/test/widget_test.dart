// The example's widget tree, pumped with a configuration that does not
// connect: no socket, no stored session, no notifications, no network.
import 'package:conferbot_example/main.dart';
import 'package:conferbot_flutter/conferbot_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the example home page builds without a connection', (tester) async {
    await tester.pumpWidget(const MyApp(
      config: ConferBotConfig(
        autoConnect: false,
        enablePersistence: false,
        enableNotifications: false,
        enableOfflineMode: false,
      ),
    ));
    await tester.pump();

    expect(find.byType(ExampleHomePage), findsOneWidget);
    expect(find.text('Conferbot SDK Example'), findsOneWidget);
    expect(find.text('Conferbot Flutter SDK'), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
