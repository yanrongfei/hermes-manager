# app_router 修复设计

> 路由配置修复
>
> Version: 1.0
>
> Date: 2026-05-21
>
> 状态: 已完成

---

# 1. 概述

## 1.1 背景

app_router 当前实现与 PRD v3.1 存在以下不一致：
1. 缺少 /chat/create 路由
2. ChatScreen 路由设计需优化

## 1.2 修复目标

| 问题 | 当前值 | 目标值 |
|------|--------|--------|
| /chat/create 路由 | 缺失 | 添加 CreateSessionScreen |
| ChatScreen agents | 通过构造函数传递 | 通过 Provider 获取 |

---

# 2. /chat/create 路由

## 2.1 当前代码

```dart
// app_router.dart
GoRoute(
  path: '/chat/:roomId',
  builder: (context, state) {
    final roomId = state.pathParameters['roomId']!;
    final roomName = state.uri.queryParameters['name'];
    return ChatScreen(roomId: roomId, roomName: roomName);
  },
),
```

## 2.2 修复后

```dart
GoRoute(
  path: '/chat/create',
  builder: (context, state) => const CreateSessionScreen(),
),
GoRoute(
  path: '/chat/:roomId',
  builder: (context, state) {
    final roomId = state.pathParameters['roomId']!;
    final roomName = state.uri.queryParameters['name'];
    return ChatScreen(roomId: roomId, roomName: roomName);
  },
),
```

## 2.3 CreateSessionScreen 导航

```dart
// CreateSessionScreen 中创建成功后的跳转
onPressed: () async {
  final room = await createSession(...);
  if (context.mounted) {
    context.go('/chat/${room.id}?name=${Uri.encodeComponent(room.name)}');
  }
}
```

---

# 3. ChatScreen 路由优化

## 3.1 当前实现问题

```dart
class ChatScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String? roomName;
  final List<Message> agents;  // ❌ 类型错误

  const ChatScreen({
    super.key,
    required this.roomId,
    this.roomName,
    this.agents = const [],
  });
```

## 3.2 ChatScreen 修改

### 构造函数简化

```dart
class ChatScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String? roomName;  // For 1:1 chats

  const ChatScreen({
    super.key,
    required this.roomId,
    this.roomName,
  });
```

### initState 中获取 room

```dart
class _ChatScreenState extends ConsumerState<ChatScreen> {
  Room? _room;
  List<AgentInfo> _agents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRoom();
  }

  Future<void> _loadRoom() async {
    final roomService = ref.read(roomProvider);
    final room = await roomService.getRoom(widget.roomId);
    setState(() {
      _room = room;
      _agents = room?.agents ?? [];
      _isLoading = false;
    });
  }

  bool get is1v1 => _room?.mode == 'direct';
  bool get isGroup => _room?.mode != 'direct';
```

## 3.3 build 中使用

```dart
@override
Widget build(BuildContext context) {
  if (_isLoading) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }

  return Scaffold(
    appBar: AppBar(
      // 根据 is1v1 / isGroup 条件渲染
      title: Text(is1v1 ? widget.roomName ?? '' : _room?.name ?? ''),
      // ...
    ),
    body: Column(
      children: [
        // 成员预览（仅群聊）
        if (isGroup) _MembersPreviewBar(agents: _agents),

        // @ 选择器
        if (isGroup && _showMentionPicker)
          _MentionPicker(
            agents: _agents,
            onSelect: _insertMention,
            onDismiss: () => setState(() => _showMentionPicker = false),
          ),

        // 输入框
        _buildInputBar(),
      ],
    ),
  );
}
```

---

# 4. AgentInfo 模型

## 4.1 创建 AgentInfo

```dart
// data/models/agent_info.dart
class AgentInfo {
  final String id;
  final String name;
  final String? avatar;
  final bool isOnline;
  final String? gatewayAddress;

  const AgentInfo({
    required this.id,
    required this.name,
    this.avatar,
    this.isOnline = false,
    this.gatewayAddress,
  });

  factory AgentInfo.fromJson(Map<String, dynamic> json) {
    return AgentInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      avatar: json['avatar'] as String?,
      isOnline: json['is_online'] as bool? ?? false,
      gatewayAddress: json['gateway_address'] as String?,
    );
  }
}
```

## 4.2 Room 模型扩展

```dart
// data/models/room.dart
class Room {
  // ... 现有字段
  final List<AgentInfo> agents;

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      // ... 现有字段
      agents: (json['agents'] as List<dynamic>?)
          ?.map((e) => AgentInfo.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
}
```

---

# 5. 完整路由配置

## 5.1 修复后代码

```dart
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/gateways',
        builder: (context, state) => const GatewaysScreen(),
      ),
      GoRoute(
        path: '/agents',
        builder: (context, state) => const AgentsDirectoryScreen(),
      ),
      GoRoute(
        path: '/skills',
        builder: (context, state) => const SkillsScreen(),
      ),
      GoRoute(
        path: '/plugins',
        builder: (context, state) => const PluginsScreen(),
      ),
      GoRoute(
        path: '/models',
        builder: (context, state) => const ModelsScreen(),
      ),
      GoRoute(
        path: '/chat/create',  // ✅ 新增
        builder: (context, state) => const CreateSessionScreen(),
      ),
      GoRoute(
        path: '/chat/:roomId',
        builder: (context, state) {
          final roomId = state.pathParameters['roomId']!;
          final roomName = state.uri.queryParameters['name'];
          return ChatScreen(roomId: roomId, roomName: roomName);
        },
      ),
    ],
  );
});
```

---

# 6. CreateSessionScreen 创建

## 6.1 基本结构

```dart
class CreateSessionScreen extends ConsumerWidget {
  const CreateSessionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('新建会话'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _CreateSessionBody(),
    );
  }
}
```

## 6.2 路由导入

```dart
import '../presentation/screens/create_session_screen.dart';
```

---

# 7. 实现检查清单

- [ ] 创建 AgentInfo 模型
- [ ] 扩展 Room 模型添加 agents 字段
- [ ] 添加 /chat/create 路由
- [ ] ChatScreen 移除 agents 构造函数参数
- [ ] ChatScreen initState 中获取 room
- [ ] ChatScreen 根据 mode 条件渲染
- [ ] 创建 CreateSessionScreen

---

# 8. 与 PRD v3.1 一致性

| PRD 要求 | 实现 |
|---------|------|
| /chat/create 路由 | ✅ 添加 |
| CreateSessionScreen | ✅ 新建 |
| ChatScreen agents 获取 | ✅ 通过 Provider |
| 1:1 vs 群聊区分 | ✅ mode 判断 |