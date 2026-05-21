# agents_directory_screen 修复设计

> Agent 目录页面修复
>
> Version: 1.0
>
> Date: 2026-05-21
>
> 状态: 已完成

---

# 1. 概述

## 1.1 背景

agents_directory_screen 当前实现与 PRD v3.1 存在以下不一致：
1. createOneOnOneRoom 参数错误
2. GatewayStatus 缺少 agentId

## 1.2 修复目标

| 问题 | 当前值 | 目标值 |
|------|--------|--------|
| createOneOnOneRoom | profile_id | agentId |
| GatewayStatus | 缺少 agentId | 添加 |

---

# 2. 问题修复

## 2.1 GatewayStatus 添加 agentId

### 当前代码

```dart
class GatewayStatus {
  final String profile;
  final String? provider;
  final String? model;
  final String? profilePath;
  final bool running;
  final bool hasEnv;
  final bool hasSoul;
  final int skillsCount;
  // ❌ 缺少 agentId
}
```

### 修复后

```dart
class GatewayStatus {
  final String agentId;  // ✅ 新增
  final String profile;
  final String? provider;
  final String? model;
  final String? profilePath;
  final bool running;
  final bool hasEnv;
  final bool hasSoul;
  final int skillsCount;
}
```

### gateway_provider 修改

```dart
// gateway_provider.dart 中 fetchGatewayStatus 需要返回 agentId
class GatewayStatus {
  // ...

  factory GatewayStatus.fromJson(Map<String, dynamic> json, String agentId) {
    return GatewayStatus(
      agentId: agentId,  // ✅
      profile: json['profile'] ?? '',
      // ...
    );
  }
}
```

## 2.2 createOneOnOneRoom 调用修复

### 当前代码

```dart
void _startConversation(BuildContext context) async {
  final room = await ref.read(roomsProvider.notifier).createOneOnOneRoom(
    widget.gateway.profile,    // agentName
    widget.gateway.profile,    // ❌ 错误：应该是 agentId
  );
}
```

### 修复后

```dart
void _startConversation(BuildContext context) async {
  final room = await ref.read(roomsProvider.notifier).createOneOnOneRoom(
    agentName: widget.gateway.profile,  // ✅ Agent 名称
    agentId: widget.gateway.agentId,     // ✅ Agent ID
  );
}
```

## 2.3 room_provider.createOneOnOneRoom 签名

### 当前代码

```dart
Future<Room> createOneOnOneRoom(String agentName, String profileId) async {
  final response = await dio.post('/rooms', data: {
    'name': agentName,
    'mode': 'direct',  // ✅ 已经是 direct
    'profile_id': profileId,  // ❌ 应该是 agentIds
  });
}
```

### 修复后

```dart
Future<Room> createOneOnOneRoom({
  required String agentName,
  required String agentId,
}) async {
  final response = await dio.post('/rooms', data: {
    'name': agentName,
    'mode': 'direct',
    'agentIds': [agentId],  // ✅ 使用 agentIds
  });
}
```

---

# 3. 完整修复代码

## 3.1 agents_directory_screen.dart

```dart
class _AgentCardState extends ConsumerState<_AgentCard> {
  void _startConversation(BuildContext context) async {
    try {
      final room = await ref.read(roomsProvider.notifier).createOneOnOneRoom(
        agentName: widget.gateway.profile,  // ✅
        agentId: widget.gateway.agentId,    // ✅
      );
      if (context.mounted) {
        context.push('/chat/${room.id}?name=${Uri.encodeComponent(room.name)}');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建对话失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
```

## 3.2 GatewayStatus 模型

```dart
class GatewayStatus {
  final String agentId;  // ✅
  final String profile;
  final String? provider;
  final String? model;
  final String? profilePath;
  final bool running;
  final bool hasEnv;
  final bool hasSoul;
  final int skillsCount;

  const GatewayStatus({
    required this.agentId,
    required this.profile,
    this.provider,
    this.model,
    this.profilePath,
    this.running = false,
    this.hasEnv = false,
    this.hasSoul = false,
    this.skillsCount = 0,
  });

  factory GatewayStatus.fromJson(Map<String, dynamic> json, String agentId) {
    return GatewayStatus(
      agentId: agentId,
      profile: json['profile'] ?? '',
      provider: json['provider'],
      model: json['model'],
      profilePath: json['profile_path'],
      running: json['running'] ?? false,
      hasEnv: json['has_env'] ?? false,
      hasSoul: json['has_soul'] ?? false,
      skillsCount: json['skills_count'] ?? 0,
    );
  }
}
```

## 3.3 room_provider.createOneOnOneRoom

```dart
Future<Room> createOneOnOneRoom({
  required String agentName,
  required String agentId,
}) async {
  final dio = _ref.read(dioProvider);
  final response = await dio.post('/rooms', data: {
    'name': agentName,
    'mode': 'direct',
    'agentIds': [agentId],  // ✅
  });
  final room = Room.fromJson(response.data);
  await loadRooms();
  return room;
}
```

---

# 4. 实现检查清单

- [ ] GatewayStatus 添加 agentId 字段
- [ ] gateway_provider 返回 agentId
- [ ] agents_directory_screen 调用 createOneOnOneRoom 使用 agentId
- [ ] room_provider.createOneOnOneRoom 使用 agentIds

---

# 5. 与 PRD v3.1 一致性

| PRD 要求 | 实现 |
|---------|------|
| 1:1 mode='direct' | ✅ room_provider 已修复 |
| createOneOnOneRoom agentId | ✅ |
| GatewayStatus.agentId | ✅ |