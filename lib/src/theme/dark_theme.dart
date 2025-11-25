import 'package:flutter/material.dart';
import 'conferbot_theme.dart';

/// Dark theme
final ConferBotTheme darkTheme = ConferBotTheme(
  brightness: Brightness.dark,
  colors: const ConferBotColors(
    // Primary colors (brighter for dark mode)
    primary: Color(0xFF0A84FF),
    secondary: Color(0xFF5E5CE6),
    background: Color(0xFF000000),
    surface: Color(0xFF1C1C1E),

    // Message bubbles
    userBubble: Color(0xFF0A84FF),
    userBubbleText: Color(0xFFFFFFFF),
    botBubble: Color(0xFF2C2C2E),
    botBubbleText: Color(0xFFFFFFFF),
    agentBubble: Color(0xFF30D158),
    agentBubbleText: Color(0xFFFFFFFF),
    systemBubble: Color(0xFF1C1C1E),
    systemBubbleText: Color(0xFF8E8E93),

    // Text colors
    text: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF8E8E93),
    textDisabled: Color(0xFF48484A),

    // Borders
    border: Color(0xFF38383A),
    divider: Color(0xFF38383A),

    // Status colors
    success: Color(0xFF30D158),
    error: Color(0xFFFF453A),
    warning: Color(0xFFFF9F0A),
    info: Color(0xFF0A84FF),

    // Connection status
    online: Color(0xFF30D158),
    offline: Color(0xFF8E8E93),
  ),
  typography: const ConferBotTypography(),
  spacing: const ConferBotSpacing(),
  borderRadius: const ConferBotBorderRadius(),
  shadows: const ConferBotShadows(),
  animations: const ConferBotAnimations(),
  layout: const ConferBotLayout(),
);
