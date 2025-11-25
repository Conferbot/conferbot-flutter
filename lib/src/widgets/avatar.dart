import 'package:flutter/material.dart';
import '../theme/conferbot_theme.dart';
import '../theme/default_theme.dart';

/// Avatar widget displaying user/agent profile picture with initials fallback
class ConferBotAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final double size;
  final AvatarShape shape;
  final ConferBotTheme? theme;

  const ConferBotAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.size = 40.0,
    this.shape = AvatarShape.circle,
    this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = theme ?? defaultTheme;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _getBackgroundColor(name),
        borderRadius: _getBorderRadius(),
        image: imageUrl != null
            ? DecorationImage(
                image: NetworkImage(imageUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: imageUrl == null
          ? Center(
              child: Text(
                _getInitials(name),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.4,
                  fontWeight: effectiveTheme.typography.fontWeightMedium,
                ),
              ),
            )
          : null,
    );
  }

  BorderRadius? _getBorderRadius() {
    switch (shape) {
      case AvatarShape.circle:
        return BorderRadius.circular(size / 2);
      case AvatarShape.square:
        return null;
      case AvatarShape.rounded:
        return BorderRadius.circular(8);
    }
  }

  String _getInitials(String? fullName) {
    if (fullName == null || fullName.isEmpty) {
      return '?';
    }

    final names = fullName.trim().split(' ');
    if (names.length == 1) {
      return names[0][0].toUpperCase();
    }

    return (names[0][0] + names[names.length - 1][0]).toUpperCase();
  }

  Color _getBackgroundColor(String? fullName) {
    const colors = [
      Color(0xFF007AFF),
      Color(0xFF5856D6),
      Color(0xFFFF2D55),
      Color(0xFFFF9500),
      Color(0xFFFFCC00),
      Color(0xFF34C759),
      Color(0xFF00C7BE),
      Color(0xFF32ADE6),
      Color(0xFF5E5CE6),
      Color(0xFFAF52DE),
    ];

    if (fullName == null || fullName.isEmpty) {
      return colors[0];
    }

    int hash = 0;
    for (int i = 0; i < fullName.length; i++) {
      hash = fullName.codeUnitAt(i) + ((hash << 5) - hash);
    }

    return colors[hash.abs() % colors.length];
  }
}

enum AvatarShape {
  circle,
  square,
  rounded,
}
