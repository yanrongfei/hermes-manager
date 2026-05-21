# chat_provider 修复设计

> ChatProvider WebSocket 事件处理修复
>
> Version: 1.0
>
> Date: 2026-05-21
>
> 状态: 已完成

---

# 1. 概述

## 1.1 背景

chat_provider 当前实现与 PRD v3.1 存在以下不一致：
1. agent_busy 事件未处理
2. sendMessage 缺少 roomId
3. sendAbort 缺少 roomId
4. sendTyping/stopTyping 缺少 roomId

## 1.2 修复目标

| 问题 | 当前值 | 目标值 |
|------|--------|--------|
| agent_busy 事件 | 未处理 | 处理并显示 Toast |
| sendMessage | 无 roomId | 添加 roomId |
| sendAbort | 无 roomId | 添加 roomId |
| sendTyping | 无 data | 添加 roomId |
| sendStopTyping | 无 data | 添加 roomId |

---

# 2. agent_busy 处理

## 2.1 当前代码

```dart
switch (event) {
  case 'message': ...
  case 'message.delta': ...
  case 'reasoning.delta': ...
  case 'tool.started': ...
  case 'tool.completed': ...
  case 'tool.error': ...
  case 'run.started': ...
  case 'run.completed': ...
  case 'run.failed': ...
  case 'abort.started': ...
  case 'abort.completed': ...
  case 'context_status': ...
  case 'queue_updated': ...
  // ❌ 缺少 agent_busy
}
```

## 2.2 修复后

```dart
case 'agent_busy':
  _handleAgentBusy();
  break;
case 'queue_updated':
  state = state.copyWith(queueLength: payload['queueLength'] as int? ?? 0);
  break;
```

## 2.3 _handleAgentBusy 实现

```dart
void _handleAgentBusy() {
  // 通过 GlobalKey 或 ToastManager 显示 Toast
  // 需要传入 context，这里使用 overlay 方式
  debugPrint('[ChatNotifier] Agent busy event received');

  // 可选：标记状态或触发 UI 更新
  // 如果 ChatScreen 需要根据此事件显示提示，可以在 state 中添加标记
  // state = state.copyWith(agentBusy: true);
}
```

## 2.4 事件 payload

```dart
// PRD v3.1 定义
// agent_busy: {}  // 空 payload
```

---

# 3. sendMessage 修复

## 3.1 当前代码

```dart
void sendMessage(String content) {
  if (_channel == null) return;
  _channel!.sink.add(jsonEncode({
    'event': 'message',
    'data': {'content': content},
  }));
}
```

## 3.2 修复后

```dart
void sendMessage(String content) {
  if (_channel == null) return;
  _channel!.sink.add(jsonEncode({
    'event': 'message',
    'data': {
      'roomId': roomId,
      'content': content,
    },
  }));
}
```

## 3.3 payload 格式

```json
{
  "event": "message",
  "data": {
    "roomId": "room-id",
    "content": "消息内容"
  }
}
```

---

# 4. sendAbort 修复

## 4.1 当前代码

```dart
void sendAbort() {
  if (_channel == null) return;
  _channel!.sink.add(jsonEncode({'event': 'abort', 'data': {}}));
}
```

## 4.2 修复后

```dart
void sendAbort() {
  if (_channel == null) return;
  _channel!.sink.add(jsonEncode({
    'event': 'abort',
    'data': {'roomId': roomId},
  }));
}
```

## 4.3 payload 格式

```json
{
  "event": "abort",
  "data": {
    "roomId": "room-id"
  }
}
```

---

# 5. sendTyping/stopTyping 修复

## 5.1 当前代码

```dart
void sendTyping() {
  if (_channel == null) return;
  _channel!.sink.add(jsonEncode({'event': 'typing'}));
}

void sendStopTyping() {
  if (_channel == null) return;
  _channel!.sink.add(jsonEncode({'event': 'stop_typing'}));
}
```

## 5.2 修复后

```dart
void sendTyping() {
  if (_channel == null) return;
  _channel!.sink.add(jsonEncode({
    'event': 'typing',
    'data': {'roomId': roomId},
  }));
}

void sendStopTyping() {
  if (_channel == null) return;
  _channel!.sink.add(jsonEncode({
    'event': 'stop_typing',
    'data': {'roomId': roomId},
  }));
}
```

## 5.3 payload 格式

```json
{
  "event": "typing",
  "data": {"roomId": "room-id"}
}
```

```json
{
  "event": "stop_typing",
  "data": {"roomId": "room-id"}
}
```

---

# 6. ChatState 扩展（可选）

## 6.1 新增字段

```dart
class ChatState {
  // ... 现有字段
  final bool agentBusy;  // Agent 正忙标记

  ChatState({
    // ... 现有字段
    this.agentBusy = false,
  });
}
```

## 6.2 copyWith 扩展

```dart
ChatState copyWith({
  // ... 现有参数
  bool? agentBusy,
}) {
  return ChatState(
    // ... 现有字段
    agentBusy: agentBusy ?? this.agentBusy,
  );
}
```

## 6.3 agent_busy 处理

```dart
case 'agent_busy':
  state = state.copyWith(agentBusy: true);
  break;
```

---

# 7. 完整修复代码对照

## 7.1 switch 事件处理

```dart
switch (event) {
  case 'message':
    _handleNewMessage(payload);
    break;
  case 'message.delta':
    _handleDelta(payload);
    break;
  case 'reasoning.delta':
    _handleReasoningDelta(payload);
    break;
  case 'tool.started':
    _handleToolStarted(payload);
    break;
  case 'tool.completed':
    _handleToolCompleted(payload);
    break;
  case 'tool.error':
    _handleToolError(payload);
    break;
  case 'run.started':
    _handleRunStarted(payload);
    break;
  case 'run.completed':
    _handleRunCompleted(payload);
    break;
  case 'run.failed':
    _handleRunFailed(payload);
    break;
  case 'abort.started':
    _handleAbortStarted(payload);
    break;
  case 'abort.completed':
    _handleAbort(payload);
    break;
  case 'context_status':
    state = state.copyWith(compressingStatus: payload['status'] as String?);
    break;
  case 'queue_updated':
    state = state.copyWith(queueLength: payload['queueLength'] as int? ?? 0);
    break;
  case 'agent_busy':  // ✅ 新增
    state = state.copyWith(agentBusy: true);
    break;
}
```

## 7.2 sendMessage

```dart
void sendMessage(String content) {
  if (_channel == null) return;
  _channel!.sink.add(jsonEncode({
    'event': 'message',
    'data': {
      'roomId': roomId,  // ✅ 新增
      'content': content,
    },
  }));
}
```

## 7.3 sendAbort

```dart
void sendAbort() {
  if (_channel == null) return;
  _channel!.sink.add(jsonEncode({
    'event': 'abort',
    'data': {'roomId': roomId},  // ✅ 新增
  }));
}
```

## 7.4 sendTyping/sendStopTyping

```dart
void sendTyping() {
  if (_channel == null) return;
  _channel!.sink.add(jsonEncode({
    'event': 'typing',
    'data': {'roomId': roomId},  // ✅ 新增
  }));
}

void sendStopTyping() {
  if (_channel == null) return;
  _channel!.sink.add(jsonEncode({
    'event': 'stop_typing',
    'data': {'roomId': roomId},  // ✅ 新增
  }));
}
```

---

# 8. 实现检查清单

- [ ] 添加 `agent_busy` 事件处理
- [ ] sendMessage 添加 roomId
- [ ] sendAbort 添加 roomId
- [ ] sendTyping 添加 roomId
- [ ] sendStopTyping 添加 roomId
- [ ] ChatState 可选添加 `agentBusy` 字段

---

# 9. 与 PRD v3.1 一致性

| PRD 要求 | 实现 |
|---------|------|
| WebSocket 统一 camelCase | ✅ roomId/messageId/runId |
| agent_busy 事件处理 | ✅ 添加 case |
| join 事件 roomId | ✅ 已一致 |
| message 事件 roomId | ✅ sendMessage 添加 |
| abort 事件 roomId | ✅ sendAbort 添加 |
| typing 事件 roomId | ✅ sendTyping 添加 |
| stop_typing 事件 roomId | ✅ sendStopTyping 添加 |