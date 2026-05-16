class Gateway {
  final String id;
  final String? name;
  final String address;
  final String? apiKey;
  final String status;
  final int? lastSeen;
  final int profileCount;
  final int agentCount;
  final int createdAt;

  Gateway({
    required this.id,
    this.name,
    required this.address,
    this.apiKey,
    this.status = 'unknown',
    this.lastSeen,
    this.profileCount = 0,
    this.agentCount = 0,
    required this.createdAt,
  });

  bool get isOnline => status == 'online';

  factory Gateway.fromJson(Map<String, dynamic> json) {
    return Gateway(
      id: json['id'] as String,
      name: json['name'] as String?,
      address: json['address'] as String,
      apiKey: json['api_key'] as String?,
      status: json['status'] as String? ?? 'unknown',
      lastSeen: json['last_seen'] as int?,
      profileCount: json['profile_count'] as int? ?? 0,
      agentCount: json['agent_count'] as int? ?? 0,
      createdAt: json['created_at'] as int,
    );
  }
}
