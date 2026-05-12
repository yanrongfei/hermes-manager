# Hermes App 设计文档

## 1. 项目概述

### 1.1 项目背景

用户在使用 hermes-web-ui（Web 版）时，希望有移动端 App 能随时与 AI Agent 对话和管理任务。hermes-web-ui 本身是桌面优先的 Web 应用，缺乏移动端体验。

本项目是完全独立的移动端应用，功能参考 hermes-web-ui，不依赖其现有服务。

### 1.2 设计目标

- 移动端随时对话，不依赖浏览器
- 突出群聊功能（参考微信风格），支持多 Agent 协作
- 能管理 Skills、Plugins、Models、Tasks 等 Agent 配置
- 多用户认证体系（JWT）
- 支持多机器多 Agent 管理

### 1.3 技术栈

| 层级 | 技术 |
|------|------|
| 前端 | Flutter (Dart) |
| 后端 | Python FastAPI + 原生 WebSocket |
| 认证 | 用户名+密码 + JWT Token |
| 数据库 | SQLite（独立，不共用 hermes-web-ui） |
| 部署 | Docker 独立容器 |
| 参考 | hermes-web-ui (Vue 3 + Koa 2 + Socket.IO) |

---

## 2. 整体架构

### 2.1 系统架构图

```
┌─────────────────────────────────────────────────────────┐
│                      Flutter App                         │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐                  │
│  │  对话   │  │  发现   │  │   我的  │                  │
│  │ (群聊)  │  │(机器/Agent)│ │ (设置)  │                  │
│  └────────┘  └────────┘  └────────┘                     │
└────────────────────┬────────────────────────────────────┘
                     │
              WebSocket / REST
                     │
┌────────────────────▼────────────────────────────────────┐
│                   FastAPI Backend                        │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐              │
│  │ JWT Auth │  │ WebSocket│  │  REST    │              │
│  │  多用户   │  │  消息推送  │  │  群/Agent │              │
│  └──────────┘  └──────────┘  └──────────┘              │
│       │            │            │                       │
│       └────────────┼────────────┘                       │
│                    │                                     │
│              ┌─────▼─────┐                              │
│              │  SQLite   │                              │
│              │  独立数据库 │                              │
│              └───────────┘                              │
└────────────────────┬────────────────────────────────────┘
                     │
              ┌──────▼──────┐
              │ Hermes     │
              │ Gateway    │
              │ (多机器)   │
              └────────────┘
```

### 2.2 后端架构

- **FastAPI** — HTTP REST API + WebSocket Endpoint
- **SQLAlchemy** — ORM for SQLite
- **PyJWT** — JWT Token 认证
- **websockets** — 原生 WebSocket（参考 hermes-web-ui 的 Socket.IO 事件格式）
- **Docker** — 独立容器部署

### 2.3 前端架构

- **Flutter** — 跨平台移动端
- **Provider/Riverpod** — 状态管理
- **dio** — HTTP 客户端
- **web_socket_channel** — WebSocket 客户端

---

## 3. 用户体系

### 3.1 用户注册/登录

| 接口 | 方法 | 说明 |
|------|------|------|
| `/auth/register` | POST | 用户名+密码注册 |
| `/auth/login` | POST | 登录，返回 JWT |
| `/auth/refresh` | POST | 刷新 Token |
| `/auth/logout` | POST | 登出 |

### 3.2 JWT 认证

- **Access Token** — 短期有效（1小时）
- **Refresh Token** — 长期有效（7天）
- 多设备可选：用户可设置是否允许多设备登录

### 3.3 多设备支持

- 默认关闭（单设备登录）
- 用户可开启多设备支持
- 多设备时 WebSocket 多端都收到

---

## 4. Tab1 对话（群聊）

### 4.1 群聊列表

- 统一消息列表（单聊+群聊混排，参考微信混合列表）
- 显示群名、群头像、最后一条消息、时间和未读数
- 搜索对话
- 创建群聊（输入群名、选择群头像）

### 4.2 加群方式

- **邀请码** — 创建群时生成邀请码，其他用户输入加入
- **链接邀请** — 生成分享链接，点击直接加入（需登录验证）

### 4.3 群聊功能

| 功能 | 说明 |
|------|------|
| 群主制 | 创建者即群主，可踢人、设置管理员 |
| 成员管理 | 群主/管理员可添加/移除成员 |
| 消息类型 | 文字 + 图片 + 语音 |
| 消息推送 | WebSocket 持久连接 |
| 已读状态 | 不需要 |
| 搜索 | 不需要 |

### 4.4 多 Agent 模式

创建群时可选择模式：

| 模式 | 说明 |
|------|------|
| 广播模式 | 用户发消息，所有 Agent 都能看到并回复 |
| 指定模式 | 用户用 @mention 指定某个 Agent 回复 |
| 智能路由 | 系统自动判断该由哪个 Agent 处理 |
| 流水线模式 | Agent A → B → C 串行处理（后续讨论） |

**@Mention 路由**：
- 用户/Agent 在消息中 @某个 Agent，被 @者处理
- Agent 也可以 @其他 Agent，形成协作链
- 参考 hermes-web-ui 的 `processMentions` 逻辑

### 4.5 消息类型

| 类型 | 说明 |
|------|------|
| 文字 | 文本消息 |
| 图片 | 支持 JPEG/PNG/GIF |
| 语音 | 原声发送，可选自动转文字 |

**语音处理**：
- 发送原声
- 用户可开启"自动转文字"，发送时附上转写文本
- 后续可扩展 Whisper ASR

### 4.6 输入体验

- 底部工具栏：语音、图片、更多（"+"）
- 快捷工具布局，类似微信但更简洁

### 4.7 消息同步

- 登录时同步最近 7 天的消息
- 更早的消息按需加载（上滑加载更多）
- 增量同步，记录上次同步时间戳

### 4.8 WebSocket 协议

沿用 hermes-web-ui 的 Socket.IO 事件格式，改用原生 WebSocket：

**客户端事件**：
```typescript
// 加入群
socket.emit('join', { roomId, name })
// 发送消息
socket.emit('message', { roomId, content })
// @提及 Agent
socket.emit('mention', { roomId, agentName, content })
// 正在输入
socket.emit('typing', { roomId })
// 停止输入
socket.emit('stop_typing', { roomId })
```

**服务端事件**：
```typescript
// 新消息
'message'
// 成员加入
'member_joined'
// 成员离开
'member_left'
// 正在输入
'typing'
// Agent 回复中
'context_status'  // 'compressing' | 'replying' | 'ready'
// 消息被处理
'message.processed'
```

---

## 5. Tab2 发现

完整参考 hermes-web-ui 的 Skills/Plugins/Models/Jobs/Kanban 功能。

### 5.1 机器管理

| 功能 | 说明 |
|------|------|
| 添加机器 | 输入机器地址（IP:Port） |
| 机器列表 | 显示已添加的机器 |
| 从机器加载 Agent | 连接 Gateway 获取 Agent 列表 |

### 5.2 Agent 管理

| 功能 | 说明 |
|------|------|
| Agent 列表 | 显示所有可用 Agent |
| Agent 信息 | 名字、描述、头像（预设模板 + 可编辑） |
| 状态 | 在线/离线 |

### 5.3 Skills 列表

- 浏览可用的 Skills
- 查看 Skill 描述

### 5.4 Plugins 管理

- 浏览/启用/禁用 Plugins

### 5.5 Models 选择

- 选择使用的 AI 模型
- 显示模型配置

### 5.6 Jobs 定时任务

- 查看定时任务列表
- 创建/编辑/删除定时任务

### 5.7 Kanban 看板

- 看板视图管理任务

---

## 6. Tab3 我的

完整参考 hermes-web-ui 的 Settings/Logs/Usage/Gateway/Profiles/Memory 功能。

### 6.1 Settings 设置

- 个人信息
- 通知设置
- 多设备设置
- 主题设置

### 6.2 Logs 日志

- 查看系统日志
- 日志级别过滤

### 6.3 Usage 用量统计

- Token 使用统计
- 成本估算

### 6.4 Gateway 网关管理

- 管理连接的 Hermes Gateway

### 6.5 Profiles 配置

- 多 Profile 支持
- Profile 切换

### 6.6 Memory 记忆

- 查看/管理 Agent 记忆

---

## 7. 数据模型

### 7.1 数据库 Schema

```sql
-- 用户表
CREATE TABLE users (
    id TEXT PRIMARY KEY,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    multi_device BOOLEAN DEFAULT FALSE
);

-- 群聊房间
CREATE TABLE rooms (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    avatar TEXT,
    owner_id TEXT NOT NULL,
    mode TEXT DEFAULT 'broadcast',  -- broadcast/mention/router/pipeline
    trigger_tokens INTEGER DEFAULT 100000,
    max_history_tokens INTEGER DEFAULT 32000,
    tail_message_count INTEGER DEFAULT 20,
    invite_code TEXT,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (owner_id) REFERENCES users(id)
);

-- 群成员
CREATE TABLE room_members (
    id TEXT PRIMARY KEY,
    room_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    role TEXT DEFAULT 'member',  -- owner/admin/member
    joined_at INTEGER NOT NULL,
    FOREIGN KEY (room_id) REFERENCES rooms(id),
    FOREIGN KEY (user_id) REFERENCES users(id)
);

-- 群消息
CREATE TABLE messages (
    id TEXT PRIMARY KEY,
    room_id TEXT NOT NULL,
    sender_id TEXT,
    sender_type TEXT,  -- 'user'/'agent'
    sender_name TEXT,
    content TEXT NOT NULL,
    content_type TEXT DEFAULT 'text',  -- text/image/voice
    extra TEXT,  -- JSON for image_url, voice_text etc.
    parent_id TEXT,  -- for threading/pipeline
    created_at INTEGER NOT NULL,
    FOREIGN KEY (room_id) REFERENCES rooms(id)
);

-- 机器配置
CREATE TABLE machines (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    name TEXT,
    address TEXT NOT NULL,  -- IP:Port
    created_at INTEGER NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Agent 配置
CREATE TABLE agents (
    id TEXT PRIMARY KEY,
    machine_id TEXT NOT NULL,
    remote_id TEXT NOT NULL,  -- ID on Hermes Gateway
    name TEXT NOT NULL,
    description TEXT,
    avatar TEXT,
    profile TEXT,
    invited BOOLEAN DEFAULT FALSE,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (machine_id) REFERENCES machines(id)
);

-- 群里的 Agent
CREATE TABLE room_agents (
    id TEXT PRIMARY KEY,
    room_id TEXT NOT NULL,
    agent_id TEXT NOT NULL,
    joined_at INTEGER NOT NULL,
    FOREIGN KEY (room_id) REFERENCES rooms(id),
    FOREIGN KEY (agent_id) REFERENCES agents(id)
);
```

### 7.2 核心 API

| 接口 | 方法 | 说明 |
|------|------|------|
| `POST /auth/register` | POST | 注册 |
| `POST /auth/login` | POST | 登录 |
| `POST /auth/refresh` | POST | 刷新 Token |
| `GET /rooms` | GET | 群列表 |
| `POST /rooms` | POST | 创建群 |
| `GET /rooms/{id}` | GET | 群详情 |
| `POST /rooms/{id}/join` | POST | 通过邀请码加入 |
| `GET /rooms/{id}/messages` | GET | 消息历史 |
| `WS /ws/chat` | WebSocket | 聊天 WebSocket |
| `GET /machines` | GET | 机器列表 |
| `POST /machines` | POST | 添加机器 |
| `GET /machines/{id}/agents` | GET | 加载机器的 Agent |
| `GET /agents` | GET | Agent 列表 |
| `POST /rooms/{id}/agents` | POST | 添加 Agent 到群 |

---

## 8. 技术实现要点

### 8.1 WebSocket vs Socket.IO

hermes-web-ui 使用 Socket.IO，本项目使用原生 WebSocket。

事件格式参考 Socket.IO，但去掉 `socket.io` 协议开销。

### 8.2 Agent 对接 Hermes Gateway

- 通过 HTTP API 调用 Hermes Gateway
- `/v1/responses` — 发送消息获取 AI 回复
- `/v1/models` — 获取可用模型
- Agent 返回流式响应（Server-Sent Events）

### 8.3 Context Compression

参考 hermes-web-ui 的 ContextEngine：
- `triggerTokens` — 超过阈值触发压缩
- `maxHistoryTokens` — 压缩后最大 token 数
- `tailMessageCount` — 保留最近 N 条消息

### 8.4 消息 Threading（Pipeline 模式后续实现）

Pipeline 模式下：
- 消息有 `parent_id` 关联
- 前端支持平铺/嵌套两种视图切换
- 流式显示处理进度

### 8.5 语音转文字（可选）

初期只发原声。
后续可集成：
- 飞书 ASR API
- 或本地 Whisper

### 8.6 部署

```yaml
# docker-compose.yml
services:
  hermes-app:
    build: ./hermes-server
    ports:
      - "8000:8000"
    volumes:
      - ./data:/app/data
    environment:
      - JWT_SECRET=${JWT_SECRET}
      - DATABASE_URL=sqlite:///data/hermes.db
```
