# ChatListTab 修复设计

> 会话列表页面功能修复
>
> Version: 1.0
>
> Date: 2026-05-21
>
> 状态: 已完成

---

# 1. 概述

## 1.1 背景

ChatListTab 当前实现与 PRD v3.1 存在以下不一致：
1. 缺少 Tab 切换（全部/我的/团队/运行中）
2. 新建对话 mode 错误（broadcast → direct）
3. 1:1 vs 群聊 UI 未区分
4. Running Tasks 未实现
5. 缺少 router 模式
6. 头像圆角不匹配

## 1.2 修复目标

| 问题 | 当前值 | 目标值 |
|------|--------|--------|
| Tab 切换 | 无 | 全部/我的/团队/运行中 |
| 新建对话 mode | broadcast | direct |
| 1:1 vs 群聊 UI | 无区分 | 根据 type 区分显示 |
| Running Tasks | 无 | 仅群聊显示 |
| router 模式 | 缺失 | 添加 |
| 头像圆角 | 8dp | 18dp (radius-xl) |

---

# 2. Tab 切换设计

## 2.1 Tab 布局

```
┌─────────────────────────────────────┐
│ Hermes 🔍 搜索 │
├─────────────────────────────────────┤
│ [全部] [我的] [团队] [运行中] │ │ ← Tab
├─────────────────────────────────────┤
│ 列表内容...
```

## 2.2 Tab 状态

| Tab | 筛选条件 | 说明 |
|-----|----------|------|
| 全部 | 无 | 显示所有会话 |
| 我的 | owner_id = 当前用户 | 我创建的会话 |
| 团队 | isTeam = true | 团队群聊 |
| 运行中 | 有 Agent 正在运行 | 群聊中正在处理的会话 |

## 2.3 实现

```dart
class ChatListTab extends ConsumerWidget {
  String _selectedTab = 'all';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // TabBar
        Container(
          color: const Color(0xFF2A2A2A),
          child: Row(
            children: [
              _TabChip(label: '全部', isSelected: _selectedTab == 'all'),
              _TabChip(label: '我的', isSelected: _selectedTab == 'mine'),
              _TabChip(label: '团队', isSelected: _selectedTab == 'team'),
              _TabChip(label: '运行中', isSelected: _selectedTab == 'running'),
            ],
          ),
        ),
        // List
        Expanded(child: _buildFilteredList()),
      ],
    );
  }
}
```

---

# 3. 1:1 vs 群聊 UI 区分

## 3.1 UI 区分设计

### 1:1 会话

```
┌─────────────────────────────────────┐
│ ┌───┐ Claude │ │
│ │ C │ Agent: 已完成代码审查 │ │
│ │ │ 刚刚 │ │
│ └───┘ │ │
└─────────────────────────────────────┘
```

| 元素 | 内容 |
|------|------|
| 头像 | Agent 首字母，颜色 #5856D6 |
| 标题 | Agent 名称 |
| 副标题 | "Agent: 状态" + 时间 |
| 无成员数 | 不显示 |
| 无 Running Tasks | 不显示 |

### 群聊

```
┌─────────────────────────────────────┐
│ ┌───┐ AI Research Team │ │
│ │ A │ 4 人 · 在线 3 │ │
│ │ │ 广播模式 2m ago ●3 │ │
│ └───┘ │ │
└─────────────────────────────────────┘
```

| 元素 | 内容 |
|------|------|
| 头像 | 首字母，颜色 #5856D6 |
| 标题 | 群聊名称 |
| 副标题 | "成员数 · 在线数" |
| 模式标签 | 广播/指定/路由 |
| Running Tasks | "●N" 表示 N 个 Agent 正在运行 |

## 3.2 类型判断

```dart
bool isOneOnOne(Room room) {
  return room.mode == 'direct' || room.agentIds.length == 1;
}

bool isGroupChat(Room room) {
  return room.mode != 'direct' && room.agentIds.length > 1;
}
```

## 3.3 _ChatListItem 修复

```dart
class _ChatListItem extends ConsumerWidget {
  // ...

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final is1v1 = isOneOnOne(room);
    final isGroup = isGroupChat(room);

    return InkWell(
      onTap: () => context.push('/chat/${room.id}?name=${Uri.encodeComponent(room.name)}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // 头像
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF5856D6),
                borderRadius: BorderRadius.circular(18),  // ✅ 18dp
              ),
              child: Center(
                child: Text(
                  room.name.isNotEmpty ? room.name[0].toUpperCase() : 'G',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(room.name, ...),
                      ),
                      Text(_formatTime(room.updatedAt), ...),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (is1v1) ...[
                        Text('Agent: ${room.lastMessagePreview}', ...),
                      ],
                      if (isGroup) ...[
                        Text('${room.memberCount} 人 · 在线 ${room.onlineCount}', ...),
                        if (room.hasRunningTasks)
                          Text(' ●${room.runningTasksCount}', style: TextStyle(color: Color(0xFF34C759))),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

# 4. Running Tasks 设计

## 4.1 显示位置

```
┌─────────────────────────────────────┐
│ │ ← Running Tasks 只在群聊显示
├─────────────────────────────────────┤
│ │
│ ┌───┐ AI Research Team │ │ ← 群聊
│ │ A │ ●3 Agent 正在思考... │ │
│ └─────────────────────────────────┘ │
```

## 4.2 数据来源

```dart
// Room 模型新增字段
class Room {
  final int runningTasksCount;  // 正在运行的任务数
  final bool hasRunningTasks;
}
```

## 4.3 状态指示

| 状态 | 样式 |
|------|------|
| 无运行中 | 不显示 ● |
| 有运行中 | ●N（绿色），N 为任务数 |

---

# 5. 新建对话修复

## 5.1 当前代码

```dart
void _createNewConversation(BuildContext context, WidgetRef ref) async {
  await dio.post('/rooms', data: {'name': '新对话', 'mode': 'broadcast'});
}
```

## 5.2 修复后

```dart
void _createNewConversation(BuildContext context, WidgetRef ref) async {
  // 应该跳转到 CreateSessionScreen 让用户选择 Agent
  context.push('/chat/create');
}
```

**注意**：PRD 要求创建 1:1 时需要选择 Agent，不应该直接创建。

---

# 6. 模式选择修复

## 6.1 当前

```dart
Row(
  children: [
    ChoiceChip(label: '广播模式', selected: selectedMode == 'broadcast'),
    ChoiceChip(label: '指定模式', selected: selectedMode == 'mention'),
    // ❌ 缺少路由
  ],
)
```

## 6.2 修复后

```dart
Row(
  children: [
    ChoiceChip(label: '广播模式', selected: selectedMode == 'broadcast'),
    ChoiceChip(label: '指定模式', selected: selectedMode == 'mention'),
    ChoiceChip(label: '路由模式', selected: selectedMode == 'router'),  // ✅
  ],
)
```

---

# 7. 邀请码加入修复

## 7.1 修复前

```dart
// chat_list_tab.dart:285
_createNewConversation: data: {'name': '新对话', 'mode': 'broadcast'}
```

## 7.2 修复后

```dart
// 应该跳转到 CreateSessionScreen
void _createNewConversation(BuildContext context, WidgetRef ref) {
  context.push('/chat/create');  // ✅
}
```

---

# 8. 视觉规范汇总

| 元素 | 当前值 | 目标值 |
|------|--------|--------|
| Tab 背景 | 无 Tab | #2A2A2A |
| Tab 选中色 | 无 | #5856D6 |
| 头像圆角 | 8dp | 18dp |
| 头像尺寸 | 48x48 | 48x48 |
| 列表项间距 | 12dp vertical | 12dp vertical |
| 空状态文字 | "暂无群聊" | "暂无会话" |

---

# 9. API 变更需求

| API | 变更 |
|-----|------|
| GET /rooms | 返回 `type` 字段（1v1/group） |
| GET /rooms | 返回 `member_count`、`online_count` |
| GET /rooms | 返回 `running_tasks_count` |
| POST /rooms | 支持 `agentIds` 参数 |

---

# 10. 实现检查清单

- [ ] 添加 Tab 切换（全部/我的/团队/运行中）
- [ ] 修改 `_ChatListItem` 区分 1:1 vs 群聊 UI
- [ ] 实现 Running Tasks 显示
- [ ] 添加 router 模式 ChoiceChip
- [ ] 修复头像圆角 8dp → 18dp
- [ ] 修复空状态文字 "暂无群聊" → "暂无会话"
- [ ] 修改 `_createNewConversation` 跳转到 `/chat/create`
- [ ] API 返回 `type`、`member_count`、`online_count`、`running_tasks_count`

---

# 11. 与 PRD v3.1 一致性

| PRD 要求 | 实现 |
|---------|------|
| Tab 切换 | ✅ 全部/我的/团队/运行中 |
| 1:1 和群聊同一列表 | ✅ |
| 1:1 显示 Agent 名称 | ✅ |
| 群聊显示成员数+在线数 | ✅ |
| Running Tasks 仅群聊显示 | ✅ |
| 流式指示点 ●N | ✅ |
| router 模式 | ✅ |
| 头像圆角 18dp | ✅ |