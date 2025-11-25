import 'dart:io';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/constants.dart';
import '../models/socket_events.dart';

/// Socket client for real-time communication
class SocketClient {
  final String apiKey;
  final String botId;
  final String socketUrl;
  io.Socket? _socket;
  bool _isConnected = false;

  SocketClient({
    required this.apiKey,
    required this.botId,
    this.socketUrl = ConferBotConstants.defaultSocketUrl,
  });

  bool get isConnected => _isConnected;

  /// Connect to socket server
  void connect() {
    if (_socket != null && _socket!.connected) {
      return;
    }

    _socket = io.io(
      socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableReconnection()
          .setReconnectionAttempts(ConferBotConstants.socketReconnectionAttempts)
          .setReconnectionDelay(ConferBotConstants.socketReconnectionDelay)
          .setReconnectionDelayMax(ConferBotConstants.socketReconnectionDelayMax)
          .setTimeout(ConferBotConstants.socketTimeout)
          .setExtraHeaders({
            ConferBotConstants.headerApiKey: apiKey,
            ConferBotConstants.headerBotId: botId,
            ConferBotConstants.headerPlatform: ConferBotConstants.platformIdentifier,
          })
          .enableAutoConnect()
          .build(),
    );

    _setupConnectionHandlers();
  }

  void _setupConnectionHandlers() {
    _socket?.on(SocketEvents.connect, (_) {
      _isConnected = true;
      debugPrint('[ConferBot Socket] Connected');
    });

    _socket?.on(SocketEvents.disconnect, (_) {
      _isConnected = false;
      debugPrint('[ConferBot Socket] Disconnected');
    });

    _socket?.on(SocketEvents.connectError, (error) {
      _isConnected = false;
      debugPrint('[ConferBot Socket] Connection error: $error');
    });

    _socket?.on(SocketEvents.reconnect, (_) {
      _isConnected = true;
      debugPrint('[ConferBot Socket] Reconnected');
    });
  }

  /// Initialize mobile session
  void mobileInit({
    required String chatSessionId,
    String? visitorId,
    Map<String, dynamic>? deviceInfo,
  }) {
    emit(SocketEvents.mobileInit, {
      'botId': botId,
      'chatSessionId': chatSessionId,
      if (visitorId != null) 'visitorId': visitorId,
      'platform': ConferBotConstants.platformIdentifier,
      if (deviceInfo != null) 'deviceInfo': deviceInfo,
    });
  }

  /// Join chat room as visitor
  void joinChatRoom(String chatSessionId) {
    emit(SocketEvents.joinChatRoom, {
      'chatSessionId': chatSessionId,
    });
  }

  /// Leave chat room
  void leaveChatRoom(String chatSessionId) {
    emit(SocketEvents.leaveChatRoom, {
      'chatSessionId': chatSessionId,
    });
  }

  /// Send visitor message
  void sendVisitorMessage({
    required String chatSessionId,
    required Map<String, dynamic> record,
    required List<dynamic> answerVariables,
    Map<String, dynamic>? visitorMeta,
  }) {
    emit(SocketEvents.sendVisitorMessage, {
      'chatSessionId': chatSessionId,
      'record': record,
      'answerVariables': answerVariables,
      'botId': botId,
      if (visitorMeta != null) 'visitorMeta': visitorMeta,
    });
  }

  /// Send visitor typing status
  void sendTypingStatus({
    required String chatSessionId,
    required bool isTyping,
  }) {
    emit(SocketEvents.visitorTyping, {
      'chatSessionId': chatSessionId,
      'isTyping': isTyping,
    });
  }

  /// Initiate handover to live agent
  void initiateHandover({
    required String chatSessionId,
    String? message,
  }) {
    emit(SocketEvents.initiateHandover, {
      'chatSessionId': chatSessionId,
      if (message != null) 'message': message,
    });
  }

  /// End chat
  void endChat(String chatSessionId) {
    emit(SocketEvents.endChat, {
      'chatSessionId': chatSessionId,
    });
  }

  /// Emit event
  void emit(String event, dynamic data) {
    if (_socket == null || !_socket!.connected) {
      debugPrint('[ConferBot Socket] Cannot emit - not connected');
      return;
    }
    _socket!.emit(event, data);
  }

  /// Listen to event
  void on(String event, Function(dynamic) callback) {
    _socket?.on(event, callback);
  }

  /// Remove event listener
  void off(String event, [Function(dynamic)? callback]) {
    if (callback != null) {
      _socket?.off(event, callback);
    } else {
      _socket?.off(event);
    }
  }

  /// Disconnect from socket
  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _isConnected = false;
    }
  }

  void dispose() {
    disconnect();
  }
}

void debugPrint(String message) {
  if (Platform.environment.containsKey('FLUTTER_TEST')) {
    return;
  }
  print(message);
}
