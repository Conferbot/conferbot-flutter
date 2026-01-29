import 'dart:convert';

/// Represents a single node visit in the chatbot flow
class NodeVisit {
  final String nodeId;
  final String nodeType;
  final String? nodeName;
  final DateTime enteredAt;
  DateTime? exitedAt;
  String? exitType;
  dynamic userInput;
  String? selectedOption;

  NodeVisit({
    required this.nodeId,
    required this.nodeType,
    this.nodeName,
    DateTime? enteredAt,
    this.exitedAt,
    this.exitType,
    this.userInput,
    this.selectedOption,
  }) : enteredAt = enteredAt ?? DateTime.now();

  /// Duration spent on this node
  Duration get duration {
    final end = exitedAt ?? DateTime.now();
    return end.difference(enteredAt);
  }

  /// Dwell time in seconds
  int get dwellTimeSeconds => duration.inSeconds;

  NodeVisit copyWith({
    String? nodeId,
    String? nodeType,
    String? nodeName,
    DateTime? enteredAt,
    DateTime? exitedAt,
    String? exitType,
    dynamic userInput,
    String? selectedOption,
  }) {
    return NodeVisit(
      nodeId: nodeId ?? this.nodeId,
      nodeType: nodeType ?? this.nodeType,
      nodeName: nodeName ?? this.nodeName,
      enteredAt: enteredAt ?? this.enteredAt,
      exitedAt: exitedAt ?? this.exitedAt,
      exitType: exitType ?? this.exitType,
      userInput: userInput ?? this.userInput,
      selectedOption: selectedOption ?? this.selectedOption,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nodeId': nodeId,
      'nodeType': nodeType,
      'nodeName': nodeName,
      'enteredAt': enteredAt.millisecondsSinceEpoch,
      'exitedAt': exitedAt?.millisecondsSinceEpoch,
      'exitType': exitType,
      'dwellTime': dwellTimeSeconds,
      'userInput': userInput,
      'selectedOption': selectedOption,
    };
  }

  factory NodeVisit.fromJson(Map<String, dynamic> json) {
    return NodeVisit(
      nodeId: json['nodeId'] as String,
      nodeType: json['nodeType'] as String,
      nodeName: json['nodeName'] as String?,
      enteredAt: DateTime.fromMillisecondsSinceEpoch(json['enteredAt'] as int),
      exitedAt: json['exitedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['exitedAt'] as int)
          : null,
      exitType: json['exitType'] as String?,
      userInput: json['userInput'],
      selectedOption: json['selectedOption'] as String?,
    );
  }
}

/// Exit type for node visits
class NodeExitType {
  static const String proceeded = 'proceeded';
  static const String abandoned = 'abandoned';
  static const String backPressed = 'back_pressed';
  static const String skipped = 'skipped';
  static const String timeout = 'timeout';
  static const String error = 'error';
}

/// Session metrics for analytics
class SessionMetrics {
  final int startedAt;
  int? firstMessageAt;
  int? lastMessageAt;
  int totalDuration;
  int activeDuration;
  int idleTime;

  SessionMetrics({
    int? startedAt,
    this.firstMessageAt,
    this.lastMessageAt,
    this.totalDuration = 0,
    this.activeDuration = 0,
    this.idleTime = 0,
  }) : startedAt = startedAt ?? DateTime.now().millisecondsSinceEpoch;

  SessionMetrics copyWith({
    int? startedAt,
    int? firstMessageAt,
    int? lastMessageAt,
    int? totalDuration,
    int? activeDuration,
    int? idleTime,
  }) {
    return SessionMetrics(
      startedAt: startedAt ?? this.startedAt,
      firstMessageAt: firstMessageAt ?? this.firstMessageAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      totalDuration: totalDuration ?? this.totalDuration,
      activeDuration: activeDuration ?? this.activeDuration,
      idleTime: idleTime ?? this.idleTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'startedAt': startedAt,
      'firstMessageAt': firstMessageAt,
      'lastMessageAt': lastMessageAt,
      'totalDuration': totalDuration,
      'activeDuration': activeDuration,
      'idleTime': idleTime,
    };
  }

  factory SessionMetrics.fromJson(Map<String, dynamic> json) {
    return SessionMetrics(
      startedAt: json['startedAt'] as int?,
      firstMessageAt: json['firstMessageAt'] as int?,
      lastMessageAt: json['lastMessageAt'] as int?,
      totalDuration: json['totalDuration'] as int? ?? 0,
      activeDuration: json['activeDuration'] as int? ?? 0,
      idleTime: json['idleTime'] as int? ?? 0,
    );
  }
}

/// Typing behavior analytics
class TypingBehavior {
  int totalTypingTimeMs;
  int deletions;
  int abandonedMessages;
  int messageCount;
  int totalMessageLength;

  TypingBehavior({
    this.totalTypingTimeMs = 0,
    this.deletions = 0,
    this.abandonedMessages = 0,
    this.messageCount = 0,
    this.totalMessageLength = 0,
  });

  /// Average message length
  double get avgMessageLength {
    if (messageCount == 0) return 0;
    return totalMessageLength / messageCount;
  }

  TypingBehavior copyWith({
    int? totalTypingTimeMs,
    int? deletions,
    int? abandonedMessages,
    int? messageCount,
    int? totalMessageLength,
  }) {
    return TypingBehavior(
      totalTypingTimeMs: totalTypingTimeMs ?? this.totalTypingTimeMs,
      deletions: deletions ?? this.deletions,
      abandonedMessages: abandonedMessages ?? this.abandonedMessages,
      messageCount: messageCount ?? this.messageCount,
      totalMessageLength: totalMessageLength ?? this.totalMessageLength,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalTypingTime': (totalTypingTimeMs / 1000).floor(),
      'deletions': deletions,
      'abandonedMessages': abandonedMessages,
      'avgMessageLength': avgMessageLength.floor(),
    };
  }

  factory TypingBehavior.fromJson(Map<String, dynamic> json) {
    return TypingBehavior(
      totalTypingTimeMs: ((json['totalTypingTime'] as int?) ?? 0) * 1000,
      deletions: json['deletions'] as int? ?? 0,
      abandonedMessages: json['abandonedMessages'] as int? ?? 0,
      messageCount: 0,
      totalMessageLength: 0,
    );
  }
}

/// Message counts by sender type
class MessageCounts {
  int botMessages;
  int userMessages;
  int agentMessages;
  int systemMessages;

  MessageCounts({
    this.botMessages = 0,
    this.userMessages = 0,
    this.agentMessages = 0,
    this.systemMessages = 0,
  });

  int get total => botMessages + userMessages + agentMessages + systemMessages;

  Map<String, dynamic> toJson() {
    return {
      'bot': botMessages,
      'user': userMessages,
      'agent': agentMessages,
      'system': systemMessages,
      'total': total,
    };
  }

  factory MessageCounts.fromJson(Map<String, dynamic> json) {
    return MessageCounts(
      botMessages: json['bot'] as int? ?? 0,
      userMessages: json['user'] as int? ?? 0,
      agentMessages: json['agent'] as int? ?? 0,
      systemMessages: json['system'] as int? ?? 0,
    );
  }
}

/// Interaction tracking (links, buttons, files, etc.)
class InteractionEvent {
  final String type;
  final String? nodeId;
  final DateTime timestamp;
  final Map<String, dynamic> data;

  InteractionEvent({
    required this.type,
    this.nodeId,
    DateTime? timestamp,
    Map<String, dynamic>? data,
  })  : timestamp = timestamp ?? DateTime.now(),
        data = data ?? {};

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'nodeId': nodeId,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'data': data,
    };
  }

  factory InteractionEvent.fromJson(Map<String, dynamic> json) {
    return InteractionEvent(
      type: json['type'] as String,
      nodeId: json['nodeId'] as String?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      data: Map<String, dynamic>.from(json['data'] as Map? ?? {}),
    );
  }
}

/// Interaction event types
class InteractionType {
  static const String linkClicked = 'linksClicked';
  static const String buttonClicked = 'buttonsClicked';
  static const String fileUploaded = 'filesUploaded';
  static const String imageViewed = 'imagesViewed';
  static const String videoWatched = 'videosWatched';
  static const String carouselInteraction = 'carouselInteractions';
  static const String calendarSlotSelected = 'calendarSlotSelected';
  static const String ratingSubmitted = 'ratingSubmitted';
}

/// Environment/device information
class EnvironmentInfo {
  final String deviceType;
  final String platform;
  final String? osVersion;
  final String? appVersion;
  final String screenResolution;
  final String language;
  final String timezone;

  EnvironmentInfo({
    required this.deviceType,
    required this.platform,
    this.osVersion,
    this.appVersion,
    required this.screenResolution,
    required this.language,
    required this.timezone,
  });

  Map<String, dynamic> toJson() {
    return {
      'deviceType': deviceType,
      'platform': platform,
      'osVersion': osVersion,
      'appVersion': appVersion,
      'screenResolution': screenResolution,
      'language': language,
      'timezone': timezone,
    };
  }

  factory EnvironmentInfo.fromJson(Map<String, dynamic> json) {
    return EnvironmentInfo(
      deviceType: json['deviceType'] as String? ?? 'unknown',
      platform: json['platform'] as String? ?? 'unknown',
      osVersion: json['osVersion'] as String?,
      appVersion: json['appVersion'] as String?,
      screenResolution: json['screenResolution'] as String? ?? 'unknown',
      language: json['language'] as String? ?? 'en',
      timezone: json['timezone'] as String? ?? 'UTC',
    );
  }
}

/// Attribution data for session tracking
class AttributionData {
  final String? entryPage;
  final String? referrer;
  final String? utmSource;
  final String? utmMedium;
  final String? utmCampaign;
  final String? utmTerm;
  final String? utmContent;
  final String? landingPage;
  final String? deepLink;

  AttributionData({
    this.entryPage,
    this.referrer,
    this.utmSource,
    this.utmMedium,
    this.utmCampaign,
    this.utmTerm,
    this.utmContent,
    this.landingPage,
    this.deepLink,
  });

  Map<String, dynamic> toJson() {
    return {
      'entryPage': entryPage,
      'referrer': referrer,
      'utmSource': utmSource,
      'utmMedium': utmMedium,
      'utmCampaign': utmCampaign,
      'utmTerm': utmTerm,
      'utmContent': utmContent,
      'landingPage': landingPage,
      'deepLink': deepLink,
    };
  }

  factory AttributionData.fromJson(Map<String, dynamic> json) {
    return AttributionData(
      entryPage: json['entryPage'] as String?,
      referrer: json['referrer'] as String?,
      utmSource: json['utmSource'] as String?,
      utmMedium: json['utmMedium'] as String?,
      utmCampaign: json['utmCampaign'] as String?,
      utmTerm: json['utmTerm'] as String?,
      utmContent: json['utmContent'] as String?,
      landingPage: json['landingPage'] as String?,
      deepLink: json['deepLink'] as String?,
    );
  }
}

/// Goal completion tracking
class GoalCompletion {
  final String goalId;
  final String? conversionEvent;
  final double? conversionValue;
  final DateTime completedAt;

  GoalCompletion({
    required this.goalId,
    this.conversionEvent,
    this.conversionValue,
    DateTime? completedAt,
  }) : completedAt = completedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'goalId': goalId,
      'conversionEvent': conversionEvent,
      'conversionValue': conversionValue,
      'completedAt': completedAt.millisecondsSinceEpoch,
    };
  }

  factory GoalCompletion.fromJson(Map<String, dynamic> json) {
    return GoalCompletion(
      goalId: json['goalId'] as String,
      conversionEvent: json['conversionEvent'] as String?,
      conversionValue: (json['conversionValue'] as num?)?.toDouble(),
      completedAt: DateTime.fromMillisecondsSinceEpoch(json['completedAt'] as int),
    );
  }
}

/// Chat rating data
class ChatRating {
  final int? csatScore;
  final String? feedback;
  final bool? thumbsUp;
  final int? npsScore;
  final String source;
  final DateTime submittedAt;

  ChatRating({
    this.csatScore,
    this.feedback,
    this.thumbsUp,
    this.npsScore,
    this.source = 'post_chat_survey',
    DateTime? submittedAt,
  }) : submittedAt = submittedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'csatScore': csatScore,
      'feedback': feedback,
      'thumbsUp': thumbsUp,
      'npsScore': npsScore,
      'source': source,
      'submittedAt': submittedAt.millisecondsSinceEpoch,
    };
  }

  factory ChatRating.fromJson(Map<String, dynamic> json) {
    return ChatRating(
      csatScore: json['csatScore'] as int?,
      feedback: json['feedback'] as String?,
      thumbsUp: json['thumbsUp'] as bool?,
      npsScore: json['npsScore'] as int?,
      source: json['source'] as String? ?? 'post_chat_survey',
      submittedAt: DateTime.fromMillisecondsSinceEpoch(
        json['submittedAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

/// Comprehensive chat analytics for a session
class ChatAnalytics {
  final String sessionId;
  final String visitorId;
  final String botId;
  final String? workspaceId;
  final DateTime sessionStart;
  DateTime? sessionEnd;

  // Metrics
  SessionMetrics sessionMetrics;
  MessageCounts messageCounts;
  TypingBehavior typingBehavior;

  // Node tracking
  final List<NodeVisit> nodeVisitHistory;
  NodeVisit? currentNode;
  final Map<String, int> nodeTypeCount;

  // Interactions
  final List<InteractionEvent> interactions;

  // Goals
  final List<GoalCompletion> goalCompletions;

  // Rating
  ChatRating? rating;

  // Environment
  EnvironmentInfo? environment;

  // Attribution
  AttributionData? attribution;

  // Activity tracking
  int lastActivityTime;
  int totalIdleTime;

  // State flags
  bool isActive;
  bool isFinalized;

  ChatAnalytics({
    required this.sessionId,
    required this.visitorId,
    required this.botId,
    this.workspaceId,
    DateTime? sessionStart,
    this.sessionEnd,
    SessionMetrics? sessionMetrics,
    MessageCounts? messageCounts,
    TypingBehavior? typingBehavior,
    List<NodeVisit>? nodeVisitHistory,
    this.currentNode,
    Map<String, int>? nodeTypeCount,
    List<InteractionEvent>? interactions,
    List<GoalCompletion>? goalCompletions,
    this.rating,
    this.environment,
    this.attribution,
    int? lastActivityTime,
    this.totalIdleTime = 0,
    this.isActive = true,
    this.isFinalized = false,
  })  : sessionStart = sessionStart ?? DateTime.now(),
        sessionMetrics = sessionMetrics ?? SessionMetrics(),
        messageCounts = messageCounts ?? MessageCounts(),
        typingBehavior = typingBehavior ?? TypingBehavior(),
        nodeVisitHistory = nodeVisitHistory ?? [],
        nodeTypeCount = nodeTypeCount ?? {},
        interactions = interactions ?? [],
        goalCompletions = goalCompletions ?? [],
        lastActivityTime = lastActivityTime ?? DateTime.now().millisecondsSinceEpoch;

  /// Total duration of the session in seconds
  int get totalDurationSeconds {
    final end = sessionEnd ?? DateTime.now();
    return end.difference(sessionStart).inSeconds;
  }

  /// Active duration (excluding idle time) in seconds
  int get activeDurationSeconds {
    return totalDurationSeconds - (totalIdleTime ~/ 1000);
  }

  /// Total number of nodes visited
  int get totalNodesVisited => nodeVisitHistory.length;

  /// Convert to JSON for storage/transmission
  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'visitorId': visitorId,
      'botId': botId,
      'workspaceId': workspaceId,
      'sessionStart': sessionStart.millisecondsSinceEpoch,
      'sessionEnd': sessionEnd?.millisecondsSinceEpoch,
      'sessionMetrics': sessionMetrics.toJson(),
      'messageCounts': messageCounts.toJson(),
      'typingBehavior': typingBehavior.toJson(),
      'nodeVisitHistory': nodeVisitHistory.map((n) => n.toJson()).toList(),
      'currentNode': currentNode?.toJson(),
      'nodeTypeCount': nodeTypeCount,
      'interactions': interactions.map((i) => i.toJson()).toList(),
      'goalCompletions': goalCompletions.map((g) => g.toJson()).toList(),
      'rating': rating?.toJson(),
      'environment': environment?.toJson(),
      'attribution': attribution?.toJson(),
      'lastActivityTime': lastActivityTime,
      'totalIdleTime': totalIdleTime,
      'isActive': isActive,
      'isFinalized': isFinalized,
    };
  }

  /// Create from JSON
  factory ChatAnalytics.fromJson(Map<String, dynamic> json) {
    return ChatAnalytics(
      sessionId: json['sessionId'] as String,
      visitorId: json['visitorId'] as String,
      botId: json['botId'] as String,
      workspaceId: json['workspaceId'] as String?,
      sessionStart: DateTime.fromMillisecondsSinceEpoch(json['sessionStart'] as int),
      sessionEnd: json['sessionEnd'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['sessionEnd'] as int)
          : null,
      sessionMetrics: SessionMetrics.fromJson(
        json['sessionMetrics'] as Map<String, dynamic>? ?? {},
      ),
      messageCounts: MessageCounts.fromJson(
        json['messageCounts'] as Map<String, dynamic>? ?? {},
      ),
      typingBehavior: TypingBehavior.fromJson(
        json['typingBehavior'] as Map<String, dynamic>? ?? {},
      ),
      nodeVisitHistory: (json['nodeVisitHistory'] as List<dynamic>?)
              ?.map((n) => NodeVisit.fromJson(n as Map<String, dynamic>))
              .toList() ??
          [],
      currentNode: json['currentNode'] != null
          ? NodeVisit.fromJson(json['currentNode'] as Map<String, dynamic>)
          : null,
      nodeTypeCount: Map<String, int>.from(json['nodeTypeCount'] as Map? ?? {}),
      interactions: (json['interactions'] as List<dynamic>?)
              ?.map((i) => InteractionEvent.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [],
      goalCompletions: (json['goalCompletions'] as List<dynamic>?)
              ?.map((g) => GoalCompletion.fromJson(g as Map<String, dynamic>))
              .toList() ??
          [],
      rating: json['rating'] != null
          ? ChatRating.fromJson(json['rating'] as Map<String, dynamic>)
          : null,
      environment: json['environment'] != null
          ? EnvironmentInfo.fromJson(json['environment'] as Map<String, dynamic>)
          : null,
      attribution: json['attribution'] != null
          ? AttributionData.fromJson(json['attribution'] as Map<String, dynamic>)
          : null,
      lastActivityTime: json['lastActivityTime'] as int?,
      totalIdleTime: json['totalIdleTime'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? false,
      isFinalized: json['isFinalized'] as bool? ?? false,
    );
  }

  /// Serialize for local storage
  String toStorageString() {
    return jsonEncode(toJson());
  }

  /// Deserialize from local storage
  static ChatAnalytics fromStorageString(String data) {
    return ChatAnalytics.fromJson(jsonDecode(data) as Map<String, dynamic>);
  }
}

/// Analytics event for queuing
class AnalyticsEvent {
  final String type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final String sessionId;
  bool isSent;

  AnalyticsEvent({
    required this.type,
    required this.data,
    required this.sessionId,
    DateTime? timestamp,
    this.isSent = false,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'data': data,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'sessionId': sessionId,
      'isSent': isSent,
    };
  }

  factory AnalyticsEvent.fromJson(Map<String, dynamic> json) {
    return AnalyticsEvent(
      type: json['type'] as String,
      data: Map<String, dynamic>.from(json['data'] as Map),
      sessionId: json['sessionId'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      isSent: json['isSent'] as bool? ?? false,
    );
  }
}

/// Analytics event types for socket emission
class AnalyticsEventType {
  static const String chatStart = 'track-chat-start';
  static const String nodeVisit = 'track-node-visit';
  static const String nodeExit = 'track-node-exit';
  static const String sentiment = 'track-sentiment';
  static const String interaction = 'track-interaction';
  static const String goalCompletion = 'track-goal-completion';
  static const String chatEngagement = 'track-chat-engagement';
  static const String chatRating = 'submit-chat-rating';
  static const String dropOff = 'track-drop-off';
  static const String finalizeAnalytics = 'finalize-analytics';
}
