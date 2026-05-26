# Hermes Mobile
# 产品需求文档（PRD） v3

> 基于 Hermes Web UI 生态重新设计的移动端 Companion App
>
> Version: 3.0
>
> Product Type: AI Multi-Agent Mobile Workspace

---

# 1. 产品定位

## 1.1 产品定义

Hermes Mobile 是 Hermes AI Ecosystem 的官方移动端 Companion App。

它不是：

- Web UI 的 Flutter Clone
- Desktop Dashboard 的完整替代
- 面向大众用户的普通 AI Chat App

而是：

- Multi-Agent 移动工作台
- AI Workflow Companion
- Hermes Runtime Monitor
- 随时接管与继续 AI Workflow 的移动入口

---

# 1.2 产品目标

Hermes Mobile 的核心目标：

## Continue

用户在 Desktop Hermes 发起任务后：

- 手机继续查看
- 手机继续聊天
- 手机继续协作

---

## Monitor

移动端实时查看：

- Agent 状态
- Workflow Progress
- Queue
- Tool Execution
- Runtime Error

---

## Collaborate

支持：

- Multi-Agent Collaboration
- Mention
- Workflow Coordination
- Team Workspace

---

# 1.3 不做的事情

移动端不适合：

- 完整 Terminal
- 复杂 Dashboard
- 高密度 Log System
- 重型 File Management
- Desktop 级 Workflow Editor

这些功能保留在 Web/Desktop。

---

# 2. 核心设计原则

# 2.1 Mobile First

不是 Desktop Layout 缩小。

而是：

- 信息层级重构
- Timeline 优先
- Collapse 优先
- Streaming 优先

---

# 2.2 Streaming First

Hermes 本质是 Streaming AI System。

移动端必须围绕：

- WebSocket Stability
- Resume Recovery
- Incremental Rendering
- Long Session Performance

设计。

---

# 2.3 Timeline First

聊天页不是 Message List。

而是：

- Message
- Tool Event
- Reasoning
- Workflow Step
- Status

组成的 Timeline。

---

# 2.4 Collapse Everything

移动端默认折叠：

- Tool Calls
- Reasoning
- Token Usage
- Metadata
- Raw Logs

避免信息爆炸。

---

# 3. 用户场景

# 3.1 场景：继续 Workflow

用户在电脑上启动：

```text
Repo Analysis Workflow
```

移动端：

- 查看进度
- 接收通知
- 查看结果
- 中断 Workflow
- 补充输入

---

# 3.2 场景：Agent 协作

用户在移动端：

```text
@ResearchAgent
总结这个 PR
```

Agent 返回：

- Summary
- Tool Timeline
- Repo Search
- Review Result

---

# 3.3 场景：Monitoring

用户查看：

- Gateway Online
- Agent Queue
- Workflow Status
- Tool Errors

---

# 4. 信息架构

# 4.1 一级导航

```text
Chats
Workflows
Notifications
Profile
```

---

# 4.2 二级开发者模块

默认隐藏。

开启 Developer Mode 后显示：

```text
Gateway
Agents
Models
Plugins
Logs
Analytics
Settings
```

---

# 5. 页面结构

# 5.1 App Structure

```text
Splash
 ├─ Login
 └─ MainApp
      ├─ Chats
      ├─ Workflows
      ├─ Notifications
      └─ Profile
```

---

# 6. Chats 页面

# 6.1 页面目标

进入 App 后：

- 快速恢复工作
- 查看运行中的 Agent
- 查看最近会话
- 快速继续聊天

---

# 6.2 页面布局

```text
┌─────────────────────┐
│ Hermes        Search│
├─────────────────────┤
│ Workspace Tabs      │
├─────────────────────┤
│ Running Tasks       │
├─────────────────────┤
│ Room List           │
│                     │
│ Room Card           │
│ Room Card           │
│ Room Card           │
│                     │
├─────────────────────┤
│ Bottom Navigation   │
└─────────────────────┘
```

---

# 6.3 Workspace Tabs

```text
[全部] [我的] [团队] [运行中]
```

支持横向滑动。

---

# 6.4 Running Tasks

显示：

- Running Workflow
- Streaming Agent
- Queue Task

---

## Running Task Card

```text
Research Agent
正在分析 repo...
▓▓▓▓▓▓░░░░ 68%
```

支持横向滚动。

---

# 6.5 Room List

# Room Card

```text
┌─────────────────────┐
│ A  AI Research Team │
│                     │
│ Agent: 分析完成...  │
│                     │
│ 自动路由   2m   ●2  │
└─────────────────────┘
```

---

# 6.6 Room Card 内容

## Header

| Element | Description |
|---|---|
| Avatar | 房间头像 |
| Room Name | 房间名称 |
| Streaming Dot | 是否运行中 |

---

## Content

| Element | Description |
|---|---|
| Last Agent | 最后发言 Agent |
| Last Message | 最后消息 |

---

## Footer

| Element | Description |
|---|---|
| Mode Badge | 自动路由/工作流 |
| Updated Time | 更新时间 |
| Unread Badge | 未读数 |

---

# 6.7 FAB

点击展开：

```text
新建会话
加入房间
快速 Agent
创建 Workflow
```

---

# 7. Chat 页面（核心）

# 7.1 页面目标

支持：

- 高性能 Streaming
- Multi-Agent Timeline
- Tool Visualization
- Workflow Coordination
- Long Session Rendering

---

# 7.2 页面布局

```text
┌─────────────────────┐
│ ← AI Research Team  │
│ 自动路由 · 4 在线    │
├─────────────────────┤
│ Timeline            │
│                     │
│ User Message        │
│ Agent Message       │
│ Tool Timeline       │
│ Reasoning           │
│ Workflow Event      │
│                     │
├─────────────────────┤
│ Input Area          │
└─────────────────────┘
```

---

# 7.3 Timeline Item Types

| Type | Description |
|---|---|
| UserMessage | 用户消息 |
| AgentMessage | Agent 回复 |
| ToolEvent | Tool 调用 |
| ReasoningEvent | 推理过程 |
| WorkflowEvent | Workflow 步骤 |
| SystemEvent | 系统消息 |
| StatusEvent | 状态更新 |

---

# 7.4 User Message

右侧 Bubble。

---

# 7.5 Agent Message

## 默认态

```text
🤖 ResearchAgent

这是分析结果...

[显示工具]
```

---

## 展开态

```text
Reasoning
Tool Timeline
Token Usage
Latency
```

---

# 7.6 Tool Timeline

默认折叠。

---

## 展开后

```text
✓ GitHub Search
✓ Python Execute
✓ Web Browser
```

---

# 7.7 Reasoning

默认隐藏。

用户点击：

```text
显示推理过程
```

后展开。

---

# 7.8 Workflow Event

Workflow 模式下：

```text
Research
 ↓
Code
 ↓
Review
 ↓
Summary
```

Stepper 展示。

---

# 7.9 Tool Running 状态

```text
⟳ 正在搜索 GitHub
```

---

# 7.10 Streaming Cursor

Streaming 中：

```text
▋
```

闪烁 Cursor。

---

# 7.11 Code Block

## Requirements

| Feature | Required |
|---|---|
| Horizontal Scroll | Yes |
| Copy Button | Yes |
| Collapse | Yes |
| Max Height | Yes |
| Syntax Highlight | Yes |

---

# 7.12 New Message Indicator

用户不在底部时：

```text
↓ 3 条新消息
```

---

# 7.13 Input Area

## 默认态

```text
[ 输入消息...             ➤ ]
```

---

## Expand Actions

```text
@Agent
Upload
Voice
Image
Workflow
Mention
```

---

# 7.14 Mention Selector

Bottom Sheet。

```text
@ResearchAgent
@CodeAgent
@BrowserAgent
```

---

# 8. Workflows 页面

# 8.1 页面目标

Workflow Monitoring。

---

# 8.2 页面布局

```text
┌─────────────────────┐
│ Running Workflows   │
├─────────────────────┤
│ Workflow Card       │
│ Workflow Card       │
└─────────────────────┘
```

---

# 8.3 Workflow Card

```text
┌─────────────────────┐
│ Repo Analysis       │
│                     │
│ ✓ Clone Repo        │
│ ✓ Analyze Structure │
│ ⟳ Generate Summary  │
│                     │
│ Running · 68%       │
└─────────────────────┘
```

---

# 8.4 Workflow Detail

## 包含

- Step Timeline
- Tool Events
- Agent Status
- Logs（简化）
- Result
- Retry
- Abort

---

# 9. Notifications 页面

# 9.1 页面目标

移动端 Notification Center。

---

# 9.2 支持通知

| Type | Description |
|---|---|
| Workflow Complete | Workflow 完成 |
| Mention | 被 Mention |
| Agent Error | Agent 错误 |
| Queue Finished | 队列完成 |
| Human Input Required | 需要用户输入 |

---

# 9.3 Notification Item

```text
✓ Workflow Finished
AI PPT 已生成完成
2分钟前
```

---

# 10. Profile 页面

# 10.1 页面布局

```text
┌─────────────────────┐
│ Avatar              │
│ Username            │
├─────────────────────┤
│ Settings            │
│ Developer Mode      │
│ Logout              │
└─────────────────────┘
```

---

# 10.2 Settings

| Setting | Type |
|---|---|
| Streaming | Switch |
| Show Reasoning | Switch |
| Font Size | Slider |
| Theme | Select |
| Markdown Rendering | Switch |
| Developer Mode | Switch |

---

# 11. Developer Mode

# 11.1 功能

开启后显示：

- Gateway
- Agents
- Models
- Plugins
- Analytics
- Logs

---

# 11.2 Gateway 页面

## 功能

- 查看 Gateway
- Online Status
- Agent Count
- Add Gateway
- Scan Gateway

---

# 11.3 Agent 页面

## 功能

- Agent List
- Status
- Context Size
- Skills
- Tools
- Recent Sessions

---

# 12. 技术架构

# 12.1 技术栈

| Layer | Tech |
|---|---|
| UI | Flutter |
| State | Riverpod |
| Storage | Drift / SQLite |
| Routing | GoRouter |
| HTTP | Dio |
| WebSocket | websocket_channel |
| Markdown | flutter_markdown |

---

# 12.2 目录结构

```text
lib/
 ├─ core/
 │   ├─ network/
 │   ├─ websocket/
 │   ├─ storage/
 │   ├─ theme/
 │   └─ utils/
 │
 ├─ features/
 │   ├─ auth/
 │   ├─ chats/
 │   ├─ workflows/
 │   ├─ notifications/
 │   ├─ agents/
 │   ├─ machines/
 │   └─ profile/
 │
 ├─ shared/
 │   ├─ widgets/
 │   ├─ services/
 │   └─ models/
 │
 └─ main.dart
```

---

# 12.3 State Architecture

```text
UI
 ↓
Riverpod Notifier
 ↓
Repository
 ↓
REST + WS
 ↓
Hermes Server
```

---

# 13. Message Model

# 13.1 Timeline Model

```dart
class TimelineItem {
  String id;
  TimelineType type;
  DateTime createdAt;
}
```

---

# 13.2 Message Entity

```dart
class MessageEntity {
  String id;

  String roomId;

  MessageStatus status;

  MessageChunk text;

  List<ToolEvent> tools;

  Reasoning reasoning;

  TokenUsage usage;
}
```

---

# 13.3 Message Status

| Status | Description |
|---|---|
| pending | 本地发送中 |
| sent | 已发送 |
| streaming | Streaming 中 |
| completed | 完成 |
| failed | 失败 |
| aborted | 中止 |

---

# 14. WebSocket 架构

# 14.1 WS Service

单例管理：

```text
WSService
 ├─ reconnect
 ├─ heartbeat
 ├─ auth refresh
 ├─ room subscribe
 ├─ event dispatch
 └─ resume stream
```

---

# 14.2 Resume Recovery

移动端必须支持：

- App Background
- Network Switch
- Weak Network
- Resume Streaming

---

# 14.3 Heartbeat

```json
ping
pong
```

20s 一次。

---

# 14.4 Message ACK

支持：

```json
message.ack
```

用于确认消息入库。

---

# 15. 本地缓存

# 15.1 SQLite Cache

缓存：

| Data | Cache |
|---|---|
| Rooms | SQLite |
| Messages | SQLite |
| Agents | SQLite |
| Drafts | SQLite |
| Attachments | File Cache |

---

# 15.2 Draft Recovery

自动保存输入框内容。

---

# 16. 性能优化

# 16.1 Streaming Buffer

禁止：

```text
每 token rebuild UI
```

---

## 正确方式

```text
delta
 ↓
buffer
 ↓
500ms merge
 ↓
局部刷新
```

---

# 16.2 Cursor Pagination

```text
GET /rooms/{id}/messages?cursor=xxx&limit=30
```

---

# 16.3 Incremental Markdown Rendering

避免整棵 Markdown Tree 重建。

---

# 17. 安全设计

# 17.1 Token Storage

必须使用：

```text
flutter_secure_storage
```

---

# 17.2 Refresh Token

自动刷新。

---

# 17.3 Gateway 安全

| Strategy | Description |
|---|---|
| HTTPS Only | 强制 HTTPS |
| API Key | 必须支持 |
| Local Network Permission | 权限控制 |
| Domain Whitelist | 可选 |

---

# 18. Push Notification

# 18.1 支持类型

| Type | Description |
|---|---|
| Workflow Finished | Workflow 完成 |
| Mention | Mention |
| Tool Failed | Tool 错误 |
| Queue Complete | 队列完成 |
| Human Input Required | 用户输入 |

---

# 19. Roadmap

# Phase 1

## 核心聊天

- Login
- Room List
- Chat Timeline
- Streaming
- Markdown
- WS Resume
- SQLite Cache

---

# Phase 2

## Workflow

- Workflow Timeline
- Notifications
- Tool Timeline
- Agent Status

---

# Phase 3

## Advanced

- Voice
- Image
- Share Session
- Team Workspace
- Multi Device Sync

---

# 21. v3.1 补充功能（对比 Web UI 缺失项）

> 以下功能已在 Web UI 实现，需在移动端补充实现以保持功能对齐

---

## 21.1 语音播报（TTS）

**功能描述**

- 支持对 AI 助手消息进行语音播报
- 支持多种 TTS Provider：OpenAI TTS / Custom Endpoint (OpenAI兼容) / Edge TTS / Web Speech API
- 播放 / 暂停 / 停止控制
- 播放时消息气泡显示彩色呼吸动效（彩虹光晕）

**UI 交互**

- 消息 meta 区显示语音播放按钮
- 播放中按钮显示 pulse 动画
- 支持自动播放事件触发

**优先级**：高

---

## 21.2 文件 / 图片附件

**功能描述**

- 用户发送消息时支持附加文件或图片
- 支持图片预览（点击放大 Overlay）
- 文件下载支持（通过 Hermes Gateway 代理）
- 支持 ContentBlock[] 格式（image / file 类型）

**UI 交互**

- 用户消息区域显示附件缩略图或文件图标
- 点击图片打开全屏预览 Overlay
- 点击文件触发下载

**优先级**：高

---

## 21.3 思考过程实时计时

**功能描述**

- Thinking Block 头部显示实时计时（从 thinking 开始到结束）
- 流式输出时自动展开 thinking 块
- 计时精度：秒级

**UI 交互**

- 显示格式：`Xm Xs`（如 `1m 23s`）
- 流式过程中每秒更新
- 组件销毁时清理 timer

**优先级**：中

---

## 21.4 ContentBlock[] 消息格式

**功能描述**

- 支持解析消息 content 字段中的 ContentBlock[] JSON 格式
- 支持 text / image / file 等多种 block 类型
- 正确提取 text content 进行展示

**优先级**：中

---

## 21.5 命令消息展示

**功能描述**

- 支持 `/status` 等命令消息类型展示
- 命令消息带特殊样式（边框 + 背景色 + 图标）
- 命令执行结果以结构化方式展示（如 status 展示为 grid）

**UI 交互**

- 命令消息以独立样式渲染（与普通消息区分）
- 命令结果 icon 区分成功 / 错误状态

**优先级**：低

---

## 21.6 Token 统计汇总（StatCards）

**功能描述**

- 页面底部或顶部显示 token 统计卡片
- 显示内容：输入 token / 输出 token / 总 token / 请求数等

**优先级**：低

---

## 21.7 消息高亮（Highlight）

**功能描述**

- 支持对特定消息添加高亮样式（如引用消息时的边框光晕）
- 高亮样式：`box-shadow` 边框光晕效果

**优先级**：低

---

## 21.8 代码语法高亮

**功能描述**

- Markdown 代码块支持语法高亮（而非纯文本）
- 代码块支持复制按钮
- 代码块支持横向滚动 + max-height 限制

**UI 交互**

- 代码高亮通过 hljs 或类似方案实现
- 代码块头部显示语言标签和复制按钮

**优先级**：低（当前 flutter_markdown 不支持，建议后续扩展）

---

# 22. 最终目标

Hermes Mobile 的目标不是：

```text
Hermes Web UI 的移动版
```

而是：

```text
Hermes AI Operating System 的移动 Companion
```

核心关键词：

- Continue Session
- Workflow Monitoring
- Multi-Agent Collaboration
- Streaming Experience
- Mobile AI Workspace

