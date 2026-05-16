# Hermes Manager - 系统设计文档

## 1. 项目概述

**项目名称：** Hermes Manager
**项目类型：** 移动端 AI 聊天应用（Flutter）+ Python 后端（FastAPI）
**核心功能：** 多用户群聊、多 Agent 协作的移动 AI 助手

### 系统组件

| 组件 | 技术栈 | 用途 |
|------|--------|------|
| hermes-server | Python/FastAPI + SQLite | REST API + WebSocket 服务 |
| hermes-app | Flutter + Riverpod | 移动端/桌面客户端 |
| Hermes Gateway | 外部服务 | AI Agent 路由和模型调用 |

---

## 2. 技术架构

### 2.1 后端架构 (hermes-server)

```
hermes-server/
├── app/
│   ├── main.py              # FastAPI 入口，/health 端点
│   ├── config.py            # pydantic-settings 配置
│   ├── database.py          # SQLAlchemy 异步设置
│   ├── api/                 # 路由处理
│   │   ├── auth.py          # 认证 (register/login/refresh/me)
│   │   ├── rooms.py         # 聊天室 CRUD
│   │   ├── messages.py      # 消息查询
│   │   ├── machines.py      # 机器管理 (遗留)
│   │   ├── gateways.py      # 网关管理 + 代理
│   │   ├── agents.py        # Agent 管理
│   │   └── ws.py            # WebSocket 聊天
│   ├── models/              # SQLAlchemy 模型
│   ├── schemas/             # Pydantic 请求/响应
│   ├── services/            # 业务逻辑
│   └── core/                # 安全、依赖注入、错误处理
└── docker-compose.prod.yml  # 生产部署
```

### 2.2 前端架构 (hermes-app)

```
hermes-app/lib/
├── main.dart
├── app.dart                 # HermesApp (MaterialApp)
├── core/config/
│   └── app_config.dart      # baseUrl, wsUrl, 超时, storage keys
├── data/
│   ├── models/              # 数据模型 (User, Room, Message, Agent, Machine)
│   └── providers/            # Riverpod 状态管理
├── presentation/
│   ├── screens/             # 页面
│   └── widgets/             # 组件 (MessageBubble, TGToast)
└── router/
    └── app_router.dart      # GoRouter 路由配置
```

---

## 3. API 设计

### 3.1 认证 `/auth`

| 方法 | 路径 | 描述 |
|------|------|------|
| POST | `/auth/register` | 用户注册 |
| POST | `/auth/login` | 登录，获取 token |
| POST | `/auth/refresh` | 刷新 token |
| GET | `/auth/me` | 获取当前用户信息 |

### 3.2 聊天室 `/rooms`

| 方法 | 路径 | 描述 |
|------|------|------|
| GET | `/rooms` | 列出用户的所有聊天室 |
| POST | `/rooms` | 创建聊天室 |
| GET | `/rooms/{room_id}` | 获取聊天室详情 |
| PUT | `/rooms/{room_id}` | 更新聊天室 |
| DELETE | `/rooms/{room_id}/leave` | 离开聊天室 |
| GET | `/rooms/{room_id}/members` | 列出成员 |
| DELETE | `/rooms/{room_id}/members/{user_id}` | 移除成员 |
| PUT | `/rooms/{room_id}/members/{user_id}` | 更新成员角色 |
| POST | `/rooms/join` | 通过邀请码加入 |
| GET | `/rooms/{room_id}/messages` | 获取消息（分页） |

### 3.3 网关 `/gateways`

| 方法 | 路径 | 描述 |
|------|------|------|
| GET | `/gateways` | 列出用户的网关 |
| GET | `/gateways/discover` | 扫描本地网络中的网关 |
| POST | `/gateways` | 添加网关 |
| GET | `/gateways/{gateway_id}` | 获取网关详情 |
| DELETE | `/gateways/{gateway_id}` | 删除网关 |
| POST | `/gateways/{gateway_id}/test` | 测试网关连接 |
| PATCH | `/gateways/{gateway_id}` | 更新网关 |
| GET | `/gateways/{gateway_id}/agents` | 发现网关上的 Agents |
| GET | `/proxy/gateway/{path}` | 代理请求到网关 |

### 3.4 Agent `/agents`

| 方法 | 路径 | 描述 |
|------|------|------|
| GET | `/agents` | 列出用户的所有 Agent |
| GET | `/machines/{machine_id}/agents` | 列出机器上的 Agent |
| POST | `/agents` | 创建 Agent |
| GET | `/agents/{agent_id}` | 获取 Agent 详情 |
| PUT | `/agents/{agent_id}` | 更新 Agent |
| DELETE | `/agents/{agent_id}` | 删除 Agent |
| GET | `/rooms/{room_id}/agents` | 列出聊天室中的 Agent |
| POST | `/rooms/{room_id}/agents` | 添加 Agent 到聊天室 |
| DELETE | `/rooms/{room_id}/agents/{agent_id}` | 从聊天室移除 Agent |

### 3.5 WebSocket `/ws/chat`

**连接方式：** `ws://host/ws/chat?token=<access_token>`

**客户端→服务端事件：**
| 事件 | 描述 |
|------|------|
| `join` | 加入聊天室 |
| `message` | 发送消息 |
| `abort` | 中止运行中的 Agent |
| `typing` / `stop_typing` | 打字状态 |

**服务端→客户端事件：**
| 事件 | 描述 |
|------|------|
| `message.delta` | 消息流式片段 |
| `reasoning.delta` | 推理过程片段 |
| `tool.started` | 工具调用开始 |
| `tool.completed` | 工具调用完成 |
| `tool.error` | 工具调用失败 |
| `run.started` | Agent 开始运行 |
| `run.completed` | Agent 运行完成 |
| `run.failed` | Agent 运行失败 |
| `abort.started` | 中止开始 |
| `abort.completed` | 中止完成 |
| `queue_updated` | 队列状态更新 |
| `member_joined` / `member_left` | 成员进出 |

---

## 4. 数据模型

### 4.1 数据库表

#### users
| 字段 | 类型 | 说明 |
|------|------|------|
| id | String (PK) | UUID |
| username | String | 唯一索引 |
| password_hash | String | Argon2 加密 |
| created_at | Integer | 时间戳 |
| multi_device | Boolean | 多设备标记 |

#### machines
| 字段 | 类型 | 说明 |
|------|------|------|
| id | String (PK) | UUID |
| user_id | String (FK) | 所属用户 |
| name | String | 名称 |
| address | String | IP:Port 或本地路径 |
| api_key | String | 网关 API Key（可选） |
| mode | String | "http" 或 "local" |
| profile_name | String | 本地 profile 名称 |
| created_at | Integer | 时间戳 |

#### agents
| 字段 | 类型 | 说明 |
|------|------|------|
| id | String (PK) | UUID |
| machine_id | String (FK) | 所属机器 |
| remote_id | String | Gateway 上的 ID |
| name | String | 名称 |
| description | String | 描述 |
| avatar | String | 头像 URL |
| profile | String | Profile 配置 |
| invited | Boolean | 是否被邀请 |
| created_at | Integer | 时间戳 |

#### rooms
| 字段 | 类型 | 说明 |
|------|------|------|
| id | String (PK) | UUID |
| name | String | 聊天室名称 |
| avatar | String | 头像 URL |
| owner_id | String (FK) | 所有者 |
| mode | String | broadcast/mention/router/pipeline |
| trigger_tokens | Integer | 触发 token 数 |
| max_history_tokens | Integer | 最大历史 token |
| tail_message_count | Integer | 保留消息数 |
| invite_code | String | 邀请码 |
| created_at | Integer | 时间戳 |

#### room_members
| 字段 | 类型 | 说明 |
|------|------|------|
| id | String (PK) | UUID |
| room_id | String (FK) | 聊天室 |
| user_id | String (FK) | 用户 |
| role | String | owner/admin/member |
| joined_at | Integer | 时间戳 |

#### messages
| 字段 | 类型 | 说明 |
|------|------|------|
| id | String (PK) | UUID |
| room_id | String (FK) | 聊天室 |
| sender_id | String | 发送者 ID |
| sender_type | String | user/agent |
| sender_name | String | 发送者名称 |
| content | Text | 消息内容 |
| content_type | String | text/image/voice |
| extra | Text | JSON（tool_calls/reasoning 等） |
| parent_id | String | 线程/管道父消息 ID |
| is_streaming | Boolean | 是否在流式传输 |
| is_aborted | Boolean | 是否被中止 |
| created_at | Integer | 时间戳 |

#### room_agents
| 字段 | 类型 | 说明 |
|------|------|------|
| id | String (PK) | UUID |
| room_id | String (FK) | 聊天室 |
| agent_id | String (FK) | Agent |
| joined_at | Integer | 时间戳 |

---

## 5. 认证机制

- **算法：** JWT (HS256)
- **密码哈希：** Argon2
- **Access Token：** 60 分钟过期
- **Refresh Token：** 7 天过期

**流程：**
1. 用户注册/登录 → 获取 access_token + refresh_token
2. 客户端存储 token
3. 请求时携带 `Authorization: Bearer <token>`
4. `get_current_user()` 依赖验证 token 并提取用户

---

## 6. 部署架构

### hermes-server
- Docker 容器运行
- 端口：3002:8000
- 数据持久化：`/vol1/1000/nas1/docker/hermes-server:/app/data`
- 数据库：SQLite (`hermes.db`)
- DEBUG 模式通过环境变量 `DEBUG=true` 控制

### hermes-app
- Flutter Web 构建
- Python http.server 提供静态文件
- 端口：3003
- 日志目录：`hermes-app/logs/app.log`

### 重启脚本
- `restart-hermes-server.sh` — 重启后端服务
- `restart-hermes-app.sh` — 重启前端服务

---

## 7. 配置参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| JWT_SECRET_KEY | your-secret-key... | 生产需修改 |
| ACCESS_TOKEN_EXPIRE_MINUTES | 60 | Access Token 过期分钟 |
| REFRESH_TOKEN_EXPIRE_DAYS | 7 | Refresh Token 过期天 |
| DEFAULT_GATEWAY_URL | http://localhost:8642 | 默认网关地址 |
| DEFAULT_MODEL | claude-sonnet-4-20250514 | 默认模型 |

---

## 8. Flutter 主题

- **背景：** #212121 (dark)
- **卡片：** #2A2A2A
- **输入框：** #343541
- **主色：** #5856D6 (purple)
- **文字主色：** #ECECEC
- **文字次色：** #A0A0A0
- **成功：** #34C759
- **错误：** #FF3B30