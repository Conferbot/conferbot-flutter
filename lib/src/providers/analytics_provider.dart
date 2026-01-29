import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/analytics.dart';
import '../services/socket_client.dart';
import '../utils/logger.dart';

/// Singleton provider for managing chat analytics across the app
/// Handles event queuing, offline persistence, and batch sending
class AnalyticsProvider with ChangeNotifier {
  // Singleton instance
  static AnalyticsProvider? _instance;

  /// Get the singleton instance
  static AnalyticsProvider get instance {
    _instance ??= AnalyticsProvider._internal();
    return _instance!;
  }

  /// Create a new instance (for testing or custom configuration)
  factory AnalyticsProvider({
    SocketClient? socketClient,
    Duration? flushInterval,
    int? maxQueueSize,
  }) {
    if (_instance == null) {
      _instance = AnalyticsProvider._internal(
        socketClient: socketClient,
        flushInterval: flushInterval,
        maxQueueSize: maxQueueSize,
      );
    }
    return _instance!;
  }

  AnalyticsProvider._internal({
    SocketClient? socketClient,
    Duration? flushInterval,
    int? maxQueueSize,
  })  : _flushInterval = flushInterval ?? const Duration(seconds: 30),
        _maxQueueSize = maxQueueSize ?? 100 {
    if (socketClient != null) {
      _socketClient = socketClient;
    }
  }

  // Dependencies
  SocketClient? _socketClient;

  // Configuration
  final Duration _flushInterval;
  final int _maxQueueSize;

  // State
  ChatAnalytics? _currentAnalytics;
  final List<AnalyticsEvent> _eventQueue = [];
  bool _isInitialized = false;
  bool _isOnline = true;
  Timer? _flushTimer;
  Timer? _engagementTimer;

  // Hive box for persistence
  Box<String>? _analyticsBox;
  static const String _boxName = 'conferbot_analytics';
  static const String _queueKey = 'event_queue';
  static const String _sessionKey = 'current_session';

  // Typing state
  int _typingStartTime = 0;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isOnline => _isOnline;
  ChatAnalytics? get currentAnalytics => _currentAnalytics;
  int get queuedEventCount => _eventQueue.length;

  // ========== Initialization ==========

  /// Initialize the analytics provider with a socket client
  Future<void> initialize(SocketClient socketClient) async {
    if (_isInitialized) {
      analyticsLogger.debug('Already initialized');
      return;
    }

    _socketClient = socketClient;

    // Initialize Hive storage
    await _initializeStorage();

    // Load persisted queue
    await _loadPersistedQueue();

    // Start flush timer
    _startFlushTimer();

    _isInitialized = true;
    notifyListeners();

    analyticsLogger.debug('Initialized');
  }

  /// Initialize Hive storage for offline persistence
  Future<void> _initializeStorage() async {
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        _analyticsBox = await Hive.openBox<String>(_boxName);
      } else {
        _analyticsBox = Hive.box<String>(_boxName);
      }
    } catch (e) {
      analyticsLogger.error('Failed to initialize storage: $e');
    }
  }

  /// Load persisted event queue from storage
  Future<void> _loadPersistedQueue() async {
    if (_analyticsBox == null) return;

    try {
      final queueJson = _analyticsBox!.get(_queueKey);
      if (queueJson != null) {
        final List<dynamic> decoded = jsonDecode(queueJson);
        _eventQueue.clear();
        _eventQueue.addAll(
          decoded.map((e) => AnalyticsEvent.fromJson(e as Map<String, dynamic>)),
        );
        analyticsLogger.debug('Loaded ${_eventQueue.length} queued events');
      }
    } catch (e) {
      analyticsLogger.error('Failed to load persisted queue: $e');
    }
  }

  /// Persist event queue to storage
  Future<void> _persistQueue() async {
    if (_analyticsBox == null) return;

    try {
      final queueJson = jsonEncode(_eventQueue.map((e) => e.toJson()).toList());
      await _analyticsBox!.put(_queueKey, queueJson);
    } catch (e) {
      analyticsLogger.error('Failed to persist queue: $e');
    }
  }

  // ========== Session Management ==========

  /// Start a new analytics session
  void startSession({
    required String sessionId,
    required String visitorId,
    required String botId,
    String? workspaceId,
    AttributionData? attribution,
  }) {
    // End existing session if any
    if (_currentAnalytics != null && _currentAnalytics!.isActive) {
      endSession();
    }

    _currentAnalytics = ChatAnalytics(
      sessionId: sessionId,
      visitorId: visitorId,
      botId: botId,
      workspaceId: workspaceId,
      attribution: attribution,
      environment: _getEnvironmentInfo(),
    );

    // Queue session start event
    _queueEvent(AnalyticsEventType.chatStart, {
      'chatSessionId': sessionId,
      'botId': botId,
      'visitorId': visitorId,
      'attribution': attribution?.toJson(),
    });

    // Start engagement timer
    _startEngagementTimer();

    // Persist session
    _persistSession();

    notifyListeners();
    analyticsLogger.debug('Session started: $sessionId');
  }

  /// End the current session
  void endSession() {
    if (_currentAnalytics == null) return;

    _stopEngagementTimer();

    // Exit current node if any
    if (_currentAnalytics!.currentNode != null) {
      trackNodeExit(exitType: NodeExitType.abandoned);
    }

    // Finalize session
    _currentAnalytics!.sessionEnd = DateTime.now();
    _currentAnalytics!.isActive = false;
    _currentAnalytics!.isFinalized = true;

    // Update session metrics
    _currentAnalytics!.sessionMetrics = _currentAnalytics!.sessionMetrics.copyWith(
      totalDuration: _currentAnalytics!.totalDurationSeconds,
      activeDuration: _currentAnalytics!.activeDurationSeconds,
      idleTime: _currentAnalytics!.totalIdleTime ~/ 1000,
    );

    // Queue finalize event
    _queueEvent(AnalyticsEventType.finalizeAnalytics, {
      'chatSessionId': _currentAnalytics!.sessionId,
      'finalMetrics': {
        'totalDuration': _currentAnalytics!.totalDurationSeconds,
        'activeDuration': _currentAnalytics!.activeDurationSeconds,
        'idleTime': _currentAnalytics!.totalIdleTime ~/ 1000,
        'messageCounts': _currentAnalytics!.messageCounts.toJson(),
        'typingBehavior': _currentAnalytics!.typingBehavior.toJson(),
        'environment': _currentAnalytics!.environment?.toJson(),
      },
    });

    // Flush immediately on session end
    _flushQueue();

    // Clear persisted session
    _clearPersistedSession();

    analyticsLogger.debug('Session ended: ${_currentAnalytics!.sessionId}');

    _currentAnalytics = null;
    notifyListeners();
  }

  /// Persist current session to storage
  Future<void> _persistSession() async {
    if (_analyticsBox == null || _currentAnalytics == null) return;

    try {
      await _analyticsBox!.put(_sessionKey, _currentAnalytics!.toStorageString());
    } catch (e) {
      analyticsLogger.error('Failed to persist session: $e');
    }
  }

  /// Clear persisted session from storage
  Future<void> _clearPersistedSession() async {
    if (_analyticsBox == null) return;

    try {
      await _analyticsBox!.delete(_sessionKey);
    } catch (e) {
      analyticsLogger.error('Failed to clear persisted session: $e');
    }
  }

  /// Resume session from storage (on app restart)
  Future<bool> resumeSession() async {
    if (_analyticsBox == null) return false;

    try {
      final sessionJson = _analyticsBox!.get(_sessionKey);
      if (sessionJson != null) {
        _currentAnalytics = ChatAnalytics.fromStorageString(sessionJson);

        // Only resume if session is still active and recent (within 1 hour)
        final sessionAge =
            DateTime.now().difference(_currentAnalytics!.sessionStart);
        if (_currentAnalytics!.isActive && sessionAge.inHours < 1) {
          _startEngagementTimer();
          notifyListeners();
          analyticsLogger.debug(
              'Session resumed: ${_currentAnalytics!.sessionId}');
          return true;
        } else {
          // Session too old, clear it
          await _clearPersistedSession();
          _currentAnalytics = null;
        }
      }
    } catch (e) {
      analyticsLogger.error('Failed to resume session: $e');
    }

    return false;
  }

  // ========== Node Tracking ==========

  /// Track node entry
  void trackNodeEntry({
    required String nodeId,
    required String nodeType,
    String? nodeName,
  }) {
    if (_currentAnalytics == null) return;

    // Exit previous node if exists
    if (_currentAnalytics!.currentNode != null) {
      trackNodeExit(exitType: NodeExitType.proceeded);
    }

    final nodeVisit = NodeVisit(
      nodeId: nodeId,
      nodeType: nodeType,
      nodeName: nodeName,
    );

    _currentAnalytics!.currentNode = nodeVisit;
    _currentAnalytics!.nodeTypeCount[nodeType] =
        (_currentAnalytics!.nodeTypeCount[nodeType] ?? 0) + 1;

    _queueEvent(AnalyticsEventType.nodeVisit, {
      'chatSessionId': _currentAnalytics!.sessionId,
      'nodeId': nodeId,
      'nodeType': nodeType,
      'nodeName': nodeName,
      'enteredAt': nodeVisit.enteredAt.millisecondsSinceEpoch,
    });

    _updateActivity();
    _persistSession();
    notifyListeners();
  }

  /// Track node exit
  void trackNodeExit({
    required String exitType,
    dynamic userInput,
    String? selectedOption,
  }) {
    if (_currentAnalytics == null || _currentAnalytics!.currentNode == null) {
      return;
    }

    final currentNode = _currentAnalytics!.currentNode!;
    currentNode.exitedAt = DateTime.now();
    currentNode.exitType = exitType;
    currentNode.userInput = userInput;
    currentNode.selectedOption = selectedOption;

    _currentAnalytics!.nodeVisitHistory.add(currentNode);

    _queueEvent(AnalyticsEventType.nodeExit, {
      'chatSessionId': _currentAnalytics!.sessionId,
      'nodeId': currentNode.nodeId,
      'exitedAt': currentNode.exitedAt!.millisecondsSinceEpoch,
      'exitType': exitType,
      'dwellTime': currentNode.dwellTimeSeconds,
      'userInput': userInput,
      'selectedOption': selectedOption,
    });

    _currentAnalytics!.currentNode = null;
    _updateActivity();
    _persistSession();
    notifyListeners();
  }

  // ========== Message Tracking ==========

  /// Track a message
  void trackMessage({
    required String sender,
    required String text,
    int? messageIndex,
  }) {
    if (_currentAnalytics == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;

    switch (sender.toLowerCase()) {
      case 'bot':
        _currentAnalytics!.messageCounts.botMessages++;
        break;
      case 'user':
        _currentAnalytics!.messageCounts.userMessages++;
        _currentAnalytics!.typingBehavior.messageCount++;
        _currentAnalytics!.typingBehavior.totalMessageLength += text.length;

        _queueEvent(AnalyticsEventType.sentiment, {
          'chatSessionId': _currentAnalytics!.sessionId,
          'messageIndex': messageIndex ?? _currentAnalytics!.messageCounts.userMessages,
          'text': text,
          'messageType': 'user',
        });
        break;
      case 'agent':
        _currentAnalytics!.messageCounts.agentMessages++;
        break;
      default:
        _currentAnalytics!.messageCounts.systemMessages++;
    }

    if (_currentAnalytics!.sessionMetrics.firstMessageAt == null) {
      _currentAnalytics!.sessionMetrics.firstMessageAt = now;
    }
    _currentAnalytics!.sessionMetrics.lastMessageAt = now;

    _updateActivity();
    notifyListeners();
  }

  // ========== Typing Behavior ==========

  /// Track typing start
  void trackTypingStart() {
    _typingStartTime = DateTime.now().millisecondsSinceEpoch;
  }

  /// Track typing end
  void trackTypingEnd() {
    if (_typingStartTime > 0 && _currentAnalytics != null) {
      final typingDuration = DateTime.now().millisecondsSinceEpoch - _typingStartTime;
      _currentAnalytics!.typingBehavior.totalTypingTimeMs += typingDuration;
      _typingStartTime = 0;
    }
  }

  /// Track deletion
  void trackDeletion() {
    if (_currentAnalytics != null) {
      _currentAnalytics!.typingBehavior.deletions++;
    }
  }

  /// Track abandoned message
  void trackAbandonedMessage() {
    if (_currentAnalytics != null) {
      _currentAnalytics!.typingBehavior.abandonedMessages++;
    }
  }

  // ========== Interaction Tracking ==========

  /// Track an interaction
  void trackInteraction({
    required String type,
    Map<String, dynamic>? data,
  }) {
    if (_currentAnalytics == null) return;

    final interaction = InteractionEvent(
      type: type,
      nodeId: _currentAnalytics!.currentNode?.nodeId,
      data: data,
    );

    _currentAnalytics!.interactions.add(interaction);

    _queueEvent(AnalyticsEventType.interaction, {
      'chatSessionId': _currentAnalytics!.sessionId,
      'type': type,
      ...?data,
      'nodeId': _currentAnalytics!.currentNode?.nodeId,
    });

    _updateActivity();
    notifyListeners();
  }

  // ========== Goal Tracking ==========

  /// Track goal completion
  void trackGoalCompletion({
    required String goalId,
    String? conversionEvent,
    double? conversionValue,
  }) {
    if (_currentAnalytics == null) return;

    final goal = GoalCompletion(
      goalId: goalId,
      conversionEvent: conversionEvent,
      conversionValue: conversionValue,
    );

    _currentAnalytics!.goalCompletions.add(goal);

    _queueEvent(AnalyticsEventType.goalCompletion, {
      'chatSessionId': _currentAnalytics!.sessionId,
      'goalId': goalId,
      'conversionEvent': conversionEvent,
      'conversionValue': conversionValue,
    });

    notifyListeners();
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
    if (_currentAnalytics == null) return;

    final rating = ChatRating(
      csatScore: csatScore,
      feedback: feedback,
      thumbsUp: thumbsUp,
      npsScore: npsScore,
      source: source,
    );

    _currentAnalytics!.rating = rating;

    _queueEvent(AnalyticsEventType.chatRating, {
      'chatSessionId': _currentAnalytics!.sessionId,
      'csatScore': csatScore,
      'feedback': feedback,
      'thumbsUp': thumbsUp,
      'npsScore': npsScore,
      'source': source,
    });

    // Flush rating immediately
    _flushQueue();
    notifyListeners();
  }

  // ========== Drop-off Tracking ==========

  /// Track drop-off
  void trackDropOff({
    String reason = 'navigated_away',
    String? lastUserAction,
  }) {
    if (_currentAnalytics == null || _currentAnalytics!.currentNode == null) {
      return;
    }

    final currentNode = _currentAnalytics!.currentNode!;
    final timeBeforeDropOff =
        (DateTime.now().millisecondsSinceEpoch - _currentAnalytics!.lastActivityTime) ~/
            1000;

    _queueEvent(AnalyticsEventType.dropOff, {
      'chatSessionId': _currentAnalytics!.sessionId,
      'nodeId': currentNode.nodeId,
      'nodeType': currentNode.nodeType,
      'nodeName': currentNode.nodeName,
      'reason': reason,
      'timeBeforeDropOff': timeBeforeDropOff,
      'lastUserAction': lastUserAction ?? 'none',
    });

    // Flush immediately on drop-off
    _flushQueue();
  }

  // ========== Engagement ==========

  /// Send engagement update
  void _sendEngagementUpdate() {
    if (_currentAnalytics == null || !_currentAnalytics!.isActive) return;

    _queueEvent(AnalyticsEventType.chatEngagement, {
      'chatSessionId': _currentAnalytics!.sessionId,
      'sessionMetrics': _currentAnalytics!.sessionMetrics.toJson(),
      'typingBehavior': _currentAnalytics!.typingBehavior.toJson(),
    });
  }

  // ========== Event Queue Management ==========

  /// Queue an analytics event
  void _queueEvent(String type, Map<String, dynamic> data) {
    if (_currentAnalytics == null) return;

    final event = AnalyticsEvent(
      type: type,
      data: data,
      sessionId: _currentAnalytics!.sessionId,
    );

    _eventQueue.add(event);

    // Trim queue if too large
    if (_eventQueue.length > _maxQueueSize) {
      _eventQueue.removeRange(0, _eventQueue.length - _maxQueueSize);
    }

    // Persist queue
    _persistQueue();
  }

  /// Flush event queue to server
  Future<void> _flushQueue() async {
    if (_socketClient == null || !_socketClient!.isConnected) {
      _isOnline = false;
      analyticsLogger.debug('Offline - events queued');
      return;
    }

    _isOnline = true;

    final unsentEvents = _eventQueue.where((e) => !e.isSent).toList();
    if (unsentEvents.isEmpty) return;

    analyticsLogger.debug('Flushing ${unsentEvents.length} events');

    for (final event in unsentEvents) {
      try {
        _socketClient!.emit(event.type, event.data);
        event.isSent = true;
      } catch (e) {
        analyticsLogger.error('Failed to send event: $e');
        break;
      }
    }

    // Remove sent events
    _eventQueue.removeWhere((e) => e.isSent);
    await _persistQueue();

    notifyListeners();
  }

  /// Force flush (for manual triggering)
  Future<void> forceFlush() async {
    await _flushQueue();
  }

  // ========== Timers ==========

  /// Start flush timer
  void _startFlushTimer() {
    _stopFlushTimer();
    _flushTimer = Timer.periodic(_flushInterval, (_) {
      _flushQueue();
    });
  }

  /// Stop flush timer
  void _stopFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = null;
  }

  /// Start engagement timer
  void _startEngagementTimer() {
    _stopEngagementTimer();
    _engagementTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _sendEngagementUpdate();
    });
  }

  /// Stop engagement timer
  void _stopEngagementTimer() {
    _engagementTimer?.cancel();
    _engagementTimer = null;
  }

  // ========== Activity Tracking ==========

  /// Update activity timestamp
  void _updateActivity() {
    if (_currentAnalytics == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final timeSinceLastActivity = now - _currentAnalytics!.lastActivityTime;

    // If idle for more than 60 seconds, count as idle time
    if (timeSinceLastActivity > 60000) {
      _currentAnalytics!.totalIdleTime += timeSinceLastActivity - 60000;
    }

    _currentAnalytics!.lastActivityTime = now;
  }

  // ========== Connection Status ==========

  /// Update online status
  void setOnlineStatus(bool isOnline) {
    if (_isOnline != isOnline) {
      _isOnline = isOnline;
      notifyListeners();

      if (isOnline) {
        // Flush queued events when coming back online
        _flushQueue();
      }
    }
  }

  // ========== Helpers ==========

  /// Get environment info
  EnvironmentInfo _getEnvironmentInfo() {
    String deviceType = 'mobile';
    String platform = 'flutter';
    String? osVersion;
    String screenResolution = 'unknown';
    String language = 'en';
    String timezone = 'UTC';

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
        language = Platform.localeName;
      } catch (_) {
        // Platform access failed
      }
    }

    try {
      timezone = DateTime.now().timeZoneName;
    } catch (_) {
      // Timezone access failed
    }

    return EnvironmentInfo(
      deviceType: deviceType,
      platform: platform,
      osVersion: osVersion,
      screenResolution: screenResolution,
      language: language,
      timezone: timezone,
    );
  }

  /// Get session analytics
  ChatAnalytics? getSessionAnalytics() => _currentAnalytics;

  // ========== Cleanup ==========

  /// Dispose resources
  @override
  void dispose() {
    _stopFlushTimer();
    _stopEngagementTimer();

    if (_currentAnalytics != null && _currentAnalytics!.isActive) {
      endSession();
    }

    super.dispose();
  }

  /// Reset singleton (for testing)
  static void resetInstance() {
    _instance?.dispose();
    _instance = null;
  }
}
