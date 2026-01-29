/// Test fixtures for Conferbot Flutter SDK tests

/// Sample node data fixtures for testing
class TestFixtures {
  TestFixtures._();

  // ==================== MESSAGE NODES ====================

  static Map<String, dynamic> messageNode({
    String nodeId = 'msg_1',
    String text = 'Hello, welcome to our chat!',
  }) {
    return {
      'id': nodeId,
      'type': 'message-node',
      'data': {
        'type': 'message-node',
        'text': text,
        'message': text,
      },
    };
  }

  static Map<String, dynamic> imageNode({
    String nodeId = 'img_1',
    String url = 'https://example.com/image.jpg',
    String? caption,
  }) {
    return {
      'id': nodeId,
      'type': 'image-node',
      'data': {
        'type': 'image-node',
        'image': url,
        'caption': caption,
      },
    };
  }

  static Map<String, dynamic> videoNode({
    String nodeId = 'vid_1',
    String url = 'https://example.com/video.mp4',
    String? caption,
  }) {
    return {
      'id': nodeId,
      'type': 'video-node',
      'data': {
        'type': 'video-node',
        'video': url,
        'caption': caption,
      },
    };
  }

  // ==================== ASK QUESTION NODES ====================

  static Map<String, dynamic> askNameNode({
    String nodeId = 'ask_name_1',
    String questionText = 'What is your name?',
    String answerVariable = 'name',
    String? nameGreet,
  }) {
    return {
      'id': nodeId,
      'type': 'ask-name-node',
      'data': {
        'type': 'ask-name-node',
        'questionText': questionText,
        'answerVariable': answerVariable,
        if (nameGreet != null) 'nameGreetResponse': nameGreet,
      },
    };
  }

  static Map<String, dynamic> askEmailNode({
    String nodeId = 'ask_email_1',
    String questionText = 'What is your email?',
    String answerVariable = 'email',
    String errorMessage = 'Please enter a valid email address',
  }) {
    return {
      'id': nodeId,
      'type': 'ask-email-node',
      'data': {
        'type': 'ask-email-node',
        'questionText': questionText,
        'answerVariable': answerVariable,
        'incorrectEmailResponse': errorMessage,
      },
    };
  }

  static Map<String, dynamic> askPhoneNode({
    String nodeId = 'ask_phone_1',
    String questionText = 'What is your phone number?',
    String answerVariable = 'phone',
    String errorMessage = 'Please enter a valid phone number',
  }) {
    return {
      'id': nodeId,
      'type': 'ask-phone-number-node',
      'data': {
        'type': 'ask-phone-number-node',
        'questionText': questionText,
        'answerVariable': answerVariable,
        'incorrectPhoneNumberResponse': errorMessage,
      },
    };
  }

  static Map<String, dynamic> askNumberNode({
    String nodeId = 'ask_number_1',
    String questionText = 'Enter a number',
    String answerVariable = 'number',
  }) {
    return {
      'id': nodeId,
      'type': 'ask-number-node',
      'data': {
        'type': 'ask-number-node',
        'questionText': questionText,
        'answerVariable': answerVariable,
      },
    };
  }

  static Map<String, dynamic> askUrlNode({
    String nodeId = 'ask_url_1',
    String questionText = 'Enter a URL',
    String answerVariable = 'url',
  }) {
    return {
      'id': nodeId,
      'type': 'ask-url-node',
      'data': {
        'type': 'ask-url-node',
        'questionText': questionText,
        'answerVariable': answerVariable,
      },
    };
  }

  static Map<String, dynamic> askCustomNode({
    String nodeId = 'ask_custom_1',
    String questionText = 'Please answer',
    String answerVariable = 'custom_answer',
  }) {
    return {
      'id': nodeId,
      'type': 'ask-custom-question-node',
      'data': {
        'type': 'ask-custom-question-node',
        'questionText': questionText,
        'answerVariable': answerVariable,
      },
    };
  }

  // ==================== CHOICE NODES ====================

  static Map<String, dynamic> twoChoicesNode({
    String nodeId = 'choice_2_1',
    String choice1 = 'Option A',
    String choice2 = 'Option B',
    String answerVariable = 'choice',
    bool disableSecond = false,
  }) {
    return {
      'id': nodeId,
      'type': 'two-choices-node',
      'data': {
        'type': 'two-choices-node',
        'choice1': choice1,
        'choice2': choice2,
        'answerVariable': answerVariable,
        'disableSecondChoice': disableSecond,
      },
    };
  }

  static Map<String, dynamic> threeChoicesNode({
    String nodeId = 'choice_3_1',
    String choice1 = 'Option A',
    String choice2 = 'Option B',
    String choice3 = 'Option C',
    String answerVariable = 'choice',
  }) {
    return {
      'id': nodeId,
      'type': 'three-choices-node',
      'data': {
        'type': 'three-choices-node',
        'choice1': choice1,
        'choice2': choice2,
        'choice3': choice3,
        'answerVariable': answerVariable,
      },
    };
  }

  static Map<String, dynamic> nChoicesNode({
    String nodeId = 'choice_n_1',
    List<Map<String, dynamic>>? choices,
    String answerVariable = 'choice',
  }) {
    return {
      'id': nodeId,
      'type': 'n-choices-node',
      'data': {
        'type': 'n-choices-node',
        'choices': choices ??
            [
              {'id': '0', 'choiceText': 'First Option'},
              {'id': '1', 'choiceText': 'Second Option'},
              {'id': '2', 'choiceText': 'Third Option'},
            ],
        'answerVariable': answerVariable,
      },
    };
  }

  static Map<String, dynamic> yesOrNoNode({
    String nodeId = 'yes_no_1',
    String answerVariable = 'response',
  }) {
    return {
      'id': nodeId,
      'type': 'yes-or-no-choice-node',
      'data': {
        'type': 'yes-or-no-choice-node',
        'answerVariable': answerVariable,
        'options': [
          {'id': 'yes', 'label': 'Yes'},
          {'id': 'no', 'label': 'No'},
        ],
      },
    };
  }

  static Map<String, dynamic> ratingChoiceNode({
    String nodeId = 'rating_1',
    String ratingType = '5',
    String answerVariable = 'rating',
  }) {
    return {
      'id': nodeId,
      'type': 'rating-choice-node',
      'data': {
        'type': 'rating-choice-node',
        'ratingType': ratingType,
        'answerVariable': answerVariable,
      },
    };
  }

  // ==================== LOGIC NODES ====================

  static Map<String, dynamic> conditionNode({
    String nodeId = 'condition_1',
    String leftValue = '{{score}}',
    String rightValue = '50',
    String operator = '>',
    bool isNumber = true,
  }) {
    return {
      'id': nodeId,
      'type': 'condition-node',
      'data': {
        'type': 'condition-node',
        'leftValue': leftValue,
        'rightValue': rightValue,
        'operator': operator,
        'isNumber': isNumber,
      },
    };
  }

  static Map<String, dynamic> booleanLogicNode({
    String nodeId = 'boolean_1',
    String leftValue = 'true',
    String rightValue = 'true',
    String operator = 'AND',
  }) {
    return {
      'id': nodeId,
      'type': 'boolean-logic-node',
      'data': {
        'type': 'boolean-logic-node',
        'leftValue': leftValue,
        'rightValue': rightValue,
        'operator': operator,
      },
    };
  }

  static Map<String, dynamic> mathOperationNode({
    String nodeId = 'math_1',
    String leftValue = '10',
    String rightValue = '5',
    String operator = '+',
  }) {
    return {
      'id': nodeId,
      'type': 'math-operation-node',
      'data': {
        'type': 'math-operation-node',
        'leftValue': leftValue,
        'rightValue': rightValue,
        'operator': operator,
      },
    };
  }

  static Map<String, dynamic> variableNode({
    String nodeId = 'var_1',
    String name = 'myVar',
    dynamic value = 'test_value',
    bool isNumber = false,
    bool customNameValue = false,
  }) {
    return {
      'id': nodeId,
      'type': 'variable-node',
      'data': {
        'type': 'variable-node',
        'name': name,
        'value': value,
        'isNumber': isNumber,
        'customNameValue': customNameValue,
      },
    };
  }

  static Map<String, dynamic> jumpToNode({
    String nodeId = 'jump_1',
    String targetNodeId = 'target_node',
  }) {
    return {
      'id': nodeId,
      'type': 'jump-to-node',
      'data': {
        'type': 'jump-to-node',
        'targetNodeId': targetNodeId,
      },
    };
  }

  static Map<String, dynamic> randomFlowNode({
    String nodeId = 'random_1',
    List<Map<String, dynamic>>? branches,
  }) {
    return {
      'id': nodeId,
      'type': 'random-flow-node',
      'data': {
        'type': 'random-flow-node',
        'branches': branches ??
            [
              {'id': '0', 'weight': 50},
              {'id': '1', 'weight': 50},
            ],
      },
    };
  }

  // ==================== SPECIAL NODES ====================

  static Map<String, dynamic> delayNode({
    String nodeId = 'delay_1',
    int delay = 2,
  }) {
    return {
      'id': nodeId,
      'type': 'delay-node',
      'data': {
        'type': 'delay-node',
        'delay': delay,
      },
    };
  }

  static Map<String, dynamic> humanHandoverNode({
    String nodeId = 'handover_1',
    String handoverMessage = 'Connecting you to an agent...',
    bool enablePreChatQuestions = false,
    List<Map<String, dynamic>>? preChatQuestions,
  }) {
    return {
      'id': nodeId,
      'type': 'human-handover-node',
      'data': {
        'type': 'human-handover-node',
        'handoverMessage': handoverMessage,
        'enablePreChatQuestions': enablePreChatQuestions,
        'preChatQuestions': preChatQuestions ?? [],
        'maxWaitTime': 5,
      },
    };
  }

  // ==================== INTEGRATION NODES ====================

  static Map<String, dynamic> webhookNode({
    String nodeId = 'webhook_1',
    String url = 'https://example.com/webhook',
    String method = 'POST',
  }) {
    return {
      'id': nodeId,
      'type': 'webhook-node',
      'data': {
        'type': 'webhook-node',
        'url': url,
        'method': method,
        'headers': {},
      },
    };
  }

  static Map<String, dynamic> emailNode({
    String nodeId = 'email_1',
    String to = 'test@example.com',
    String subject = 'Test Email',
  }) {
    return {
      'id': nodeId,
      'type': 'email-node',
      'data': {
        'type': 'email-node',
        'to': to,
        'subject': subject,
      },
    };
  }

  // ==================== FLOW FIXTURES ====================

  /// Simple flow with message and question
  static List<Map<String, dynamic>> simpleFlow() {
    return [
      messageNode(nodeId: 'step_1', text: 'Welcome!'),
      askNameNode(nodeId: 'step_2'),
      messageNode(nodeId: 'step_3', text: 'Thank you!'),
    ];
  }

  /// Simple edges for flow
  static List<Map<String, dynamic>> simpleEdges() {
    return [
      {'id': 'edge_1', 'source': 'step_1', 'target': 'step_2'},
      {'id': 'edge_2', 'source': 'step_2', 'target': 'step_3'},
    ];
  }

  /// Branching flow with two choices
  static List<Map<String, dynamic>> branchingFlow() {
    return [
      messageNode(nodeId: 'step_1', text: 'Choose an option:'),
      twoChoicesNode(nodeId: 'step_2', choice1: 'Option A', choice2: 'Option B'),
      messageNode(nodeId: 'step_3a', text: 'You chose A!'),
      messageNode(nodeId: 'step_3b', text: 'You chose B!'),
    ];
  }

  /// Edges for branching flow
  static List<Map<String, dynamic>> branchingEdges() {
    return [
      {'id': 'edge_1', 'source': 'step_1', 'target': 'step_2'},
      {'id': 'edge_2', 'source': 'step_2', 'sourceHandle': 'source-1', 'target': 'step_3a'},
      {'id': 'edge_3', 'source': 'step_2', 'sourceHandle': 'source-2', 'target': 'step_3b'},
    ];
  }

  /// Flow with condition
  static List<Map<String, dynamic>> conditionFlow() {
    return [
      askNumberNode(nodeId: 'step_1', questionText: 'Enter a number'),
      conditionNode(
        nodeId: 'step_2',
        leftValue: '{{number}}',
        rightValue: '50',
        operator: '>',
        isNumber: true,
      ),
      messageNode(nodeId: 'step_3a', text: 'Number is greater than 50'),
      messageNode(nodeId: 'step_3b', text: 'Number is 50 or less'),
    ];
  }
}
