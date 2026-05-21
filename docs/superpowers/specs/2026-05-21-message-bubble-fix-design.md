# MessageBubble 组件修复设计

> 消息气泡组件视觉一致性修复
>
> Version: 1.0
>
> Date: 2026-05-21
>
> 状态: 已完成

---

# 1. 概述

## 1.1 背景

MessageBubble 组件当前实现与 PRD v3.1 及设计系统存在以下不一致：
1. 用户消息颜色不匹配
2. 消息气泡圆角不匹配
3. Agent 头像颜色不匹配
4. Streaming Dots 颜色不匹配
5. Reasoning 最大高度未限制

## 1.2 修复目标

| 问题 | 当前值 | 目标值 |
|------|--------|--------|
| 用户消息背景色 | #543EBE | #7C6CFF |
| 气泡圆角 | 16dp | 18dp (radius-xl) |
| Agent 头像颜色 | #10A37F | #5856D6 |
| Streaming Dots 颜色 | 绿色 | 紫色 (#8E7CFF) |
| Reasoning 最大高度 | 无限制 | 320dp |

---

# 2. 修复详情

## 2.1 用户消息背景色

### 当前代码

```dart
// message_bubble.dart:118
color: isUser ? const Color(0xFF543EBE) : const Color(0xFF343541),
```

### 修复后

```dart
color: isUser ? const Color(0xFF7C6CFF) : const Color(0xFF343541),
```

### 视觉对比

| 状态 | 当前 | 修复后 |
|------|------|--------|
| 用户消息 | 深紫色 #543EBE | 主色 #7C6CFF |

---

## 2.2 气泡圆角

### 当前代码

```dart
// message_bubble.dart:119
borderRadius: BorderRadius.circular(16),
```

### 修复后

```dart
borderRadius: BorderRadius.circular(18),
```

### 视觉对比

| 状态 | 当前 | 修复后 |
|------|------|--------|
| 圆角 | 16dp | 18dp (radius-xl) |

---

## 2.3 Agent 头像颜色

### 当前代码

```dart
// message_bubble.dart:96
backgroundColor: isAgent ? const Color(0xFF10A37F) : const Color(0xFF10A37F),
```

### 修复后

```dart
backgroundColor: isAgent ? const Color(0xFF5856D6) : const Color(0xFF34C759),
```

### 视觉对比

| 角色 | 当前 | 修复后 |
|------|------|--------|
| Agent 头像 | 绿色 #10A37F | 主色 #5856D6 |
| User 头像 | 绿色 #10A37F | 绿色 #34C759（保持） |

---

## 2.4 Streaming Dots 颜色

### 当前代码

```dart
// message_bubble.dart:209
color: Colors.green.withOpacity(opacity.clamp(0.3, 1.0)),
```

### 修复后

```dart
color: const Color(0xFF8E7CFF).withOpacity(opacity.clamp(0.3, 1.0)),
```

### PRD AI Semantic Colors 对照

| Semantic | 颜色 | 用途 |
|----------|------|------|
| reasoning | #8E7CFF | 推理过程 |
| tool-running | #5AC8FA | 工具运行中 |
| streaming | #7C6CFF | 流式消息 |

**选择**：Streaming Dots 使用 `#8E7CFF`（reasoning 语义色），表示 AI 正在思考。

---

## 2.5 Reasoning 最大高度限制

### 当前代码

```dart
// message_bubble.dart:310-318
if (_expanded) ...[
  const SizedBox(height: 8),
  Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(...),
    child: _MarkdownContent(content: widget.reasoning),
  ),
],
```

### 修复后

```dart
if (_expanded) ...[
  const SizedBox(height: 8),
  Container(
    width: double.infinity,
    maxHeight: 320,  // 新增最大高度限制
    constraints: const BoxConstraints(maxHeight: 320),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(...),
    child: SingleChildScrollView(
      child: _MarkdownContent(content: widget.reasoning),
    ),
  ),
],
```

### 视觉规范

| 属性 | 值 |
|------|---|
| 最大高度 | 320dp |
| 溢出处理 | ScrollView |
| 背景 | #1C1C1C |

---

## 2.6 Tool Timeline 默认折叠

### 当前实现

```dart
// message_bubble.dart:341
bool _expanded = false;
```

**状态**：默认折叠 ✅ 已正确实现

### 展开后样式

| 属性 | 值 |
|------|---|
| 背景色 | #2A2A2A |
| 圆角 | 6dp |
| 内边距 | 10dp horizontal, 6dp vertical |
| 展开图标 | expand_less / expand_more |

---

# 3. 完整修复代码对照

## 3.1 _BubbleContent

```dart
// 修复前
Container(
  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  decoration: BoxDecoration(
    color: isUser ? const Color(0xFF543EBE) : const Color(0xFF343541),
    borderRadius: BorderRadius.circular(16),  // ❌
  ),
  // ...
)

// 修复后
Container(
  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  decoration: BoxDecoration(
    color: isUser ? const Color(0xFF7C6CFF) : const Color(0xFF343541),  // ✅
    borderRadius: BorderRadius.circular(18),  // ✅
  ),
  // ...
)
```

## 3.2 _Avatar

```dart
// 修复前
CircleAvatar(
  radius: 16,
  backgroundColor: isAgent ? const Color(0xFF10A37F) : const Color(0xFF10A37F),  // ❌
  // ...
)

// 修复后
CircleAvatar(
  radius: 16,
  backgroundColor: isAgent ? const Color(0xFF5856D6) : const Color(0xFF34C759),  // ✅
  // ...
)
```

## 3.3 _StreamingDots

```dart
// 修复前
color: Colors.green.withOpacity(opacity.clamp(0.3, 1.0)),  // ❌

// 修复后
color: const Color(0xFF8E7CFF).withOpacity(opacity.clamp(0.3, 1.0)),  // ✅
```

## 3.4 _ThinkingBlock

```dart
// 修复前
Container(
  width: double.infinity,
  padding: const EdgeInsets.all(10),
  decoration: BoxDecoration(...),
  child: _MarkdownContent(content: widget.reasoning),  // ❌ 无最大高度限制
),

// 修复后
Container(
  width: double.infinity,
  constraints: const BoxConstraints(maxHeight: 320),  // ✅
  padding: const EdgeInsets.all(10),
  decoration: BoxDecoration(...),
  child: SingleChildScrollView(
    child: _MarkdownContent(content: widget.reasoning),
  ),
),
```

---

# 4. 视觉规范汇总

| 元素 | 属性 | 当前值 | 目标值 | 规范来源 |
|------|------|--------|--------|----------|
| 用户消息背景 | color | #543EBE | #7C6CFF | PRD 4.2.3 |
| 气泡圆角 | radius | 16dp | 18dp | 设计系统 radius-xl |
| Agent 头像 | background | #10A37F | #5856D6 | 设计系统 primary |
| Streaming Dots | color | green | #8E7CFF | 设计系统 reasoning |
| Reasoning | maxHeight | none | 320dp | 设计系统 5.4 |

---

# 5. 实现检查清单

- [ ] 用户消息颜色 `#543EBE` → `#7C6CFF`
- [ ] 气泡圆角 `16` → `18`
- [ ] Agent 头像颜色 `#10A37F` → `#5856D6`
- [ ] Streaming Dots 绿色 → `#8E7CFF`
- [ ] Reasoning 展开添加 `maxHeight: 320` + `SingleChildScrollView`

---

# 6. 与设计系统一致性

| 设计 Token | 组件中使用 |
|------------|-----------|
| radius-xl (18dp) | 气泡圆角 ✅ |
| primary (#5856D6) | Agent 头像、用户消息背景 ✅ |
| text-primary / text-secondary | 文字颜色 ✅ |
| reasoning (#8E7CFF) | Streaming Dots ✅ |
| surface (#1C1C1E) | Reasoning 背景 ✅ |