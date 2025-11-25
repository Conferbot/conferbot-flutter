/// Agent model representing a live agent
class Agent {
  final String id;
  final String name;
  final String? email;
  final String? avatar;
  final String? title;
  final String? status;

  const Agent({
    required this.id,
    required this.name,
    this.email,
    this.avatar,
    this.title,
    this.status,
  });

  factory Agent.fromJson(Map<String, dynamic> json) {
    return Agent(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String?,
      avatar: json['avatar'] as String?,
      title: json['title'] as String?,
      status: json['status'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (email != null) 'email': email,
      if (avatar != null) 'avatar': avatar,
      if (title != null) 'title': title,
      if (status != null) 'status': status,
    };
  }
}
