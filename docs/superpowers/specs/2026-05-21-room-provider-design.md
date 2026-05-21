# room_provider & Room 模型修复设计

> 会话状态管理修复
>
> Version: 1.0
>
> Date: 2026-05-21
>
> 状态: 已完成

---

# 1. 概述

## 1.1 背景

room_provider 和 Room 模型当前实现与 PRD v3.1 存在以下不一致：
1. Room 缺少 agent_id 字段
2. Room 缺少 type 字段
3. createRoom 缺少 agentIds 参数
4. createOneOnOneRoom mode 错误（mention → direct）
5. Room 缺少成员信息字段

## 1.2 修复目标

| 问题 | 当前值 | 目标值 |
|------|--------|--------|
| agent_id 字段 | 缺失 | 添加 |
| type 字段 | 缺失 | 添加（计算字段） |
| createRoom agentIds | 缺失 | 添加 |
| createOneOnOneRoom mode | mention | direct |
| 成员信息 | 缺失 | 添加 |

---

# 2. Room 模型修复

## 2.1 当前模型

```dart
class Room {
  final String id;
  final String name;
  final String? avatar;
  final String ownerId;
  final String mode;
  final String? inviteCode;
  final String? profileId;
  final int createdAt;
  // ❌ 缺少 agentId
  // ❌ 缺少 type
  // ❌ 缺少成员信息
}
```

## 2.2 修复后模型

```dart
class Room {
  final String id;
  final String name;
  final String? avatar;
  final String ownerId;
  final String mode;
  final String? agentId;      // ✅ 1:1 时关联的 Agent ID
  final String? profileId;    // 内部查询优化
  final String? inviteCode;   // 懒生成
  final int createdAt;

  // ✅ 新增字段
  final String type;         // 1v1 / group（计算字段）
  final int memberCount;      // 成员数量
  final int onlineCount;       // 在线数量
  final String? lastMessage;  // 最新消息预览
  final int? updatedAt;       // 最后更新时间
  final bool hasRunningTasks; // 是否有运行中的任务
  final int runningTasksCount; // 运行中的任务数
}
```

## 2.3 type 计算逻辑

```dart
factory Room.fromJson(Map<String, dynamic> json) {
  // 后端返回 type，或者前端根据 agentIds.length 计算
  final type = json['type'] as String? ??
      ((json['agent_ids'] as List?)?.length == 1 ? '1v1' : 'group');

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

    // 新增
    type: type,
    memberCount: json['member_count'] as int? ?? 0,
    onlineCount: json['online_count'] as int? ?? 0,
    lastMessage: json['last_message'] as String?,
    updatedAt: json['updated_at'] as int?,
    hasRunningTasks: json['has_running_tasks'] as bool? ?? false,
    runningTasksCount: json['running_tasks_count'] as int? ?? 0,
  );
}
```

---

# 3. room_provider 修复

## 3.1 createRoom 修复

### 当前代码

```dart
Future<void> createRoom(String name, {String mode = 'broadcast'}) async {
  final dio = _ref.read(dioProvider);
  await dio.post('/rooms', data: {'name': name, 'mode': mode});
  await loadRooms();
}
```

### 修复后

```dart
Future<Room> createRoom({
  required String name,
  required List<String> agentIds,
  String mode = 'direct',
}) async {
  final dio = _ref.read(dioProvider);
  final response = await dio.post('/rooms', data: {
    'name': name,
    'agentIds': agentIds,
    'mode': mode,
  });
  final room = Room.fromJson(response.data);
  await loadRooms();
  return room;
}
```

### API 调用示例

```dart
// 创建 1:1
await ref.read(roomsProvider.notifier).createRoom(
  name: 'Claude',
  agentIds: ['agent-id-1'],
  mode: 'direct',
);

// 创建群聊
await ref.read(roomsProvider.notifier).createRoom(
  name: 'AI Research Team',
  agentIds: ['agent-id-1', 'agent-id-2'],
  mode: 'broadcast',
);
```

## 3.2 createOneOnOneRoom 修复

### 当前代码

```dart
Future<Room> createOneOnOneRoom(String agentName, String profileId) async {
  final response = await dio.post('/rooms', data: {
    'name': agentName,
    'mode': 'mention',  // ❌ 错误
    'profile_id': profileId,
  });
}
```

### 修复后

```dart
Future<Room> createOneOnOneRoom(String agentName, String agentId) async {
  final response = await dio.post('/rooms', data: {
    'name': agentName,
    'mode': 'direct',  // ✅ 1:1 使用 direct
    'agentIds': [agentId],
  });
}
```

## 3.3 保留的方法

| 方法 | 说明 | 修改 |
|------|------|------|
| loadRooms | 加载所有会话 | 无 |
| createRoom | 创建会话 | 参数变化 |
| createOneOnOneRoom | 创建 1:1 | mode 修正 |
| updateRoom | 更新会话信息 | 无 |
| deleteRoom | 删除会话 | 无 |
| joinByCode | 通过邀请码加入 | 无 |

---

# 4. 辅助属性

## 4.1 Room 辅助方法

```dart
extension RoomExtension on Room {
  bool get is1v1 => type == '1v1' || mode == 'direct';
  bool get isGroup => type == 'group' || mode != 'direct';

  String get displayName {
    if (is1v1) {
      return name;  // 1:1 显示 Agent 名称
    }
    return name;  // 群聊显示群名
  }

  String get subtitle {
    if (is1v1) {
      return lastMessage ?? '';
    }
    return '$memberCount 人 · 在线 $onlineCount';
  }
}
```

## 4.2 列表筛选

```dart
// ChatListTab 中使用
final allRooms = rooms;
final myRooms = rooms.where((r) => r.ownerId == currentUserId);
final teamRooms = rooms.where((r) => r.isGroup && r.memberCount > 2);
final runningRooms = rooms.where((r) => r.hasRunningTasks);
```

---

# 5. 完整修复代码

## 5.1 Room 模型

```dart
class Room {
  final String id;
  final String name;
  final String? avatar;
  final String ownerId;
  final String mode;
  final String? agentId;      // ✅
  final String? profileId;
  final String? inviteCode;
  final int createdAt;

  // ✅ 新增
  final String type;
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
    final agentIds = json['agent_ids'] as List?;
    final type = json['type'] as String? ??
        (agentIds?.length == 1 ? '1v1' : 'group');

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
  bool get isGroup => type == 'group' && mode != 'direct';
}
```

## 5.2 room_provider

```dart
class RoomsNotifier extends StateNotifier<AsyncValue<List<Room>>> {
  final Ref _ref;

  RoomsNotifier(this._ref) : super(const AsyncValue.loading()) {
    loadRooms();
  }

  Future<void> loadRooms() async {
    state = const AsyncValue.loading();
    try {
      final dio = _ref.read(dioProvider);
      final response = await dio.get('/rooms');
      final rooms = (response.data as List)
          .map((json) => Room.fromJson(json))
          .toList();
      state = AsyncValue.data(rooms);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Room> createRoom({
    required String name,
    required List<String> agentIds,
    String mode = 'direct',
  }) async {
    final dio = _ref.read(dioProvider);
    final response = await dio.post('/rooms', data: {
      'name': name,
      'agentIds': agentIds,
      'mode': mode,
    });
    final room = Room.fromJson(response.data);
    await loadRooms();
    return room;
  }

  Future<Room> createOneOnOneRoom(String agentName, String agentId) async {
    return createRoom(
      name: agentName,
      agentIds: [agentId],
      mode: 'direct',
    );
  }

  Future<void> joinByCode(String inviteCode) async {
    final dio = _ref.read(dioProvider);
    await dio.post('/rooms/join', data: {'invite_code': inviteCode});
    await loadRooms();
  }

  Future<void> updateRoom(String roomId, String name) async {
    final dio = _ref.read(dioProvider);
    await dio.put('/rooms/$roomId', data: {'name': name});
    await loadRooms();
  }

  Future<void> deleteRoom(String roomId) async {
    final dio = _ref.read(dioProvider);
    await dio.delete('/rooms/$roomId');
    await loadRooms();
  }
}
```

---

# 6. 实现检查清单

- [ ] Room 模型添加 `agentId` 字段
- [ ] Room 模型添加 `type` 字段
- [ ] Room 模型添加成员信息字段
- [ ] createRoom 添加 `agentIds` 参数
- [ ] createOneOnOneRoom 修正 mode 为 `direct`
- [ ] Room 添加辅助属性 `is1v1`、`isGroup`

---

# 7. 与 PRD v3.1 一致性

| PRD 要求 | 实现 |
|---------|------|
| agent_id 字段 | ✅ Room.agentId |
| type 字段 | ✅ Room.type（计算） |
| createRoom agentIds | ✅ createRoom(agentIds: [...]) |
| createOneOnOneRoom mode=direct | ✅ |
| 成员信息 | ✅ memberCount、onlineCount 等 |