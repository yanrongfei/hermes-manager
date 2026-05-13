# Hermes App 设计文档

> **文档版本：** v2.0
> **更新日期：** 2026-05-13
> **状态：** 草稿

---

## 1. 项目概述

### 1.1 项目背景

用户在使用 hermes-web-ui（Web 版）时，希望有移动端 App 能随时与 AI Agent 对话和管理任务。hermes-web-ui 本身是桌面优先的 Web 应用，缺乏移动端体验。

本项目是完全独立的移动端应用，功能参考 hermes-web-ui，不依赖其现有服务。

### 1.2 设计目标

- 移动端随时对话，不依赖浏览器
- 突出群聊功能（参考微信风格），支持多 Agent 协作
- 能管理 Gateway、Agent、Profiles 等配置
- 多用户认证体系（JWT）
- 支持多 Gateway 实例管理

### 1.3 术语澄清

| 术语 | 移动端定义 | 说明 |
|------|-----------|------|
| **Gateway** | 远程 AI Gateway 服务地址 | 对应 hermes-web-ui 中的 Machine/IP:Port，用户添加远程地址（如 192.168.1.100:8642）|
| **Agent** | Gateway 上发现的 AI 实体 | Agent = Profile + Gateway 连接能力，用户无法在本机跑 Gateway 子进程 |
| **Profile** | Agent 的角色配置 | Agent 的名字、描述、头像等元数据 |

### 1.4 技术栈

#### 服务端

| 层级 | 技术 | 说明 |
|------|------|------|
| 语言 | Python 3.11+ | - |
| 框架 | FastAPI | 异步高性能、自动 OpenAPI |
| ORM | SQLAlchemy 2.0 | 异步支持、类型提示完善 |
| 数据库 | SQLite | 独立数据库，不共用 hermes-web-ui |
| WebSocket | FastAPI 内置 | 原生 WebSocket |
| 认证 | PyJWT | JWT Token |
| 验证 | Pydantic v2 | 请求/响应验证 |
| 部署 | Docker | 独立容器 |

#### App 端

| 层级 | 技术 | 说明 |
|------|------|------|
| 框架 | Flutter 3.x | Dart 语言 |
| 状态管理 | Riverpod | 编译安全、测试方便 |
| HTTP | dio | 拦截器、配置灵活 |
| WebSocket | web_socket_channel | 官方维护 |
| 路由 | go_router | Google 官方、深链接支持 |
| 本地存储 | shared_preferences | 轻量 KV 存储 |

---

## 2. 整体架构

### 2.1 系统架构图

```
┌─────────────────────────────────────────────────────────┐
│                      Flutter App                         │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐                  │
│  │  对话   │  │  发现   │  │   我的  │                  │
│  │ (群聊)  │  │(Gateway/Agent)│ │ (设置)  │                  │
│  └────────┘  └────────┘  └────────┘                     │
└────────────────────┬────────────────────────────────────┘
                     │
              WebSocket / REST
                     │
┌────────────────────▼────────────────────────────────────┐
│                   FastAPI Backend                        │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐              │
│  │ JWT Auth │  │ WebSocket│  │  REST    │              │
│  │  多用户   │  │  消息推送  │  │  群/Gateway │              │
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
              │  Remote     │
              │  Gateway    │
              │ (用户添加的地址)│
              └────────────┘
```

**核心变化：** Gateway 是远程服务，App 通过 HTTP/WebSocket 调用远程 Gateway 的 `/v1/responses` API 获取 Agent 回复。

### 2.2 后端架构

```
hermes-server/
├── app/
│   ├── __init__.py
│   ├── main.py              # FastAPI 入口
│   ├── config.py            # 配置管理
│   ├── database.py          # SQLAlchemy 连接
│   ├── models/              # SQLAlchemy 模型
│   │   ├── user.py
│   │   ├── room.py
│   │   ├── message.py
│   │   ├── gateway.py       # 重命名自 machine.py
│   │   └── agent.py
│   ├── schemas/             # Pydantic schemas
│   │   ├── auth.py
│   │   ├── room.py
│   │   ├── message.py
│   │   └── agent.py
│   ├── api/                 # API 路由
│   │   ├── auth.py
│   │   ├── rooms.py
│   │   ├── messages.py
│   │   ├── gateways.py      # 重命名自 machines.py
│   │   └── agents.py
│   ├── services/           # 业务逻辑
│   │   ├── auth.py
│   │   ├── room.py
│   │   ├── message.py
│   │   ├── websocket.py
│   │   ├── gateway_client.py # HTTP 调用远程 Gateway
│   │   └── context_engine.py # 上下文压缩
│   └── core/               # 核心工具
│       ├── security.py      # JWT 工具
│       └── exceptions.py    # 自定义异常
├── tests/
├── Dockerfile
├── docker-compose.yml
├── requirements.txt
└── README.md
```

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

### 4.4 Agent 交互流程（核心）

#### 4.4.1 Agent 的来源

1. 用户在 App 添加远程 Gateway 地址（如 `192.168.1.100:8642`）
2. App 从 Gateway 发现可用的 Agent（每个 Gateway 对应一个 Agent/Profile）
3. 用户把 Agent 拉入群聊房间
4. 之后通过 @mention 调用

#### 4.4.2 消息路由模式

创建群时可选择模式：

| 模式 | 说明 | 触发条件 |
|------|------|---------|
| 广播模式 | 用户发消息，所有 Agent 都收到并回复 | 默认模式 |
| 指定模式 | 用户用 @mention 指定某个 Agent 回复 | 消息含 @AgentName |
| 协作链 | Agent A 可以 @Agent B，形成协作链 | Agent 回复中 @其他Agent |

#### 4.4.3 流式响应（重点）

Agent 回复是逐字流式输出的，App 端需要像 ChatGPT 一样实时更新消息气泡。

**后端处理流程：**

```
1. 用户发消息 → WebSocket message 事件
2. 后端判断路由模式（广播/指定）
3. 后端调用远程 Gateway 的 /v1/responses API（SSE 流式）
4. Gateway 返回流式数据
5. 后端分片推送 message.delta 事件到 App
6. App 实时更新消息气泡
```

**WebSocket 事件（扩展）：**

```typescript
// 服务端推送
message.delta      → 流式片段（逐字更新）
message.done      → 流式结束
message.error     → 流式出错
context_status    → 'idle' | 'compressing' | 'replying'
agent.thinking    → Agent 思考过程（可折叠）
agent.tool_call   → Agent 工具调用中间过程
```

### 4.5 消息队列与 Abort

**消息队列：**
- Agent 正在回复时，用户再发消息应该排队等待
- 前端显示"等待 Agent 空闲..."

**Abort 支持：**
- 用户可以中断 Agent 的回复
- 后端收到 abort 事件后，停止从 Gateway 获取数据
- 前端显示"已中止"

### 4.6 Tool Calls 和 Reasoning 展示

**Tool Calls 展示：**
- Agent 执行工具时的中间过程展示（如搜索、代码执行）
- 显示工具名称、参数、结果
- 可折叠/展开

**Thinking/Reasoning 展示：**
- Agent 的思考过程
- 可折叠显示（类似 ChatGPT 的 think 折叠）
- 节省 UI 空间

### 4.7 Context Compression（上下文压缩）

参考 hermes-web-ui 的 ContextEngine：

**触发条件：**
- 当对话 token 累积超过 `triggerTokens`（默认 10 万）
- 自动压缩旧消息

**压缩算法：**
- 保留最近 N 条消息原文（`tailMessageCount`，默认 20）
- 旧消息用 LLM 生成摘要
- 压缩后的上下文传给 Agent，避免超出模型窗口

**群聊场景尤为重要：** 多 Agent 来回对话时 token 增长很快。

### 4.8 WebSocket 协议

**客户端事件：**

```typescript
join           → 加入群
leave          → 离开群
message        → 发送消息
mention        → @提及 Agent
abort          → 中断 Agent 回复
typing         → 正在输入
stop_typing    → 停止输入
```

**服务端事件：**

```typescript
message           → 新消息
message.delta     → 流式片段
message.done      → 流式结束
message.error     → 流式出错
context_status    → 'idle' | 'compressing' | 'replying'
agent.thinking    → 思考过程
agent.tool_call   → 工具调用
member_joined     → 成员加入
member_left       → 成员离开
typing            → 正在输入
```

---

## 5. Tab2 发现

### 5.1 Gateway 管理（重命名自机器管理）

| 功能 | 说明 |
|------|------|
| 添加 Gateway | 输入远程地址（如 192.168.1.100:8642），为其命名 |
| Gateway 列表 | 显示已添加的 Gateway，支持删除 |
| 连接测试 | 保存前测试连通性，显示在线/离线状态 |
| 发现 Agent | 从 Gateway 发现可用的 Agent 列表 |

### 5.2 Agent 管理

| 功能 | 说明 |
|------|------|
| Agent 列表 | 展示所有可用 Agent（按 Gateway 分组） |
| Agent 信息 | 名字、描述、头像、所属 Gateway、在线状态 |
| 添加到群 | 从 Agent 列表选择，添加到指定群聊 |
| 状态 | 在线（绿色）/ 离线（灰色）/ 忙碌（橙色）|

### 5.3 Skills 浏览器

- 展示所有可用 Skills（从各 Gateway 加载）
- 每个 Skill 显示：名称、描述、触发关键词

### 5.4 Plugins 管理

| 功能 | 说明 |
|------|------|
| 插件列表 | 展示所有已安装 Plugins |
| 启用/禁用 | 开关控制插件是否生效 |

### 5.5 Models 选择

- 当前可用模型列表（从各 Gateway 加载）
- 显示模型名称、上下文窗口、状态

---

## 6. Tab3 我的

### 6.1 Settings 设置

- 个人信息
- 通知设置
- 多设备设置
- 主题设置

### 6.2 Usage 用量统计

- Token 使用统计
- 成本估算

### 6.3 Profiles 配置

- 多 Profile 支持
- Profile 切换

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
    mode TEXT DEFAULT 'broadcast',  -- broadcast/mention
    trigger_tokens INTEGER DEFAULT 100000,  -- 触发压缩的 token 数
    max_history_tokens INTEGER DEFAULT 32000,  -- 压缩后最大 token 数
    tail_message_count INTEGER DEFAULT 20,  -- 保留最近消息条数
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

-- 消息（扩展支持流式和工具调用）
CREATE TABLE messages (
    id TEXT PRIMARY KEY,
    room_id TEXT NOT NULL,
    sender_id TEXT,
    sender_type TEXT,  -- 'user'/'agent'
    sender_name TEXT,
    content TEXT NOT NULL,
    content_type TEXT DEFAULT 'text',  -- text/image/voice
    extra TEXT,  -- JSON for image_url, voice_text, tool_calls, thinking 等
    parent_id TEXT,  -- for threading/pipeline
    is_streaming BOOLEAN DEFAULT FALSE,  -- 是否正在流式输出
    is_aborted BOOLEAN DEFAULT FALSE,  -- 是否被中止
    created_at INTEGER NOT NULL,
    FOREIGN KEY (room_id) REFERENCES rooms(id)
);

-- Gateway 配置（重命名自 machines）
CREATE TABLE gateways (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    name TEXT NOT NULL,
    address TEXT NOT NULL,  -- IP:Port 或域名:Port
    status TEXT DEFAULT 'offline',  -- online/offline
    last_seen INTEGER,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Agent 配置
CREATE TABLE agents (
    id TEXT PRIMARY KEY,
    gateway_id TEXT NOT NULL,
    remote_id TEXT NOT NULL,  -- ID on Remote Gateway
    name TEXT NOT NULL,
    description TEXT,
    avatar TEXT,
    profile TEXT,  -- JSON profile data
    status TEXT DEFAULT 'offline',  -- online/offline/busy
    invited BOOLEAN DEFAULT FALSE,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (gateway_id) REFERENCES gateways(id)
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

-- 压缩后的消息摘要（用于 Context Compression）
CREATE TABLE message_summaries (
    id TEXT PRIMARY KEY,
    room_id TEXT NOT NULL,
    start_message_id TEXT NOT NULL,
    end_message_id TEXT NOT NULL,
    summary TEXT NOT NULL,  -- LLM 生成的摘要
    token_count INTEGER NOT NULL,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (room_id) REFERENCES rooms(id)
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
| `WS /ws/chat` | WebSocket | 聊天 WebSocket（含流式） |
| `GET /gateways` | GET | Gateway 列表 |
| `POST /gateways` | POST | 添加 Gateway |
| `GET /gateways/{id}/agents` | GET | 从 Gateway 发现 Agent |
| `GET /agents` | GET | Agent 列表 |
| `POST /rooms/{id}/agents` | POST | 添加 Agent 到群 |

---

## 8. 不需要的功能（明确排除）

以下 hermes-web-ui 功能在一期 **不实现**：

| 功能 | 原因 |
|------|------|
| Terminal（终端） | 移动端不需要 |
| Channels（Telegram/Discord 集成） | 移动端直接交互 |
| Profiles 导入/导出 | 简化处理 |
| WeChat/WeCom/Feishu 平台集成 | 不需要 |
| Jobs 定时任务 | 后续版本考虑 |
| Kanban 看板 | 后续版本考虑 |

---

## 9. 需要补充的功能（新增）

### 9.1 Tool Calls 展示

- Agent 执行工具时的中间过程
- 显示工具名称、输入参数、执行结果
- 前端可折叠/展开

### 9.2 Reasoning/Thinking 展示

- Agent 的思考过程
- 可折叠显示
- 节省 UI 空间

### 9.3 消息队列

- Agent 正在回复时，用户再发消息应该排队
- 前端显示"等待 Agent 空闲..."

### 9.4 Abort 支持

- 用户可以中断 Agent 的回复
- 后端收到 abort 事件后停止获取数据
- 前端显示"已中止"

---

## 10. 技术实现要点

### 10.1 WebSocket 流式响应

```python
# 后端调用远程 Gateway
async def stream_agent_response(gateway_url: str, messages: list):
    async with httpx.AsyncClient() as client:
        async with client.stream(
            "POST",
            f"{gateway_url}/v1/responses",
            json={"messages": messages},
            timeout=120.0
        ) as response:
            async for chunk in response.aiter_bytes():
                # 分片推送到 WebSocket 客户端
                await websocket.send_bytes(chunk)
```

### 10.2 Context Compression 实现

```python
class ContextEngine:
    def __init__(self, trigger_tokens: int = 100000, max_history_tokens: int = 32000):
        self.trigger_tokens = trigger_tokens
        self.max_history_tokens = max_history_tokens

    async def should_compress(self, room_id: str) -> bool:
        # 计算当前 token 数，超过阈值则压缩
        current_tokens = await self.count_tokens(room_id)
        return current_tokens >= self.trigger_tokens

    async def compress(self, room_id: str) -> str:
        # 1. 获取需要压缩的消息
        # 2. 保留最近 tailMessageCount 条原文
        # 3. 旧消息调用 LLM 生成摘要
        # 4. 返回压缩后的上下文
```

### 10.3 Agent 协作链

```python
async def process_agent_mention(room_id: str, message: str, sender: str):
    mentioned_agents = extract_mentions(message)  # 解析 @AgentName

    for agent in mentioned_agents:
        # 调用远程 Gateway
        response = await call_gateway(agent.gateway_address, agent.remote_id, message)

        # 如果 Agent 回复中也有 @，继续递归
        if has_mentions(response):
            await process_agent_mention(room_id, response, agent.name)
```

---

## 11. 部署

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
