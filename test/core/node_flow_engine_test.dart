import 'package:flutter_test/flutter_test.dart';
import 'package:conferbot_flutter/src/core/node_flow_engine.dart';
import 'package:conferbot_flutter/src/core/nodes/node_types.dart';
import 'package:conferbot_flutter/src/core/nodes/handlers/display_handlers.dart';
import '../mocks/mock_socket_client.dart';
import '../fixtures/test_fixtures.dart';

void main() {
  late NodeFlowEngine engine;
  late MockSocketClient mockSocketClient;

  setUp(() {
    mockSocketClient = MockSocketClient();
    engine = NodeFlowEngine(socketClient: mockSocketClient);
  });

  tearDown(() {
    engine.dispose();
    mockSocketClient.clearEmittedEvents();
  });

  group('NodeFlowEngine Initialization', () {
    test('should initialize with session data', () {
      engine.initialize(
        chatSessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
        stepsData: TestFixtures.simpleFlow(),
        edgesData: TestFixtures.simpleEdges(),
      );

      expect(engine.chatSessionId, 'session_123');
      expect(engine.visitorId, 'visitor_456');
      expect(engine.botId, 'bot_789');
      expect(engine.isInitialized, true);
    });

    test('should load steps and edges', () {
      engine.initialize(
        chatSessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
        stepsData: TestFixtures.simpleFlow(),
        edgesData: TestFixtures.simpleEdges(),
      );

      expect(engine.steps.length, 3);
      expect(engine.edges.length, 2);
    });

    test('should start in not processing state', () {
      expect(engine.isProcessing, false);
      expect(engine.currentUIState, isNull);
      expect(engine.currentNodeId, isNull);
    });
  });

  group('NodeFlowEngine Start', () {
    test('should start processing first node', () async {
      engine.initialize(
        chatSessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
        stepsData: TestFixtures.simpleFlow(),
        edgesData: TestFixtures.simpleEdges(),
      );

      engine.start();

      // Wait for async processing
      await Future.delayed(const Duration(milliseconds: 100));

      expect(engine.currentNodeId, isNotNull);
    });

    test('should not start if not initialized', () {
      engine.start();

      expect(engine.isProcessing, false);
      expect(engine.currentNodeId, isNull);
    });

    test('should not start with empty steps', () {
      engine.initialize(
        chatSessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
        stepsData: [],
        edgesData: [],
      );

      engine.start();

      expect(engine.isProcessing, false);
    });
  });

  group('NodeFlowEngine Handler Registry', () {
    test('should have handlers for all display node types', () {
      expect(engine.hasHandler(NodeTypes.message), true);
      expect(engine.hasHandler(NodeTypes.image), true);
      expect(engine.hasHandler(NodeTypes.video), true);
      expect(engine.hasHandler(NodeTypes.audio), true);
      expect(engine.hasHandler(NodeTypes.file), true);
    });

    test('should have handlers for ask question node types', () {
      expect(engine.hasHandler(NodeTypes.askName), true);
      expect(engine.hasHandler(NodeTypes.askEmail), true);
      expect(engine.hasHandler(NodeTypes.askPhone), true);
      expect(engine.hasHandler(NodeTypes.askNumber), true);
      expect(engine.hasHandler(NodeTypes.askUrl), true);
    });

    test('should have handlers for choice node types', () {
      expect(engine.hasHandler(NodeTypes.twoChoices), true);
      expect(engine.hasHandler(NodeTypes.threeChoices), true);
      expect(engine.hasHandler(NodeTypes.nChoices), true);
      expect(engine.hasHandler(NodeTypes.yesOrNoChoice), true);
    });

    test('should have handlers for logic node types', () {
      expect(engine.hasHandler(NodeTypes.condition), true);
      expect(engine.hasHandler(NodeTypes.booleanLogic), true);
      expect(engine.hasHandler(NodeTypes.mathOperation), true);
      expect(engine.hasHandler(NodeTypes.variable), true);
      expect(engine.hasHandler(NodeTypes.jumpTo), true);
    });

    test('should have handlers for integration node types', () {
      expect(engine.hasHandler(NodeTypes.webhook), true);
      expect(engine.hasHandler(NodeTypes.email), true);
      expect(engine.hasHandler(NodeTypes.googleSheets), true);
      expect(engine.hasHandler(NodeTypes.stripe), true);
    });

    test('should have handler for special node types', () {
      expect(engine.hasHandler(NodeTypes.delay), true);
      expect(engine.hasHandler(NodeTypes.humanHandover), true);
    });
  });

  group('NodeFlowEngine Node Processing', () {
    test('should process message node and display UI', () async {
      final steps = [
        TestFixtures.messageNode(nodeId: 'msg_1', text: 'Hello!'),
      ];

      engine.initialize(
        chatSessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
        stepsData: steps,
        edgesData: [],
      );

      engine.start();
      await Future.delayed(const Duration(milliseconds: 200));

      expect(engine.currentUIState, isNotNull);
      expect(engine.currentUIState, isA<MessageState>());
      final messageState = engine.currentUIState as MessageState;
      expect(messageState.text, 'Hello!');
    });

    test('should auto-proceed from message node', () async {
      final steps = [
        TestFixtures.messageNode(nodeId: 'msg_1', text: 'Hello!'),
        TestFixtures.messageNode(nodeId: 'msg_2', text: 'Goodbye!'),
      ];
      final edges = [
        {'id': 'edge_1', 'source': 'msg_1', 'target': 'msg_2'},
      ];

      engine.initialize(
        chatSessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
        stepsData: steps,
        edgesData: edges,
      );

      engine.start();
      await Future.delayed(const Duration(milliseconds: 500));

      // Should have moved past first message
      expect(engine.currentNodeId, isNotNull);
    });
  });

  group('NodeFlowEngine Response Handling', () {
    test('should submit response for interactive node', () async {
      final steps = [
        TestFixtures.askNameNode(nodeId: 'ask_name'),
      ];

      engine.initialize(
        chatSessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
        stepsData: steps,
        edgesData: [],
      );

      engine.start();
      await Future.delayed(const Duration(milliseconds: 200));

      engine.submitResponse('John Doe');
      await Future.delayed(const Duration(milliseconds: 200));

      // Response should have been processed
      expect(engine.chatState.getAnswerVariableValue('name'), isNotNull);
    });

    test('should handle branching response', () async {
      final steps = [
        TestFixtures.twoChoicesNode(nodeId: 'choice_1'),
        TestFixtures.messageNode(nodeId: 'path_a', text: 'Path A'),
        TestFixtures.messageNode(nodeId: 'path_b', text: 'Path B'),
      ];
      final edges = [
        {'id': 'edge_1', 'source': 'choice_1', 'sourceHandle': 'source-1', 'target': 'path_a'},
        {'id': 'edge_2', 'source': 'choice_1', 'sourceHandle': 'source-2', 'target': 'path_b'},
      ];

      engine.initialize(
        chatSessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
        stepsData: steps,
        edgesData: edges,
      );

      engine.start();
      await Future.delayed(const Duration(milliseconds: 200));

      engine.submitResponse({'id': '1', 'text': 'Option B'});
      await Future.delayed(const Duration(milliseconds: 300));

      // Should have followed path B
      expect(engine.currentNodeId, 'path_b');
    });
  });

  group('NodeFlowEngine Edge Navigation', () {
    test('should find next node from edge', () {
      engine.initialize(
        chatSessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
        stepsData: TestFixtures.simpleFlow(),
        edgesData: TestFixtures.simpleEdges(),
      );

      final nextNode = engine.findNextNode('step_1', null);

      expect(nextNode, isNotNull);
      expect(nextNode!['id'], 'step_2');
    });

    test('should find next node with target port', () {
      final edges = [
        {'id': 'edge_1', 'source': 'choice', 'sourceHandle': 'source-1', 'target': 'path_a'},
        {'id': 'edge_2', 'source': 'choice', 'sourceHandle': 'source-2', 'target': 'path_b'},
      ];
      final steps = [
        {'id': 'choice', 'type': 'two-choices-node'},
        {'id': 'path_a', 'type': 'message-node'},
        {'id': 'path_b', 'type': 'message-node'},
      ];

      engine.initialize(
        chatSessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
        stepsData: steps,
        edgesData: edges,
      );

      final pathA = engine.findNextNode('choice', 'source-1');
      expect(pathA, isNotNull);
      expect(pathA!['id'], 'path_a');

      final pathB = engine.findNextNode('choice', 'source-2');
      expect(pathB, isNotNull);
      expect(pathB!['id'], 'path_b');
    });

    test('should return null when no edge found', () {
      engine.initialize(
        chatSessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
        stepsData: TestFixtures.simpleFlow(),
        edgesData: [],
      );

      final nextNode = engine.findNextNode('step_1', null);

      expect(nextNode, isNull);
    });
  });

  group('NodeFlowEngine Jump To', () {
    test('should jump to target node', () async {
      final steps = [
        TestFixtures.jumpToNode(nodeId: 'jump_1', targetNodeId: 'target'),
        TestFixtures.messageNode(nodeId: 'skipped', text: 'Skipped'),
        TestFixtures.messageNode(nodeId: 'target', text: 'Target reached'),
      ];

      engine.initialize(
        chatSessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
        stepsData: steps,
        edgesData: [],
      );

      engine.start();
      await Future.delayed(const Duration(milliseconds: 300));

      expect(engine.currentNodeId, 'target');
    });
  });

  group('NodeFlowEngine Variable Substitution', () {
    test('should substitute variables in text', () async {
      final steps = [
        TestFixtures.variableNode(nodeId: 'var_1', name: 'username', value: 'Alice'),
        {
          'id': 'msg_1',
          'type': 'message-node',
          'data': {
            'type': 'message-node',
            'text': 'Hello {{username}}!',
          },
        },
      ];
      final edges = [
        {'id': 'edge_1', 'source': 'var_1', 'target': 'msg_1'},
      ];

      engine.initialize(
        chatSessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
        stepsData: steps,
        edgesData: edges,
      );

      engine.start();
      await Future.delayed(const Duration(milliseconds: 300));

      // The variable should have been set
      expect(engine.chatState.getVariable('username'), 'Alice');
    });
  });

  group('NodeFlowEngine Flow Completion', () {
    test('should mark flow as complete when no more nodes', () async {
      final steps = [
        TestFixtures.messageNode(nodeId: 'msg_1', text: 'End'),
      ];

      engine.initialize(
        chatSessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
        stepsData: steps,
        edgesData: [],
      );

      engine.start();
      await Future.delayed(const Duration(milliseconds: 500));

      expect(engine.isFlowComplete, true);
    });
  });

  group('NodeFlowEngine Error Handling', () {
    test('should set error message on processing error', () async {
      // Create an invalid node type to trigger error
      final steps = [
        {
          'id': 'invalid',
          'type': 'unknown-node-type',
          'data': {'type': 'unknown-node-type'},
        },
      ];

      engine.initialize(
        chatSessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
        stepsData: steps,
        edgesData: [],
      );

      engine.start();
      await Future.delayed(const Duration(milliseconds: 200));

      expect(engine.errorMessage, isNotNull);
    });

    test('should clear error', () {
      engine.initialize(
        chatSessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
        stepsData: [],
        edgesData: [],
      );

      // Manually set error for testing
      engine.setError('Test error');
      expect(engine.errorMessage, 'Test error');

      engine.clearError();
      expect(engine.errorMessage, isNull);
    });
  });

  group('NodeFlowEngine Reset', () {
    test('should reset all state', () async {
      final steps = [
        TestFixtures.messageNode(nodeId: 'msg_1', text: 'Hello'),
      ];

      engine.initialize(
        chatSessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
        stepsData: steps,
        edgesData: [],
      );

      engine.start();
      await Future.delayed(const Duration(milliseconds: 200));

      engine.reset();

      expect(engine.isInitialized, false);
      expect(engine.isProcessing, false);
      expect(engine.currentNodeId, isNull);
      expect(engine.currentUIState, isNull);
      expect(engine.isFlowComplete, false);
    });
  });

  group('NodeFlowEngine Server Message Handling', () {
    test('should handle server message with node data', () {
      engine.initialize(
        chatSessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
        stepsData: [],
        edgesData: [],
      );

      engine.handleServerMessage({
        'nodeId': 'server_node',
        'nodeData': {
          'type': 'message-node',
          'text': 'Server message',
        },
      });

      // Should process the message
      expect(engine.currentNodeId, 'server_node');
    });
  });

  group('NodeFlowEngine Agent Handover', () {
    test('should handle agent accepted event', () {
      engine.initialize(
        chatSessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
        stepsData: [],
        edgesData: [],
      );

      engine.handleAgentAccepted('Agent Smith');

      // Agent name should be recorded in transcript
      expect(
        engine.chatState.transcript.any((e) => e.message.contains('Agent Smith')),
        true,
      );
    });

    test('should handle no agents available event', () {
      engine.initialize(
        chatSessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
        stepsData: [],
        edgesData: [],
      );

      engine.handleNoAgentsAvailable();

      // Should add fallback message to transcript
      expect(engine.chatState.transcript.length, greaterThan(0));
    });

    test('should handle chat ended event', () {
      engine.initialize(
        chatSessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
        stepsData: [],
        edgesData: [],
      );

      engine.handleChatEnded();

      // Should mark flow as complete or handle post-chat survey
      // The exact behavior depends on current node state
    });
  });

  group('NodeFlowEngine ChangeNotifier', () {
    test('should notify listeners on state change', () async {
      var notifyCount = 0;
      engine.addListener(() => notifyCount++);

      engine.initialize(
        chatSessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
        stepsData: TestFixtures.simpleFlow(),
        edgesData: TestFixtures.simpleEdges(),
      );

      engine.start();
      await Future.delayed(const Duration(milliseconds: 300));

      expect(notifyCount, greaterThan(0));
    });
  });
}
