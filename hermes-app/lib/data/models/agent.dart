class Agent {
  final String id;
  final String machineId;
  final String remoteId;
  final String name;
  final String? description;
  final String? avatar;
  final String? profile;
  final bool invited;
  final int createdAt;

  Agent({
    required this.id,
    required this.machineId,
    required this.remoteId,
    required this.name,
    this.description,
    this.avatar,
    this.profile,
    this.invited = false,
    required this.createdAt,
  });

  factory Agent.fromJson(Map<String, dynamic> json) {
    return Agent(
      id: json['id'] as String,
      machineId: json['machine_id'] as String,
      remoteId: json['remote_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      avatar: json['avatar'] as String?,
      profile: json['profile'] as String?,
      invited: json['invited'] as bool? ?? false,
      createdAt: json['created_at'] as int,
    );
  }
}
