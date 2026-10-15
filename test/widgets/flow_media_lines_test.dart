/// A flow step's video, audio, file, HTML and link lines are drawn in the
/// chat (#55): they used to show nothing.
library;

import 'package:conferbot_flutter/src/models/message.dart';
import 'package:conferbot_flutter/src/widgets/media/audio_player_widget.dart';
import 'package:conferbot_flutter/src/widgets/media/video_player_widget.dart';
import 'package:conferbot_flutter/src/widgets/message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, Map<String, dynamic> nodeData, {String? text}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MessageBubble(
          message: BotMessageRecord(id: 'bot_n_1', time: DateTime(2026, 10, 15), text: text, nodeData: nodeData),
        ),
      ),
    ));
  }

  testWidgets('a file step shows its name', (tester) async {
    await pump(tester, {'fileUrl': 'https://cdn.test/docs/price-list.pdf', 'fileName': 'price-list.pdf'});
    expect(find.text('price-list.pdf'), findsOneWidget);
  });

  testWidgets('an HTML step shows its content', (tester) async {
    await pump(tester, {'html': '<p>Hello <b>there</b></p>'});
    expect(find.byType(Html), findsOneWidget);
  });

  testWidgets('a redirect step shows its link', (tester) async {
    await pump(tester, {'linkUrl': 'https://shop.test', 'linkLabel': 'Open the shop'}, text: 'Open the shop\nhttps://shop.test');
    expect(find.text('Open the shop'), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new), findsOneWidget);
  });

  testWidgets('an audio step shows a player', (tester) async {
    await pump(tester, {'audioUrl': 'https://cdn.test/a.mp3'});
    expect(find.byType(AudioPlayerWidget), findsOneWidget);
  });

  testWidgets('a video step shows a player', (tester) async {
    await pump(tester, {'videoUrl': 'https://cdn.test/v.mp4', 'mediaNodeId': 'v'});
    expect(find.byType(VideoPlayerWidget), findsOneWidget);
  });
}
