class User {
  final String id;
  final String username;
  final bool multiDevice;

  User({
    required this.id,
    required this.username,
    this.multiDevice = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      username: json['username'] as String,
      multiDevice: json['multi_device'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'multi_device': multiDevice,
  };
}
