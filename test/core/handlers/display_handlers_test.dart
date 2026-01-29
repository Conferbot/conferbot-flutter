import 'package:flutter_test/flutter_test.dart';
import 'package:conferbot_flutter/src/core/nodes/handlers/display_handlers.dart';
import 'package:conferbot_flutter/src/core/nodes/node_result.dart';
import 'package:conferbot_flutter/src/core/nodes/node_types.dart';
import '../../mocks/mock_chat_state.dart';
import '../../fixtures/test_fixtures.dart';

void main() {
  late MockChatState mockState;

  setUp(() {
    mockState = MockChatState();
  });

  tearDown(() {
    mockState.reset();
  });

  group('MessageNodeHandler', () {
    late MessageNodeHandler handler;

    setUp(() {
      handler = MessageNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.message);
    });

    test('should display message and proceed', () async {
      final nodeData = TestFixtures.messageNode(
        text: 'Hello, welcome!',
      )['data'] as Map<String, dynamic>;

      final result = await handler.process(nodeData, 'msg_1');

      expect(result, isA<DisplayUIResult>());
      final uiState = (result as DisplayUIResult).uiState as MessageState;
      expect(uiState.text, 'Hello, welcome!');
      expect(uiState.nodeId, 'msg_1');
    });

    test('should add to transcript', () async {
      final nodeData = TestFixtures.messageNode(
        text: 'Bot message',
      )['data'] as Map<String, dynamic>;

      await handler.process(nodeData, 'msg_1');

      expect(mockState.transcriptEntries.length, 1);
      expect(mockState.transcriptEntries.first.by, 'bot');
      expect(mockState.transcriptEntries.first.message, 'Bot message');
    });

    test('should strip HTML from message', () async {
      final nodeData = {
        'type': 'message-node',
        'text': '<p>Hello <strong>World</strong>!</p>',
      };

      final result = await handler.process(nodeData, 'msg_1');

      expect(result, isA<DisplayUIResult>());
      final uiState = (result as DisplayUIResult).uiState as MessageState;
      expect(uiState.text, 'Hello World!');
    });

    test('should resolve variable references', () async {
      mockState.addAnswerVariable('prev_node', 'name', value: 'John');

      final nodeData = {
        'type': 'message-node',
        'text': 'Hello {{name}}!',
      };

      final result = await handler.process(nodeData, 'msg_1');

      expect(result, isA<DisplayUIResult>());
      final uiState = (result as DisplayUIResult).uiState as MessageState;
      expect(uiState.text, contains('John'));
    });

    test('should handle typing delay', () async {
      final nodeData = {
        'type': 'message-node',
        'text': 'Hello!',
        'typingDelay': 2000,
      };

      final result = await handler.process(nodeData, 'msg_1');

      expect(result, isA<DisplayUIResult>());
    });

    test('should push to record', () async {
      final nodeData = TestFixtures.messageNode(
        text: 'Hello!',
      )['data'] as Map<String, dynamic>;

      await handler.process(nodeData, 'msg_1');

      expect(mockState.recordEntries.length, 1);
      expect(mockState.recordEntries.first.shape, 'bot-message');
    });
  });

  group('ImageNodeHandler', () {
    late ImageNodeHandler handler;

    setUp(() {
      handler = ImageNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.image);
    });

    test('should display image', () async {
      final nodeData = TestFixtures.imageNode(
        url: 'https://example.com/image.jpg',
        caption: 'Test image',
      )['data'] as Map<String, dynamic>;

      final result = await handler.process(nodeData, 'img_1');

      expect(result, isA<DisplayUIResult>());
      final uiState = (result as DisplayUIResult).uiState as ImageState;
      expect(uiState.url, 'https://example.com/image.jpg');
      expect(uiState.caption, 'Test image');
      expect(uiState.nodeId, 'img_1');
    });

    test('should handle image without caption', () async {
      final nodeData = TestFixtures.imageNode(
        url: 'https://example.com/image.jpg',
      )['data'] as Map<String, dynamic>;

      final result = await handler.process(nodeData, 'img_1');

      expect(result, isA<DisplayUIResult>());
      final uiState = (result as DisplayUIResult).uiState as ImageState;
      expect(uiState.caption, isNull);
    });

    test('should push to record', () async {
      final nodeData = TestFixtures.imageNode()['data'] as Map<String, dynamic>;

      await handler.process(nodeData, 'img_1');

      expect(mockState.recordEntries.length, 1);
      expect(mockState.recordEntries.first.shape, 'bot-image');
    });
  });

  group('VideoNodeHandler', () {
    late VideoNodeHandler handler;

    setUp(() {
      handler = VideoNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.video);
    });

    test('should display video', () async {
      final nodeData = TestFixtures.videoNode(
        url: 'https://example.com/video.mp4',
        caption: 'Test video',
      )['data'] as Map<String, dynamic>;

      final result = await handler.process(nodeData, 'vid_1');

      expect(result, isA<DisplayUIResult>());
      final uiState = (result as DisplayUIResult).uiState as VideoState;
      expect(uiState.url, 'https://example.com/video.mp4');
      expect(uiState.caption, 'Test video');
      expect(uiState.nodeId, 'vid_1');
    });

    test('should handle autoplay setting', () async {
      final nodeData = {
        'type': 'video-node',
        'video': 'https://example.com/video.mp4',
        'autoplay': true,
      };

      final result = await handler.process(nodeData, 'vid_1');

      expect(result, isA<DisplayUIResult>());
      final uiState = (result as DisplayUIResult).uiState as VideoState;
      expect(uiState.autoplay, true);
    });

    test('should push to record', () async {
      final nodeData = TestFixtures.videoNode()['data'] as Map<String, dynamic>;

      await handler.process(nodeData, 'vid_1');

      expect(mockState.recordEntries.length, 1);
      expect(mockState.recordEntries.first.shape, 'bot-video');
    });
  });

  group('AudioNodeHandler', () {
    late AudioNodeHandler handler;

    setUp(() {
      handler = AudioNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.audio);
    });

    test('should display audio', () async {
      final nodeData = {
        'type': 'audio-node',
        'audio': 'https://example.com/audio.mp3',
        'title': 'Test audio',
      };

      final result = await handler.process(nodeData, 'audio_1');

      expect(result, isA<DisplayUIResult>());
      final uiState = (result as DisplayUIResult).uiState as AudioState;
      expect(uiState.url, 'https://example.com/audio.mp3');
      expect(uiState.title, 'Test audio');
      expect(uiState.nodeId, 'audio_1');
    });

    test('should push to record', () async {
      final nodeData = {
        'type': 'audio-node',
        'audio': 'https://example.com/audio.mp3',
      };

      await handler.process(nodeData, 'audio_1');

      expect(mockState.recordEntries.length, 1);
      expect(mockState.recordEntries.first.shape, 'bot-audio');
    });
  });

  group('FileNodeHandler', () {
    late FileNodeHandler handler;

    setUp(() {
      handler = FileNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.file);
    });

    test('should display file', () async {
      final nodeData = {
        'type': 'file-node',
        'file': 'https://example.com/document.pdf',
        'fileName': 'document.pdf',
        'fileSize': '1.2 MB',
      };

      final result = await handler.process(nodeData, 'file_1');

      expect(result, isA<DisplayUIResult>());
      final uiState = (result as DisplayUIResult).uiState as FileState;
      expect(uiState.url, 'https://example.com/document.pdf');
      expect(uiState.fileName, 'document.pdf');
      expect(uiState.fileSize, '1.2 MB');
      expect(uiState.nodeId, 'file_1');
    });

    test('should handle missing file name', () async {
      final nodeData = {
        'type': 'file-node',
        'file': 'https://example.com/document.pdf',
      };

      final result = await handler.process(nodeData, 'file_1');

      expect(result, isA<DisplayUIResult>());
      final uiState = (result as DisplayUIResult).uiState as FileState;
      expect(uiState.fileName, isNotEmpty);
    });

    test('should push to record', () async {
      final nodeData = {
        'type': 'file-node',
        'file': 'https://example.com/document.pdf',
        'fileName': 'document.pdf',
      };

      await handler.process(nodeData, 'file_1');

      expect(mockState.recordEntries.length, 1);
      expect(mockState.recordEntries.first.shape, 'bot-file');
    });
  });

  group('HtmlNodeHandler', () {
    late HtmlNodeHandler handler;

    setUp(() {
      handler = HtmlNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.html);
    });

    test('should display HTML content', () async {
      final nodeData = {
        'type': 'html-node',
        'htmlContent': '<div><h1>Hello</h1><p>World</p></div>',
      };

      final result = await handler.process(nodeData, 'html_1');

      expect(result, isA<DisplayUIResult>());
      final uiState = (result as DisplayUIResult).uiState as HtmlState;
      expect(uiState.htmlContent, contains('<h1>Hello</h1>'));
      expect(uiState.nodeId, 'html_1');
    });

    test('should push to record', () async {
      final nodeData = {
        'type': 'html-node',
        'htmlContent': '<p>Test</p>',
      };

      await handler.process(nodeData, 'html_1');

      expect(mockState.recordEntries.length, 1);
      expect(mockState.recordEntries.first.shape, 'bot-html');
    });
  });

  group('UserRedirectNodeHandler', () {
    late UserRedirectNodeHandler handler;

    setUp(() {
      handler = UserRedirectNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.userRedirect);
    });

    test('should display redirect state', () async {
      final nodeData = {
        'type': 'user-redirect-node',
        'url': 'https://example.com',
        'message': 'Redirecting...',
      };

      final result = await handler.process(nodeData, 'redirect_1');

      expect(result, isA<DisplayUIResult>());
      final uiState = (result as DisplayUIResult).uiState as RedirectState;
      expect(uiState.url, 'https://example.com');
      expect(uiState.message, 'Redirecting...');
      expect(uiState.nodeId, 'redirect_1');
    });

    test('should handle open in new tab setting', () async {
      final nodeData = {
        'type': 'user-redirect-node',
        'url': 'https://example.com',
        'openInNewTab': true,
      };

      final result = await handler.process(nodeData, 'redirect_1');

      expect(result, isA<DisplayUIResult>());
      final uiState = (result as DisplayUIResult).uiState as RedirectState;
      expect(uiState.openInNewTab, true);
    });

    test('should push to record', () async {
      final nodeData = {
        'type': 'user-redirect-node',
        'url': 'https://example.com',
      };

      await handler.process(nodeData, 'redirect_1');

      expect(mockState.recordEntries.length, 1);
      expect(mockState.recordEntries.first.shape, 'bot-redirect');
    });
  });

  group('NavigateNodeHandler', () {
    late NavigateNodeHandler handler;

    setUp(() {
      handler = NavigateNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.navigate);
    });

    test('should display navigate state', () async {
      final nodeData = {
        'type': 'navigate-node',
        'url': 'https://example.com/page',
      };

      final result = await handler.process(nodeData, 'nav_1');

      expect(result, isA<DisplayUIResult>());
      final uiState = (result as DisplayUIResult).uiState as RedirectState;
      expect(uiState.url, 'https://example.com/page');
      expect(uiState.nodeId, 'nav_1');
    });
  });

  group('BaseNodeHandler Utility Methods', () {
    late MessageNodeHandler handler;

    setUp(() {
      handler = MessageNodeHandler();
      handler.state = mockState;
    });

    test('getString should return value or default', () {
      final nodeData = {'key': 'value'};

      expect(handler.getString(nodeData, 'key', 'default'), 'value');
      expect(handler.getString(nodeData, 'missing', 'default'), 'default');
    });

    test('getInt should parse integers', () {
      final nodeData = {'intVal': 42, 'strVal': '100', 'invalid': 'abc'};

      expect(handler.getInt(nodeData, 'intVal', 0), 42);
      expect(handler.getInt(nodeData, 'strVal', 0), 100);
      expect(handler.getInt(nodeData, 'invalid', 0), 0);
      expect(handler.getInt(nodeData, 'missing', 5), 5);
    });

    test('getBoolean should parse booleans', () {
      final nodeData = {'boolVal': true, 'strTrue': 'true', 'strFalse': 'false'};

      expect(handler.getBoolean(nodeData, 'boolVal', false), true);
      expect(handler.getBoolean(nodeData, 'strTrue', false), true);
      expect(handler.getBoolean(nodeData, 'strFalse', true), false);
      expect(handler.getBoolean(nodeData, 'missing', true), true);
    });

    test('getList should return list or empty', () {
      final nodeData = {'list': [1, 2, 3]};

      expect(handler.getList<int>(nodeData, 'list'), [1, 2, 3]);
      expect(handler.getList<int>(nodeData, 'missing'), isEmpty);
    });

    test('getMap should return map or empty', () {
      final nodeData = {
        'map': {'key': 'value'}
      };

      expect(handler.getMap(nodeData, 'map'), {'key': 'value'});
      expect(handler.getMap(nodeData, 'missing'), isEmpty);
    });

    test('stripHtml should remove HTML tags', () {
      expect(handler.stripHtml('<p>Hello</p>'), 'Hello');
      expect(handler.stripHtml('<strong>Bold</strong>'), 'Bold');
      expect(handler.stripHtml('No tags'), 'No tags');
      expect(handler.stripHtml('&amp;&lt;&gt;'), '&<>');
      expect(handler.stripHtml('&nbsp;space'), ' space');
    });

    test('isValidEmail should validate emails', () {
      expect(handler.isValidEmail('test@example.com'), true);
      expect(handler.isValidEmail('invalid'), false);
      expect(handler.isValidEmail(''), false);
    });

    test('isValidPhone should validate phones', () {
      expect(handler.isValidPhone('1234567890'), true);
      expect(handler.isValidPhone('+1-234-567-8900'), true);
      expect(handler.isValidPhone('123'), false);
    });

    test('isValidUrl should validate URLs', () {
      expect(handler.isValidUrl('https://example.com'), true);
      expect(handler.isValidUrl('http://example.com/path'), true);
      expect(handler.isValidUrl('invalid'), false);
    });

    test('isValidNumber should validate numbers', () {
      expect(handler.isValidNumber('42'), true);
      expect(handler.isValidNumber('3.14'), true);
      expect(handler.isValidNumber('abc'), false);
    });
  });

  group('DisplayNodeHandlers Registry', () {
    test('should return all display handlers', () {
      final handlers = DisplayNodeHandlers.handlers;

      expect(handlers.length, greaterThan(0));
      expect(handlers.any((h) => h.nodeType == NodeTypes.message), true);
      expect(handlers.any((h) => h.nodeType == NodeTypes.image), true);
      expect(handlers.any((h) => h.nodeType == NodeTypes.video), true);
      expect(handlers.any((h) => h.nodeType == NodeTypes.audio), true);
      expect(handlers.any((h) => h.nodeType == NodeTypes.file), true);
    });

    test('should get handler by type', () {
      final handler = DisplayNodeHandlers.getHandler(NodeTypes.message);
      expect(handler, isA<MessageNodeHandler>());
    });

    test('should return null for unknown type', () {
      final handler = DisplayNodeHandlers.getHandler('unknown-type');
      expect(handler, isNull);
    });

    test('should check if handler exists', () {
      expect(DisplayNodeHandlers.hasHandler(NodeTypes.message), true);
      expect(DisplayNodeHandlers.hasHandler('unknown-type'), false);
    });
  });
}
