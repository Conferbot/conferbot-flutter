import 'package:flutter/material.dart';
import 'conferbot_theme.dart';

/// Default light theme matching Android SDK's LightTheme
final ConferBotTheme defaultTheme = ConferBotTheme(
  brightness: Brightness.light,
  colors: const ConferBotColors(
    // Primary brand color (Android: #0100EC)
    primary: Color(0xFF0100EC),
    secondary: Color(0xFF6750A4),
    background: Color(0xFFFFFBFF),
    surface: Color(0xFFFFFBFF),

    // Header (Android: primary blue + white text)
    headerBg: Color(0xFF0100EC),
    headerText: Color(0xFFFFFFFF),

    // Message bubbles (Android palette)
    userBubble: Color(0xFF0100EC),
    userBubbleText: Color(0xFFFFFFFF),
    botBubble: Color(0xFFF5F5F5),
    botBubbleText: Color(0xFF1C1B1F),
    agentBubble: Color(0xFFE8F5E9),
    agentBubbleText: Color(0xFF1B5E20),
    systemBubble: Color(0xFFF5F5F5),
    systemBubbleText: Color(0xFF6B6B6B),

    // Choice buttons (Android: surfaceVariant)
    optionBubble: Color(0xFFF5F5F5),
    optionBubbleText: Color(0xFF1C1B1F),

    // Text colors
    text: Color(0xFF1C1B1F),
    textSecondary: Color(0xFF49454F),
    textDisabled: Color(0xFFC7C7CC),

    // Borders
    border: Color(0xFFE0E0E0),
    divider: Color(0xFFE0E0E0),

    // Status colors
    success: Color(0xFF4CAF50),
    error: Color(0xFFB3261E),
    warning: Color(0xFFFF9500),
    info: Color(0xFF0100EC),

    // Connection status
    online: Color(0xFF4CAF50),
    offline: Color(0xFF9E9E9E),
  ),
  typography: const ConferBotTypography(),
  spacing: const ConferBotSpacing(),
  borderRadius: const ConferBotBorderRadius(),
  shadows: const ConferBotShadows(),
  animations: const ConferBotAnimations(),
  layout: const ConferBotLayout(),
);
