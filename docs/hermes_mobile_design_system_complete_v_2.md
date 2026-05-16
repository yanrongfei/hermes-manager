# Hermes Mobile
# Complete Design System & Engineering UI Specification

> Hermes AI Operating System Companion App
>
> Version: 2.0
>
> Platform: Flutter / iOS / Android

---

# 1. Design Philosophy

Hermes Mobile 不是传统聊天 App。

它是：

```text
AI Native Multi-Agent Workspace
```

因此设计目标不是：

- 模仿 ChatGPT
- 模仿普通 IM
- 模仿企业后台

而是：

- Streaming Native
- Timeline Native
- Workflow Native
- Multi-Agent Native

---

# 1.1 产品气质

| Trait | Description |
|---|---|
| Calm | 降低 AI 信息焦虑 |
| Fast | 高频 Streaming 反馈 |
| Intelligent | AI Native 体验 |
| Layered | 信息分层 |
| Focused | 降低信息密度 |
| Technical | 工程化专业感 |

---

# 1.2 参考产品

| Product | Reference |
|---|---|
| Linear | 信息层级 |
| Discord | 多 Agent/多人流 |
| Claude Mobile | 长文本体验 |
| Arc Search | AI Native Interaction |
| Notion Mobile | 卡片层级 |
| Perplexity | 搜索式 AI 交互 |

---

# 2. Design Token System

# 2.1 Spacing System

禁止随机 spacing。

统一使用 token。

---

# Base Unit

```text
4dp
```

---

# Spacing Tokens

| Token | Value |
|---|---|
| space-1 | 4 |
| space-2 | 8 |
| space-3 | 12 |
| space-4 | 16 |
| space-5 | 20 |
| space-6 | 24 |
| space-8 | 32 |
| space-10 | 40 |
| space-12 | 48 |
| space-16 | 64 |

---

# Usage Rules

| Usage | Token |
|---|---|
| Card Padding | space-4 |
| Section Gap | space-6 |
| Bubble Padding | space-4 |
| Timeline Gap | space-5 |
| Screen Horizontal | space-4 |

---

# Flutter Example

```dart
class AppSpacing {
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
}
```

---

# 2.2 Radius System

# Radius Tokens

| Token | Value |
|---|---|
| radius-sm | 8 |
| radius-md | 14 |
| radius-lg | 18 |
| radius-xl | 22 |
| radius-2xl | 28 |
| radius-full | 999 |

---

# Usage

| Component | Radius |
|---|---|
| Button | radius-md |
| Input | radius-lg |
| Message Bubble | radius-xl |
| Card | radius-xl |
| Bottom Sheet | radius-2xl |

---

# 2.3 Typography System

# Font Family

```text
Inter
```

中文：

```text
PingFang SC
```

---

# Typography Scale

| Token | Size | Weight | Line Height | Usage |
|---|---|---|---|---|
| display-large | 34 | 700 | 40 | Hero |
| display-medium | 28 | 700 | 34 | Page Title |
| title-large | 22 | 600 | 28 | Section Title |
| title-medium | 18 | 600 | 24 | Card Title |
| body-large | 16 | 400 | 24 | Main Content |
| body-medium | 14 | 400 | 20 | Secondary Text |
| label-large | 14 | 500 | 18 | Button |
| label-small | 12 | 500 | 16 | Badge |
| mono-small | 13 | 400 | 18 | Code |

---

# Typography Rules

| Rule | Description |
|---|---|
| 最大正文宽度 | 72 characters |
| 禁止超长行 | 提升阅读性 |
| Code 使用 monospace | 必须 |
| 不允许随机 fontWeight | 必须 token 化 |

---

# Flutter Theme

```dart
TextTheme
```

统一管理。

---

# 2.4 Color System

# Dark Theme（默认）

| Token | Value |
|---|---|
| background | #121212 |
| surface | #1E1E1E |
| surface-2 | #262626 |
| card | #2A2A2A |
| primary | #7C6CFF |
| primary-soft | #A79BFF |
| success | #34C759 |
| warning | #FF9F0A |
| error | #FF453A |
| info | #5AC8FA |
| text-primary | #F2F2F7 |
| text-secondary | #8E8E93 |
| divider | #3A3A3C |
| border | #3A3A3C |
| overlay | rgba(0,0,0,0.4) |

---

# AI Semantic Colors

| Semantic | Color |
|---|---|
| reasoning | #8E7CFF |
| tool-running | #5AC8FA |
| tool-success | #34C759 |
| tool-error | #FF453A |
| workflow | #64D2FF |
| streaming | #7C6CFF |
| agent | #A284FF |

---

# Surface Layers

| Layer | Usage |
|---|---|
| surface | page bg |
| surface-2 | card bg |
| surface-3 | expanded block |

---

# 2.5 Shadow System

# Mobile Rule

减少传统阴影。

更多依赖：

- Layer
- Border
- Blur
- Elevation Contrast

---

# Shadow Tokens

| Token | Usage |
|---|---|
| shadow-sm | Input |
| shadow-md | Card |
| shadow-lg | Modal |

---

# 2.6 Motion System

# Motion Philosophy

AI 产品动效：

```text
Subtle > Dramatic
```

---

# Duration Tokens

| Token | Duration |
|---|---|
| motion-fast | 120ms |
| motion-normal | 220ms |
| motion-slow | 320ms |
| motion-streaming | 500ms |

---

# Curve Tokens

| Usage | Curve |
|---|---|
| Expand | easeOutCubic |
| Modal | easeInOut |
| FAB | spring |
| Page Transition | fastOutSlowIn |
| Streaming | linear |

---

# Animation Rules

| Rule | Description |
|---|---|
| 不做过度动画 | 保持专业感 |
| Timeline Expand 必须动画 | 提升层次感 |
| Streaming 不允许 rebuild 整页 | 性能要求 |
| Modal 必须 Blur 背景 | 提升层次 |

---

# 3. Layout System

# 3.1 Breakpoints

| Device | Width |
|---|---|
| Compact | <600 |
| Medium | 600-840 |
| Expanded | >840 |

---

# Compact Layout

```text
Single Column
```

---

# Medium Layout

```text
Overlay Sidebar + Chat
```

---

# Expanded Layout

```text
Sidebar + Chat + Detail
```

---

# 3.2 Safe Area Rules

| Platform | Rule |
|---|---|
| iOS | Respect Dynamic Island |
| Android | Edge-to-edge |

---

# 4. Navigation System

# Bottom Navigation

```text
Chats
Workflow
Notifications
Profile
```

---

# Navigation Rules

| Rule | Description |
|---|---|
| 一级导航 ≤4 | 避免复杂度 |
| 不使用 Drawer | Mobile 不适合 |
| Developer 功能隐藏 | 放入设置 |
| Chat 永远默认首页 | 主入口 |

---

# 5. Component Library

# 5.1 Room Card

# Layout

```text
┌─────────────────────┐
│ A  AI Research Team │
│                     │
│ ResearchAgent:      │
│ 分析完成，发现...   │
│                     │
│ 自动路由  2m   ●2   │
└─────────────────────┘
```

---

# States

| State | Description |
|---|---|
| default | 默认 |
| unread | 高亮 |
| streaming | 显示 pulse |
| muted | 静音 |

---

# Interaction

| Action | Result |
|---|---|
| Tap | 打开聊天 |
| Long Press | Bottom Sheet |
| Swipe Left | Pin |
| Swipe Right | Archive |

---

# Accessibility

| Requirement | Description |
|---|---|
| Minimum Height | 72dp |
| Touch Area | 44x44 |
| Screen Reader | Read room status |

---

# 5.2 Agent Message

# Structure

```text
Avatar
Agent Name
Content
Tool Timeline
Reasoning
Metadata
```

---

# States

| State | Description |
|---|---|
| streaming | 输出中 |
| completed | 完成 |
| failed | 失败 |
| aborted | 中止 |

---

# Streaming Rules

| Rule | Description |
|---|---|
| 增量渲染 | 不重建全文 |
| Cursor 动画 | 必须 |
| Markdown 延迟解析 | 避免卡顿 |

---

# 5.3 Tool Timeline

# Default

```text
使用了 3 个工具 >
```

---

# Expanded

```text
✓ GitHub Search
✓ Python Execute
✓ Web Browser
```

---

# Tool States

| State | Color |
|---|---|
| running | tool-running |
| success | tool-success |
| error | tool-error |

---

# Interaction

点击 Tool Event：

```text
Bottom Sheet
```

展示：

- Input
- Output
- Logs
- Duration

---

# 5.4 Reasoning Block

# Default

```text
显示推理过程
```

---

# Expanded

```text
Thought 1...
Thought 2...
```

---

# Rules

| Rule | Description |
|---|---|
| 默认折叠 | 降低噪音 |
| 最大高度 | 320dp |
| 独立背景色 | 与正文区分 |
| 支持 Copy | 必须 |

---

# 5.5 Workflow Card

# Layout

```text
┌─────────────────────┐
│ Repo Analysis       │
│                     │
│ ✓ Clone Repo        │
│ ✓ Analyze           │
│ ⟳ Generate Summary  │
│                     │
│ Running · 68%       │
└─────────────────────┘
```

---

# States

| State | Description |
|---|---|
| queued | 等待 |
| running | 运行 |
| success | 完成 |
| failed | 失败 |
| paused | 暂停 |

---

# 5.6 Input Bar

# Default

```text
┌─────────────────────┐
│ 输入消息...      ➤ │
└─────────────────────┘
```

---

# Expanded Actions

```text
@Agent
Upload
Voice
Image
Workflow
```

---

# Rules

| Rule | Description |
|---|---|
| 自动增长高度 | 最大 6 行 |
| 键盘避让 | 必须 |
| Streaming 时允许 Stop | 必须 |

---

# 6. Chat Timeline System

# Timeline Item Types

| Type | Description |
|---|---|
| UserMessage | 用户消息 |
| AgentMessage | Agent 回复 |
| ToolEvent | Tool 调用 |
| ReasoningEvent | 推理 |
| WorkflowEvent | Workflow Step |
| SystemEvent | 系统消息 |
| StatusEvent | 状态 |

---

# Timeline Rules

| Rule | Description |
|---|---|
| 不做 IM 风格 | Hermes 是 Workflow Timeline |
| Tool Event 可折叠 | 减少信息密度 |
| Workflow Event Stepper 化 | 强化结构感 |
| 长消息虚拟化 | 必须 |

---

# 7. Platform Specific Design

# 7.1 iOS

| Feature | Strategy |
|---|---|
| Navigation | Cupertino Large Title |
| Scroll | Bounce |
| Modal | Blur Background |
| Haptic | Soft Impact |

---

# 7.2 Android

| Feature | Strategy |
|---|---|
| Navigation | Material 3 |
| Edge-to-edge | Required |
| Haptic | Material Haptic |
| Back Gesture | Native Support |

---

# 8. Accessibility

# Accessibility Level

```text
WCAG AA
```

---

# Requirements

| Requirement | Description |
|---|---|
| Contrast Ratio | ≥4.5 |
| Touch Area | ≥44x44 |
| Screen Reader | Required |
| Collapse State | 必须可读 |
| Streaming | aria-live polite |

---

# Flutter

使用：

```dart
Semantics
```

---

# 9. Performance Rules

# 9.1 Streaming

禁止：

```text
每 token rebuild 全页面
```

---

# 正确方案

```text
stream delta
 ↓
buffer
 ↓
partial render
```

---

# 9.2 Timeline

必须：

```text
ListView.builder
```

支持：

- 虚拟化
- cursor pagination
- incremental render

---

# 9.3 Markdown

| Rule | Description |
|---|---|
| 延迟解析 | Streaming 时 |
| Code Block 独立 Widget | 必须 |
| 避免 rebuild tree | 必须 |

---

# 10. Flutter Architecture Spec

# Theme Structure

```text
AppTheme
 ├─ Colors
 ├─ Typography
 ├─ Radius
 ├─ Motion
 └─ Spacing
```

---

# Component Structure

```text
shared/widgets/
 ├─ cards/
 ├─ timeline/
 ├─ inputs/
 ├─ sheets/
 └─ animations/
```

---

# 11. Final Product Goal

Hermes Mobile 的目标不是：

```text
Flutter Chat App
```

也不是：

```text
Hermes Web UI Clone
```

而是：

```text
AI Native Multi-Agent Mobile Workspace
```

核心体验：

- Streaming Native
- Workflow Native
- Timeline Native
- Multi-Agent Native
- Mobile Companion Native

