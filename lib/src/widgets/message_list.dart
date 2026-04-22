import 'package:flutter/material.dart';
import '../core/state/chat_state.dart';
import '../models/message.dart';
import '../models/queued_message.dart';
import '../theme/conferbot_theme.dart';
import '../theme/default_theme.dart';
import 'message_bubble.dart';
import 'typing_indicator.dart';
import 'avatar.dart';
import 'empty_state.dart';

/// Configuration for message list pagination behavior
class MessageListPaginationConfig {
  /// Distance from top to trigger loading more messages
  final double loadMoreThreshold;

  /// Whether to show loading indicator when fetching more
  final bool showLoadingIndicator;

  /// Whether to show "Jump to bottom" button
  final bool showJumpToBottom;

  /// Threshold for showing jump to bottom (distance from bottom)
  final double jumpToBottomThreshold;

  const MessageListPaginationConfig({
    this.loadMoreThreshold = 200.0,
    this.showLoadingIndicator = true,
    this.showJumpToBottom = true,
    this.jumpToBottomThreshold = 300.0,
  });
}

/// Scrollable message list widget with pagination and delivery status support
///
/// Features:
/// - Efficient ListView.builder with pagination
/// - Load more messages when scrolling to top
/// - Maintains scroll position when loading older messages
/// - Jump to bottom button
/// - Loading indicators
/// - Message delivery status (for offline queue support)
class MessageList extends StatefulWidget {
  final List<RecordItem> messages;
  final bool showTypingIndicator;
  final bool showTimestamps;
  final bool showAvatars;
  final bool showDeliveryStatus;
  final Widget? emptyWidget;
  final ConferBotTheme? theme;

  /// Whether there are more messages to load
  final bool hasMoreMessages;

  /// Whether currently loading more messages
  final bool isLoadingMore;

  /// Callback when user scrolls to top to load more
  final VoidCallback? onLoadMore;

  /// Callback when user scrolls far from bottom
  final VoidCallback? onScrollAwayFromBottom;

  /// Callback when retry is tapped on a failed message
  final void Function(String messageId)? onRetryMessage;

  /// Pagination configuration
  final MessageListPaginationConfig paginationConfig;

  const MessageList({
    super.key,
    required this.messages,
    this.showTypingIndicator = false,
    this.showTimestamps = false,
    this.showAvatars = true,
    this.showDeliveryStatus = true,
    this.emptyWidget,
    this.theme,
    this.hasMoreMessages = false,
    this.isLoadingMore = false,
    this.onLoadMore,
    this.onScrollAwayFromBottom,
    this.onRetryMessage,
    this.paginationConfig = const MessageListPaginationConfig(),
  });

  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
  final ScrollController _scrollController = ScrollController();
  final ChatState _chatState = ChatState.instance;

  /// Track if user is near the bottom
  bool _isNearBottom = true;

  /// Track if we should show jump to bottom button
  bool _showJumpToBottom = false;

  /// Track previous message count to maintain scroll position
  int _previousMessageCount = 0;

  /// Track if we're in the process of loading more
  bool _isLoadingTriggered = false;

  /// Key for preserving scroll position
  final GlobalKey _listKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _previousMessageCount = widget.messages.length;

    // Listen for delivery status changes
    if (widget.showDeliveryStatus) {
      _chatState.addListener(_onChatStateChange);
    }
  }

  void _onChatStateChange() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(MessageList oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reset loading triggered flag when loading completes
    if (oldWidget.isLoadingMore && !widget.isLoadingMore) {
      _isLoadingTriggered = false;
    }

    // Handle new messages being added at the bottom
    if (widget.messages.length > oldWidget.messages.length) {
      final addedCount = widget.messages.length - oldWidget.messages.length;

      // Check if messages were added at the end (new messages)
      // vs prepended at the beginning (loaded older messages)
      final isNewMessage = _checkIsNewMessage(oldWidget.messages);

      if (isNewMessage) {
        // New message added - scroll to bottom if we were near bottom
        if (_isNearBottom) {
          _scrollToBottom();
        } else {
          // Show jump to bottom indicator
          setState(() {
            _showJumpToBottom = true;
          });
        }
      } else {
        // Older messages loaded - maintain scroll position
        _maintainScrollPosition(addedCount);
      }

      _previousMessageCount = widget.messages.length;
    }
  }

  /// Check if the change is a new message (at end) vs loaded older (at start)
  bool _checkIsNewMessage(List<RecordItem> oldMessages) {
    if (oldMessages.isEmpty || widget.messages.isEmpty) {
      return true;
    }

    // If the last message is different, it's a new message
    final lastOldMessage = oldMessages.last;
    final lastNewMessage = widget.messages.last;

    return lastOldMessage.id != lastNewMessage.id;
  }

  /// Maintain scroll position after loading older messages
  void _maintainScrollPosition(int addedCount) {
    if (!_scrollController.hasClients) return;

    // Use WidgetsBinding to defer the scroll position maintenance
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        // Calculate the height of added items (estimate)
        // This is an approximation - in production you might want
        // to measure actual item heights
        final estimatedItemHeight = 80.0; // Average message height
        final addedHeight = addedCount * estimatedItemHeight;

        // Adjust scroll position to account for new items at top
        final currentOffset = _scrollController.offset;
        _scrollController.jumpTo(currentOffset + addedHeight);
      }
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final maxScroll = position.maxScrollExtent;
    final currentScroll = position.pixels;

    // Check if near bottom
    final distanceFromBottom = maxScroll - currentScroll;
    final wasNearBottom = _isNearBottom;
    _isNearBottom = distanceFromBottom < widget.paginationConfig.jumpToBottomThreshold;

    // Update jump to bottom button visibility
    if (widget.paginationConfig.showJumpToBottom) {
      final shouldShowJumpToBottom = !_isNearBottom && distanceFromBottom > widget.paginationConfig.jumpToBottomThreshold;
      if (shouldShowJumpToBottom != _showJumpToBottom) {
        setState(() {
          _showJumpToBottom = shouldShowJumpToBottom;
        });
      }
    }

    // Notify if scrolled away from bottom
    if (wasNearBottom && !_isNearBottom) {
      widget.onScrollAwayFromBottom?.call();
    }

    // Check if near top - trigger load more
    if (currentScroll < widget.paginationConfig.loadMoreThreshold &&
        widget.hasMoreMessages &&
        !widget.isLoadingMore &&
        !_isLoadingTriggered) {
      _isLoadingTriggered = true;
      widget.onLoadMore?.call();
    }
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        if (animated) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }

        setState(() {
          _showJumpToBottom = false;
          _isNearBottom = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    if (widget.showDeliveryStatus) {
      _chatState.removeListener(_onChatStateChange);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = widget.theme ?? defaultTheme;

    if (widget.messages.isEmpty && !widget.showTypingIndicator) {
      return widget.emptyWidget ?? EmptyState(theme: effectiveTheme);
    }

    return Stack(
      children: [
        Container(
          color: effectiveTheme.colors.background,
          child: ListView.builder(
            key: _listKey,
            controller: _scrollController,
            padding: EdgeInsets.only(
              top: effectiveTheme.spacing.md,
              bottom: effectiveTheme.spacing.md,
            ),
            // Add 1 for typing indicator, 1 for load more indicator at top
            itemCount: _calculateItemCount(),
            itemBuilder: (context, index) =>
                _buildItem(context, index, effectiveTheme),
          ),
        ),
        // Jump to bottom button
        if (_showJumpToBottom && widget.paginationConfig.showJumpToBottom)
          Positioned(
            right: effectiveTheme.spacing.md,
            bottom: effectiveTheme.spacing.md,
            child: _JumpToBottomButton(
              onPressed: () => _scrollToBottom(),
              theme: effectiveTheme,
            ),
          ),
      ],
    );
  }

  int _calculateItemCount() {
    int count = widget.messages.length;

    // Add loading indicator at top if loading more
    if (widget.isLoadingMore || widget.hasMoreMessages) {
      count += 1; // For the load more indicator/trigger at top
    }

    // Add typing indicator at bottom
    if (widget.showTypingIndicator) {
      count += 1;
    }

    return count;
  }

  Widget _buildItem(BuildContext context, int index, ConferBotTheme theme) {
    final hasLoadMoreIndicator = widget.isLoadingMore || widget.hasMoreMessages;
    final messageStartIndex = hasLoadMoreIndicator ? 1 : 0;
    final messageEndIndex = messageStartIndex + widget.messages.length;

    // Load more indicator at top (index 0 when loading)
    if (hasLoadMoreIndicator && index == 0) {
      return _buildLoadMoreIndicator(theme);
    }

    // Typing indicator at bottom
    if (widget.showTypingIndicator && index == _calculateItemCount() - 1) {
      return _buildTypingIndicator(theme);
    }

    // Message item
    final messageIndex = index - messageStartIndex;
    if (messageIndex >= 0 && messageIndex < widget.messages.length) {
      final message = widget.messages[messageIndex];

      // Get delivery status for user messages
      MessageDeliveryStatus? deliveryStatus;
      if (widget.showDeliveryStatus && _isUserMessage(message)) {
        deliveryStatus = _chatState.getDeliveryStatus(message.id);
      }

      return MessageBubble(
        message: message,
        showAvatar: widget.showAvatars,
        showTimestamp: widget.showTimestamps,
        showDeliveryStatus: widget.showDeliveryStatus,
        deliveryStatus: deliveryStatus,
        onRetry: deliveryStatus == MessageDeliveryStatus.failed
            ? () => widget.onRetryMessage?.call(message.id)
            : null,
        theme: theme,
      );
    }

    return const SizedBox.shrink();
  }

  bool _isUserMessage(RecordItem message) {
    return message.type == MessageType.userMessage ||
        message.type == MessageType.userInputResponse;
  }

  Widget _buildLoadMoreIndicator(ConferBotTheme theme) {
    if (!widget.paginationConfig.showLoadingIndicator) {
      return const SizedBox(height: 1);
    }

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: theme.spacing.md,
      ),
      child: Center(
        child: widget.isLoadingMore
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colors.primary,
                      ),
                    ),
                  ),
                  SizedBox(width: theme.spacing.sm),
                  Text(
                    'Loading more messages...',
                    style: TextStyle(
                      fontSize: theme.typography.fontSizeSm,
                      color: theme.colors.textSecondary,
                    ),
                  ),
                ],
              )
            : widget.hasMoreMessages
                ? GestureDetector(
                    onTap: () {
                      if (!_isLoadingTriggered) {
                        _isLoadingTriggered = true;
                        widget.onLoadMore?.call();
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: theme.spacing.md,
                        vertical: theme.spacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colors.surface,
                        borderRadius: BorderRadius.circular(theme.borderRadius.md),
                        border: Border.all(
                          color: theme.colors.border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.history,
                            size: 16,
                            color: theme.colors.textSecondary,
                          ),
                          SizedBox(width: theme.spacing.xs),
                          Text(
                            'Load older messages',
                            style: TextStyle(
                              fontSize: theme.typography.fontSizeSm,
                              color: theme.colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildTypingIndicator(ConferBotTheme theme) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.md,
        vertical: theme.spacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Bot avatar — matches web widget
          ConferBotAvatar(
            size: 32,
            name: 'Bot',
            theme: theme,
          ),
          SizedBox(width: theme.spacing.sm),
          // Typing dots in a bubble
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colors.botBubble,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(theme.borderRadius.lg),
                topRight: Radius.circular(theme.borderRadius.lg),
                bottomLeft: Radius.zero,
                bottomRight: Radius.circular(theme.borderRadius.lg),
              ),
            ),
            child: TypingIndicator(
              visible: widget.showTypingIndicator,
              theme: theme,
            ),
          ),
        ],
      ),
    );
  }
}

/// Jump to bottom floating action button
class _JumpToBottomButton extends StatelessWidget {
  final VoidCallback onPressed;
  final ConferBotTheme theme;

  const _JumpToBottomButton({
    required this.onPressed,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.colors.primary,
      borderRadius: BorderRadius.circular(theme.borderRadius.full),
      elevation: 4,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(theme.borderRadius.full),
        child: Container(
          padding: EdgeInsets.all(theme.spacing.sm),
          child: Icon(
            Icons.keyboard_arrow_down,
            color: Colors.white,
            size: theme.layout.iconSize,
          ),
        ),
      ),
    );
  }
}

/// A simpler version of MessageList without pagination
/// For use when you don't need pagination features
class SimpleMessageList extends StatefulWidget {
  final List<RecordItem> messages;
  final bool showTypingIndicator;
  final bool showTimestamps;
  final bool showAvatars;
  final bool showDeliveryStatus;
  final Widget? emptyWidget;
  final ConferBotTheme? theme;
  final void Function(String messageId)? onRetryMessage;

  const SimpleMessageList({
    super.key,
    required this.messages,
    this.showTypingIndicator = false,
    this.showTimestamps = false,
    this.showAvatars = true,
    this.showDeliveryStatus = true,
    this.emptyWidget,
    this.theme,
    this.onRetryMessage,
  });

  @override
  State<SimpleMessageList> createState() => _SimpleMessageListState();
}

class _SimpleMessageListState extends State<SimpleMessageList> {
  final ScrollController _scrollController = ScrollController();
  final ChatState _chatState = ChatState.instance;

  @override
  void initState() {
    super.initState();
    if (widget.showDeliveryStatus) {
      _chatState.addListener(_onChatStateChange);
    }
  }

  void _onChatStateChange() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(SimpleMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length > oldWidget.messages.length) {
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    if (widget.showDeliveryStatus) {
      _chatState.removeListener(_onChatStateChange);
    }
    super.dispose();
  }

  bool _isUserMessage(RecordItem message) {
    return message.type == MessageType.userMessage ||
        message.type == MessageType.userInputResponse;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = widget.theme ?? defaultTheme;

    if (widget.messages.isEmpty && !widget.showTypingIndicator) {
      return widget.emptyWidget ?? EmptyState(theme: effectiveTheme);
    }

    return Container(
      color: effectiveTheme.colors.background,
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.symmetric(
          vertical: effectiveTheme.spacing.md,
        ),
        itemCount: widget.messages.length + (widget.showTypingIndicator ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == widget.messages.length) {
            // Typing indicator
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: effectiveTheme.spacing.md,
                vertical: effectiveTheme.spacing.sm,
              ),
              child: Row(
                children: [
                  TypingIndicator(
                    visible: widget.showTypingIndicator,
                    theme: effectiveTheme,
                  ),
                  SizedBox(width: effectiveTheme.spacing.sm),
                  Text(
                    'Agent is typing...',
                    style: TextStyle(
                      fontSize: effectiveTheme.typography.fontSizeSm,
                      color: effectiveTheme.colors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            );
          }

          final message = widget.messages[index];

          // Get delivery status for user messages
          MessageDeliveryStatus? deliveryStatus;
          if (widget.showDeliveryStatus && _isUserMessage(message)) {
            deliveryStatus = _chatState.getDeliveryStatus(message.id);
          }

          return MessageBubble(
            message: message,
            showAvatar: widget.showAvatars,
            showTimestamp: widget.showTimestamps,
            showDeliveryStatus: widget.showDeliveryStatus,
            deliveryStatus: deliveryStatus,
            onRetry: deliveryStatus == MessageDeliveryStatus.failed
                ? () => widget.onRetryMessage?.call(message.id)
                : null,
            theme: effectiveTheme,
          );
        },
      ),
    );
  }
}
