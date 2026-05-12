class Message {
  final String id;
  final String roomId;
  final String? senderId;
  final String? senderType;  // 'user' or 'agent'
  final String? senderName;
  final String content;
  final String contentType;  // 'text', 'image', 'voice'
  final String? extra;  // JSON for additional data
  final String? parentId;
  final int createdAt;

  Message({
    required this.id,
    required this.roomId,
    this.senderId,
    this.senderType,
    this.senderName,
    required this.content,
    this.contentType = 'text',
    this.extra,
    this.parentId,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      senderId: json['sender_id'] as String?,
      senderType: json['sender_type'] as String?,
      senderName: json['sender_name'] as String?,
      content: json['content'] as String,
      contentType: json['content_type'] as String? ?? 'text',
      extra: json['extra'] as String?,
      parentId: json['parent_id'] as String?,
      createdAt: json['created_at'] as int,
    );
  }

  bool get isFromUser => senderType == 'user';
  bool get isFromAgent => senderType == 'agent';
}