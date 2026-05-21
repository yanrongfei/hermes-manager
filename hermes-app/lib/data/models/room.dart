class Room {
  final String id;
  final String name;
  final String? avatar;
  final String ownerId;
  final String mode;
  final String? agentId;      // 1:1 时关联的 Agent ID
  final String? profileId;      // 内部字段
  final String? inviteCode;    // 懒生成
  final int createdAt;

  // 新增字段
  final String type;           // "1v1" | "group"
  final int memberCount;
  final int onlineCount;
  final String? lastMessage;
  final int? updatedAt;
  final bool hasRunningTasks;
  final int runningTasksCount;

  Room({
    required this.id,
    required this.name,
    this.avatar,
    required this.ownerId,
    required this.mode,
    this.agentId,
    this.profileId,
    this.inviteCode,
    required this.createdAt,
    this.type = 'group',
    this.memberCount = 0,
    this.onlineCount = 0,
    this.lastMessage,
    this.updatedAt,
    this.hasRunningTasks = false,
    this.runningTasksCount = 0,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    // 计算 type: 后端返回或根据 agent_ids 长度计算
    final agentIds = json['agent_ids'] as List?;
    final type = json['type'] as String? ??
        ((agentIds?.length == 1) ? '1v1' : 'group');

    return Room(
      id: json['id'] as String,
      name: json['name'] as String,
      avatar: json['avatar'] as String?,
      ownerId: json['owner_id'] as String,
      mode: json['mode'] as String? ?? 'direct',
      agentId: json['agent_id'] as String?,
      profileId: json['profile_id'] as String?,
      inviteCode: json['invite_code'] as String?,
      createdAt: json['created_at'] as int,
      type: type,
      memberCount: json['member_count'] as int? ?? 0,
      onlineCount: json['online_count'] as int? ?? 0,
      lastMessage: json['last_message'] as String?,
      updatedAt: json['updated_at'] as int?,
      hasRunningTasks: json['has_running_tasks'] as bool? ?? false,
      runningTasksCount: json['running_tasks_count'] as int? ?? 0,
    );
  }

  // 辅助属性
  bool get is1v1 => type == '1v1' || mode == 'direct';
  bool get isGroup => type == 'group' || mode != 'direct';
}
