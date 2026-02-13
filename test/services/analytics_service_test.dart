import 'package:flutter_test/flutter_test.dart';
import 'package:conferbot_flutter/src/services/analytics_service.dart';
import 'package:conferbot_flutter/src/models/analytics.dart';
import '../mocks/mock_socket_client.dart';

void main() {
  late AnalyticsService analyticsService;
  late MockSocketClient mockSocketClient;

  setUp(() {
    mockSocketClient = MockSocketClient();
    mockSocketClient.mockIsConnected = true;
    analyticsService = AnalyticsService(
      socketClient: mockSocketClient,
      engagementInterval: const Duration(seconds: 30),
      idleThreshold: const Duration(seconds: 60),
    );
  });

  tearDown(() {
    analyticsService.dispose();
    mockSocketClient.clearEmittedEvents();
  });

  group('AnalyticsService Construction', () {
    test('should create with required parameters', () {
      expect(analyticsService.isInitialized, false);
      expect(analyticsService.analytics, isNull);
      expect(analyticsService.sessionId, isNull);
    });

    test('should create with custom configuration', () {
      final customService = AnalyticsService(
        socketClient: mockSocketClient,
        engagementInterval: const Duration(seconds: 60),
        idleThreshold: const Duration(seconds: 120),
      );

      expect(customService.engagementInterval, const Duration(seconds: 60));
      expect(customService.idleThreshold, const Duration(seconds: 120));

      customService.dispose();
    });
  });

  group('AnalyticsService.startSession', () {
    test('should initialize analytics session', () {
      analyticsService.startSession(
        sessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
      );

      expect(analyticsService.isInitialized, true);
      expect(analyticsService.sessionId, 'session_123');
      expect(analyticsService.analytics, isNotNull);
      expect(analyticsService.analytics!.visitorId, 'visitor_456');
      expect(analyticsService.analytics!.botId, 'bot_789');
    });

    test('should emit chat start event', () {
      analyticsService.startSession(
        sessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
      );

      expect(mockSocketClient.wasEventEmitted(AnalyticsEventType.chatStart), true);
      final events = mockSocketClient.getEmittedEvents(AnalyticsEventType.chatStart);
      expect(events.first.data['chatSessionId'], 'session_123');
      expect(events.first.data['botId'], 'bot_789');
      expect(events.first.data['visitorId'], 'visitor_456');
    });

    test('should include attribution data if provided', () {
      final attribution = AttributionData(
        utmSource: 'google',
        utmMedium: 'cpc',
        utmCampaign: 'summer_sale',
      );

      analyticsService.startSession(
        sessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
        attribution: attribution,
      );

      expect(analyticsService.analytics!.attribution, isNotNull);
      expect(analyticsService.analytics!.attribution!.utmSource, 'google');
    });

    test('should include workspace ID if provided', () {
      analyticsService.startSession(
        sessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
        workspaceId: 'workspace_abc',
      );

      expect(analyticsService.analytics!.workspaceId, 'workspace_abc');
    });

    test('should not reinitialize if same session', () {
      analyticsService.startSession(
        sessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
      );

      mockSocketClient.clearEmittedEvents();

      analyticsService.startSession(
        sessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
      );

      expect(mockSocketClient.emittedEvents.isEmpty, true);
    });

    test('should reinitialize for different session', () {
      analyticsService.startSession(
        sessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
      );

      mockSocketClient.clearEmittedEvents();

      analyticsService.startSession(
        sessionId: 'session_456',
        visitorId: 'visitor_789',
        botId: 'bot_abc',
      );

      expect(analyticsService.sessionId, 'session_456');
      expect(mockSocketClient.wasEventEmitted(AnalyticsEventType.chatStart), true);
    });
  });

  group('AnalyticsService.endSession', () {
    test('should finalize analytics session', () {
      analyticsService.startSession(
        sessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
      );

      mockSocketClient.clearEmittedEvents();
      analyticsService.endSession();

      expect(analyticsService.isInitialized, false);
      expect(analyticsService.analytics!.isFinalized, true);
      expect(analyticsService.analytics!.isActive, false);
      expect(analyticsService.analytics!.sessionEnd, isNotNull);
    });

    test('should emit finalize analytics event', () {
      analyticsService.startSession(
        sessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
      );

      mockSocketClient.clearEmittedEvents();
      analyticsService.endSession();

      expect(mockSocketClient.wasEventEmitted(AnalyticsEventType.finalizeAnalytics), true);
      final events = mockSocketClient.getEmittedEvents(AnalyticsEventType.finalizeAnalytics);
      expect(events.first.data['chatSessionId'], 'session_123');
      expect(events.first.data['finalMetrics'], isNotNull);
    });

    test('should do nothing if not initialized', () {
      analyticsService.endSession();

      expect(mockSocketClient.emittedEvents.isEmpty, true);
    });

    test('should exit current node if exists', () {
      analyticsService.startSession(
        sessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
      );

      analyticsService.trackNodeEntry(
        nodeId: 'node_1',
        nodeType: 'ask-question',
      );

      mockSocketClient.clearEmittedEvents();
      analyticsService.endSession();

      expect(mockSocketClient.wasEventEmitted(AnalyticsEventType.nodeExit), true);
    });
  });

  group('AnalyticsService.trackNodeEntry', () {
    setUp(() {
      analyticsService.startSession(
        sessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
      );
      mockSocketClient.clearEmittedEvents();
    });

    test('should track node entry', () {
      analyticsService.trackNodeEntry(
        nodeId: 'node_1',
        nodeType: 'ask-question',
        nodeName: 'Get User Name',
      );

      expect(analyticsService.analytics!.currentNode, isNotNull);
      expect(analyticsService.analytics!.currentNode!.nodeId, 'node_1');
      expect(analyticsService.analytics!.currentNode!.nodeType, 'ask-question');
      expect(analyticsService.analytics!.currentNode!.nodeName, 'Get User Name');
    });

    test('should emit node visit event', () {
      analyticsService.trackNodeEntry(
        nodeId: 'node_1',
        nodeType: 'ask-question',
      );

      expect(mockSocketClient.wasEventEmitted(AnalyticsEventType.nodeVisit), true);
      final events = mockSocketClient.getEmittedEvents(AnalyticsEventType.nodeVisit);
      expect(events.first.data['nodeId'], 'node_1');
      expect(events.first.data['nodeType'], 'ask-question');
    });

    test('should update node type count', () {
      analyticsService.trackNodeEntry(
        nodeId: 'node_1',
        nodeType: 'ask-question',
      );
      analyticsService.trackNodeEntry(
        nodeId: 'node_2',
        nodeType: 'ask-question',
      );
      analyticsService.trackNodeEntry(
        nodeId: 'node_3',
        nodeType: 'bot-message',
      );

      expect(analyticsService.analytics!.nodeTypeCount['ask-question'], 2);
      expect(analyticsService.analytics!.nodeTypeCount['bot-message'], 1);
    });

    test('should exit previous node if exists', () {
      analyticsService.trackNodeEntry(
        nodeId: 'node_1',
        nodeType: 'ask-question',
      );

      mockSocketClient.clearEmittedEvents();

      analyticsService.trackNodeEntry(
        nodeId: 'node_2',
        nodeType: 'bot-message',
      );

      expect(mockSocketClient.wasEventEmitted(AnalyticsEventType.nodeExit), true);
    });

    test('should not track if not initialized', () {
      final newService = AnalyticsService(socketClient: mockSocketClient);
      mockSocketClient.clearEmittedEvents();

      newService.trackNodeEntry(
        nodeId: 'node_1',
        nodeType: 'ask-question',
      );

      expect(mockSocketClient.emittedEvents.isEmpty, true);
      newService.dispose();
    });
  });

  group('AnalyticsService.trackNodeExit', () {
    setUp(() {
      analyticsService.startSession(
        sessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
      );
      analyticsService.trackNodeEntry(
        nodeId: 'node_1',
        nodeType: 'ask-question',
      );
      mockSocketClient.clearEmittedEvents();
    });

    test('should track node exit', () {
      analyticsService.trackNodeExit(
        exitType: NodeExitType.proceeded,
        userInput: 'John Doe',
      );

      expect(analyticsService.analytics!.currentNode, isNull);
      expect(analyticsService.analytics!.nodeVisitHistory.length, 1);
    });

    test('should emit node exit event', () {
      analyticsService.trackNodeExit(
        exitType: NodeExitType.proceeded,
        userInput: 'John Doe',
      );

      expect(mockSocketClient.wasEventEmitted(AnalyticsEventType.nodeExit), true);
      final events = mockSocketClient.getEmittedEvents(AnalyticsEventType.nodeExit);
      expect(events.first.data['nodeId'], 'node_1');
      expect(events.first.data['exitType'], NodeExitType.proceeded);
      expect(events.first.data['userInput'], 'John Doe');
    });

    test('should record selected option', () {
      analyticsService.trackNodeExit(
        exitType: NodeExitType.proceeded,
        selectedOption: 'Option A',
      );

      final lastVisit = analyticsService.analytics!.nodeVisitHistory.last;
      expect(lastVisit.selectedOption, 'Option A');
    });

    test('should calculate dwell time', () async {
      // Wait a bit to accumulate dwell time
      await Future.delayed(const Duration(milliseconds: 50));

      analyticsService.trackNodeExit(
        exitType: NodeExitType.proceeded,
      );

      final lastVisit = analyticsService.analytics!.nodeVisitHistory.last;
      expect(lastVisit.dwellTimeSeconds, greaterThanOrEqualTo(0));
    });

    test('should not track if no current node', () {
      analyticsService.trackNodeExit(exitType: NodeExitType.proceeded);

      mockSocketClient.clearEmittedEvents();

      analyticsService.trackNodeExit(exitType: NodeExitType.proceeded);

      expect(mockSocketClient.emittedEvents.isEmpty, true);
    });
  });

  group('AnalyticsService.trackMessage', () {
    setUp(() {
      analyticsService.startSession(
        sessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
      );
      mockSocketClient.clearEmittedEvents();
    });

    test('should track bot message', () {
      analyticsService.trackMessage(sender: 'bot', text: 'Hello!');

      expect(analyticsService.analytics!.messageCounts.botMessages, 1);
    });

    test('should track user message', () {
      analyticsService.trackMessage(sender: 'user', text: 'Hi there');

      expect(analyticsService.analytics!.messageCounts.userMessages, 1);
      expect(analyticsService.analytics!.typingBehavior.messageCount, 1);
      expect(analyticsService.analytics!.typingBehavior.totalMessageLength, 8);
    });

    test('should track agent message', () {
      analyticsService.trackMessage(sender: 'agent', text: 'How can I help?');

      expect(analyticsService.analytics!.messageCounts.agentMessages, 1);
    });

    test('should track system message', () {
      analyticsService.trackMessage(sender: 'system', text: 'Agent joined');

      expect(analyticsService.analytics!.messageCounts.systemMessages, 1);
    });

    test('should emit sentiment event for user messages', () {
      analyticsService.trackMessage(sender: 'user', text: 'Hello');

      expect(mockSocketClient.wasEventEmitted(AnalyticsEventType.sentiment), true);
      final events = mockSocketClient.getEmittedEvents(AnalyticsEventType.sentiment);
      expect(events.first.data['text'], 'Hello');
      expect(events.first.data['messageType'], 'user');
    });

    test('should update first message timestamp', () {
      expect(analyticsService.analytics!.sessionMetrics.firstMessageAt, isNull);

      analyticsService.trackMessage(sender: 'bot', text: 'Hello!');

      expect(analyticsService.analytics!.sessionMetrics.firstMessageAt, isNotNull);
    });

    test('should update last message timestamp', () {
      analyticsService.trackMessage(sender: 'bot', text: 'Hello!');
      final firstTimestamp = analyticsService.analytics!.sessionMetrics.lastMessageAt;

      analyticsService.trackMessage(sender: 'user', text: 'Hi!');

      expect(
        analyticsService.analytics!.sessionMetrics.lastMessageAt,
        greaterThanOrEqualTo(firstTimestamp!),
      );
    });
  });

  group('AnalyticsService Typing Behavior', () {
    setUp(() {
      analyticsService.startSession(
        sessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
      );
    });

    test('should track typing start and end', () async {
      analyticsService.trackTypingStart();
      await Future.delayed(const Duration(milliseconds: 50));
      analyticsService.trackTypingEnd();

      expect(
        analyticsService.analytics!.typingBehavior.totalTypingTimeMs,
        greaterThanOrEqualTo(50),
      );
    });

    test('should track deletions', () {
      analyticsService.trackDeletion();
      analyticsService.trackDeletion();
      analyticsService.trackDeletion();

      expect(analyticsService.analytics!.typingBehavior.deletions, 3);
    });

    test('should track abandoned messages', () {
      analyticsService.trackAbandonedMessage();
      analyticsService.trackAbandonedMessage();

      expect(analyticsService.analytics!.typingBehavior.abandonedMessages, 2);
    });

    test('should calculate average message length', () {
      analyticsService.trackMessage(sender: 'user', text: 'Hello');
      analyticsService.trackMessage(sender: 'user', text: 'World!!!!!');

      expect(analyticsService.analytics!.typingBehavior.avgMessageLength, 7.5);
    });
  });

  group('AnalyticsService.trackInteraction', () {
    setUp(() {
      analyticsService.startSession(
        sessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
      );
      mockSocketClient.clearEmittedEvents();
    });

    test('should track interaction event', () {
      analyticsService.trackInteraction(
        type: InteractionType.linkClicked,
        data: {'url': 'https://example.com'},
      );

      expect(analyticsService.analytics!.interactions.length, 1);
      expect(analyticsService.analytics!.interactions.first.type, InteractionType.linkClicked);
    });

    test('should emit interaction event', () {
      analyticsService.trackInteraction(
        type: InteractionType.buttonClicked,
        data: {'buttonId': 'submit_btn'},
      );

      expect(mockSocketClient.wasEventEmitted(AnalyticsEventType.interaction), true);
      final events = mockSocketClient.getEmittedEvents(AnalyticsEventType.interaction);
      expect(events.first.data['type'], InteractionType.buttonClicked);
      expect(events.first.data['buttonId'], 'submit_btn');
    });

    test('should include current node ID', () {
      analyticsService.trackNodeEntry(
        nodeId: 'node_1',
        nodeType: 'ask-question',
      );
      mockSocketClient.clearEmittedEvents();

      analyticsService.trackInteraction(type: InteractionType.fileUploaded);

      final events = mockSocketClient.getEmittedEvents(AnalyticsEventType.interaction);
      expect(events.first.data['nodeId'], 'node_1');
    });
  });

  group('AnalyticsService.trackGoalCompletion', () {
    setUp(() {
      analyticsService.startSession(
        sessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
      );
      mockSocketClient.clearEmittedEvents();
    });

    test('should track goal completion', () {
      analyticsService.trackGoalCompletion(
        goalId: 'goal_signup',
        conversionEvent: 'user_signed_up',
        conversionValue: 100.0,
      );

      expect(analyticsService.analytics!.goalCompletions.length, 1);
      expect(analyticsService.analytics!.goalCompletions.first.goalId, 'goal_signup');
      expect(analyticsService.analytics!.goalCompletions.first.conversionValue, 100.0);
    });

    test('should emit goal completion event', () {
      analyticsService.trackGoalCompletion(goalId: 'goal_purchase');

      expect(mockSocketClient.wasEventEmitted(AnalyticsEventType.goalCompletion), true);
      final events = mockSocketClient.getEmittedEvents(AnalyticsEventType.goalCompletion);
      expect(events.first.data['goalId'], 'goal_purchase');
    });
  });

  group('AnalyticsService.submitRating', () {
    setUp(() {
      analyticsService.startSession(
        sessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
      );
      mockSocketClient.clearEmittedEvents();
    });

    test('should submit CSAT rating', () {
      analyticsService.submitRating(
        csatScore: 5,
        feedback: 'Great service!',
      );

      expect(analyticsService.analytics!.rating, isNotNull);
      expect(analyticsService.analytics!.rating!.csatScore, 5);
      expect(analyticsService.analytics!.rating!.feedback, 'Great service!');
    });

    test('should submit thumbs up/down rating', () {
      analyticsService.submitRating(thumbsUp: true);

      expect(analyticsService.analytics!.rating!.thumbsUp, true);
    });

    test('should submit NPS score', () {
      analyticsService.submitRating(npsScore: 9);

      expect(analyticsService.analytics!.rating!.npsScore, 9);
    });

    test('should emit chat rating event', () {
      analyticsService.submitRating(csatScore: 4);

      expect(mockSocketClient.wasEventEmitted(AnalyticsEventType.chatRating), true);
      final events = mockSocketClient.getEmittedEvents(AnalyticsEventType.chatRating);
      expect(events.first.data['csatScore'], 4);
    });

    test('should include rating source', () {
      analyticsService.submitRating(
        csatScore: 5,
        source: 'in_chat_prompt',
      );

      expect(analyticsService.analytics!.rating!.source, 'in_chat_prompt');
    });
  });

  group('AnalyticsService.trackDropOff', () {
    setUp(() {
      analyticsService.startSession(
        sessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
      );
      analyticsService.trackNodeEntry(
        nodeId: 'node_1',
        nodeType: 'ask-question',
      );
      mockSocketClient.clearEmittedEvents();
    });

    test('should emit drop off event', () {
      analyticsService.trackDropOff(
        reason: 'user_closed_widget',
        lastUserAction: 'button_click',
      );

      expect(mockSocketClient.wasEventEmitted(AnalyticsEventType.dropOff), true);
      final events = mockSocketClient.getEmittedEvents(AnalyticsEventType.dropOff);
      expect(events.first.data['reason'], 'user_closed_widget');
      expect(events.first.data['lastUserAction'], 'button_click');
    });

    test('should include current node info', () {
      analyticsService.trackDropOff();

      final events = mockSocketClient.getEmittedEvents(AnalyticsEventType.dropOff);
      expect(events.first.data['nodeId'], 'node_1');
      expect(events.first.data['nodeType'], 'ask-question');
    });

    test('should not emit if no current node', () {
      analyticsService.trackNodeExit(exitType: NodeExitType.proceeded);
      mockSocketClient.clearEmittedEvents();

      analyticsService.trackDropOff();

      expect(mockSocketClient.emittedEvents.isEmpty, true);
    });
  });

  group('AnalyticsService.sendEngagementUpdate', () {
    setUp(() {
      analyticsService.startSession(
        sessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
      );
      mockSocketClient.clearEmittedEvents();
    });

    test('should emit engagement update', () {
      analyticsService.sendEngagementUpdate();

      expect(mockSocketClient.wasEventEmitted(AnalyticsEventType.chatEngagement), true);
      final events = mockSocketClient.getEmittedEvents(AnalyticsEventType.chatEngagement);
      expect(events.first.data['chatSessionId'], 'session_123');
      expect(events.first.data['sessionMetrics'], isNotNull);
      expect(events.first.data['typingBehavior'], isNotNull);
    });
  });

  group('AnalyticsService Data Access', () {
    setUp(() {
      analyticsService.startSession(
        sessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
      );
    });

    test('should return session analytics', () {
      final analytics = analyticsService.getSessionAnalytics();

      expect(analytics, isNotNull);
      expect(analytics!.sessionId, 'session_123');
    });

    test('should return analytics as JSON', () {
      final json = analyticsService.getAnalyticsJson();

      expect(json, isNotNull);
      expect(json!['sessionId'], 'session_123');
      expect(json['visitorId'], 'visitor_456');
      expect(json['botId'], 'bot_789');
    });

    test('should return null if not initialized', () {
      final newService = AnalyticsService(socketClient: mockSocketClient);

      expect(newService.getSessionAnalytics(), isNull);
      expect(newService.getAnalyticsJson(), isNull);

      newService.dispose();
    });
  });

  group('AnalyticsService Offline Behavior', () {
    test('should not emit events when socket disconnected', () {
      mockSocketClient.mockIsConnected = false;

      analyticsService.startSession(
        sessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
      );

      // Events are not emitted but analytics state is still tracked
      expect(analyticsService.isInitialized, true);
      expect(mockSocketClient.emittedEvents.isEmpty, true);
    });
  });

  group('AnalyticsService Environment Tracking', () {
    test('should include environment info in session', () {
      analyticsService.startSession(
        sessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
      );

      expect(analyticsService.analytics!.environment, isNotNull);
      expect(analyticsService.analytics!.environment!.platform, isNotNull);
      expect(analyticsService.analytics!.environment!.timezone, isNotNull);
    });
  });

  group('AnalyticsService.dispose', () {
    test('should end session on dispose', () {
      analyticsService.startSession(
        sessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
      );

      mockSocketClient.clearEmittedEvents();
      analyticsService.dispose();

      expect(mockSocketClient.wasEventEmitted(AnalyticsEventType.finalizeAnalytics), true);
    });

    test('should do nothing if not initialized', () {
      analyticsService.dispose();

      expect(mockSocketClient.emittedEvents.isEmpty, true);
    });
  });
}
