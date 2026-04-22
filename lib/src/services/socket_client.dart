import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/constants.dart';
import '../models/queued_message.dart';
import '../models/socket_events.dart';
import '../core/errors/conferbot_exceptions.dart';
import '../core/errors/error_handler.dart';
import '../utils/logger.dart';
import 'connectivity_service.dart';
import 'message_queue_service.dart';

// ============================================
// CONNECTION STATE
// ============================================

/// Connection state for the socket
enum SocketConnectionState {
  /// Not connected
  disconnected,

  /// Attempting initial connection
  connecting,

  /// Successfully connected
  connected,

  /// Attempting to reconnect after disconnect
  reconnecting,

  /// Connection failed permanently after max retries
  failed,
}

// ============================================
// SOCKET CLIENT CONFIGURATION
// ============================================

/// Configuration for socket client behavior
class SocketClientConfig {
  /// Maximum number of reconnection attempts
  final int maxReconnectionAttempts;

  /// Initial delay for reconnection (milliseconds)
  final int reconnectionDelay;

  /// Maximum delay for reconnection (milliseconds)
  final int reconnectionDelayMax;

  /// Socket connection timeout (milliseconds)
  final int connectionTimeout;

  /// Whether to use exponential backoff for reconnection
  final bool useExponentialBackoff;

  /// Whether to automatically reconnect on disconnect
  final bool autoReconnect;

  /// Whether to enable offline message queue
  final bool enableOfflineQueue;

  const SocketClientConfig({
    this.maxReconnectionAttempts = ConferBotConstants.socketReconnectionAttempts,
    this.reconnectionDelay = ConferBotConstants.socketReconnectionDelay,
    this.reconnectionDelayMax = ConferBotConstants.socketReconnectionDelayMax,
    this.connectionTimeout = ConferBotConstants.socketTimeout,
    this.useExponentialBackoff = true,
    this.autoReconnect = true,
    this.enableOfflineQueue = true,
  });

  /// Create config from ConferBotNetworkConfig (uses runtime-configurable values)
  factory SocketClientConfig.fromNetworkConfig() {
    return SocketClientConfig(
      maxReconnectionAttempts: ConferBotNetworkConfig.reconnectionAttempts,
      reconnectionDelay: ConferBotNetworkConfig.reconnectionDelay.inMilliseconds,
      reconnectionDelayMax: ConferBotNetworkConfig.reconnectionDelayMax.inMilliseconds,
      connectionTimeout: ConferBotNetworkConfig.socketTimeout.inMilliseconds,
    );
  }

  /// Default configuration
  static const SocketClientConfig defaultConfig = SocketClientConfig();
}

// ============================================
// SOCKET CLIENT
// ============================================

/// Socket client for real-time communication with comprehensive error handling
/// and offline support
class SocketClient with ChangeNotifier {
  final String apiKey;
  final String botId;
  final String socketUrl;
  final SocketClientConfig config;

  // Backwards compatibility getter
  bool get enableOfflineQueue => config.enableOfflineQueue;

  io.Socket? _socket;
  SocketConnectionState _connectionState = SocketConnectionState.disconnected;
  int _reconnectionAttempts = 0;
  Timer? _reconnectionTimer;
  Timer? _connectionTimeoutTimer;
  SocketException? _lastError;

  // Services
  final ConnectivityService _connectivity = ConnectivityService.instance;
  final MessageQueueService _messageQueue = MessageQueueService.instance;
  StreamSubscription<bool>? _connectivitySubscription;

  // Stream controllers for connection state and errors
  final StreamController<SocketConnectionState> _connectionStateController =
      StreamController<SocketConnectionState>.broadcast();
  final StreamController<void> _onReconnectController =
      StreamController<void>.broadcast();
  final StreamController<SocketException?> _errorController =
      StreamController<SocketException?>.broadcast();

  /// Callback for connection state changes
  void Function(SocketConnectionState state)? onConnectionStateChanged;

  /// Callback for errors
  void Function(SocketException error)? onError;

  /// Callback when reconnecting
  void Function(int attempt, int maxAttempts)? onReconnecting;

  /// Error logging callback
  ErrorLogCallback? onErrorLog;

  SocketClient({
    required this.apiKey,
    required this.botId,
    this.socketUrl = ConferBotConstants.defaultSocketUrl,
    this.config = SocketClientConfig.defaultConfig,
    this.onConnectionStateChanged,
    this.onError,
    this.onReconnecting,
    this.onErrorLog,
    @Deprecated('Use config.enableOfflineQueue instead')
    bool? enableOfflineQueue,
  });

  // ========== Getters ==========

  /// Current connection state
  SocketConnectionState get connectionState => _connectionState;

  /// Whether socket is connected
  bool get isConnected => _connectionState == SocketConnectionState.connected;

  /// Whether currently reconnecting
  bool get isReconnecting =>
      _connectionState == SocketConnectionState.reconnecting;

  /// Whether connection has permanently failed
  bool get hasFailed => _connectionState == SocketConnectionState.failed;

  /// Whether device is online (network available)
  bool get isOnline => _connectivity.isOnline;

  /// Stream of connection state changes
  Stream<SocketConnectionState> get onConnectionStateChanged_ =>
      _connectionStateController.stream;

  /// Stream that emits when socket reconnects
  Stream<void> get onReconnect => _onReconnectController.stream;

  /// Stream of socket errors
  Stream<SocketException?> get errorStream => _errorController.stream;

  /// Number of pending messages in queue
  int get pendingMessageCount => _messageQueue.queueSize;

  /// Current reconnection attempt number
  int get reconnectionAttempts => _reconnectionAttempts;

  /// Maximum reconnection attempts
  int get maxReconnectionAttempts => config.maxReconnectionAttempts;

  /// Last error that occurred
  SocketException? get lastError => _lastError;

  // ========== Connection Management ==========

  /// Connect to socket server
  Future<void> connect() async {
    if (_socket != null && _socket!.connected) {
      socketLogger.debug('Already connected');
      return;
    }

    _updateConnectionState(SocketConnectionState.connecting);
    _clearError();

    // Initialize message queue with send callback
    if (config.enableOfflineQueue) {
      await _messageQueue.initialize(
        sendCallback: _sendQueuedMessage,
      );

      // Listen for connectivity changes
      _connectivitySubscription?.cancel();
      _connectivitySubscription =
          _connectivity.onlineStatus.listen((isOnline) {
        if (isOnline && !this.isConnected) {
          socketLogger.debug('Network restored, reconnecting...');
          _attemptReconnection();
        }
      });
    }

    try {
      _createSocket();
      _startConnectionTimeout();
    } catch (e, stackTrace) {
      _handleConnectionError(e, stackTrace);
    }
  }

  /// Create and configure socket connection
  void _createSocket() {
    _socket = io.io(
      socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableReconnection()
          .setReconnectionAttempts(config.maxReconnectionAttempts)
          .setReconnectionDelay(config.reconnectionDelay)
          .setReconnectionDelayMax(config.reconnectionDelayMax)
          .setTimeout(config.connectionTimeout)
          .setExtraHeaders({
            ConferBotConstants.headerApiKey: apiKey,
            ConferBotConstants.headerBotId: botId,
            ConferBotConstants.headerPlatform:
                ConferBotConstants.platformIdentifier,
          })
          .enableAutoConnect()
          .build(),
    );

    _setupConnectionHandlers();
  }

  void _setupConnectionHandlers() {
    _socket?.on(SocketEvents.connect, (_) {
      _cancelConnectionTimeout();
      _reconnectionAttempts = 0;
      _clearError();
      _updateConnectionState(SocketConnectionState.connected);
      socketLogger.debug('Connected');

      // Process any queued messages
      if (config.enableOfflineQueue) {
        _messageQueue.processQueue();
      }
    });

    _socket?.on(SocketEvents.disconnect, (reason) {
      socketLogger.debug('Disconnected: $reason');

      // Check if disconnection was intentional
      if (reason == 'io client disconnect' ||
          reason == 'io server disconnect') {
        _updateConnectionState(SocketConnectionState.disconnected);
      } else if (config.autoReconnect) {
        // Unexpected disconnect - attempt reconnection
        final error = SocketException.disconnected(reason: reason?.toString());
        _setError(error);
        _attemptReconnection();
      } else {
        _updateConnectionState(SocketConnectionState.disconnected);
      }
    });

    _socket?.on(SocketEvents.connectError, (error) {
      socketLogger.debug('Connection error: $error');
      _handleConnectionError(error, null);
    });

    _socket?.on(SocketEvents.reconnect, (_) {
      _reconnectionAttempts = 0;
      _clearError();
      _updateConnectionState(SocketConnectionState.connected);
      _onReconnectController.add(null);
      socketLogger.debug('Reconnected');

      // Process queued messages on reconnect
      if (config.enableOfflineQueue) {
        _messageQueue.processQueue();
      }
    });

    _socket?.on(SocketEvents.reconnectAttempt, (attempt) {
      _reconnectionAttempts = attempt as int? ?? _reconnectionAttempts + 1;
      _updateConnectionState(SocketConnectionState.reconnecting);
      onReconnecting?.call(
        _reconnectionAttempts,
        config.maxReconnectionAttempts,
      );
      socketLogger.debug(
        'Reconnect attempt $_reconnectionAttempts/${config.maxReconnectionAttempts}',
      );
    });

    _socket?.on(SocketEvents.reconnectFailed, (_) {
      _updateConnectionState(SocketConnectionState.failed);
      final error = SocketException.reconnectionFailed(
        attempts: _reconnectionAttempts,
        maxAttempts: config.maxReconnectionAttempts,
      );
      _setError(error);
      socketLogger.debug('Reconnection failed');
    });

    _socket?.on('error', (error) {
      socketLogger.debug('Error event: $error');
      final socketError = SocketException(
        message: error?.toString() ?? 'Unknown socket error',
        code: 'SOCKET_ERROR',
        originalError: error,
      );
      _setError(socketError);
    });
  }

  /// Handle connection errors
  void _handleConnectionError(dynamic error, StackTrace? stackTrace) {
    _cancelConnectionTimeout();

    final socketError = SocketException.connectionFailed(
      originalError: error,
      originalStackTrace: stackTrace,
    );
    _setError(socketError);

    if (config.autoReconnect &&
        _reconnectionAttempts < config.maxReconnectionAttempts) {
      _attemptReconnection();
    } else {
      _updateConnectionState(SocketConnectionState.failed);
    }
  }

  /// Attempt reconnection with exponential backoff
  void _attemptReconnection() {
    if (_reconnectionAttempts >= config.maxReconnectionAttempts) {
      _updateConnectionState(SocketConnectionState.failed);
      final error = SocketException.reconnectionFailed(
        attempts: _reconnectionAttempts,
        maxAttempts: config.maxReconnectionAttempts,
      );
      _setError(error);
      return;
    }

    _reconnectionAttempts++;
    _updateConnectionState(SocketConnectionState.reconnecting);
    onReconnecting?.call(_reconnectionAttempts, config.maxReconnectionAttempts);

    // Calculate backoff delay
    final delay = _calculateBackoffDelay(_reconnectionAttempts);

    socketLogger.debug(
      'Reconnecting in ${delay.inMilliseconds}ms '
      '(attempt $_reconnectionAttempts/${config.maxReconnectionAttempts})',
    );

    _reconnectionTimer?.cancel();
    _reconnectionTimer = Timer(delay, () {
      if (_connectionState == SocketConnectionState.reconnecting) {
        socketLogger.debug(
          'Executing reconnection attempt $_reconnectionAttempts',
        );

        // Reconnect existing socket or create new one
        if (_socket != null) {
          _socket!.connect();
        } else {
          _createSocket();
        }
      }
    });
  }

  /// Calculate backoff delay for reconnection
  Duration _calculateBackoffDelay(int attempt) {
    if (!config.useExponentialBackoff) {
      return Duration(milliseconds: config.reconnectionDelay);
    }

    return ErrorHandler.calculateBackoffDelay(
      attempt: attempt,
      baseDelay: config.reconnectionDelay,
      maxDelay: config.reconnectionDelayMax,
      jitter: true,
    );
  }

  void _startConnectionTimeout() {
    _cancelConnectionTimeout();
    _connectionTimeoutTimer = Timer(
      Duration(milliseconds: config.connectionTimeout),
      () {
        if (_connectionState == SocketConnectionState.connecting) {
          socketLogger.debug('Connection timeout');
          final error = SocketException.timeout();
          _setError(error);

          if (config.autoReconnect) {
            _attemptReconnection();
          } else {
            _updateConnectionState(SocketConnectionState.failed);
          }
        }
      },
    );
  }

  void _cancelConnectionTimeout() {
    _connectionTimeoutTimer?.cancel();
    _connectionTimeoutTimer = null;
  }

  void _cancelReconnectionTimer() {
    _reconnectionTimer?.cancel();
    _reconnectionTimer = null;
  }

  // ========== State Management ==========

  /// Update connection state and notify listeners
  void _updateConnectionState(SocketConnectionState state) {
    if (_connectionState != state) {
      _connectionState = state;
      _connectionStateController.add(state);
      onConnectionStateChanged?.call(state);
      notifyListeners();
    }
  }

  void _setError(SocketException error) {
    _lastError = error;
    _errorController.add(error);
    onError?.call(error);
    onErrorLog?.call(error, error.originalStackTrace);
  }

  void _clearError() {
    if (_lastError != null) {
      _lastError = null;
      _errorController.add(null);
    }
  }

  // ========== Offline Queue ==========

  /// Callback for sending queued messages
  Future<bool> _sendQueuedMessage(
    String event,
    Map<String, dynamic> data,
  ) async {
    if (!isConnected) {
      return false;
    }

    try {
      _socket!.emit(event, data);
      return true;
    } catch (e) {
      socketLogger.debug('Error sending queued message: $e');
      return false;
    }
  }

  // ========== Socket Operations ==========

  /// Get chatbot data (call after connection)
  void getChatbotData() {
    debugPrint('[Socket][DEBUG] Emitting get-chatbot-data for botId: $botId, connected: ${_socket?.connected}, socketUrl: $socketUrl');
    emit(SocketEvents.getChatbotData, {'botId': botId});
  }

  /// Join chat room as visitor
  void joinChatRoomVisitor(String chatSessionId) {
    emit(SocketEvents.joinChatRoomVisitor, {'chatSessionId': chatSessionId});
  }

  /// Deprecated: Use joinChatRoomVisitor instead
  @Deprecated('Use joinChatRoomVisitor instead')
  void joinChatRoom(String chatSessionId) => joinChatRoomVisitor(chatSessionId);

  /// Leave chat room
  void leaveChatRoom(String chatSessionId) {
    emit(SocketEvents.leaveChatRoom, {'chatSessionId': chatSessionId});
  }

  /// Send response record (visitor message) with offline queue support
  /// Returns the queued message if offline, null if sent immediately
  Future<QueuedMessage?> sendResponseRecord({
    required String chatSessionId,
    required dynamic record,
    List<dynamic>? answerVariables,
    Map<String, dynamic>? visitorMeta,
  }) async {
    final data = {
      'chatSessionId': chatSessionId,
      'record': record,
      'answerVariables': answerVariables ?? [],
      'botId': botId,
      if (visitorMeta != null) 'visitorMeta': visitorMeta,
    };

    // If connected, send immediately
    if (isConnected) {
      emit(SocketEvents.responseRecord, data);
      return null;
    }

    // If offline and queue enabled, queue the message
    if (config.enableOfflineQueue) {
      final message = QueuedMessage(
        id: 'resp_${DateTime.now().millisecondsSinceEpoch}',
        type: QueuedMessageType.response,
        eventName: SocketEvents.responseRecord,
        data: data,
      );
      await _messageQueue.enqueue(message);
      return message;
    }

    // If offline and queue disabled, report error
    socketLogger.debug(
      'Cannot emit - not connected and queue disabled',
    );
    final error = SocketException.emitFailed(
      event: SocketEvents.responseRecord,
      originalError: 'Socket not connected and offline queue disabled',
    );
    _setError(error);
    return null;
  }

  /// Deprecated: Use sendResponseRecord instead
  @Deprecated('Use sendResponseRecord instead')
  void sendVisitorMessage({
    required String chatSessionId,
    required Map<String, dynamic> record,
    required List<dynamic> answerVariables,
    Map<String, dynamic>? visitorMeta,
  }) {
    sendResponseRecord(
      chatSessionId: chatSessionId,
      record: record,
      answerVariables: answerVariables,
      visitorMeta: visitorMeta,
    );
  }

  /// Send visitor typing status
  void sendTypingStatus({
    required String chatSessionId,
    required bool isTyping,
  }) {
    // Typing status doesn't need to be queued
    if (isConnected) {
      emit(SocketEvents.visitorTyping, {
        'chatSessionId': chatSessionId,
        'isTyping': isTyping,
      });
    }
  }

  /// Initiate handover to live agent with offline queue support
  Future<QueuedMessage?> initiateHandover({
    required String chatSessionId,
    String? message,
  }) async {
    final data = {
      'chatSessionId': chatSessionId,
      if (message != null) 'message': message,
    };

    if (isConnected) {
      emit(SocketEvents.initiateHandover, data);
      return null;
    }

    if (config.enableOfflineQueue) {
      final queuedMessage = QueuedMessage(
        id: 'handover_${DateTime.now().millisecondsSinceEpoch}',
        type: QueuedMessageType.handover,
        eventName: SocketEvents.initiateHandover,
        data: data,
      );
      await _messageQueue.enqueue(queuedMessage);
      return queuedMessage;
    }

    socketLogger.debug('Cannot initiate handover - not connected');
    final error = SocketException.emitFailed(
      event: SocketEvents.initiateHandover,
      originalError: 'Socket not connected',
    );
    _setError(error);
    return null;
  }

  /// End chat
  void endChat(String chatSessionId) {
    emit(SocketEvents.endChat, {'chatSessionId': chatSessionId});
  }

  /// Emit event with error handling
  void emit(String event, dynamic data) {
    if (_socket == null || !_socket!.connected) {
      socketLogger.debug('Cannot emit "$event" - not connected');

      // If auto-reconnect is enabled and we're not already reconnecting
      if (config.autoReconnect &&
          _connectionState != SocketConnectionState.reconnecting &&
          _connectionState != SocketConnectionState.connecting) {
        socketLogger.debug('Triggering reconnection for emit');
        _attemptReconnection();
      }
      return;
    }

    try {
      _socket!.emit(event, data);
    } catch (e, stackTrace) {
      final error = SocketException.emitFailed(
        event: event,
        originalError: e,
        originalStackTrace: stackTrace,
      );
      _setError(error);
      socketLogger.debug('Emit error: $e');
    }
  }

  /// Emit event with offline queue fallback
  /// Returns true if sent immediately, false if queued
  Future<bool> emitWithQueue(
    String event,
    Map<String, dynamic> data, {
    QueuedMessageType type = QueuedMessageType.chat,
  }) async {
    if (isConnected) {
      emit(event, data);
      return true;
    }

    if (config.enableOfflineQueue) {
      final message = QueuedMessage(
        id: '${type.value}_${DateTime.now().millisecondsSinceEpoch}',
        type: type,
        eventName: event,
        data: data,
      );
      await _messageQueue.enqueue(message);
      return false;
    }

    return false;
  }

  /// Emit event with acknowledgement and timeout
  Future<dynamic> emitWithAck(
    String event,
    dynamic data, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (_socket == null || !_socket!.connected) {
      throw SocketException.emitFailed(
        event: event,
        originalError: 'Socket not connected',
      );
    }

    final completer = Completer<dynamic>();
    Timer? timeoutTimer;

    try {
      timeoutTimer = Timer(timeout, () {
        if (!completer.isCompleted) {
          completer.completeError(SocketException.timeout(event: event));
        }
      });

      _socket!.emitWithAck(event, data, ack: (response) {
        timeoutTimer?.cancel();
        if (!completer.isCompleted) {
          completer.complete(response);
        }
      });

      return await completer.future;
    } catch (e, stackTrace) {
      timeoutTimer?.cancel();
      throw SocketException.emitFailed(
        event: event,
        originalError: e,
        originalStackTrace: stackTrace,
      );
    }
  }

  /// Listen to event
  void on(String event, Function(dynamic) callback) {
    _socket?.on(event, callback);
  }

  /// Listen to event once
  void once(String event, Function(dynamic) callback) {
    _socket?.once(event, callback);
  }

  /// Remove event listener
  void off(String event, [Function(dynamic)? callback]) {
    if (callback != null) {
      _socket?.off(event, callback);
    } else {
      _socket?.off(event);
    }
  }

  /// Check if socket has listeners for event
  bool hasListenersForEvent(String event) {
    return _socket?.hasListeners(event) ?? false;
  }

  // ========== Queue Management ==========

  /// Manually trigger queue processing
  Future<void> processQueue() async {
    if (config.enableOfflineQueue) {
      await _messageQueue.processQueue();
    }
  }

  /// Get pending messages in queue
  Future<List<QueuedMessage>> getPendingMessages() async {
    if (config.enableOfflineQueue) {
      return _messageQueue.getPendingMessages();
    }
    return [];
  }

  /// Clear the message queue
  Future<void> clearQueue() async {
    if (config.enableOfflineQueue) {
      await _messageQueue.clearQueue();
    }
  }

  /// Retry all failed messages
  Future<void> retryFailedMessages() async {
    if (config.enableOfflineQueue) {
      await _messageQueue.retryFailedMessages();
    }
  }

  // ========== Manual Reconnection ==========

  /// Manually trigger reconnection
  void reconnect() {
    if (_connectionState == SocketConnectionState.reconnecting) {
      socketLogger.debug('Already reconnecting');
      return;
    }

    // Reset state and try fresh connection
    _cancelReconnectionTimer();
    _reconnectionAttempts = 0;
    _clearError();

    if (_socket != null) {
      _socket!.connect();
    } else {
      _createSocket();
    }
  }

  /// Reset connection after permanent failure
  void resetConnection() {
    disconnect();
    _reconnectionAttempts = 0;
    _clearError();
    connect();
  }

  // ========== Cleanup ==========

  /// Disconnect from socket
  void disconnect() {
    _cancelConnectionTimeout();
    _cancelReconnectionTimer();

    if (_socket != null) {
      _socket!.clearListeners();
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }

    _updateConnectionState(SocketConnectionState.disconnected);
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _cancelConnectionTimeout();
    _cancelReconnectionTimer();
    _connectionStateController.close();
    _onReconnectController.close();
    _errorController.close();
    disconnect();
    super.dispose();
  }
}
