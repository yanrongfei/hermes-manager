class Agent {
  final String id;
  final String profileId;
  final String remoteId;
  final String name;
  final String? description;
  final String? avatar;
  final bool invited;
  final int createdAt;

  Agent({
    required this.id,
    required this.profileId,
    required this.remoteId,
    required this.name,
    this.description,
    this.avatar,
    this.invited = false,
    required this.createdAt,
  });

  factory Agent.fromJson(Map<String, dynamic> json) {
    return Agent(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      remoteId: json['remote_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      avatar: json['avatar'] as String?,
      invited: json['invited'] as bool? ?? false,
      createdAt: json['created_at'] as int,
    );
  }
}
