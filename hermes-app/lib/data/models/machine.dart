class Machine {
  final String id;
  final String? name;
  final String address;
  final String? apiKey;
  final int createdAt;

  Machine({
    required this.id,
    this.name,
    required this.address,
    this.apiKey,
    required this.createdAt,
  });

  factory Machine.fromJson(Map<String, dynamic> json) {
    return Machine(
      id: json['id'] as String,
      name: json['name'] as String?,
      address: json['address'] as String,
      apiKey: json['api_key'] as String?,
      createdAt: json['created_at'] as int,
    );
  }
}
