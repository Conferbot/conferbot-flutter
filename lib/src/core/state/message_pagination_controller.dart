import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/message.dart';
import '../../utils/logger.dart';
import 'message_storage_service.dart';

/// Configuration for message pagination
class PaginationConfig {
  /// Number of messages to load per page
  final int pageSize;

  /// Maximum messages to keep in memory
  final int maxInMemory;

  /// Threshold for loading more (distance from top in pixels)
  final double loadMoreThreshold;

  /// Whether to enable persistence
  final bool enablePersistence;

  const PaginationConfig({
    this.pageSize = 50,
    this.maxInMemory = 150,
    this.loadMoreThreshold = 200.0,
    this.enablePersistence = true,
  });
}

/// Pagination state for the message list
class PaginationState {
  final List<RecordItem> visibleMessages;
  final int totalMessages;
  final int currentPage;
  final bool hasMoreMessages;
  final bool isLoadingMore;
  final String? error;

  const PaginationState({
    this.visibleMessages = const [],
    this.totalMessages = 0,
    this.currentPage = 0,
    this.hasMoreMessages = false,
    this.isLoadingMore = false,
    this.error,
  });

  PaginationState copyWith({
    List<RecordItem>? visibleMessages,
    int? totalMessages,
    int? currentPage,
    bool? hasMoreMessages,
    bool? isLoadingMore,
    String? error,
  }) {
    return PaginationState(
      visibleMessages: visibleMessages ?? this.visibleMessages,
      totalMessages: totalMessages ?? this.totalMessages,
      currentPage: currentPage ?? this.currentPage,
      hasMoreMessages: hasMoreMessages ?? this.hasMoreMessages,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
    );
  }
}

/// Controller for managing paginated message loading
///
/// This controller handles:
/// - Loading messages in batches from storage
/// - Keeping only recent messages in memory
/// - Loading older messages on scroll
/// - Persisting messages to local storage
class MessagePaginationController with ChangeNotifier {
  final PaginationConfig config;
  final MessageStorageService? _storageService;

  PaginationState _state = const PaginationState();
  PaginationState get state => _state;

  // Internal buffer for all messages (up to maxInMemory)
  final List<RecordItem> _messageBuffer = [];

  // Chat session ID for storage
  String? _chatSessionId;

  // Track if initialized
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  MessagePaginationController({
    this.config = const PaginationConfig(),
    MessageStorageService? storageService,
  }) : _storageService = storageService;

  /// Initialize the controller with a chat session
  Future<void> initialize(String chatSessionId) async {
    _chatSessionId = chatSessionId;
    _messageBuffer.clear();

    if (config.enablePersistence && _storageService != null) {
      try {
        // Load total count from storage
        final totalCount = await _storageService.getMessageCount(chatSessionId);

        // Load most recent messages
        final recentMessages = await _storageService.loadMessages(
          chatSessionId: chatSessionId,
          limit: config.pageSize,
          offset: 0,
        );

        _messageBuffer.addAll(recentMessages);

        _state = PaginationState(
          visibleMessages: List.unmodifiable(_messageBuffer),
          totalMessages: totalCount,
          currentPage: 0,
          hasMoreMessages: totalCount > config.pageSize,
          isLoadingMore: false,
        );
      } catch (e) {
        paginationLogger.error('Error loading from storage: $e');
        _state = PaginationState(
          visibleMessages: const [],
          totalMessages: 0,
          currentPage: 0,
          hasMoreMessages: false,
          isLoadingMore: false,
          error: 'Failed to load messages: $e',
        );
      }
    } else {
      _state = const PaginationState();
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// Load messages from an existing list (e.g., from API response)
  Future<void> loadFromList(List<RecordItem> messages) async {
    _messageBuffer.clear();

    // Take only the most recent messages up to maxInMemory
    final startIndex = messages.length > config.maxInMemory
        ? messages.length - config.maxInMemory
        : 0;
    _messageBuffer.addAll(messages.sublist(startIndex));

    // Persist all messages if storage is enabled
    if (config.enablePersistence && _storageService != null && _chatSessionId != null) {
      try {
        await _storageService.saveMessages(_chatSessionId!, messages);
      } catch (e) {
        paginationLogger.error('Error saving to storage: $e');
      }
    }

    _state = PaginationState(
      visibleMessages: List.unmodifiable(_messageBuffer),
      totalMessages: messages.length,
      currentPage: 0,
      hasMoreMessages: messages.length > config.maxInMemory,
      isLoadingMore: false,
    );

    notifyListeners();
  }

  /// Add a new message to the list
  /// This adds to both the in-memory buffer and persists to storage
  Future<void> addMessage(RecordItem message) async {
    // Add to buffer
    _messageBuffer.add(message);

    // Trim buffer if it exceeds maxInMemory
    if (_messageBuffer.length > config.maxInMemory) {
      _messageBuffer.removeRange(0, _messageBuffer.length - config.maxInMemory);
    }

    // Persist to storage
    if (config.enablePersistence && _storageService != null && _chatSessionId != null) {
      try {
        await _storageService.appendMessage(_chatSessionId!, message);
      } catch (e) {
        paginationLogger.error('Error appending to storage: $e');
      }
    }

    _state = _state.copyWith(
      visibleMessages: List.unmodifiable(_messageBuffer),
      totalMessages: _state.totalMessages + 1,
    );

    notifyListeners();
  }

  /// Add multiple messages at once
  Future<void> addMessages(List<RecordItem> messages) async {
    if (messages.isEmpty) return;

    _messageBuffer.addAll(messages);

    // Trim buffer if it exceeds maxInMemory
    if (_messageBuffer.length > config.maxInMemory) {
      _messageBuffer.removeRange(0, _messageBuffer.length - config.maxInMemory);
    }

    // Persist to storage
    if (config.enablePersistence && _storageService != null && _chatSessionId != null) {
      try {
        await _storageService.saveMessages(
          _chatSessionId!,
          messages,
          append: true,
        );
      } catch (e) {
        paginationLogger.error('Error saving messages to storage: $e');
      }
    }

    _state = _state.copyWith(
      visibleMessages: List.unmodifiable(_messageBuffer),
      totalMessages: _state.totalMessages + messages.length,
    );

    notifyListeners();
  }

  /// Load more (older) messages when scrolling to top
  Future<void> loadMoreMessages() async {
    if (_state.isLoadingMore || !_state.hasMoreMessages) {
      return;
    }

    if (_storageService == null || _chatSessionId == null) {
      return;
    }

    _state = _state.copyWith(isLoadingMore: true);
    notifyListeners();

    try {
      final nextPage = _state.currentPage + 1;
      final offset = nextPage * config.pageSize;

      final olderMessages = await _storageService.loadMessages(
        chatSessionId: _chatSessionId!,
        limit: config.pageSize,
        offset: offset,
      );

      if (olderMessages.isNotEmpty) {
        // Prepend older messages to the buffer
        _messageBuffer.insertAll(0, olderMessages);

        // Trim from the end if exceeds maxInMemory
        if (_messageBuffer.length > config.maxInMemory) {
          _messageBuffer.removeRange(
            config.maxInMemory,
            _messageBuffer.length,
          );
        }

        final loadedSoFar = (nextPage + 1) * config.pageSize;

        _state = _state.copyWith(
          visibleMessages: List.unmodifiable(_messageBuffer),
          currentPage: nextPage,
          hasMoreMessages: loadedSoFar < _state.totalMessages,
          isLoadingMore: false,
        );
      } else {
        _state = _state.copyWith(
          hasMoreMessages: false,
          isLoadingMore: false,
        );
      }
    } catch (e) {
      paginationLogger.error('Error loading more messages: $e');
      _state = _state.copyWith(
        isLoadingMore: false,
        error: 'Failed to load more messages: $e',
      );
    }

    notifyListeners();
  }

  /// Unload older messages to free memory
  /// Called when user scrolls back to bottom
  void trimOlderMessages() {
    if (_messageBuffer.length <= config.pageSize) {
      return;
    }

    // Keep only the most recent pageSize messages in view
    final excessCount = _messageBuffer.length - config.pageSize;
    if (excessCount > 0) {
      _messageBuffer.removeRange(0, excessCount);

      _state = _state.copyWith(
        visibleMessages: List.unmodifiable(_messageBuffer),
        currentPage: 0,
        hasMoreMessages: _state.totalMessages > config.pageSize,
      );

      notifyListeners();
    }
  }

  /// Get message by ID
  RecordItem? getMessageById(String id) {
    try {
      return _messageBuffer.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Update an existing message
  Future<void> updateMessage(RecordItem updatedMessage) async {
    final index = _messageBuffer.indexWhere((m) => m.id == updatedMessage.id);
    if (index != -1) {
      _messageBuffer[index] = updatedMessage;

      // Update in storage
      if (config.enablePersistence && _storageService != null && _chatSessionId != null) {
        try {
          await _storageService.updateMessage(_chatSessionId!, updatedMessage);
        } catch (e) {
          paginationLogger.error('Error updating message in storage: $e');
        }
      }

      _state = _state.copyWith(
        visibleMessages: List.unmodifiable(_messageBuffer),
      );

      notifyListeners();
    }
  }

  /// Delete a message
  Future<void> deleteMessage(String messageId) async {
    final index = _messageBuffer.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      _messageBuffer.removeAt(index);

      // Delete from storage
      if (config.enablePersistence && _storageService != null && _chatSessionId != null) {
        try {
          await _storageService.deleteMessage(_chatSessionId!, messageId);
        } catch (e) {
          paginationLogger.error('Error deleting message from storage: $e');
        }
      }

      _state = _state.copyWith(
        visibleMessages: List.unmodifiable(_messageBuffer),
        totalMessages: _state.totalMessages - 1,
      );

      notifyListeners();
    }
  }

  /// Clear all messages
  Future<void> clearMessages() async {
    _messageBuffer.clear();

    if (config.enablePersistence && _storageService != null && _chatSessionId != null) {
      try {
        await _storageService.clearMessages(_chatSessionId!);
      } catch (e) {
        paginationLogger.error('Error clearing storage: $e');
      }
    }

    _state = const PaginationState();
    notifyListeners();
  }

  /// Clear any error state
  void clearError() {
    if (_state.error != null) {
      _state = _state.copyWith(error: null);
      notifyListeners();
    }
  }

  /// Reset the controller
  void reset() {
    _messageBuffer.clear();
    _chatSessionId = null;
    _isInitialized = false;
    _state = const PaginationState();
    notifyListeners();
  }

  @override
  void dispose() {
    _messageBuffer.clear();
    super.dispose();
  }
}
