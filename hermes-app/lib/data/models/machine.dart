class Machine {
  final String id;
  final String? name;
  final String address;
  final String? apiKey;
  final String mode;
  final String? profileName;
  final int createdAt;

  Machine({
    required this.id,
    this.name,
    required this.address,
    this.apiKey,
    this.mode = 'http',
    this.profileName,
    required this.createdAt,
  });

  bool get isLocal => mode == 'local';

  factory Machine.fromJson(Map<String, dynamic> json) {
    return Machine(
      id: json['id'] as String,
      name: json['name'] as String?,
      address: json['address'] as String,
      apiKey: json['api_key'] as String?,
      mode: json['mode'] as String? ?? 'http',
      profileName: json['profile_name'] as String?,
      createdAt: json['created_at'] as int,
    );
  }
}
