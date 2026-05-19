class Room {
  final String id;
  final String name;
  final String? avatar;
  final String ownerId;
  final String mode;
  final String? inviteCode;
  final String? profileId;
  final int createdAt;

  Room({
    required this.id,
    required this.name,
    this.avatar,
    required this.ownerId,
    required this.mode,
    this.inviteCode,
    this.profileId,
    required this.createdAt,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as String,
      name: json['name'] as String,
      avatar: json['avatar'] as String?,
      ownerId: json['owner_id'] as String,
      mode: json['mode'] as String? ?? 'broadcast',
      inviteCode: json['invite_code'] as String?,
      profileId: json['profile_id'] as String?,
      createdAt: json['created_at'] as int,
    );
  }
}
