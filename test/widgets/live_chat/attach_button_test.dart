import 'package:conferbot_flutter/src/widgets/chat_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The live chat's attach button: ChatWidget passes onAttachmentPress only
// when the owner allows visitor uploads (or an agent asked for a file), so a
// host app's enableAttachments: true never draws a dead button (#102).
Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('no attach button without a handler, even when the app enables attachments', (tester) async {
    await tester.pumpWidget(_host(ChatBottomBar(onSend: (_) async {}, enableAttachments: true)));
    expect(find.byIcon(Icons.attach_file), findsNothing);
  });

  testWidgets('the attach button shows once uploads are allowed', (tester) async {
    await tester.pumpWidget(_host(ChatBottomBar(onSend: (_) async {}, enableAttachments: true, onAttachmentPress: () {})));
    expect(find.byIcon(Icons.attach_file), findsOneWidget);
  });
}
