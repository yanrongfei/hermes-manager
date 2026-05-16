class Profile {
  final String id;
  final String gatewayId;
  final String remoteName;
  final String? alias;
  final String? model;
  final String? provider;
  final int skills;
  final String? description;
  final int? syncedAt;
  final int agentCount;
  final int createdAt;

  Profile({
    required this.id,
    required this.gatewayId,
    required this.remoteName,
    this.alias,
    this.model,
    this.provider,
    this.skills = 0,
    this.description,
    this.syncedAt,
    this.agentCount = 0,
    required this.createdAt,
  });

  String get displayName => alias ?? remoteName;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      gatewayId: json['gateway_id'] as String,
      remoteName: json['remote_name'] as String,
      alias: json['alias'] as String?,
      model: json['model'] as String?,
      provider: json['provider'] as String?,
      skills: json['skills'] as int? ?? 0,
      description: json['description'] as String?,
      syncedAt: json['synced_at'] as int?,
      agentCount: json['agent_count'] as int? ?? 0,
      createdAt: json['created_at'] as int,
    );
  }
}
