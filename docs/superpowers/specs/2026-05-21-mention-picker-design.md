# @ Agent 选择器详细设计

> MentionPicker 组件修复与优化
>
> Version: 1.0
>
> Date: 2026-05-21
>
> 状态: 已完成

---

# 1. 概述

## 1.1 背景

当前 @ Agent 选择器存在以下问题：
1. 使用 `List<Message>` 作为 Agent 列表数据源，类型错误
2. 1:1 模式下错误显示 @ 按钮
3. Agent 信息来源不明确
4. UI 缺少头像和状态显示

## 1.2 修复目标

| 问题 | 修复目标 |
|------|----------|
| 数据源类型错误 | 使用 `List<AgentInfo>` |
| 1:1 显示 @ 按钮 | 根据 mode 条件隐藏 |
| Agent 来源不明确 | 从 roomProvider 获取 |
| UI 缺少信息 | 显示头像 + 在线状态 |

---

# 2. 数据模型设计

## 2.1 AgentInfo 模型

```dart
class AgentInfo {
  final String id;           // Agent ID
  final String name;         // Agent 名称
  final String? avatar;      // 头像 URL（可选）
  final bool isOnline;       // 在线状态
  final String? gatewayAddress;  // Gateway 地址（可选）

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

## 2.2 Room 模型扩展

```dart
class Room {
  // ... 现有字段
  final List<AgentInfo> agents;  // 新增：Room 关联的 Agent 列表

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

# 3. @ 触发逻辑设计

## 3.1 触发条件

| 条件 | 说明 |
|------|------|
| 输入 `@` 字符 | 用户输入 @ |
| @ 后无空格 | `@` 后面没有空格或换行 |
| 光标位置 > 0 | 不在文本开头 |
| 不是 1:1 会话 | mode != 'direct' |

## 3.2 状态定义

```dart
class ChatScreenState {
  bool _showMentionPicker = false;
  String _mentionQuery = '';
  List<AgentInfo> _filteredAgents = [];
}
```

## 3.3 触发流程

```
用户输入字符
    │
    ▼
onTextChanged(text)
    │
    ├── 光标位置 <= 0 → 关闭选择器
    │
    ├── 检测到 @ →
    │     ├── @ 后有空格/换行 → 关闭选择器
    │     └── @ 后无空格/换行 →
    │           ├── 显示选择器
    │           ├── 过滤 Agent 列表
    │           └── 保存查询词
    │
    └── 无 @ → 关闭选择器
```

---

# 4. 选择器 UI 设计

## 4.1 布局结构

```
┌─────────────────────────────────────┐
│  联系人                    ✕        │ ← Header：32dp 高度
├─────────────────────────────────────┤
│  🔍 搜索                          │ ← 搜索框（可选）
├─────────────────────────────────────┤
│  ┌───────────────────────────────┐  │
│  │ 🤖 ResearchAgent        🟢   │  │ ← Agent 列表项
│  └───────────────────────────────┘  │
│  ┌───────────────────────────────┐  │
│  │ 🤖 CodeAssistant        🟢   │  │
│  └───────────────────────────────┘  │
│  ┌───────────────────────────────┐  │
│  │ 🤖 DocWriter            ⚫   │  │ ← 离线状态
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
        maxHeight: 240dp
        width: 与输入框同宽
```

---

## 4.2 列表项设计

```
┌───────────────────────────────┐
│ 🤖 ResearchAgent        🟢   │
│    在线                       │
└───────────────────────────────┘
         height: 56dp
         padding: 12dp
```

### 元素说明

| 元素 | 内容 | 样式 |
|------|------|------|
| 头像 | 🤖 或 Agent 头像图片 | 40x40，圆角 20dp |
| 名称 | Agent 名称 | 16px，600，#F2F2F7 |
| 在线状态 | 🟢/⚫ + 文字 | 12px，#8E8E93 |
| 分割线 | 底部分隔线 | 1px，#3A3A3C |

---

## 4.3 选中状态高亮

```
┌───────────────────────────────┐
│ 🤖 ResearchAgent        🟢   │ ← 选中背景：#262626
└───────────────────────────────┘
```

---

## 4.4 搜索高亮

```
┌───────────────────────────────┐
│ 🤖 Re**search**Agent    🟢   │ ← 匹配文字高亮：#5856D6
└───────────────────────────────┘
```

---

## 4.5 视觉规范

| 属性 | 值 |
|------|---|
| 容器背景 | #2A2A2A |
| 圆角（顶部） | 14dp |
| 圆角（底部） | 14dp |
| 最大高度 | 240dp |
| 内边距 | 12dp |
| 列表项高度 | 56dp |
| 头像尺寸 | 40x40 |
| 头像圆角 | 20dp |
| 在线颜色 | #34C759 |
| 离线颜色 | #8E8E93 |
| 选中背景 | #262626 |
| 分割线 | #3A3A3C |

---

# 5. 文本插入逻辑

## 5.1 插入规则

| 输入 | 插入结果 |
|------|----------|
| 用户输入 `@` 后选择 Agent | `@ResearchAgent ` |

**注意**：插入后自动添加空格，避免连写。

## 5.2 光标位置

```
@ResearchAgent|    ← 光标位置在空格后
```

## 5.3 代码实现

```dart
void _insertMention(String agentName) {
  final text = _messageController.text;
  final cursorPos = _messageController.selection.baseOffset;
  final textBefore = text.substring(0, cursorPos);
  final atIndex = textBefore.lastIndexOf('@');

  // 替换 @ 和查询内容为 @AgentName +
  final newText = text.substring(0, atIndex) +
                  '@$agentName ' +
                  text.substring(cursorPos);

  _messageController.value = TextEditingValue(
    text: newText,
    selection: TextSelection.collapsed(
      offset: atIndex + agentName.length + 2,  // +2 是 @ 和空格
    ),
  );

  setState(() {
    _showMentionPicker = false;
    _mentionQuery = '';
  });

  _focusNode.requestFocus();
}
```

---

# 6. 条件显示逻辑

## 6.1 @ 按钮显示条件

```dart
// 在 ChatScreen 中
final isGroupChat = room.mode != 'direct';  // 或 agentIds.length > 1

// 输入栏 @ 按钮
if (isGroupChat) ... @Button ...

// @ 触发检测
if (isGroupChat) {
  // 只有群聊才检测 @ 触发
  _onTextChanged(text);
}
```

## 6.2 PRD v3.1 要求对照

| 场景 | PRD 要求 | 实现 |
|------|----------|------|
| 1:1 聊天 | 无 @ 按钮 | `isGroupChat = mode != 'direct'` |
| 群聊 | 有 @ 按钮 | 显示 @Button |
| @ 触发 | 只在群聊生效 | `_onTextChanged` 中检测 |

---

# 7. 完整交互流程

```
┌─────────────────────────────────────┐
│  用户在输入框输入 "@"              │
└─────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────┐
│  检测条件：                        │
│  - mode != 'direct' (群聊)         │
│  - @ 后无空格/换行                │
│  - 光标位置 > 0                   │
└─────────────────────────────────────┘
                │
        ┌──────┴──────┐
        │             │
        ▼             ▼
    ┌─────┐      ┌────────┐
    │ 不  │      │  显示   │
    │ 显示│      │ Mention │
    │ 选择器│     │ Picker  │
    └─────┘      └────────┘
                      │
                      ▼
┌─────────────────────────────────────┐
│  用户输入更多字符 "Re"             │
│  → 过滤 Agent 列表                 │
│  → 高亮匹配文字                    │
└─────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────┐
│  用户点击 Agent 或按 Tab           │
└─────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────┐
│  _insertMention("ResearchAgent")   │
│  → 文本替换                         │
│  → 光标定位                         │
│  → 关闭选择器                      │
└─────────────────────────────────────┘
```

---

# 8. 技术实现注意事项

## 8.1 数据获取

```dart
// ChatScreen initState 中
Future<void> _loadRoomAgents() async {
  // 通过 roomProvider 获取 Room 的 Agent 列表
  final room = await ref.read(roomProvider).getRoom(widget.roomId);
  setState(() {
    _agents = room.agents;
    _filteredAgents = _agents;
  });
}
```

## 8.2 过滤逻辑

```dart
List<AgentInfo> _filterAgents(String query) {
  if (query.isEmpty) return _agents;
  return _agents.where((agent) {
    return agent.name.toLowerCase().contains(query.toLowerCase());
  }).toList();
}
```

## 8.3 防止在 1:1 中触发

```dart
void _onTextChanged(String value) {
  if (!_isGroupChat) return;  // 1:1 不触发

  // ... 现有逻辑
}
```

---

# 9. 与现有设计的差异

| 项目 | 现有实现 | 修复后 |
|------|----------|--------|
| 数据类型 | `List<Message>` | `List<AgentInfo>` |
| 数据来源 | 路由参数传递 | `roomProvider` 获取 |
| @ 按钮 | 所有 ChatScreen 显示 | 仅群聊显示 |
| 头像 | 无 | 显示 Agent 头像 |
| 状态 | 无 | 显示在线/离线 |
| 搜索高亮 | 无 | 高亮匹配文字 |

---

# 10. 实现检查清单

- [ ] 创建 `AgentInfo` 模型
- [ ] 扩展 `Room` 模型添加 `agents` 字段
- [ ] 修改 ChatScreen 获取 Agent 列表逻辑
- [ ] 根据 `mode != 'direct'` 条件显示 @ 按钮
- [ ] 在 `_onTextChanged` 中检测 @ 触发
- [ ] 实现 `_MentionPicker` UI 优化
- [ ] 实现 `_insertMention` 文本插入
- [ ] 测试 1:1 模式不显示 @ 按钮
- [ ] 测试群聊 @ 触发正常