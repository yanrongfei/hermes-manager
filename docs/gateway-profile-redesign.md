# Gateway + Profile 架构重设计

## 1. 背景

当前 hermes-manager 存在以下问题：

- **Machine/Gateway 命名混乱**：后端同时存在 `/machines` 和 `/gateways` 两套 API，数据模型用 `Machine`，路由用 `/gateways`，语义不统一
- **缺少 Profile 概念**：`profile_name` 只是 Machine 上的字符串字段，不是一等实体，无法表达一个网关下多个 Profile 的场景
- **Agent 归属扁平**：Agent 直接挂在 Machine 上，无法区分同一网关不同 Profile 下的 Agent

参考 hermes-web-ui 的 Profile-centric 架构，将数据模型从 `Machine → Agent` 升级为 `Gateway → Profile → Agent` 三级模型。

## 2. 核心概念

```
Gateway (一个运行中的 Hermes 网关实例)
  └── Profile (网关上的一套配置：模型、技能、人格)
        └── Agent (Profile 下可对话的 AI 助手)
```

| 旧概念 | 新概念 | 变化说明 |
|--------|--------|----------|
| Machine | **Gateway** | 统一命名，废弃 Machine |
| Machine.profile_name | **Profile（独立实体）** | 从字符串字段升级为一等实体 |
| Agent.machine_id | **Agent.profile_id** | Agent 挂在 Profile 下 |

**移动端 vs Web UI 的区别：**

hermes-web-ui 的 BFF 运行在网关本机，可以直接管理网关生命周期（start/stop）。移动端是远程客户端，通过 hermes-server 代理访问 Gateway API 来获取 Profile 信息，不能直接 start/stop 网关。

---

## 3. 数据模型

### 3.1 gateways 表（替换原 machines 表）

```sql
CREATE TABLE gateways (
    id          VARCHAR(36) PRIMARY KEY,
    user_id     VARCHAR(36) NOT NULL REFERENCES users(id),
    name        VARCHAR,                -- 用户自定义名称，如 "Home Gateway"
    address     VARCHAR NOT NULL,       -- IP:Port 或域名，如 192.168.1.100:8642
    api_key     VARCHAR,                -- 网关 API Key（可选）
    status      VARCHAR DEFAULT 'unknown',  -- online / offline / unknown
    last_seen   INTEGER,                -- 最后在线时间戳
    created_at  INTEGER NOT NULL
);
```

**删除的字段：** `mode`（http/local）、`profile_name`（属于 Profile 概念）

### 3.2 profiles 表（新增）

```sql
CREATE TABLE profiles (
    id          VARCHAR(36) PRIMARY KEY,
    gateway_id  VARCHAR(36) NOT NULL REFERENCES gateways(id) ON DELETE CASCADE,
    remote_name VARCHAR NOT NULL,       -- Gateway 上的 profile 名称
    alias       VARCHAR,                -- 用户自定义别名
    model       VARCHAR,                -- 默认模型
    provider    VARCHAR,                -- 模型提供商
    skills      INTEGER DEFAULT 0,      -- 已安装技能数量
    description VARCHAR,                -- Profile 描述
    synced_at   INTEGER,                -- 最后同步时间
    created_at  INTEGER NOT NULL,
    UNIQUE(gateway_id, remote_name)
);
```

**设计说明：**
- Profile 数据从 Gateway API **拉取并缓存**，不是本地创建的
- `remote_name` 是 Gateway 上的原始名称，`alias` 是用户给的自定义名
- `synced_at` 控制缓存新鲜度，超过阈值自动重新拉取

### 3.3 agents 表（修改）

```sql
CREATE TABLE agents (
    id          VARCHAR(36) PRIMARY KEY,
    profile_id  VARCHAR(36) NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    remote_id   VARCHAR NOT NULL,       -- Gateway 上的 Agent ID
    name        VARCHAR NOT NULL,
    description VARCHAR,
    avatar      VARCHAR,
    invited     BOOLEAN DEFAULT FALSE,
    created_at  INTEGER NOT NULL,
    UNIQUE(profile_id, remote_id)
);
```

**变化：** `machine_id` → `profile_id`，删除 `profile` 字符串字段（Profile 已是一等实体）

---

## 4. API 设计

### 4.1 Gateway API（统一 `/gateways`，废弃 `/machines`）

| 方法 | 路径 | 描述 |
|------|------|------|
| GET | `/gateways` | 列出用户的所有网关（含 profile_count、agent_count） |
| GET | `/gateways/discover` | 扫描局域网网关 |
| POST | `/gateways` | 手动添加网关 |
| GET | `/gateways/{id}` | 网关详情 |
| PATCH | `/gateways/{id}` | 更新网关（名称、API Key） |
| DELETE | `/gateways/{id}` | 删除网关（级联删除 profiles + agents） |
| POST | `/gateways/{id}/test` | 测试连通性 |
| POST | `/gateways/{id}/sync` | 从网关拉取 profiles 和 agents |
| GET | `/gateways/{id}/profiles` | 列出网关下的所有 profiles |

**`/sync` 端点核心逻辑：**

1. 通过 GatewayChannel 连接网关
2. 调用网关 API 获取 profiles 列表
3. 对每个 profile upsert 到 profiles 表
4. 获取每个 profile 下的 agents 并 upsert
5. 更新 gateway.status、gateway.last_seen 和 profile.synced_at

```json
// POST /gateways/{id}/sync 响应示例
{
    "profiles_synced": 3,
    "agents_synced": 8,
    "gateway_status": "online"
}
```

### 4.2 Profile API（新增）

| 方法 | 路径 | 描述 |
|------|------|------|
| GET | `/gateways/{id}/profiles` | 列出网关下所有 profiles |
| GET | `/profiles/{id}` | Profile 详情（含 agents 列表） |
| PATCH | `/profiles/{id}` | 更新本地缓存（alias） |
| POST | `/profiles/{id}/refresh` | 重新从网关拉取该 profile 的信息 |

**注意：** 移动端不能 create/delete profile（那是 web-ui 的职责），只能读取和缓存。

### 4.3 Agent API（调整）

| 方法 | 路径 | 描述 |
|------|------|------|
| GET | `/agents` | 列出用户所有 agents（跨网关） |
| GET | `/profiles/{id}/agents` | 列出某 profile 下的 agents |
| POST | `/agents/{id}/invite` | 邀请 Agent（标记 invited=true） |
| DELETE | `/agents/{id}` | 移除本地缓存的 Agent |
| GET | `/rooms/{id}/agents` | 列出聊天室中的 agents |
| POST | `/rooms/{id}/agents` | 添加 Agent 到聊天室 |
| DELETE | `/rooms/{id}/agents/{agent_id}` | 从聊天室移除 Agent |

**删除的端点：** `POST /agents`（Agent 从网关同步，不可手动创建）、`PUT /agents/{id}`（Agent 属性由网关定义）、`GET /machines/{id}/agents`

### 4.4 Proxy API（保留）

| 方法 | 路径 | 描述 |
|------|------|------|
| ANY | `/proxy/gateway/{path}` | 代理请求到网关 |

---

## 5. 同步策略

| 场景 | 行为 |
|------|------|
| 首次添加网关 | 自动全量同步 |
| 进入网关详情页 | 检查 `synced_at`，超过 1 小时自动同步 |
| 手动点击同步按钮 | 强制全量同步 |
| 网关离线 | 显示缓存数据 + 离线提示 |

---

## 6. 移动端页面设计

### 6.1 DiscoverTab（发现页）调整

```
Section: 连接
┌─────────────────────────────────────────┐
│ 🌐 Gateway 管理    管理 Hermes 网关连接   │ → GatewaysScreen
│ 🤖 Agent 目录      浏览可用 AI 助手       │ → AgentsDirectoryScreen
└─────────────────────────────────────────┘
```

### 6.2 GatewaysScreen（替换原 MachinesScreen）

```
AppBar: "Gateway 管理"    [扫描按钮]

┌─ 扫描区域 ─────────────────────────────┐
│ [📡 扫描网关]  扫描局域网中的 Gateway    │
│                                         │
│ 扫描结果:                               │
│  • 192.168.1.100:8642  🟢在线  [添加]   │
│  • 192.168.1.105:8642  🔴离线           │
└─────────────────────────────────────────┘

┌─ 已添加的网关 ─────────────────────────┐
│ Card:                                   │
│ 🌐 Home Gateway                        │
│    192.168.1.100:8642                   │
│    3 profiles · 8 agents               │
│    🟢 在线 · 最后同步: 10分钟前         │
│                        [同步] [详情 →]  │
│                                         │
│ Card:                                   │
│ 🌐 Office Gateway                      │
│    10.0.0.50:8642                       │
│    2 profiles · 4 agents               │
│    🔴 离线                             │
│                        [测试] [详情 →]  │
└─────────────────────────────────────────┘

FAB: [+ 手动添加网关]
```

### 6.3 GatewayDetailScreen（替换原 MachineDetailScreen）

```
AppBar: "Home Gateway"    [⋮ 编辑/删除/测试连接]

┌─ 网关信息 ─────────────────────────────┐
│ 地址: 192.168.1.100:8642               │
│ 状态: 🟢 在线                          │
│ 最后同步: 10分钟前  [立即同步]          │
└─────────────────────────────────────────┘

┌─ Profiles ─────────────────────────────┐
│ Card:                                   │
│ 📂 default                             │
│    模型: claude-sonnet-4                │
│    技能: 5个 · Agent: 3个              │
│    [查看 Agents →]                      │
│                                         │
│ Card:                                   │
│ 📂 coder                               │
│    模型: claude-opus-4                  │
│    技能: 12个 · Agent: 2个             │
│    [查看 Agents →]                      │
└─────────────────────────────────────────┘
```

### 6.4 ProfileDetailScreen（新增页面）

```
AppBar: "default (Profile)"    [↻ 刷新]

┌─ Profile 信息 ─────────────────────────┐
│ 模型: claude-sonnet-4-20250514          │
│ 提供商: Anthropic                       │
│ 技能数量: 5                             │
│ 别名: [可编辑]                          │
└─────────────────────────────────────────┘

┌─ Agents ───────────────────────────────┐
│ ListTile:                               │
│ 🤖 Assistant                            │
│    通用 AI 助手                         │
│    [邀请到聊天室]                        │
│                                         │
│ ListTile:                               │
│ 🤖 Coder                                │
│    编程专用 Agent                       │
│    [邀请到聊天室]                        │
└─────────────────────────────────────────┘
```

### 6.5 AgentsDirectoryScreen（替换原 agents_screen.dart）

```
AppBar: "Agent 目录"

┌─ 筛选栏 ───────────────────────────────┐
│ [全部] [Home GW] [Office GW]  下拉筛选 │
└─────────────────────────────────────────┘

┌─ Agent 列表 ───────────────────────────┐
│ Card:                                   │
│ 🤖 Assistant                            │
│    来源: Home Gateway > default         │
│    模型: claude-sonnet-4                │
│    [已邀请 ✓]                           │
│                                         │
│ Card:                                   │
│ 🤖 Coder                                │
│    来源: Home Gateway > coder           │
│    模型: claude-opus-4                  │
│    [邀请]                               │
└─────────────────────────────────────────┘
```

---

## 7. 交互流程

### 7.1 添加网关并同步 Agent

```
用户点击 [扫描网关]
    ↓
扫描局域网，发现网关列表
    ↓
用户点击 [添加]
    ↓
POST /gateways { name, address, api_key }
    ↓ (自动触发)
POST /gateways/{id}/sync  ← 从网关拉取 profiles + agents
    ↓
显示同步结果: "发现 3 个 Profile, 8 个 Agent"
    ↓
自动跳转到 GatewayDetailScreen
    ↓
用户浏览 Profile → 选择 Agent → 邀请到聊天室
```

---

## 8. 修改文件清单

### 后端（hermes-server/）

| 操作 | 文件 |
|------|------|
| 新建 | `app/models/gateway.py` |
| 新建 | `app/models/profile.py` |
| 修改 | `app/models/agent.py` |
| 修改 | `app/models/__init__.py` |
| 修改 | `app/models/user.py` |
| 新建 | `app/schemas/gateway.py` |
| 新建 | `app/schemas/profile.py` |
| 修改 | `app/schemas/agent.py` |
| 重写 | `app/api/gateways.py` |
| 删除 | `app/api/machines.py` |
| 重写 | `app/api/agents.py` |
| 新建 | `app/services/gateway_sync.py` |
| 重命名→重写 | `app/services/machine.py` → `app/services/gateway.py` |
| 修改 | `app/services/agent.py` |
| 修改 | `app/services/gateway_channel.py` |
| 修改 | `app/main.py` |

### 前端（hermes-app/）

| 操作 | 文件 |
|------|------|
| 新建 | `lib/data/models/gateway.dart` |
| 新建 | `lib/data/models/profile.dart` |
| 修改 | `lib/data/models/agent.dart` |
| 删除 | `lib/data/models/machine.dart` |
| 新建 | `lib/data/providers/gateway_provider.dart` |
| 新建 | `lib/data/providers/profile_provider.dart` |
| 删除 | `lib/data/providers/machine_provider.dart` |
| 新建 | `lib/presentation/screens/gateways_screen.dart` |
| 新建 | `lib/presentation/screens/gateway_detail_screen.dart` |
| 新建 | `lib/presentation/screens/profile_detail_screen.dart` |
| 新建 | `lib/presentation/screens/agents_directory_screen.dart` |
| 删除 | `lib/presentation/screens/machines_screen.dart` |
| 修改 | `lib/presentation/screens/discover_tab.dart` |
