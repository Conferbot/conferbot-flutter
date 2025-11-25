import 'package:flutter/material.dart';
import 'conferbot_theme.dart';

/// Default light theme (iOS inspired)
final ConferBotTheme defaultTheme = ConferBotTheme(
  brightness: Brightness.light,
  colors: const ConferBotColors(
    // Primary colors
    primary: Color(0xFF007AFF),
    secondary: Color(0xFF5856D6),
    background: Color(0xFFF2F2F7),
    surface: Color(0xFFFFFFFF),

    // Message bubbles
    userBubble: Color(0xFF007AFF),
    userBubbleText: Color(0xFFFFFFFF),
    botBubble: Color(0xFFE9E9EB),
    botBubbleText: Color(0xFF000000),
    agentBubble: Color(0xFF34C759),
    agentBubbleText: Color(0xFFFFFFFF),
    systemBubble: Color(0xFFF2F2F7),
    systemBubbleText: Color(0xFF8E8E93),

    // Text colors
    text: Color(0xFF000000),
    textSecondary: Color(0xFF8E8E93),
    textDisabled: Color(0xFFC7C7CC),

    // Borders
    border: Color(0xFFE5E5EA),
    divider: Color(0xFFE5E5EA),

    // Status colors
    success: Color(0xFF34C759),
    error: Color(0xFFFF3B30),
    warning: Color(0xFFFF9500),
    info: Color(0xFF007AFF),

    // Connection status
    online: Color(0xFF34C759),
    offline: Color(0xFF8E8E93),
  ),
  typography: const ConferBotTypography(),
  spacing: const ConferBotSpacing(),
  borderRadius: const ConferBotBorderRadius(),
  shadows: const ConferBotShadows(),
  animations: const ConferBotAnimations(),
  layout: const ConferBotLayout(),
);
