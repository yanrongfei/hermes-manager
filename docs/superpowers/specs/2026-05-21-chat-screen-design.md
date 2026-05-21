# ChatScreen 修复设计

> 聊天页面功能修复
>
> Version: 1.0
>
> Date: 2026-05-21
>
> 状态: 已完成

---

# 1. 概述

## 1.1 背景

ChatScreen 当前实现与 PRD v3.1 存在以下不一致：
1. 1:1 AppBar 不简洁（有编辑功能）
2. 成员预览缺失
3. Running Tasks 未区分 mode
4. agent_busy 未处理
5. Queue Indicator 在 1:1 显示
6. @ 按钮位置错误
7. 缺少成员列表入口

## 1.2 修复目标

| 问题 | 当前值 | 目标值 |
|------|--------|--------|
| 1:1 AppBar | 有编辑图标 | 简洁，只有返回+名称 |
| 成员预览 | 无 | 群聊 AppBar 下方显示 |
| Running Tasks | 全部显示 | 仅群聊显示 |
| agent_busy | 未处理 | 显示 Toast |
| Queue Indicator | 全部显示 | 仅群聊显示 |
| @ 按钮 | 附件按钮 | 输入框右边 |
| 成员列表入口 | 无 | AppBar 添加 |

---

# 2. AppBar 设计

## 2.1 1:1 AppBar

```
┌─────────────────────────────────────┐
│ ← Claude ✕ │ │ ← 简洁 AppBar
└─────────────────────────────────────┘
```

**元素**：
| 元素 | 说明 |
|------|------|
| 返回按钮 | Icons.arrow_back |
| 标题 | Agent 名称 |
| 关闭按钮 | Icons.close（结束对话） |
| 无编辑 | ❌ 无编辑图标 |

**代码**：
```dart
if (is1v1) ...[
  leading: IconButton(icon: Icons.arrow_back, onPressed: () => Navigator.pop(context)),
  title: Text(agentName, style: TextStyle(color: Color(0xFFECECEC))),
  actions: [
    IconButton(icon: Icons.close, onPressed: () => _showCloseConfirmation()),
  ],
]
```

## 2.2 群聊 AppBar

```
┌─────────────────────────────────────┐
│ ← AI Research Team 4人 ⋮ │ │ ← 完整 AppBar
└─────────────────────────────────────┘
```

**元素**：
| 元素 | 说明 |
|------|------|
| 返回按钮 | Icons.arrow_back |
| 标题 | 群聊名称 |
| 成员数 | "{count}人" |
| 更多按钮 | ⋮ (more_vert) |

**代码**：
```dart
if (isGroupChat) ...[
  leading: IconButton(icon: Icons.arrow_back, onPressed: () => Navigator.pop(context)),
  title: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(roomName, style: TextStyle(color: Color(0xFFECECEC))),
      Text(' $memberCount人', style: TextStyle(color: Colors.grey[500])),
    ],
  ),
  actions: [
    IconButton(icon: Icons.people_outline, onPressed: () => _showMembersSheet()),
    PopupMenuButton(...),  // 更多菜单
  ],
]
```

---

# 3. 成员预览设计

## 3.1 位置

在 AppBar 下方，消息列表上方：

```
┌─────────────────────────────────────┐
│ ← AI Research Team 4人 ⋮ │
├─────────────────────────────────────┤
│ 👤👤🤖🤖 4 在线 │ │ ← 成员预览
├─────────────────────────────────────┤
│ 消息列表...
```

## 3.2 显示规则

| 类型 | 显示 |
|------|------|
| 1:1 | 不显示成员预览 |
| 群聊 | 显示成员头像 + 在线数 |

## 3.3 实现

```dart
// AppBar 下方添加
if (isGroupChat) ...[
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    color: const Color(0xFF2A2A2A),
    child: Row(
      children: [
        // 头像列表（最多显示 4 个）
        ...memberAvatars.take(4).map((avatar) => Padding(
          padding: const EdgeInsets.only(right: 4),
          child: avatar,
        )),
        const SizedBox(width: 8),
        Text(
          '$onlineCount 在线',
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
        const Spacer(),
        TextButton(
          onPressed: () => _showMembersSheet(),
          child: Text('查看全部', style: TextStyle(color: Color(0xFF5856D6), fontSize: 12)),
        ),
      ],
    ),
  ),
]
```

---

# 4. Running Tasks 条件显示

## 4.1 当前代码

```dart
if (hasRunningAgents)
  _RunningAgentsBar(...)
```

## 4.2 修复后

```dart
// 只有群聊才显示 Running Tasks
if (isGroupChat && hasRunningAgents)
  _RunningAgentsBar(...)
```

**1:1 模式**：
- 不显示 Running Tasks
- Agent 忙碌时直接发送 `agent_busy` 事件

---

# 5. Queue Indicator 条件显示

## 5.1 当前代码

```dart
if (chatState.queueLength > 0)
  Container(
    child: Text('${chatState.queueLength} 条消息等待中...'),
  )
```

## 5.2 修复后

```dart
// 只有群聊才显示队列提示
if (isGroupChat && chatState.queueLength > 0)
  Container(...)
```

---

# 6. agent_busy 处理

## 6.1 chat_provider 中添加处理

```dart
// chat_provider.dart
switch (event) {
  case 'agent_busy':
    // 显示 Toast
    _showAgentBusyToast();
    break;
  // ... 其他事件
}
```

## 6.2 Toast 显示

```dart
void _showAgentBusyToast() {
  // 使用之前设计的 AgentBusyToast 组件
  ToastManager.showAgentBusy(context);
}
```

---

# 7. 输入框设计

## 7.1 1:1 输入框

```
┌─────────────────────────────────────┐
│ ┌───────────────────────────┐📤│
│ │ 输入消息... │ │ ← 无 @ 按钮
│ └───────────────────────────┘ │
└─────────────────────────────────────┘
```

**元素**：
| 元素 | 说明 |
|------|------|
| 输入框 | 多行，hint "输入消息..." |
| 发送按钮 | Icons.send |

**注意**：无 @ 按钮（1:1 不需要）

## 7.2 群聊输入框

```
┌─────────────────────────────────────┐
│ ┌────────────────────────┐ @ │📤│
│ │                        │ │ ← 有 @ 按钮
│ └────────────────────────┘ │
└─────────────────────────────────────┘
```

**元素**：
| 元素 | 说明 |
|------|------|
| 输入框 | 多行，hint "输入消息..." |
| @ 按钮 | Icons.alternate_email |
| 发送按钮 | Icons.send |

## 7.3 实现

```dart
Widget _buildInputBar() {
  final isGroup = isGroupChat;

  return Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: const Color(0xFF2A2A2A),
      border: Border(top: BorderSide(color: const Color(0xFF3A3A3A))),
    ),
    child: SafeArea(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // @ 按钮（仅群聊）
          if (isGroup)
            IconButton(
              icon: const Icon(Icons.alternate_email, color: Color(0xFFA0A0A0)),
              onPressed: () => _showMentionPickerInline(),
            ),
          Flexible(
            child: TextField(
              controller: _messageController,
              focusNode: _focusNode,
              maxLines: 5,
              minLines: 1,
              style: const TextStyle(color: Color(0xFFECECEC)),
              decoration: InputDecoration(
                hintText: '输入消息...',
                hintStyle: TextStyle(color: Colors.grey[600]),
                filled: true,
                fillColor: const Color(0xFF343541),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _onTextChanged,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Color(0xFF5856D6)),
            onPressed: _sendMessage,
          ),
        ],
      ),
    ),
  );
}
```

---

# 8. 成员列表入口

## 8.1 AppBar 添加成员图标

```dart
actions: [
  IconButton(
    icon: const Icon(Icons.people_outline, color: Colors.grey),
    onPressed: () => _showMembersSheet(),
  ),
  PopupMenuButton<String>(...),
]
```

## 8.2 _showMembersSheet 实现

```dart
void _showMembersSheet() {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF2A2A2A),
    builder: (context) => Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('成员 ($memberCount)', style: TextStyle(color: Color(0xFFECECEC), fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(icon: Icons.close, onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 16),
          // 成员列表
          ListView.builder(
            shrinkWrap: true,
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: member.isAgent ? Color(0xFF5856D6) : Color(0xFF34C759),
                  child: Text(member.name[0].toUpperCase()),
                ),
                title: Text(member.name, style: TextStyle(color: Color(0xFFECECEC))),
                subtitle: Text(member.isOnline ? '在线' : '离线', style: TextStyle(color: Colors.grey[500])),
                trailing: member.role != 'member' ? Text(member.role, style: TextStyle(color: Color(0xFF5856D6))) : null,
              );
            },
          ),
        ],
      ),
    ),
  );
}
```

---

# 9. mode 判断

## 9.1 获取 Room 的 mode

```dart
// 在 initState 或 build 中获取
final room = ref.read(roomProvider).getRoom(widget.roomId);
final is1v1 = room.mode == 'direct';
final isGroup = room.mode != 'direct';
```

## 9.2 条件渲染

```dart
// 1:1 模式
final is1v1 = room.mode == 'direct';

// AppBar
if (is1v1) {
  // 简洁 AppBar
} else {
  // 完整 AppBar + 成员预览
}

// Running Tasks
if (isGroup && hasRunningAgents) ..._RunningAgentsBar...

// Queue Indicator
if (isGroup && queueLength > 0) ...Container...

// @ 按钮
if (isGroup) ...IconButton(Icons.alternate_email)...
```

---

# 10. 实现检查清单

- [ ] 1:1 AppBar 简化（移除编辑图标）
- [ ] 群聊 AppBar 显示成员数
- [ ] AppBar 下方添加成员预览（仅群聊）
- [ ] Running Tasks 仅群聊显示
- [ ] Queue Indicator 仅群聊显示
- [ ] chat_provider 添加 agent_busy 处理
- [ ] AgentBusyToast 显示
- [ ] 输入框 @ 按钮（群聊）
- [ ] AppBar 添加成员列表入口

---

# 11. 与 PRD v3.1 一致性

| PRD 要求 | 实现 |
|---------|------|
| 1:1 AppBar 简洁 | ✅ 移除编辑图标 |
| 群聊 AppBar 完整 | ✅ 名称+人数+更多 |
| 成员预览 | ✅ AppBar 下方显示 |
| Running Tasks 仅群聊 | ✅ mode 判断 |
| Queue Indicator 仅群聊 | ✅ mode 判断 |
| agent_busy Toast | ✅ chat_provider 处理 |
| @ 按钮（群聊） | ✅ 条件显示 |
| 成员列表入口 | ✅ AppBar 图标 |