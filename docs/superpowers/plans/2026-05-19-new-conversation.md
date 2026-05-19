# 新建对话功能实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**目标:** 实现与单个 Agent 的 1:1 对话功能，支持编辑名称和删除对话

**架构:** 使用现有 Room 模型（mode: 'mention' 表示 1:1 对话），复用 ChatScreen。Agent 列表页添加"开始对话"按钮触发创建。

**技术栈:** Flutter Riverpod, GoRouter, Dio

---

## 文件结构

| 文件 | 职责 |
|------|------|
| `agents_directory_screen.dart` | Agent 卡片添加"开始对话"按钮 |
| `chat_screen.dart` | 动态标题（agent名 vs 群聊）、编辑名称、删除 |
| `chat_list_tab.dart` | 对话列表显示 agent 头像、支持删除 |
| `room_provider.dart` | 添加 updateRoom、deleteRoom、createOneOnOneRoom 方法 |
| `app_router.dart` | 已有 `/chat/:roomId` 路由 |

---

## Task 1: RoomProvider 添加 createOneOnOneRoom、updateRoom、deleteRoom 方法

**Files:**
- Modify: `hermes-app/lib/data/providers/room_provider.dart`

- [ ] **Step 1: 添加 createOneOnOneRoom 方法**

在 `RoomsNotifier` 类中添加：

```dart
Future<Room> createOneOnOneRoom(String agentName, String agentId) async {
  final dio = _ref.read(dioProvider);
  final response = await dio.post('/rooms', data: {
    'name': agentName,
    'mode': 'mention',
    'agent_id': agentId,
  });
  final room = Room.fromJson(response.data);
  await loadRooms();
  return room;
}
```

- [ ] **Step 2: 添加 updateRoom 方法**

```dart
Future<void> updateRoom(String roomId, String name) async {
  final dio = _ref.read(dioProvider);
  await dio.put('/rooms/$roomId', data: {'name': name});
  await loadRooms();
}
```

- [ ] **Step 3: 添加 deleteRoom 方法**

```dart
Future<void> deleteRoom(String roomId) async {
  final dio = _ref.read(dioProvider);
  await dio.delete('/rooms/$roomId');
  await loadRooms();
}
```

- [ ] **Step 4: 运行 flutter analyze 验证**

```bash
cd hermes-app && flutter analyze lib/data/providers/room_provider.dart
```

Expected: No errors

- [ ] **Step 5: 提交**

```bash
git add hermes-app/lib/data/providers/room_provider.dart
git commit -m "feat(room): add createOneOnOneRoom, updateRoom, deleteRoom methods"
```

---

## Task 2: Agent 列表页添加"开始对话"按钮

**Files:**
- Modify: `hermes-app/lib/presentation/screens/agents_directory_screen.dart`

- [ ] **Step 1: 添加导入**

```dart
import 'package:go_router/go_router.dart';
import '../../data/providers/room_provider.dart';
```

- [ ] **Step 2: 在 _AgentCard 添加"开始对话"按钮**

在 `_AgentCard` 的 `build` 方法中，Row 末尾添加 IconButton：

```dart
if (gateway.running)
  IconButton(
    onPressed: () => _startConversation(context, ref),
    icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF5856D6)),
    tooltip: '开始对话',
  ),
```

- [ ] **Step 3: 添加 _startConversation 方法**

在 `_AgentCard` 类中添加：

```dart
void _startConversation(BuildContext context, WidgetRef ref) async {
  try {
    final room = await ref.read(roomsProvider.notifier).createOneOnOneRoom(
      gateway.profile,
      gateway.profile,
    );
    if (context.mounted) {
      context.push('/chat/${room.id}');
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('创建对话失败: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
```

- [ ] **Step 4: 运行 flutter analyze 验证**

```bash
cd hermes-app && flutter analyze lib/presentation/screens/agents_directory_screen.dart
```

Expected: No errors (可能有 info 级别警告)

- [ ] **Step 5: 提交**

```bash
git add hermes-app/lib/presentation/screens/agents_directory_screen.dart
git commit -m "feat(agents): add start conversation button on agent card"
```

---

## Task 3: ChatScreen 动态标题显示

**Files:**
- Modify: `hermes-app/lib/presentation/screens/chat_screen.dart`

- [ ] **Step 1: 添加 room 状态获取**

在 `_ChatScreenState` 中添加：

```dart
final _roomNameController = TextEditingController();

@override
void dispose() {
  _roomNameController.dispose();
  super.dispose();
}
```

- [ ] **Step 2: 修改标题栏逻辑**

找到 AppBar 的 `title` 字段，改为根据 room mode 条件显示：

```dart
title: GestureDetector(
  onTap: () => _showEditNameDialog(context),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CircleAvatar(
        radius: 14,
        backgroundColor: const Color(0xFF5856D6),
        child: Text(
          widget.agents.isNotEmpty ? widget.agents.first.senderName[0].toUpperCase() : '?',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        widget.agents.isNotEmpty ? widget.agents.first.senderName : '群聊',
        style: const TextStyle(color: Color(0xFFECECEC), fontSize: 16),
      ),
      const SizedBox(width: 4),
      const Icon(Icons.edit, color: Colors.grey, size: 14),
    ],
  ),
),
```

- [ ] **Step 3: 添加 _showEditNameDialog 方法**

```dart
void _showEditNameDialog(BuildContext context) {
  _roomNameController.text = widget.agents.isNotEmpty
      ? widget.agents.first.senderName
      : '群聊';

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF2A2A2A),
      title: const Text('编辑对话名称', style: TextStyle(color: Color(0xFFECECEC))),
      content: TextField(
        controller: _roomNameController,
        style: const TextStyle(color: Color(0xFFECECEC)),
        decoration: InputDecoration(
          hintText: '输入对话名称',
          hintStyle: TextStyle(color: Colors.grey[600]),
          filled: true,
          fillColor: const Color(0xFF343541),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        TextButton(
          onPressed: () async {
            final newName = _roomNameController.text.trim();
            if (newName.isNotEmpty) {
              await ref.read(chatProvider(widget.roomId).notifier).updateRoomName(newName);
              if (ctx.mounted) Navigator.pop(ctx);
            }
          },
          child: const Text('保存'),
        ),
      ],
    ),
  );
}
```

注意：需要先在 ChatNotifier 中添加 updateRoomName 方法（见 Task 4）

- [ ] **Step 4: 运行 flutter analyze 验证**

```bash
cd hermes-app && flutter analyze lib/presentation/screens/chat_screen.dart
```

Expected: 可能提示 `updateRoomName` 未定义（下一步添加）

- [ ] **Step 5: 提交**

```bash
git add hermes-app/lib/presentation/screens/chat_screen.dart
git commit -m "feat(chat): add dynamic title with edit functionality"
```

---

## Task 4: ChatNotifier 添加 updateRoomName 方法

**Files:**
- Modify: `hermes-app/lib/data/providers/chat_provider.dart`

- [ ] **Step 1: 添加 updateRoomName 方法到 ChatNotifier**

```dart
Future<void> updateRoomName(String name) async {
  final dio = _ref.read(dioProvider);
  await dio.put('/rooms/$roomId', data: {'name': name});
}
```

- [ ] **Step 2: 运行 flutter analyze 验证**

```bash
cd hermes-app && flutter analyze lib/data/providers/chat_provider.dart
```

Expected: No errors

- [ ] **Step 3: 提交**

```bash
git add hermes-app/lib/data/providers/chat_provider.dart
git commit -m "feat(chat): add updateRoomName to ChatNotifier"
```

---

## Task 5: ChatScreen 添加删除功能

**Files:**
- Modify: `hermes-app/lib/presentation/screens/chat_screen.dart`

- [ ] **Step 1: 在 AppBar actions 添加删除按钮**

```dart
actions: [
  PopupMenuButton<String>(
    icon: const Icon(Icons.more_vert, color: Colors.grey),
    color: const Color(0xFF3A3A3A),
    onSelected: (value) {
      if (value == 'delete') _showDeleteConfirmation(context);
    },
    itemBuilder: (context) => [
      const PopupMenuItem(
        value: 'delete',
        child: Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red, size: 18),
            SizedBox(width: 12),
            Text('删除对话', style: TextStyle(color: Color(0xFFECECEC))),
          ],
        ),
      ),
    ],
  ),
],
```

- [ ] **Step 2: 添加 _showDeleteConfirmation 方法**

```dart
void _showDeleteConfirmation(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF2A2A2A),
      title: const Text('删除对话', style: TextStyle(color: Color(0xFFECECEC))),
      content: const Text('确定要删除这个对话吗？', style: TextStyle(color: Color(0xFFECECEC))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        TextButton(
          onPressed: () async {
            Navigator.pop(ctx);
            await ref.read(roomsProvider.notifier).deleteRoom(widget.roomId);
            if (context.mounted) GoRouter.of(context).go('/home');
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('删除'),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 3: 添加导入**

```dart
import 'package:go_router/go_router.dart';
import '../../data/providers/room_provider.dart';
```

- [ ] **Step 4: 运行 flutter analyze 验证**

```bash
cd hermes-app && flutter analyze lib/presentation/screens/chat_screen.dart
```

Expected: No errors

- [ ] **Step 5: 提交**

```bash
git add hermes-app/lib/presentation/screens/chat_screen.dart
git commit -m "feat(chat): add delete conversation functionality"
```

---

## Task 6: 对话列表支持删除（可选：左滑删除）

**Files:**
- Modify: `hermes-app/lib/presentation/screens/chat_list_tab.dart`

- [ ] **Step 1: 修改 _ChatListItem 支持左滑删除**

将 `_ChatListItem` 改为使用 `Dismissible`：

```dart
class _ChatListItem extends StatelessWidget {
  final dynamic room;

  const _ChatListItem({required this.room});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(room.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF2A2A2A),
            title: const Text('删除对话', style: TextStyle(color: Color(0xFFECECEC))),
            content: Text('确定删除"${room.name}"吗？', style: const TextStyle(color: Color(0xFFECECEC))),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('删除'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        // Use roomsProvider from parent
      },
      child: InkWell(
        onTap: () => context.push('/chat/${room.id}'),
        child: Container(
          // ... existing content
        ),
      ),
    );
  }
}
```

注意：需要通过 callback 将删除事件传递给父组件，或者使用 `ProviderScope` 访问 `roomsProvider`

- [ ] **Step 2: 运行 flutter analyze 验证**

```bash
cd hermes-app && flutter analyze lib/presentation/screens/chat_list_tab.dart
```

Expected: No errors

- [ ] **Step 3: 提交**

```bash
git add hermes-app/lib/presentation/screens/chat_list_tab.dart
git commit -m "feat(chatlist): add swipe-to-delete for conversations"
```

---

## 实施顺序

1. Task 1: RoomProvider 方法（基础）
2. Task 2: Agent 列表"开始对话"按钮（验证创建流程）
3. Task 3 & 4: ChatScreen 动态标题（并行）
4. Task 5: 删除功能
5. Task 6: 列表删除（可选）
