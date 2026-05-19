class Gateway {
  final String id;
  final String? name;
  final String address;
  final String? apiKey;
  final String status;
  final int? lastSeen;
  final int createdAt;
  final int profileCount;
  final int agentCount;

  Gateway({
    required this.id,
    this.name,
    required this.address,
    this.apiKey,
    this.status = 'unknown',
    this.lastSeen,
    required this.createdAt,
    this.profileCount = 0,
    this.agentCount = 0,
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
      createdAt: json['created_at'] as int,
      profileCount: json['profile_count'] as int? ?? 0,
      agentCount: json['agent_count'] as int? ?? 0,
    );
  }
}

class GatewayStatus {
  final String profile;
  final String host;
  final int port;
  final String url;
  final bool running;
  final int? pid;
  final String? model;
  final String? provider;
  final String? profilePath;
  final int skillsCount;
  final bool hasEnv;
  final bool hasSoul;

  GatewayStatus({
    required this.profile,
    required this.host,
    required this.port,
    required this.url,
    required this.running,
    this.pid,
    this.model,
    this.provider,
    this.profilePath,
    this.skillsCount = 0,
    this.hasEnv = false,
    this.hasSoul = false,
  });

  factory GatewayStatus.fromJson(Map<String, dynamic> json) {
    return GatewayStatus(
      profile: json['profile'] as String? ?? '',
      host: json['host'] as String? ?? '127.0.0.1',
      port: json['port'] as int? ?? 8642,
      url: json['url'] as String? ?? '',
      running: json['running'] as bool? ?? false,
      pid: json['pid'] as int?,
      model: json['model'] as String?,
      provider: json['provider'] as String?,
      profilePath: json['profile_path'] as String?,
      skillsCount: json['skills_count'] as int? ?? 0,
      hasEnv: json['has_env'] as bool? ?? false,
      hasSoul: json['has_soul'] as bool? ?? false,
    );
  }
}