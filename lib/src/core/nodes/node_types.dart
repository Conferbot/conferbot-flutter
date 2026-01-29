/// All 51 node types supported by Conferbot
/// Organized by category matching the web widget
class NodeTypes {
  NodeTypes._();

  // ==================== DISPLAY NODES (28 types) ====================

  // Legacy nodes (v1)
  static const String twoChoices = 'two-choices-node';
  static const String threeChoices = 'three-choices-node';
  static const String selectOption = 'select-option-node';
  static const String userRating = 'user-rating-node';
  static const String quiz = 'quiz-node';
  static const String userInput = 'user-input-node';
  static const String userRange = 'user-range-node';

  // Send response nodes (v2)
  static const String message = 'message-node';
  static const String image = 'image-node';
  static const String video = 'video-node';
  static const String audio = 'audio-node';
  static const String file = 'file-node';

  // Ask question nodes (v2)
  static const String askName = 'ask-name-node';
  static const String askEmail = 'ask-email-node';
  static const String askPhone = 'ask-phone-number-node';
  static const String askNumber = 'ask-number-node';
  static const String askUrl = 'ask-url-node';
  static const String askFile = 'ask-file-node';
  static const String askLocation = 'ask-location-node';
  static const String askCustom = 'ask-custom-question-node';
  static const String askMultiple = 'ask-multiple-questions-node';
  static const String calendar = 'calendar-node';
  static const String nSelectOption = 'n-select-option-node';
  static const String nCheckOptions = 'n-check-options-node';

  // Flow operation nodes (v2)
  static const String nChoices = 'n-choices-node';
  static const String imageChoice = 'image-choice-node';
  static const String ratingChoice = 'rating-choice-node';
  static const String yesOrNoChoice = 'yes-or-no-choice-node';
  static const String opinionScaleChoice = 'opinion-scale-choice-node';

  // Special display nodes (v2)
  static const String userRedirect = 'user-redirect-node';
  static const String html = 'html-node';
  static const String navigate = 'navigate-node';

  // ==================== LOGIC NODES (7 types) ====================

  static const String condition = 'condition-node';
  static const String booleanLogic = 'boolean-logic-node';
  static const String randomFlow = 'random-flow-node';
  static const String mathOperation = 'math-operation-node';
  static const String variable = 'variable-node';
  static const String jumpTo = 'jump-to-node';
  static const String businessHours = 'business-hours-node';

  // ==================== INTEGRATION NODES (17 types) ====================

  static const String email = 'email-node';
  static const String webhook = 'webhook-node';
  static const String gpt = 'gpt-node';
  static const String zapier = 'zapier-node';
  static const String googleSheets = 'google-sheets-node';
  static const String gmail = 'gmail-node';
  static const String googleCalendar = 'google-calendar-node';
  static const String googleMeet = 'google-meet-node';
  static const String googleDrive = 'google-drive-node';
  static const String googleDocs = 'google-docs-node';
  static const String slack = 'slack-node';
  static const String discord = 'discord-node';
  static const String airtable = 'airtable-node';
  static const String hubspot = 'hubspot-node';
  static const String notion = 'notion-node';
  static const String zohoCrm = 'zohocrm-node';
  static const String stripe = 'stripe-node';

  // ==================== SPECIAL FLOW NODES (2 types) ====================

  static const String delay = 'delay-node';
  static const String humanHandover = 'human-handover-node';

  // ==================== CATEGORY LISTS ====================

  static const List<String> displayNodes = [
    twoChoices,
    threeChoices,
    selectOption,
    userRating,
    quiz,
    userInput,
    userRange,
    message,
    image,
    video,
    audio,
    file,
    askName,
    askEmail,
    askPhone,
    askNumber,
    askUrl,
    askFile,
    askLocation,
    askCustom,
    askMultiple,
    calendar,
    nSelectOption,
    nCheckOptions,
    nChoices,
    imageChoice,
    ratingChoice,
    yesOrNoChoice,
    opinionScaleChoice,
    userRedirect,
    html,
    navigate,
  ];

  static const List<String> logicNodes = [
    condition,
    booleanLogic,
    randomFlow,
    mathOperation,
    variable,
    jumpTo,
    businessHours,
  ];

  static const List<String> integrationNodes = [
    email,
    webhook,
    gpt,
    zapier,
    googleSheets,
    gmail,
    googleCalendar,
    googleMeet,
    googleDrive,
    googleDocs,
    slack,
    discord,
    airtable,
    hubspot,
    notion,
    zohoCrm,
    stripe,
  ];

  static const List<String> specialFlowNodes = [
    delay,
    humanHandover,
  ];

  static List<String> get allNodes => [
        ...displayNodes,
        ...logicNodes,
        ...integrationNodes,
        ...specialFlowNodes,
      ];

  // ==================== CATEGORY HELPERS ====================

  /// Check if type is a display node
  static bool isDisplayNode(String type) => displayNodes.contains(type);

  /// Check if type is a logic node
  static bool isLogicNode(String type) => logicNodes.contains(type);

  /// Check if type is an integration node
  static bool isIntegrationNode(String type) => integrationNodes.contains(type);

  /// Check if type is a special flow node
  static bool isSpecialFlowNode(String type) => specialFlowNodes.contains(type);

  /// Check if node requires user input/interaction
  static bool requiresUserInteraction(String type) {
    switch (type) {
      // Ask question nodes
      case askName:
      case askEmail:
      case askPhone:
      case askNumber:
      case askUrl:
      case askFile:
      case askLocation:
      case askCustom:
      case askMultiple:
        return true;
      // Choice nodes
      case twoChoices:
      case threeChoices:
      case nChoices:
      case selectOption:
      case nSelectOption:
      case nCheckOptions:
      case imageChoice:
      case ratingChoice:
      case yesOrNoChoice:
      case opinionScaleChoice:
        return true;
      // Rating/Quiz
      case userRating:
      case quiz:
      case userInput:
      case userRange:
        return true;
      // Calendar
      case calendar:
        return true;
      // Human handover pre-chat questions
      case humanHandover:
        return true;
      // Everything else auto-proceeds
      default:
        return false;
    }
  }

  /// Check if node type captures user metadata
  static bool capturesMetadata(String type) {
    return type == askName || type == askEmail || type == askPhone;
  }

  /// Check if node is a message display (no interaction)
  static bool isMessageOnly(String type) {
    return type == message ||
        type == image ||
        type == video ||
        type == audio ||
        type == file ||
        type == html;
  }

  /// Get the category name for a node type
  static String? getCategoryName(String type) {
    if (isDisplayNode(type)) return 'display';
    if (isLogicNode(type)) return 'logic';
    if (isIntegrationNode(type)) return 'integration';
    if (isSpecialFlowNode(type)) return 'special_flow';
    return null;
  }

  /// Check if a node type is valid/supported
  static bool isValidNodeType(String type) => allNodes.contains(type);
}
