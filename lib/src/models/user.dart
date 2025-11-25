/// User identification model
class ConferBotUser {
  final String id;
  final String? name;
  final String? email;
  final String? phone;
  final Map<String, dynamic>? metadata;

  const ConferBotUser({
    required this.id,
    this.name,
    this.email,
    this.phone,
    this.metadata,
  });

  factory ConferBotUser.fromJson(Map<String, dynamic> json) {
    return ConferBotUser(
      id: json['id'] as String,
      name: json['name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (metadata != null) 'metadata': metadata,
    };
  }
}

/// UI customization options
class ConferBotCustomization {
  final String? primaryColor;
  final String? fontFamily;
  final double? bubbleRadius;
  final String? headerTitle;
  final bool? enableAvatar;
  final String? avatarUrl;
  final String? botBubbleColor;
  final String? userBubbleColor;

  const ConferBotCustomization({
    this.primaryColor,
    this.fontFamily,
    this.bubbleRadius,
    this.headerTitle,
    this.enableAvatar,
    this.avatarUrl,
    this.botBubbleColor,
    this.userBubbleColor,
  });

  factory ConferBotCustomization.fromJson(Map<String, dynamic> json) {
    return ConferBotCustomization(
      primaryColor: json['primaryColor'] as String?,
      fontFamily: json['fontFamily'] as String?,
      bubbleRadius: json['bubbleRadius'] as double?,
      headerTitle: json['headerTitle'] as String?,
      enableAvatar: json['enableAvatar'] as bool?,
      avatarUrl: json['avatarUrl'] as String?,
      botBubbleColor: json['botBubbleColor'] as String?,
      userBubbleColor: json['userBubbleColor'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (primaryColor != null) 'primaryColor': primaryColor,
      if (fontFamily != null) 'fontFamily': fontFamily,
      if (bubbleRadius != null) 'bubbleRadius': bubbleRadius,
      if (headerTitle != null) 'headerTitle': headerTitle,
      if (enableAvatar != null) 'enableAvatar': enableAvatar,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (botBubbleColor != null) 'botBubbleColor': botBubbleColor,
      if (userBubbleColor != null) 'userBubbleColor': userBubbleColor,
    };
  }
}
