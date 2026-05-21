# Hermes Mobile 产品需求文档 v3.1

> 1:1 聊天与群聊合并设计
>
> Version: 3.1
>
> Date: 2026-05-20
>
> 状态: 已评审（v3.1.1）

---

# 1. 产品概述

## 1.1 更新背景

本次更新将原有的「1:1 聊天」和「群聊」两套功能合并为统一的「会话」模型，通过模式区分行为，降低用户理解成本，提升代码复用率。

## 1.2 核心变化

| 变化 | 旧设计 | 新设计 |
|------|--------|--------|
| 会话类型 | 1:1 聊天 + 群聊（两套入口） | 统一会话，模式区分 |
| 数据模型 | 两套 API | 一套 Room API |
| UI | 分离 | 统一组件，UI 自适应 |
| 扩展性 | 1:1 无法升级为群 | v2 支持升级为群聊 |

---

# 2. 核心设计原则

## 2.1 统一会话模型

```
会话（Room）
├── 类型：通过 mode 和 agentIds.length 判断
├── 成员：用户 + N 个 Agent
└── 行为：由「mode」决定
```

## 2.2 类型判断规则

| 判断条件 | type | 说明 |
|----------|------|------|
| agentIds.length == 1 | 1:1 | 直接调用配置的 Agent |
| agentIds.length > 1 | group | 走 broadcast/mention/router |

**注意**：
- 数据库**不新增 `type` 字段**，type 由前端根据 `mode` + `agentIds` 长度实时判断
- API Response 中返回 `type` 字段是为了让前端方便判断，**type 值由后端根据 `mode` 和 `agentIds.length` 计算得出**，不是独立存储的 DB 字段

## 2.3 四种协作模式

| 模式 | 标识 | type | 行为 |
|------|------|------|------|
| **direct** | 1:1 | 1:1 | 只调用配置的 1 个 Agent |
| **broadcast** | 广播 | group | 所有 Agent 同时响应 |
| **mention** | 指定 | group | 只有 **@** 被点的 Agent 响应 |
| **router** | 路由 | group | Gateway 智能路由 |

---

# 3. 数据模型

## 3.1 rooms 表设计

```sql
CREATE TABLE rooms (
 id VARCHAR(36) PRIMARY KEY,
 name VARCHAR NOT NULL,
 avatar VARCHAR,
 owner_id VARCHAR(36) NOT NULL,
 mode VARCHAR DEFAULT 'direct', -- direct/broadcast/mention/router
 agent_id VARCHAR(36), -- 1:1 时关联的 Agent ID
 profile_id VARCHAR(36), -- Agent 使用的 profile（内部字段，不暴露）
 invite_code VARCHAR, -- 群聊邀请码（懒生成）
 created_at INTEGER NOT NULL
);
```

## 3.2 字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| mode | direct/broadcast/mention/router | 协作模式 |
| agent_id | VARCHAR(36) | 1:1 时关联的 Agent ID |
| profile_id | VARCHAR(36) | 内部查询优化，不暴露给前端 |
| invite_code | VARCHAR | 懒生成，首次邀请时生成 |

## 3.3 创建行为

| type | mode | agent_id | invite_code |
|------|------|----------|-------------|
| 1:1 | direct | 必填 | null（不生成） |
| group | broadcast/mention/router | null | 懒生成 |

## 3.4 现有 rooms 表 vs 新设计

| 字段 | 现有设计 | 新设计 | 变更说明 |
|------|----------|--------|----------|
| id | VARCHAR(36) PK | VARCHAR(36) PK | 不变 |
| name | VARCHAR | VARCHAR | 不变 |
| avatar | VARCHAR | VARCHAR | 不变 |
| owner_id | VARCHAR(36) FK | VARCHAR(36) FK | 不变 |
| mode | VARCHAR | VARCHAR DEFAULT 'direct' | 扩展，支持 direct/broadcast/mention/router |
| agent_id | NULL | VARCHAR(36) | **新增**：1:1 时关联的 Agent |
| profile_id | NULL | VARCHAR(36) | **新增**：内部查询优化字段 |
| invite_code | VARCHAR | VARCHAR | 不变（懒生成） |
| created_at | INTEGER | INTEGER | 不变 |

**迁移说明**：
- `mode` 默认值为 `'direct'`，现有 room 的 `mode` 字段在迁移脚本中统一填充为 `'direct'`
- `agent_id` 和 `profile_id` 为新增字段，允许 NULL

---

# 4. 功能规格

## 4.1 会话管理

### 4.1.1 创建会话

| 功能 | 说明 | 优先级 |
|------|------|--------|
| 创建 1:1 会话 | 选择 1 个 Agent，自动设置 direct 模式 | P0 |
| 创建群聊 | 选择多个 Agent，选择模式（broadcast/mention/router） | P0 |
| 邀请码加入 | 输入 6 位邀请码加入群聊 | P0 |
| 退出群聊 | 成员退出（非 owner） | P0 |
| 解散群聊 | owner 解散群聊 | P1 |
| 升级 1:1 为群聊 | 向 1:1 会话添加更多 Agent | **v2** |

### 4.1.2 会话列表（Chats Tab）

| 功能 | 说明 | 优先级 |
|------|------|--------|
| 全部会话 | 显示所有 1:1 和群聊 | P0 |
| 运行中 | 有 Agent 正在运行的会话（**仅群聊**） | P0 |
| 我的会话 | 我创建的会话 | P1 |
| 团队会话 | 我参与的团队群聊 | P1 |
| 会话置顶 | 重要会话置顶显示 | P1 |

**注意**：Running Tasks **只在群聊显示**，1:1 场景简单不需要。

### 4.1.3 会话搜索

| 功能 | 说明 | 优先级 |
|------|------|--------|
| 会话内搜索 | 在当前会话中搜索历史消息 | P1 |
| 全局搜索 | 搜索所有会话和消息 | P2 |

---

## 4.2 消息功能

### 4.2.1 发送消息

| 功能 | 说明 | 优先级 |
|------|------|--------|
| 发送文本消息 | 用户发送文本 | P0 |
| @ 提及 Agent | 在群聊中 @ 特定 Agent | P0 |
| 消息引用/回复 | 针对某条消息进行回复（parent_id） | P1 |

### 4.2.2 消息展示

| 功能 | 说明 | 优先级 |
|------|------|--------|
| Timeline 展示 | User Message → Agent Message → Tool → Reasoning | P0 |
| 流式消息 | 实时更新内容 + 光标闪烁 | P0 |
| Tool Timeline | 显示工具调用过程（默认折叠） | P0 |
| Reasoning | 显示 AI 推理过程（默认折叠） | P1 |
| Token 统计 | 显示输入/输出 Token 数量 | P1 |

### 4.2.3 消息气泡样式

| 类型 | 样式 |
|------|------|
| 用户消息 | 右侧，背景色 #7C6CFF，文字白色 |
| Agent 消息 | 左侧，背景色 #2A2A2A，Agent 头像 + 名称 |
| 流式消息 | 带光标闪烁，实时更新 |
| 错误消息 | 橙色 #FF9500，SelectableText 可复制 |

---

## 4.3 Agent 协作

### 4.3.1 模式行为

**direct 模式（1:1）**
- 用户发送消息 → 直接调用 `room.agent_id` 对应的 Agent
- 无需 @ 提及
- **Agent 忙碌时：直接拒绝**，UI 提示"Agent 正忙，请稍后再试"
- 不需要消息队列

**broadcast 模式（广播）**
- 用户发送消息 → 所有在群聊中的 Agent 同时响应
- 适合需要多角度分析的场景

**mention 模式（指定）**
- 用户发送消息 → 只有 ` 被点的 Agent 响应
- 如果没有 @ 任何人，则提示"请 @ 一个 Agent"

**router 模式（路由）**
- 用户发送消息 → Gateway 智能判断由哪个 Agent 处理

### 4.3.2 消息队列（仅群聊）

| 场景 | 行为 |
|------|------|
| Agent 空闲 | 立即处理消息 |
| Agent 忙碌 | 消息进入队列等待 |
| 队列满 | 提示"Agent 正忙，请稍后再试" |
| 用户中止 | 清空队列中的用户消息 |

---

## 4.4 群聊管理

### 4.4.1 成员管理

| 功能 | 说明 | 优先级 |
|------|------|--------|
| 查看成员列表 | 显示所有成员和在线状态 | P0 |
| 邀请码邀请 | 生成分享链接或邀请码（**懒生成**） | P0 |
| 移除成员 | admin/owner 移除成员 | P1 |
| 转让群聊 | owner 转让群聊所有权 | v2 |

### 4.4.2 邀请码设计

- **生成时机**：用户点击"邀请"时生成（非创建时）
- **1:1 会话**：不生成邀请码
- **群聊**：首次邀请时生成 6 位邀请码

### 4.4.3 角色权限

| 角色 | 权限 |
|------|------|
| owner | 解散群聊、任命 admin、移除任意成员、修改群聊设置 |
| admin | 移除普通成员、管理 Agent |
| member | 发送消息、查看消息 |

### 4.4.4 错误处理与边界场景

| 场景 | 处理方式 |
|------|----------|
| Agent 数量为 0 | 返回错误："请至少选择 1 个 Agent" |
| Agent 数量超过限制（>10） | 提示"最多选择 10 个 Agent" |
| 1:1 会话中尝试 @ Agent | 前端隐藏 @ 按钮，后端忽略 |
| @ 提及不存在的 Agent | 提示"该 Agent 不在群聊中" |
| router 模式 Gateway 不可用 | 提示"Agent 暂时不可用，请稍后再试" |
| direct 模式 Agent 忙碌 | 返回 `agent_busy` 事件，前端提示"Agent 正忙，请稍后再试" |
| 用户在非群聊中尝试邀请 | 1:1 会话不显示邀请入口 |
| 邀请码格式错误 | 提示"请输入 6 位邀请码" |
| 邀请码无效/已过期 | 提示"邀请码无效，请检查后重试" |

**邀请码规范**：6 位字母数字组合，无过期时间，v1 版本不设有效期限制。

---

# 5. 页面结构

## 5.1 App 结构

```
Splash
 ├─ Token 有效 → MainApp
 └─ Token 无效 → Login

MainApp
 ├─ Chats（对话）
 ├─ Workflows（工作流）
 ├─ Notifications（通知）
 └─ Profile（设置）
```

## 5.2 路由

| 路由 | 页面 | 说明 |
|------|------|------|
| /login | LoginScreen | 登录 |
| /register | RegisterScreen | 注册 |
| /home | HomeScreen | 主页面（Chats Tab） |
| /chat/:roomId | ChatScreen | 聊天页（1:1/群聊自适应） |
| /chat/create | CreateSessionScreen | 创建会话页 |

---

# 6. 页面设计

## 6.1 Chats 首页

```
┌─────────────────────────────────────┐
│ Hermes 🔍 搜索 │
├─────────────────────────────────────┤
│ [全部] [我的] [团队] [运行中] │ │ ← Tab
├─────────────────────────────────────┤
│ ┌─────────────────────────────────┐ │
│ │ 🚀 AI Research Team │ │ ← Running Tasks（仅群聊）
│ │ [展开] │ │
│ └─────────────────────────────────┘ │
├─────────────────────────────────────┤
│ │
│ ┌───┐ Claude │ │ ← 1:1 会话
│ │ C │ Agent: 已完成代码审查 │ │
│ │ │ 刚刚 │ │
│ └───┘ │ │
│ │
│ ┌───┐ AI Research Team │ │ ← 群聊
│ │ A │ Agent: 分析中... │ │
│ │ │ 广播模式 2m ago ●3 │ │
│ └───┘ │ │
│ │
└─────────────────────────────────────┘
```

**设计要点：**
- 1:1 会话：显示 Agent 名称，无成员数，无 Running Tasks
- 群聊：显示群名 + 成员数 + 在线数，有 Running Tasks
- 流式指示点（●）：表示有 Agent 正在响应
- "●3" 表示该群聊有 3 个 Agent 正在运行中

---

## 6.2 Chat 聊天页（1:1 模式）

```
┌─────────────────────────────────────┐
│ ← Claude ✕ │ │ ← 简洁 AppBar
├─────────────────────────────────────┤
│ │
│ ┌───────────────────────────┐ │
│ │ 你 10:30 │ │
│ │ 这个 PR 怎么样了？ │ │
│ └───────────────────────────┘ │
│ │
│ ┌───────────────────────────┐ │
│ │ 🤖 Claude 10:31 │ │
│ │ │ │
│ │ 已完成审查，建议如下... │ │
│ │ │ │
│ │ [▾ 展开工具 (3)] │ │
│ └───────────────────────────┘ │
│ │
├─────────────────────────────────────┤
│ ┌───────────────────────────┐📤│
│ │ 输入消息... │ │
│ └───────────────────────────┘ │
└─────────────────────────────────────┘
```

**1:1 特点：**
- 无 @ 按钮（只有一个 Agent，不需要选择）
- 无成员列表入口
- 无 Running Tasks
- 简洁优先

---

## 6.3 Chat 聊天页（群聊模式）

```
┌─────────────────────────────────────┐
│ ← AI Research Team 4人 ⋮ │ │ ← 完整 AppBar
├─────────────────────────────────────┤
│ 👤👤🤖🤖 4 在线 │ │ ← 成员预览
├─────────────────────────────────────┤
│ │
│ ┌───────────────────────────┐ │
│ │ User1 10:30 │ │
│ │ 总结一下这个 PR │ │
│ └───────────────────────────┘ │
│ │
│ ┌───────────────────────────┐ │
│ │ 🤖 ResearchAgent 10:31 │ │
│ │ 分析结果如下... │ │
│ │ [▾ 展开工具 (3)] │ │
│ └───────────────────────────┘ │
│ │
├─────────────────────────────────────┤
│ ┌────────────────────────┐ @ │📤│
│ │ │ │ │ ← 有 @ 按钮
│ └────────────────────────┘ │
└─────────────────────────────────────┘
```

**群聊特点：**
- 有 @ 按钮（弹出 Agent 选择器）
- 有成员列表入口
- 有 Running Tasks
- 支持邀请码

---

## 6.4 创建会话页

```
┌─────────────────────────────────────┐
│ ← 新建会话 ✕ │
├─────────────────────────────────────┤
│ │
│ 会话名称 │
│ ┌───────────────────────────────┐ │
│ │ │ │
│ └───────────────────────────────┘ │
│ │
│ 选择 Agent │
│ ┌─────────────────────────────────┐ │
│ │ 🤖 ResearchAgent │ ○ │ │
│ ├─────────────────────────────────┤ │
│ │ 🤖 CodeAssistant │ ○ │ │ ← 单选 = 1:1
│ ├─────────────────────────────────┤ │
│ │ 🤖 DocWriter │ ○ │ │ 多选 = 群聊
│ └─────────────────────────────────┘ │
│ │
│ 模式（群聊时显示） │
│ [广播] [指定] [路由] │ │
│ │
│ ┌─────────────────────────────────┐ │
│ │ 创建会话 │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

---

# 7. API 设计

## 7.1 会话（Room）API

### 创建会话

```
POST /rooms
Body: {
 "name": string,
 "agentIds": string[], // 1个 = 1:1，多个 = 群聊
 "mode": "direct" | "broadcast" | "mention" | "router"
}
Response: {
 "id": string,
 "name": string,
 "mode": string,
 "type": "1v1" | "group", // 后端根据 agentIds.length 计算得出，非独立 DB 字段
 "inviteCode": string | null // 群聊时返回 null（懒生成）
}
```

### 获取会话列表

```
GET /rooms
Query: ?type=1v1|group|all&status=running|all
Response: [Room]
```

### 获取会话详情

```
GET /rooms/{id}
Response: {
 ...Room,
 members: [Member],
 agents: [Agent],
 isMember: boolean
}
```

### 更新会话

```
PUT /rooms/{id}
Body: {
 "name"?: string
}
```

**注意**：1:1 不允许修改 mode，群聊才允许修改。

### 升级 1:1 为群聊（v2）

```
PUT /rooms/{id}/upgrade
Body: {
 "agentIds": string[],
 "mode": "broadcast" | "mention" | "router"
}
Response: {
 ...Room,
 type: "group" // 后端计算得出
}
```

### 解散/退出

```
DELETE /rooms/{id}/leave // 退出群聊
DELETE /rooms/{id} // 解散群聊（owner）
```

---

## 7.2 成员 API

```
GET /rooms/{id}/members // 成员列表
POST /rooms/{id}/join // 邀请码加入
POST /rooms/{id}/invite // 生成邀请码（懒生成）
DELETE /rooms/{id}/members/{userId} // 移除成员
PUT /rooms/{id}/members/{userId} // 更新成员角色
```

---

## 7.3 消息 API

```
GET /rooms/{id}/messages?before={messageId}&limit=20
Response: {
 messages: [Message],
 hasMore: boolean
}
```

### Message 类型

```typescript
interface Message {
 id: string;
 roomId: string;
 senderId: string;
 senderType: "user" | "agent";
 senderName: string;
 content: string;
 contentType: "text";
 extra: {
 toolCalls?: ToolCall[];
 reasoning?: string;
 tokens?: { input: number; output: number };
 } | null;
 parentId?: string; // 用于引用/回复
 isStreaming: boolean;
 isAborted: boolean;
 createdAt: number;
}
```

---

## 7.4 WebSocket 事件

### 客户端 → 服务端

| 事件 | payload | 说明 |
|------|---------|------|
| join | `{ "roomId": string }` | 加入会话 |
| message | `{ "roomId": string, "content": string }` | 发送消息 |
| abort | `{ "roomId": string }` | 中止运行 |
| typing | `{ "roomId": string }` | 正在输入 |
| stop_typing | `{ "roomId": string }` | 停止输入 |

### 服务端 → 客户端

| 事件 | payload | 说明 |
|------|---------|------|
| message | Message | 新消息 |
| message.delta | `{ "messageId": string, "content": string }` | 流式片段 |
| reasoning.delta | `{ "messageId": string, "content": string }` | 推理片段 |
| tool.started | `{ "tool": string, "arguments": object }` | 工具开始 |
| tool.completed | `{ "tool": string, "output": string, "duration": int }` | 工具完成 |
| tool.error | `{ "tool": string, "error": string }` | 工具失败 |
| run.started | `{ "runId": string }` | Agent 开始 |
| run.completed | `{ "runId": string }` | Agent 完成 |
| run.failed | `{ "runId": string, "error": string }` | Agent 失败 |
| queue_updated | `{ "queueLength": int }` | 队列更新（仅群聊） |
| agent_busy | `{}` | Agent 正忙（direct 模式） |
| member_joined | `{ "userId": string }` | 成员加入 |
| member_left | `{ "userId": string }` | 成员离开 |

### 新增事件

| 事件 | 触发场景 | 说明 |
|------|----------|------|
| agent_busy | direct 模式 Agent 忙碌时 | 替代队列机制 |

---

# 8. 设计决策总结

| # | 问题 | 决策 |
|---|------|------|
| 1 | type 字段 | 后端根据 agentIds.length 计算得出，API Response 返回，前端据此判断 type |
| 2 | 1:1 升级群聊 | v2 再做 |
| 3 | 1:1 关联 | agent_id 字段（profile_id 作内部优化） |
| 4 | broadcast 消息分组 | 不需要，v1 简化 |
| 5 | Running Tasks 位置 | 只在群聊显示 |
| 6 | 邀请码生成 | 懒生成（首次邀请时生成） |
| 7 | direct 模式忙碌处理 | 直接拒绝（agent_busy 事件） |
| 8 | WebSocket 事件命名 | v3.1 统一使用 camelCase（roomId/messageId/runId） |
| 9 | Agent 数量上限 | 群聊最多 10 个 Agent |
| 10 | 邀请码规范 | 6 位字母数字组合，无过期时间 |

---

# 9. 里程碑

| 阶段 | 内容 | 优先级 |
|------|------|--------|
| **Phase 1** | 后端：Room API 支持 type 判断，统一 Model | P0 |
| **Phase 2** | 后端：direct 模式 agent_busy 事件 | P0 |
| **Phase 3** | 前端：合并 1:1 和群聊 UI，共用组件 | P0 |
| **Phase 4** | 前端：创建会话流程（1:1 vs 群聊） | P0 |
| **Phase 5** | 前端：@ Agent 选择器（群聊） | P0 |
| **Phase 6** | 前后端联调 + 回归测试 | P0 |
| **Phase 7** | 邀请码懒生成功能 | P1 |
| **v2** | 1:1 升级为群聊功能 | v2 |

---

# 10. 验收标准

- [ ] 1:1 会话和群聊在同一个列表展示
- [ ] 创建 1:1 会话：选择 1 个 Agent，自动设置 direct 模式
- [ ] 创建群聊：选择多个 Agent，选择模式（broadcast/mention/router）
- [ ] 1:1 聊天页：无 @ 按钮，无成员列表，无 Running Tasks
- [ ] 群聊页：有 @ 按钮，有成员列表，有 Running Tasks
- [ ] 邀请码懒生成：群聊创建时 invite_code 为 null
- [ ] direct 模式 Agent 忙碌时返回 agent_busy 事件
- [ ] WebSocket 消息收发正常
- [ ] Tool Timeline 默认折叠，点击展开
- [ ] 流式消息实时更新 + 光标闪烁
- [ ] Token 统计显示正常

---

# 11. 术语表

| 术语 | 定义 |
|------|------|
| Room / 会话 | 统一的聊天会话单位，包含 1:1 和群聊 |
| Direct 模式 | 1:1 专属，只调用配置的 Agent |
| Broadcast 模式 | 广播模式，所有 Agent 同时响应 |
| Mention 模式 | 指定模式，只有 @ 的 Agent 响应 |
| Router 模式 | 路由模式，Gateway 智能分发 |
| Running Tasks | 正在运行的 Agent 任务（仅群聊） |
| Streaming | 实时流式输出 |
| Tool Call | Agent 调用外部工具 |
| 懒生成 | 首次使用时才生成，非创建时 |
