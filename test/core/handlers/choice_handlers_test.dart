import 'package:flutter_test/flutter_test.dart';
import 'package:conferbot_flutter/src/core/nodes/handlers/choice_handlers.dart';
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

  group('TwoChoicesNodeHandler', () {
    late TwoChoicesNodeHandler handler;

    setUp(() {
      handler = TwoChoicesNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.twoChoices);
    });

    test('should display two choices', () async {
      final nodeData = TestFixtures.twoChoicesNode(
        choice1: 'Option A',
        choice2: 'Option B',
      )['data'] as Map<String, dynamic>;

      final result = await handler.process(nodeData, 'choice_1');

      expect(result, isA<DisplayUIResult>());
      final uiState = (result as DisplayUIResult).uiState as SingleChoiceState;
      expect(uiState.choices.length, 2);
      expect(uiState.choices[0].text, 'Option A');
      expect(uiState.choices[1].text, 'Option B');
    });

    test('should display one choice when second is disabled', () async {
      final nodeData = TestFixtures.twoChoicesNode(
        choice1: 'Option A',
        choice2: 'Option B',
        disableSecond: true,
      )['data'] as Map<String, dynamic>;

      final result = await handler.process(nodeData, 'choice_1');

      expect(result, isA<DisplayUIResult>());
      final uiState = (result as DisplayUIResult).uiState as SingleChoiceState;
      expect(uiState.choices.length, 1);
      expect(uiState.choices[0].text, 'Option A');
    });

    test('should route to source-1 for first choice', () async {
      final nodeData = TestFixtures.twoChoicesNode()['data'] as Map<String, dynamic>;

      await handler.process(nodeData, 'choice_1');
      final result = await handler.handleResponse({'id': '0', 'text': 'Option A'}, nodeData, 'choice_1');

      expect(result, isA<DelayedProceedResult>());
      expect((result as DelayedProceedResult).targetPort, 'source-1');
    });

    test('should route to source-2 for second choice', () async {
      final nodeData = TestFixtures.twoChoicesNode()['data'] as Map<String, dynamic>;

      await handler.process(nodeData, 'choice_1');
      final result = await handler.handleResponse({'id': '1', 'text': 'Option B'}, nodeData, 'choice_1');

      expect(result, isA<DelayedProceedResult>());
      expect((result as DelayedProceedResult).targetPort, 'source-2');
    });

    test('should store answer variable', () async {
      final nodeData = TestFixtures.twoChoicesNode(
        answerVariable: 'selected_choice',
      )['data'] as Map<String, dynamic>;

      await handler.process(nodeData, 'choice_1');
      await handler.handleResponse({'id': '0', 'text': 'Option A'}, nodeData, 'choice_1');

      expect(mockState.answerVariables['choice_1']?['value'], 'Option A');
    });

    test('should add to transcript', () async {
      final nodeData = TestFixtures.twoChoicesNode()['data'] as Map<String, dynamic>;

      await handler.process(nodeData, 'choice_1');
      await handler.handleResponse({'id': '0', 'text': 'Option A'}, nodeData, 'choice_1');

      expect(mockState.transcriptEntries.any((e) => e.by == 'user' && e.message == 'Option A'), true);
    });

    test('should push to record', () async {
      final nodeData = TestFixtures.twoChoicesNode()['data'] as Map<String, dynamic>;

      await handler.process(nodeData, 'choice_1');
      await handler.handleResponse({'id': '0', 'text': 'Option A'}, nodeData, 'choice_1');

      expect(mockState.recordEntries.any((e) => e.shape == 'user-selected-choice'), true);
    });

    test('should strip HTML from choices', () async {
      final nodeData = {
        'type': 'two-choices-node',
        'choice1': '<b>Option A</b>',
        'choice2': '<i>Option B</i>',
        'answerVariable': 'choice',
      };

      final result = await handler.process(nodeData, 'choice_1');

      expect(result, isA<DisplayUIResult>());
      final uiState = (result as DisplayUIResult).uiState as SingleChoiceState;
      expect(uiState.choices[0].text, 'Option A');
      expect(uiState.choices[1].text, 'Option B');
    });
  });

  group('ThreeChoicesNodeHandler', () {
    late ThreeChoicesNodeHandler handler;

    setUp(() {
      handler = ThreeChoicesNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.threeChoices);
    });

    test('should display three choices', () async {
      final nodeData = TestFixtures.threeChoicesNode(
        choice1: 'Option A',
        choice2: 'Option B',
        choice3: 'Option C',
      )['data'] as Map<String, dynamic>;

      final result = await handler.process(nodeData, 'choice_1');

      expect(result, isA<DisplayUIResult>());
      final uiState = (result as DisplayUIResult).uiState as SingleChoiceState;
      expect(uiState.choices.length, 3);
      expect(uiState.choices[0].text, 'Option A');
      expect(uiState.choices[1].text, 'Option B');
      expect(uiState.choices[2].text, 'Option C');
    });

    test('should route to correct port based on choice', () async {
      final nodeData = TestFixtures.threeChoicesNode()['data'] as Map<String, dynamic>;

      await handler.process(nodeData, 'choice_1');

      final result1 = await handler.handleResponse({'id': '0'}, nodeData, 'choice_1');
      expect((result1 as DelayedProceedResult).targetPort, 'source-1');

      final result2 = await handler.handleResponse({'id': '1'}, nodeData, 'choice_1');
      expect((result2 as DelayedProceedResult).targetPort, 'source-2');

      final result3 = await handler.handleResponse({'id': '2'}, nodeData, 'choice_1');
      expect((result3 as DelayedProceedResult).targetPort, 'source-3');
    });
  });

  group('NChoicesNodeHandler', () {
    late NChoicesNodeHandler handler;

    setUp(() {
      handler = NChoicesNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.nChoices);
    });

    test('should display dynamic choices', () async {
      final nodeData = TestFixtures.nChoicesNode(
        choices: [
          {'id': '0', 'choiceText': 'First'},
          {'id': '1', 'choiceText': 'Second'},
          {'id': '2', 'choiceText': 'Third'},
          {'id': '3', 'choiceText': 'Fourth'},
        ],
      )['data'] as Map<String, dynamic>;

      final result = await handler.process(nodeData, 'choice_1');

      expect(result, isA<DisplayUIResult>());
      final uiState = (result as DisplayUIResult).uiState as SingleChoiceState;
      expect(uiState.choices.length, 4);
    });

    test('should route to dynamic port based on choice id', () async {
      final nodeData = TestFixtures.nChoicesNode()['data'] as Map<String, dynamic>;

      await handler.process(nodeData, 'choice_1');
      final result = await handler.handleResponse({'id': '2', 'text': 'Third'}, nodeData, 'choice_1');

      expect(result, isA<DelayedProceedResult>());
      expect((result as DelayedProceedResult).targetPort, 'source-2');
    });
  });

  group('SelectOptionNodeHandler', () {
    late SelectOptionNodeHandler handler;

    setUp(() {
      handler = SelectOptionNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.selectOption);
    });

    test('should display dropdown options', () async {
      final nodeData = {
        'type': 'select-option-node',
        'option1': 'First',
        'option2': 'Second',
        'option3': 'Third',
        'answerVariable': 'selected',
      };

      final result = await handler.process(nodeData, 'select_1');

      expect(result, isA<DisplayUIResult>());
      final uiState = (result as DisplayUIResult).uiState as DropdownState;
      expect(uiState.options.length, 3);
    });

    test('should skip disabled options', () async {
      final nodeData = {
        'type': 'select-option-node',
        'option1': 'First',
        'option2': 'Second',
        'disableOption2': true,
        'option3': 'Third',
        'answerVariable': 'selected',
      };

      final result = await handler.process(nodeData, 'select_1');

      expect(result, isA<DisplayUIResult>());
      final uiState = (result as DisplayUIResult).uiState as DropdownState;
      expect(uiState.options.length, 2);
    });

    test('should handle selection response', () async {
      final nodeData = {
        'type': 'select-option-node',
        'option1': 'First',
        'option2': 'Second',
        'answerVariable': 'selected',
      };

      await handler.process(nodeData, 'select_1');
      final result = await handler.handleResponse({'text': 'First'}, nodeData, 'select_1');

      expect(result, isA<DelayedProceedResult>());
      expect(mockState.answerVariables['select_1']?['value'], 'First');
    });
  });

  group('NSelectOptionNodeHandler', () {
    late NSelectOptionNodeHandler handler;

    setUp(() {
      handler = NSelectOptionNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.nSelectOption);
    });

    test('should display dynamic dropdown options', () async {
      final nodeData = {
        'type': 'n-select-option-node',
        'options': [
          {'id': '0', 'optionText': 'First'},
          {'id': '1', 'optionText': 'Second'},
          {'id': '2', 'optionText': 'Third'},
        ],
        'answerVariable': 'selected',
      };

      final result = await handler.process(nodeData, 'nselect_1');

      expect(result, isA<DisplayUIResult>());
      final uiState = (result as DisplayUIResult).uiState as DropdownState;
      expect(uiState.options.length, 3);
    });
  });

  group('NCheckOptionsNodeHandler', () {
    late NCheckOptionsNodeHandler handler;

    setUp(() {
      handler = NCheckOptionsNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.nCheckOptions);
    });

    test('should display multiple choice options', () async {
      final nodeData = {
        'type': 'n-check-options-node',
        'options': [
          {'id': '0', 'optionText': 'Option 1'},
          {'id': '1', 'optionText': 'Option 2'},
          {'id': '2', 'optionText': 'Option 3'},
        ],
        'answerVariable': 'selected',
      };

      final result = await handler.process(nodeData, 'check_1');

      expect(result, isA<DisplayUIResult>());
      final uiState = (result as DisplayUIResult).uiState as MultipleChoiceState;
      expect(uiState.options.length, 3);
    });

    test('should handle multiple selection response as list', () async {
      final nodeData = {
        'type': 'n-check-options-node',
        'options': [
          {'id': '0', 'optionText': 'Option 1'},
          {'id': '1', 'optionText': 'Option 2'},
        ],
        'answerVariable': 'selected',
      };

      await handler.process(nodeData, 'check_1');
      final result = await handler.handleResponse(['Option 1', 'Option 2'], nodeData, 'check_1');

      expect(result, isA<ProceedResult>());
      expect(mockState.answerVariables['check_1']?['value'], 'Option 1, Option 2');
    });

    test('should handle multiple selection response as string', () async {
      final nodeData = {
        'type': 'n-check-options-node',
        'options': [
          {'id': '0', 'optionText': 'Option 1'},
        ],
        'answerVariable': 'selected',
      };

      await handler.process(nodeData, 'check_1');
      final result = await handler.handleResponse('Option 1, Option 2', nodeData, 'check_1');

      expect(result, isA<ProceedResult>());
      expect(mockState.answerVariables['check_1']?['value'], 'Option 1, Option 2');
    });
  });

  group('ImageChoiceNodeHandler', () {
    late ImageChoiceNodeHandler handler;

    setUp(() {
      handler = ImageChoiceNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.imageChoice);
    });

    test('should display image choices', () async {
      final nodeData = {
        'type': 'image-choice-node',
        'images': [
          {'id': '0', 'image': 'https://example.com/img1.jpg', 'label': 'Image 1'},
          {'id': '1', 'image': 'https://example.com/img2.jpg', 'label': 'Image 2'},
        ],
        'answerVariable': 'selected_image',
      };

      final result = await handler.process(nodeData, 'imgchoice_1');

      expect(result, isA<DisplayUIResult>());
      final uiState = (result as DisplayUIResult).uiState as ImageChoiceState;
      expect(uiState.images.length, 2);
      expect(uiState.images[0].imageUrl, 'https://example.com/img1.jpg');
      expect(uiState.images[0].label, 'Image 1');
    });

    test('should route to correct port based on image selection', () async {
      final nodeData = {
        'type': 'image-choice-node',
        'images': [
          {'id': '0', 'image': 'https://example.com/img1.jpg', 'label': 'Image 1'},
          {'id': '1', 'image': 'https://example.com/img2.jpg', 'label': 'Image 2'},
        ],
        'answerVariable': 'selected_image',
      };

      await handler.process(nodeData, 'imgchoice_1');
      final result = await handler.handleResponse({'id': '1', 'label': 'Image 2'}, nodeData, 'imgchoice_1');

      expect(result, isA<DelayedProceedResult>());
      expect((result as DelayedProceedResult).targetPort, 'source-1');
    });
  });

  group('YesOrNoChoiceNodeHandler', () {
    late YesOrNoChoiceNodeHandler handler;

    setUp(() {
      handler = YesOrNoChoiceNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.yesOrNoChoice);
    });

    test('should display default yes/no choices', () async {
      final nodeData = TestFixtures.yesOrNoNode()['data'] as Map<String, dynamic>;

      final result = await handler.process(nodeData, 'yesno_1');

      expect(result, isA<DisplayUIResult>());
      final uiState = (result as DisplayUIResult).uiState as SingleChoiceState;
      expect(uiState.choices.length, 2);
      expect(uiState.choices[0].text, 'Yes');
      expect(uiState.choices[1].text, 'No');
    });

    test('should display custom yes/no options', () async {
      final nodeData = {
        'type': 'yes-or-no-choice-node',
        'options': [
          {'id': 'yes', 'label': 'Agree'},
          {'id': 'no', 'label': 'Disagree'},
        ],
        'answerVariable': 'response',
      };

      final result = await handler.process(nodeData, 'yesno_1');

      expect(result, isA<DisplayUIResult>());
      final uiState = (result as DisplayUIResult).uiState as SingleChoiceState;
      expect(uiState.choices[0].text, 'Agree');
      expect(uiState.choices[1].text, 'Disagree');
    });

    test('should route to source-yes for yes response', () async {
      final nodeData = TestFixtures.yesOrNoNode()['data'] as Map<String, dynamic>;

      await handler.process(nodeData, 'yesno_1');
      final result = await handler.handleResponse({'id': 'yes', 'text': 'Yes'}, nodeData, 'yesno_1');

      expect(result, isA<DelayedProceedResult>());
      expect((result as DelayedProceedResult).targetPort, 'source-yes');
    });

    test('should route to source-no for no response', () async {
      final nodeData = TestFixtures.yesOrNoNode()['data'] as Map<String, dynamic>;

      await handler.process(nodeData, 'yesno_1');
      final result = await handler.handleResponse({'id': 'no', 'text': 'No'}, nodeData, 'yesno_1');

      expect(result, isA<DelayedProceedResult>());
      expect((result as DelayedProceedResult).targetPort, 'source-no');
    });
  });

  group('RatingChoiceNodeHandler', () {
    late RatingChoiceNodeHandler handler;

    setUp(() {
      handler = RatingChoiceNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.ratingChoice);
    });

    test('should display 5-star rating', () async {
      final nodeData = TestFixtures.ratingChoiceNode(
        ratingType: '5',
      )['data'] as Map<String, dynamic>;

      final result = await handler.process(nodeData, 'rating_1');

      expect(result, isA<DisplayUIResult>());
      final uiState = (result as DisplayUIResult).uiState as RatingState;
      expect(uiState.ratingType, RatingType.star);
      expect(uiState.minValue, 1);
      expect(uiState.maxValue, 5);
    });

    test('should display 10-point rating', () async {
      final nodeData = TestFixtures.ratingChoiceNode(
        ratingType: '10',
      )['data'] as Map<String, dynamic>;

      final result = await handler.process(nodeData, 'rating_1');

      expect(result, isA<DisplayUIResult>());
      final uiState = (result as DisplayUIResult).uiState as RatingState;
      expect(uiState.ratingType, RatingType.number);
      expect(uiState.maxValue, 10);
    });

    test('should display smiley rating', () async {
      final nodeData = TestFixtures.ratingChoiceNode(
        ratingType: 'smiley',
      )['data'] as Map<String, dynamic>;

      final result = await handler.process(nodeData, 'rating_1');

      expect(result, isA<DisplayUIResult>());
      final uiState = (result as DisplayUIResult).uiState as RatingState;
      expect(uiState.ratingType, RatingType.smiley);
    });

    test('should route to correct port based on rating', () async {
      final nodeData = TestFixtures.ratingChoiceNode()['data'] as Map<String, dynamic>;

      await handler.process(nodeData, 'rating_1');
      final result = await handler.handleResponse(3, nodeData, 'rating_1');

      expect(result, isA<DelayedProceedResult>());
      expect((result as DelayedProceedResult).targetPort, 'source-2'); // rating 3 -> source-2 (0-indexed)
    });

    test('should handle string rating response', () async {
      final nodeData = TestFixtures.ratingChoiceNode()['data'] as Map<String, dynamic>;

      await handler.process(nodeData, 'rating_1');
      final result = await handler.handleResponse('4', nodeData, 'rating_1');

      expect(result, isA<DelayedProceedResult>());
      expect(mockState.answerVariables['rating_1']?['value'], 4);
    });
  });

  group('OpinionScaleChoiceNodeHandler', () {
    late OpinionScaleChoiceNodeHandler handler;

    setUp(() {
      handler = OpinionScaleChoiceNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.opinionScaleChoice);
    });

    test('should display opinion scale with custom range', () async {
      final nodeData = {
        'type': 'opinion-scale-choice-node',
        'from': 0,
        'to': 10,
        'answerVariable': 'nps',
      };

      final result = await handler.process(nodeData, 'nps_1');

      expect(result, isA<DisplayUIResult>());
      final uiState = (result as DisplayUIResult).uiState as RatingState;
      expect(uiState.ratingType, RatingType.opinionScale);
      expect(uiState.minValue, 0);
      expect(uiState.maxValue, 10);
    });

    test('should route to correct port based on value and from', () async {
      final nodeData = {
        'type': 'opinion-scale-choice-node',
        'from': 1,
        'to': 10,
        'answerVariable': 'nps',
      };

      await handler.process(nodeData, 'nps_1');
      final result = await handler.handleResponse(5, nodeData, 'nps_1');

      expect(result, isA<DelayedProceedResult>());
      expect((result as DelayedProceedResult).targetPort, 'source-4'); // value 5, from 1 -> port 4
    });
  });

  group('UserRatingNodeHandler (Legacy)', () {
    late UserRatingNodeHandler handler;

    setUp(() {
      handler = UserRatingNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.userRating);
    });

    test('should display 5-star rating', () async {
      final nodeData = {
        'type': 'user-rating-node',
        'answerVariable': 'rating',
      };

      final result = await handler.process(nodeData, 'rating_1');

      expect(result, isA<DisplayUIResult>());
      final uiState = (result as DisplayUIResult).uiState as RatingState;
      expect(uiState.ratingType, RatingType.star);
      expect(uiState.minValue, 1);
      expect(uiState.maxValue, 5);
    });

    test('should proceed without port (legacy behavior)', () async {
      final nodeData = {
        'type': 'user-rating-node',
        'answerVariable': 'rating',
      };

      await handler.process(nodeData, 'rating_1');
      final result = await handler.handleResponse(4, nodeData, 'rating_1');

      expect(result, isA<ProceedResult>());
      expect((result as ProceedResult).targetPort, isNull);
    });
  });

  group('ChoiceHandlers Registry', () {
    test('should return all choice handlers', () {
      final handlers = ChoiceHandlers.handlers;

      expect(handlers.length, greaterThan(0));
      expect(handlers.any((h) => h.nodeType == NodeTypes.twoChoices), true);
      expect(handlers.any((h) => h.nodeType == NodeTypes.threeChoices), true);
      expect(handlers.any((h) => h.nodeType == NodeTypes.nChoices), true);
      expect(handlers.any((h) => h.nodeType == NodeTypes.selectOption), true);
      expect(handlers.any((h) => h.nodeType == NodeTypes.nSelectOption), true);
      expect(handlers.any((h) => h.nodeType == NodeTypes.nCheckOptions), true);
      expect(handlers.any((h) => h.nodeType == NodeTypes.imageChoice), true);
      expect(handlers.any((h) => h.nodeType == NodeTypes.yesOrNoChoice), true);
      expect(handlers.any((h) => h.nodeType == NodeTypes.ratingChoice), true);
      expect(handlers.any((h) => h.nodeType == NodeTypes.opinionScaleChoice), true);
    });

    test('should get handler by type', () {
      final handler = ChoiceHandlers.getHandler(NodeTypes.twoChoices);
      expect(handler, isA<TwoChoicesNodeHandler>());
    });

    test('should return null for unknown type', () {
      final handler = ChoiceHandlers.getHandler('unknown-type');
      expect(handler, isNull);
    });
  });
}
