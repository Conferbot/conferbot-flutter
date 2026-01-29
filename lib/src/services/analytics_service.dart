import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/analytics.dart';
import '../utils/logger.dart';
import 'socket_client.dart';

/// Service for tracking and sending chat analytics
/// Mirrors the web widget's chatAnalytics.ts functionality
class AnalyticsService {
  final SocketClient _socketClient;

  // Session state
  ChatAnalytics? _analytics;
  bool _isInitialized = false;

  // Timing
  Timer? _engagementTimer;
  int _typingStartTime = 0;

  // Configuration
  final Duration engagementInterval;
  final Duration idleThreshold;

  AnalyticsService({
    required SocketClient socketClient,
    this.engagementInterval = const Duration(seconds: 30),
    this.idleThreshold = const Duration(seconds: 60),
  }) : _socketClient = socketClient;

  /// Whether analytics is initialized for a session
  bool get isInitialized => _isInitialized;

  /// Current analytics data (read-only)
  ChatAnalytics? get analytics => _analytics;

  /// Current session ID
  String? get sessionId => _analytics?.sessionId;

  // ========== Session Lifecycle ==========

  /// Initialize analytics tracking for a new chat session
  void startSession({
    required String sessionId,
    required String visitorId,
    required String botId,
    String? workspaceId,
    AttributionData? attribution,
  }) {
    if (_isInitialized && _analytics?.sessionId == sessionId) {
      analyticsLogger.debug('Session $sessionId already initialized');
      return;
    }

    // Create new analytics instance
    _analytics = ChatAnalytics(
      sessionId: sessionId,
      visitorId: visitorId,
      botId: botId,
      workspaceId: workspaceId,
      attribution: attribution,
      environment: _getEnvironmentInfo(),
    );

    _isInitialized = true;

    // Emit session start event
    _emitEvent(AnalyticsEventType.chatStart, {
      'chatSessionId': sessionId,
      'botId': botId,
      'visitorId': visitorId,
      'attribution': attribution?.toJson(),
    });

    // Start periodic engagement tracking
    _startEngagementTimer();

    analyticsLogger.debug('Session started: $sessionId');
  }

  /// End the current analytics session
  void endSession() {
    if (!_isInitialized || _analytics == null) {
      return;
    }

    // Stop engagement timer
    _stopEngagementTimer();

    // Exit current node if any
    if (_analytics!.currentNode != null) {
      trackNodeExit(exitType: NodeExitType.abandoned);
    }

    // Finalize analytics
    _analytics!.sessionEnd = DateTime.now();
    _analytics!.isActive = false;
    _analytics!.isFinalized = true;

    // Update session metrics
    _analytics!.sessionMetrics = _analytics!.sessionMetrics.copyWith(
      totalDuration: _analytics!.totalDurationSeconds,
      activeDuration: _analytics!.activeDurationSeconds,
      idleTime: _analytics!.totalIdleTime ~/ 1000,
    );

    // Emit finalize event
    _emitEvent(AnalyticsEventType.finalizeAnalytics, {
      'chatSessionId': _analytics!.sessionId,
      'finalMetrics': {
        'totalDuration': _analytics!.totalDurationSeconds,
        'activeDuration': _analytics!.activeDurationSeconds,
        'idleTime': _analytics!.totalIdleTime ~/ 1000,
        'messageCounts': _analytics!.messageCounts.toJson(),
        'typingBehavior': _analytics!.typingBehavior.toJson(),
        'environment': _analytics!.environment?.toJson(),
      },
    });

    analyticsLogger.debug('Session ended: ${_analytics!.sessionId}');

    _isInitialized = false;
  }

  // ========== Node Tracking ==========

  /// Track entry into a node
  void trackNodeEntry({
    required String nodeId,
    required String nodeType,
    String? nodeName,
  }) {
    if (!_isInitialized || _analytics == null) {
      return;
    }

    // Exit previous node if exists
    if (_analytics!.currentNode != null) {
      trackNodeExit(exitType: NodeExitType.proceeded);
    }

    // Create new node visit
    final nodeVisit = NodeVisit(
      nodeId: nodeId,
      nodeType: nodeType,
      nodeName: nodeName,
    );

    _analytics!.currentNode = nodeVisit;

    // Update node type count
    _analytics!.nodeTypeCount[nodeType] =
        (_analytics!.nodeTypeCount[nodeType] ?? 0) + 1;

    // Emit node visit event
    _emitEvent(AnalyticsEventType.nodeVisit, {
      'chatSessionId': _analytics!.sessionId,
      'nodeId': nodeId,
      'nodeType': nodeType,
      'nodeName': nodeName,
      'enteredAt': nodeVisit.enteredAt.millisecondsSinceEpoch,
    });

    _updateActivity();

    analyticsLogger.debug('Node entry: $nodeType ($nodeId)');
  }

  /// Track exit from current node
  void trackNodeExit({
    required String exitType,
    dynamic userInput,
    String? selectedOption,
  }) {
    if (!_isInitialized || _analytics == null || _analytics!.currentNode == null) {
      return;
    }

    final currentNode = _analytics!.currentNode!;
    currentNode.exitedAt = DateTime.now();
    currentNode.exitType = exitType;
    currentNode.userInput = userInput;
    currentNode.selectedOption = selectedOption;

    // Add to history
    _analytics!.nodeVisitHistory.add(currentNode);

    // Emit node exit event
    _emitEvent(AnalyticsEventType.nodeExit, {
      'chatSessionId': _analytics!.sessionId,
      'nodeId': currentNode.nodeId,
      'exitedAt': currentNode.exitedAt!.millisecondsSinceEpoch,
      'exitType': exitType,
      'dwellTime': currentNode.dwellTimeSeconds,
      'userInput': userInput,
      'selectedOption': selectedOption,
    });

    _analytics!.currentNode = null;
    _updateActivity();

    analyticsLogger.debug(
        'Node exit: ${currentNode.nodeType} - $exitType (${currentNode.dwellTimeSeconds}s)');
  }

  // ========== Message Tracking ==========

  /// Track a message (bot, user, or agent)
  void trackMessage({
    required String sender,
    required String text,
    int? messageIndex,
  }) {
    if (!_isInitialized || _analytics == null) {
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;

    // Update message counts
    switch (sender.toLowerCase()) {
      case 'bot':
        _analytics!.messageCounts.botMessages++;
        break;
      case 'user':
        _analytics!.messageCounts.userMessages++;
        _analytics!.typingBehavior.messageCount++;
        _analytics!.typingBehavior.totalMessageLength += text.length;

        // Track sentiment for user messages
        _emitEvent(AnalyticsEventType.sentiment, {
          'chatSessionId': _analytics!.sessionId,
          'messageIndex': messageIndex ?? _analytics!.messageCounts.userMessages,
          'text': text,
          'messageType': 'user',
        });
        break;
      case 'agent':
        _analytics!.messageCounts.agentMessages++;
        break;
      default:
        _analytics!.messageCounts.systemMessages++;
    }

    // Update session metrics
    if (_analytics!.sessionMetrics.firstMessageAt == null) {
      _analytics!.sessionMetrics.firstMessageAt = now;
    }
    _analytics!.sessionMetrics.lastMessageAt = now;

    _updateActivity();

    analyticsLogger.debug('Message tracked: $sender');
  }

  // ========== Typing Behavior ==========

  /// Track typing start
  void trackTypingStart() {
    _typingStartTime = DateTime.now().millisecondsSinceEpoch;
  }

  /// Track typing end
  void trackTypingEnd() {
    if (_typingStartTime > 0 && _analytics != null) {
      final typingDuration = DateTime.now().millisecondsSinceEpoch - _typingStartTime;
      _analytics!.typingBehavior.totalTypingTimeMs += typingDuration;
      _typingStartTime = 0;
    }
  }

  /// Track text deletion (backspace)
  void trackDeletion() {
    if (_analytics != null) {
      _analytics!.typingBehavior.deletions++;
    }
  }

  /// Track abandoned message (started typing but didn't send)
  void trackAbandonedMessage() {
    if (_analytics != null) {
      _analytics!.typingBehavior.abandonedMessages++;
    }
  }

  // ========== Interaction Tracking ==========

  /// Track a user interaction (link click, button click, etc.)
  void trackInteraction({
    required String type,
    Map<String, dynamic>? data,
  }) {
    if (!_isInitialized || _analytics == null) {
      return;
    }

    final interaction = InteractionEvent(
      type: type,
      nodeId: _analytics!.currentNode?.nodeId,
      data: data,
    );

    _analytics!.interactions.add(interaction);

    _emitEvent(AnalyticsEventType.interaction, {
      'chatSessionId': _analytics!.sessionId,
      'type': type,
      ...?data,
      'nodeId': _analytics!.currentNode?.nodeId,
    });

    _updateActivity();

    analyticsLogger.debug('Interaction: $type');
  }

  // ========== Goal Tracking ==========

  /// Track goal completion
  void trackGoalCompletion({
    required String goalId,
    String? conversionEvent,
    double? conversionValue,
  }) {
    if (!_isInitialized || _analytics == null) {
      return;
    }

    final goal = GoalCompletion(
      goalId: goalId,
      conversionEvent: conversionEvent,
      conversionValue: conversionValue,
    );

    _analytics!.goalCompletions.add(goal);

    _emitEvent(AnalyticsEventType.goalCompletion, {
      'chatSessionId': _analytics!.sessionId,
      'goalId': goalId,
      'conversionEvent': conversionEvent,
      'conversionValue': conversionValue,
    });

    analyticsLogger.debug('Goal completed: $goalId');
  }

  // ========== Rating ==========

  /// Submit chat rating
  void submitRating({
    int? csatScore,
    String? feedback,
    bool? thumbsUp,
    int? npsScore,
    String source = 'post_chat_survey',
  }) {
    if (!_isInitialized || _analytics == null) {
      return;
    }

    final rating = ChatRating(
      csatScore: csatScore,
      feedback: feedback,
      thumbsUp: thumbsUp,
      npsScore: npsScore,
      source: source,
    );

    _analytics!.rating = rating;

    _emitEvent(AnalyticsEventType.chatRating, {
      'chatSessionId': _analytics!.sessionId,
      'csatScore': csatScore,
      'feedback': feedback,
      'thumbsUp': thumbsUp,
      'npsScore': npsScore,
      'source': source,
    });

    analyticsLogger.debug('Rating submitted: $csatScore');
  }

  // ========== Drop-off Tracking ==========

  /// Track potential drop-off (user leaving mid-flow)
  void trackDropOff({
    String reason = 'navigated_away',
    String? lastUserAction,
  }) {
    if (!_isInitialized || _analytics == null) {
      return;
    }

    final currentNode = _analytics!.currentNode;
    if (currentNode == null) return;

    final timeBeforeDropOff =
        (DateTime.now().millisecondsSinceEpoch - _analytics!.lastActivityTime) ~/ 1000;

    _emitEvent(AnalyticsEventType.dropOff, {
      'chatSessionId': _analytics!.sessionId,
      'nodeId': currentNode.nodeId,
      'nodeType': currentNode.nodeType,
      'nodeName': currentNode.nodeName,
      'reason': reason,
      'timeBeforeDropOff': timeBeforeDropOff,
      'lastUserAction': lastUserAction ?? 'none',
    });

    analyticsLogger.debug('Drop-off tracked: $reason');
  }

  // ========== Engagement ==========

  /// Send periodic engagement update
  void sendEngagementUpdate() {
    if (!_isInitialized || _analytics == null) {
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final sessionMetrics = SessionMetrics(
      startedAt: _analytics!.sessionStart.millisecondsSinceEpoch,
      firstMessageAt: _analytics!.sessionMetrics.firstMessageAt,
      lastMessageAt: _analytics!.sessionMetrics.lastMessageAt,
      totalDuration: _analytics!.totalDurationSeconds,
      activeDuration: _analytics!.activeDurationSeconds,
      idleTime: _analytics!.totalIdleTime ~/ 1000,
    );

    _emitEvent(AnalyticsEventType.chatEngagement, {
      'chatSessionId': _analytics!.sessionId,
      'sessionMetrics': sessionMetrics.toJson(),
      'typingBehavior': _analytics!.typingBehavior.toJson(),
    });
  }

  // ========== Data Access ==========

  /// Get current session analytics
  ChatAnalytics? getSessionAnalytics() {
    return _analytics;
  }

  /// Get analytics data as JSON
  Map<String, dynamic>? getAnalyticsJson() {
    return _analytics?.toJson();
  }

  // ========== Private Methods ==========

  /// Start periodic engagement timer
  void _startEngagementTimer() {
    _stopEngagementTimer();
    _engagementTimer = Timer.periodic(engagementInterval, (_) {
      sendEngagementUpdate();
    });
  }

  /// Stop engagement timer
  void _stopEngagementTimer() {
    _engagementTimer?.cancel();
    _engagementTimer = null;
  }

  /// Update activity timestamp and track idle time
  void _updateActivity() {
    if (_analytics == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final timeSinceLastActivity = now - _analytics!.lastActivityTime;

    // If idle for more than threshold, count as idle time
    if (timeSinceLastActivity > idleThreshold.inMilliseconds) {
      _analytics!.totalIdleTime +=
          timeSinceLastActivity - idleThreshold.inMilliseconds;
    }

    _analytics!.lastActivityTime = now;
  }

  /// Emit analytics event via socket
  void _emitEvent(String eventType, Map<String, dynamic> data) {
    if (!_socketClient.isConnected) {
      analyticsLogger.debug('Socket not connected, event queued: $eventType');
      // Events could be queued here for offline support
      return;
    }

    _socketClient.emit(eventType, data);
  }

  /// Get environment info for current platform
  EnvironmentInfo _getEnvironmentInfo() {
    String deviceType = 'mobile';
    String platform = 'flutter';
    String? osVersion;
    String screenResolution = 'unknown';

    if (kIsWeb) {
      deviceType = 'web';
      platform = 'flutter_web';
    } else {
      try {
        if (Platform.isAndroid) {
          platform = 'android';
          osVersion = Platform.operatingSystemVersion;
        } else if (Platform.isIOS) {
          platform = 'ios';
          osVersion = Platform.operatingSystemVersion;
        } else if (Platform.isMacOS) {
          deviceType = 'desktop';
          platform = 'macos';
        } else if (Platform.isWindows) {
          deviceType = 'desktop';
          platform = 'windows';
        } else if (Platform.isLinux) {
          deviceType = 'desktop';
          platform = 'linux';
        }
      } catch (_) {
        // Platform not available
      }
    }

    return EnvironmentInfo(
      deviceType: deviceType,
      platform: platform,
      osVersion: osVersion,
      screenResolution: screenResolution,
      language: Platform.localeName,
      timezone: DateTime.now().timeZoneName,
    );
  }

  /// Dispose resources
  void dispose() {
    _stopEngagementTimer();
    if (_isInitialized) {
      endSession();
    }
  }
}
