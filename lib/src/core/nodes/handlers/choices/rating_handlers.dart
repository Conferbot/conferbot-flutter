/// Rating choice handlers
///
/// Handlers for rating-based choices:
/// - RatingChoiceNodeHandler (star/smiley/number ratings)
/// - OpinionScaleChoiceNodeHandler (NPS-style scales)
/// - UserRatingNodeHandler (legacy 5-star rating)
library;

import '../../node_types.dart';
import '../legacy_handlers.dart';
import 'choice_ui_states.dart';

/// Handler for rating-choice-node
/// Displays rating selector (smiley, 5-star, 10-point) with port-based routing
class RatingChoiceNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.ratingChoice;

  @override
  Future<NodeResult> process(
      Map<String, dynamic> nodeData, String nodeId) async {
    final ratingTypeStr = getString(nodeData, 'ratingType', '5');
    final answerKey = getString(nodeData, 'answerVariable', nodeId);

    state?.addAnswerVariable(nodeId, answerKey);

    RatingType type;
    int min;
    int max;

    switch (ratingTypeStr.toLowerCase()) {
      case 'smiley':
        type = RatingType.smiley;
        min = 1;
        max = 5;
        break;
      case '10':
        type = RatingType.number;
        min = 1;
        max = 10;
        break;
      default:
        type = RatingType.star;
        min = 1;
        max = 5;
    }

    return DisplayUI(
      RatingState(
        questionText: null,
        ratingType: type,
        minValue: min,
        maxValue: max,
        nodeId: nodeId,
        answerKey: answerKey,
      ),
    );
  }

  @override
  Future<NodeResult> handleResponse(
    dynamic response,
    Map<String, dynamic> nodeData,
    String nodeId,
  ) async {
    int rating;
    if (response is num) {
      rating = response.toInt();
    } else if (response is String) {
      rating = int.tryParse(response) ?? 0;
    } else {
      rating = 0;
    }

    state?.setAnswerVariable(nodeId, rating);
    state?.addToTranscript('user', rating.toString());

    recordResponse(
      nodeId: nodeId,
      shape: 'user-rating-choice',
      text: rating.toString(),
      type: nodeType,
    );

    // Port is 0-indexed (rating 1 -> source-0, etc.)
    final targetPort = 'source-${rating - 1}';
    return DelayedProceed(delayMs: 600, targetPort: targetPort);
  }
}

/// Handler for opinion-scale-choice-node
/// Displays NPS-style opinion scale with port-based routing
class OpinionScaleChoiceNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.opinionScaleChoice;

  @override
  Future<NodeResult> process(
      Map<String, dynamic> nodeData, String nodeId) async {
    final from = getInt(nodeData, 'from', 1);
    final to = getInt(nodeData, 'to', 10);
    final answerKey = getString(nodeData, 'answerVariable', nodeId);

    state?.addAnswerVariable(nodeId, answerKey);

    return DisplayUI(
      RatingState(
        questionText: null,
        ratingType: RatingType.opinionScale,
        minValue: from,
        maxValue: to,
        nodeId: nodeId,
        answerKey: answerKey,
      ),
    );
  }

  @override
  Future<NodeResult> handleResponse(
    dynamic response,
    Map<String, dynamic> nodeData,
    String nodeId,
  ) async {
    int value;
    if (response is num) {
      value = response.toInt();
    } else if (response is String) {
      value = int.tryParse(response) ?? 0;
    } else {
      value = 0;
    }

    state?.setAnswerVariable(nodeId, value);
    state?.addToTranscript('user', value.toString());

    recordResponse(
      nodeId: nodeId,
      shape: 'user-opinion-scale-choice',
      text: value.toString(),
      type: nodeType,
    );

    // Calculate port index based on from value
    final from = getInt(nodeData, 'from', 1);
    final portIndex = value - from;
    return DelayedProceed(delayMs: 600, targetPort: 'source-$portIndex');
  }
}

/// Handler for user-rating-node (legacy)
/// Displays simple 5-star rating
class UserRatingNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.userRating;

  @override
  Future<NodeResult> process(
      Map<String, dynamic> nodeData, String nodeId) async {
    final answerKey = getString(nodeData, 'answerVariable', nodeId);
    state?.addAnswerVariable(nodeId, answerKey);

    return DisplayUI(
      RatingState(
        questionText: null,
        ratingType: RatingType.star,
        minValue: 1,
        maxValue: 5,
        nodeId: nodeId,
        answerKey: answerKey,
      ),
    );
  }

  @override
  Future<NodeResult> handleResponse(
    dynamic response,
    Map<String, dynamic> nodeData,
    String nodeId,
  ) async {
    int rating;
    if (response is num) {
      rating = response.toInt();
    } else if (response is String) {
      rating = int.tryParse(response) ?? 0;
    } else {
      rating = 0;
    }

    state?.setAnswerVariable(nodeId, rating);
    state?.addToTranscript('user', rating.toString());

    recordResponse(
      nodeId: nodeId,
      shape: 'user-rating-response',
      text: rating.toString(),
      type: nodeType,
    );

    return const Proceed();
  }
}
