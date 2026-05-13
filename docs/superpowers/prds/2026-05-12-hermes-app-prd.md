# Hermes App 产品需求文档（PRD）

> **文档版本：** v2.0
> **编制日期：** 2026-05-12
> **更新日期：** 2026-05-13
> **状态：** 草稿
> **密级：** 内部

---

## 1. 产品概述

### 1.1 产品背景

用户在使用 hermes-web-ui（Web 版）时，希望有移动端 App 能随时与 AI Agent 对话和管理任务。hermes-web-ui 本身是桌面优先的 Web 应用，缺乏移动端体验。

本产品是完全独立的移动端应用，功能参考 hermes-web-ui，但针对移动场景重新设计交互体验，不依赖其现有服务。

### 1.2 产品定义

**一句话定位：** 移动端的 AI Agent 协作平台，支持多用户群聊、多 Agent 调度和远程 Gateway 管理。

**核心价值：** 随时随地通过手机与 AI Agent 交互，灵活组建 Agent 协作群组，通过添加远程 Gateway 地址发现和使用 Agent 资源。

### 1.3 术语澄清

| 术语 | 定义 | 说明 |
|------|------|------|
| **Gateway** | 远程 AI Gateway 服务地址 | 对应 hermes-web-ui 中的 Machine/IP:Port，用户添加远程地址（如 192.168.1.100:8642）|
| **Agent** | Gateway 上发现的 AI 实体 | Agent = Profile + Gateway 连接能力，用户无法在本机跑 Gateway 子进程 |
| **Context Compression** | 上下文压缩 | 当对话 token 超过阈值时，自动压缩旧消息保留关键上下文 |

### 1.4 目标用户

| 用户类型 | 场景描述 |
|---------|---------|
| AI 开发者 | 调试多 Agent 协作，实时查看对话效果 |
| 技术团队 | 多人共用 Agent 资源，按需调用 |
| AI 爱好者 | 体验多 Agent 群聊，探索 Agent 能力 |

### 1.5 成功指标

- 用户可在 3 分钟内完成注册并发起第一句对话
- 群聊消息延迟 < 2 秒（WebSocket 推送）
- App 冷启动时间 < 3 秒

---

## 2. 功能需求

### 2.1 用户体系

#### 2.1.1 账号与认证

| 功能 | 描述 | 优先级 |
|------|------|--------|
| 用户注册 | 用户名（3-50字符）+ 密码（至少6字符） | P0 |
| 用户登录 | 返回 Access Token（1小时）+ Refresh Token（7天） | P0 |
| Token 刷新 | 支持 Refresh Token 换新 Access Token | P0 |
| 登出 | 清除本地 Token | P0 |
| 个人信息 | 查看用户名、注册时间、多设备开关 | P1 |

#### 2.1.2 多设备支持

- 默认单设备登录（同一账号不能同时在两台设备登录）
- 用户可开启"多设备允许"开关
- 多设备模式下，所有设备均能收到 WebSocket 消息推送

#### 2.1.3 身份与权限

| 角色 | 权限范围 |
|------|---------|
| 群主 | 创建群、踢人、设置管理员、转让群主、解散群 |
| 管理员 | 添加/移除成员、修改群信息 |
| 成员 | 发送消息、查看历史、主动退群 |

---

### 2.2 Tab1：对话（群聊）

#### 2.2.1 对话列表页

**列表设计**
- 统一消息列表（单聊+群聊混排，参考微信混合列表样式）
- 每个对话卡片显示：群头像、群名、最后一条消息（截断显示）、时间戳、未读数红点
- 置顶功能（可选，留待二期）

**交互行为**
- 点击进入对话详情
- 列表顶部固定搜索栏，支持按群名搜索
- 右滑或长按显示快捷操作菜单（置顶、删除）

**创建群聊**
- 点击右上角"+"或"新建群"按钮
- 输入群名（必填）
- 选择群头像（预设头像池，支持自定义头像 URL）
- 选择入群方式：邀请码 或 链接邀请

#### 2.2.2 加群方式

| 方式 | 流程 |
|------|------|
| 邀请码 | 创建群后生成6位邀请码 → 其他用户输入邀请码加入 |
| 链接邀请 | 生成分享链接（格式：`hermesapp://join/{invite_code}`）→ 点击链接 → 已登录则直接入群，未登录跳转登录页 |

**邀请码规则**
- 6位字母数字组合
- 创建时生成，不支持自定义
- 长期有效（暂不支持过期机制）

#### 2.2.3 群聊功能

**成员管理**
- 群主可设置管理员（最多3人）
- 群主/管理员可踢除成员（需二次确认）
- 成员可主动退出群聊
- 成员列表页：显示头像、用户名、角色标签（群主/管理员）

**消息类型**

| 类型 | 说明 | 支持格式 |
|------|------|---------|
| 文字 | 纯文本消息 | - |
| 图片 | 支持 JPEG/PNG/GIF | 最大 10MB |
| 语音 | 原声发送，可选自动转文字 | 最大 60 秒 |

**消息推送**
- WebSocket 持久连接，实时推送新消息
- App 在后台时通过系统推送通知（参考 iOS APNs / Android FCM）

**输入体验**
- 底部工具栏：语音入口（左）、输入框（中）、图片入口、更多"+"（右）
- 展开"更多"显示：图片、拍照、文件
- 快捷工具布局参考微信，但更简洁

#### 2.2.4 Agent 交互流程（核心）

**Agent 的来源**

1. 用户在 App 添加远程 Gateway 地址（如 `192.168.1.100:8642`）
2. App 从 Gateway 发现可用的 Agent（每个 Gateway 对应一个 Agent/Profile）
3. 用户把 Agent 拉入群聊房间
4. 之后通过 @mention 调用

**消息路由模式**

| 模式 | 说明 | 触发条件 |
|------|------|---------|
| 广播模式 | 用户发消息，所有 Agent 都收到并回复 | 默认模式 |
| 指定模式 | 用户用 @mention 指定某个 Agent 回复 | 消息含 @AgentName |
| 协作链 | Agent A 可以 @Agent B，形成协作链 | Agent 回复中 @其他Agent |

**流式响应**

Agent 回复是逐字流式输出的，App 端需要像 ChatGPT 一样实时更新消息气泡：

| 阶段 | 后端行为 | 前端行为 |
|------|---------|---------|
| 1. 用户发消息 | 收到 WebSocket message 事件 | 显示消息 |
| 2. 判断路由 | 广播或指定 | - |
| 3. 调用 Gateway | HTTP POST /v1/responses (SSE) | 显示"Agent 思考中..." |
| 4. 流式返回 | 分片推送 message.delta 事件 | **实时更新消息气泡** |
| 5. 完成 | 推送 message.done | 显示完整回复 |

**消息队列**

- Agent 正在回复时，用户再发消息应该排队等待
- 前端显示"等待 Agent 空闲..."

**Abort 支持**

- 用户可以中断 Agent 的回复
- 点击"停止"按钮发送 abort 事件
- 后端收到 abort 事件后，停止从 Gateway 获取数据
- 前端显示"已中止"

#### 2.2.5 Tool Calls 和 Reasoning 展示

**Tool Calls 展示**

Agent 执行工具时的中间过程展示（如搜索、代码执行）：

| 阶段 | 显示内容 |
|------|---------|
| 触发工具 | 显示工具名称（如 "Searching the web..."）|
| 执行中 | 显示参数 JSON（可折叠）|
| 执行完成 | 显示结果（可折叠）|

**Thinking/Reasoning 展示**

- Agent 的思考过程
- 可折叠显示（类似 ChatGPT 的 think 折叠）
- 节省 UI 空间

#### 2.2.6 Context Compression（上下文压缩）

**触发条件**
- 当对话 token 累积超过 `triggerTokens`（默认 10 万）
- 自动压缩旧消息

**压缩效果**
- 保留最近 N 条消息原文（`tailMessageCount`，默认 20）
- 旧消息用 LLM 生成摘要
- 压缩后的上下文传给 Agent，避免超出模型窗口

**群聊场景尤为重要：** 多 Agent 来回对话时 token 增长很快。

#### 2.2.7 WebSocket 协议

**客户端发送事件**

```
join           → 加入群聊 Room
leave          → 离开群聊 Room
message        → 发送消息
mention        → @提及 Agent
abort          → 中断 Agent 回复
typing         → 正在输入
stop_typing    → 停止输入
```

**服务端推送事件**

```
message           → 新消息
message.delta     → 流式片段（逐字更新）
message.done      → 流式结束
message.error     → 流式出错
context_status    → 'idle' | 'compressing' | 'replying'
agent.thinking    → Agent 思考过程
agent.tool_call   → Agent 工具调用
member_joined     → 成员加入
member_left       → 成员离开
typing            → 成员正在输入
```

**连接管理**
- WebSocket 连接建立时携带 JWT Token 进行认证
- 连接断开时自动重连（指数退避，最长30秒）
- 心跳 ping/pong 间隔 30 秒

#### 2.2.8 消息同步策略

- 登录时同步最近 7 天的消息（按时间倒序）
- 更早的消息上滑加载更多（每次加载20条）
- 增量同步：记录本地最后一条消息的时间戳，跳过已同步消息

---

### 2.3 Tab2：发现

#### 2.3.1 Gateway 管理

| 功能 | 描述 |
|------|------|
| 添加 Gateway | 输入远程地址（如 192.168.1.100:8642），为其命名 |
| Gateway 列表 | 显示已添加的 Gateway，支持删除 |
| 连接测试 | 保存前测试连通性，显示在线/离线状态 |
| 发现 Agent | 从 Gateway 发现可用的 Agent 列表 |

**Gateway 状态**
- 在线（绿色）：Gateway 可达，正常响应
- 离线（灰色）：Gateway 连接失败
- 忙碌（橙色）：正在处理请求

#### 2.3.2 Agent 管理

| 功能 | 描述 |
|------|------|
| Agent 列表 | 展示所有可用 Agent（按 Gateway 分组） |
| Agent 详情 | 名字、描述、头像、所属 Gateway、在线状态 |
| 添加到群 | 从 Agent 列表选择，添加到指定群聊 |
| 头像编辑 | 预设头像池 + 自定义图片 URL |

**Agent 状态**
- 在线（绿色）：Gateway 可达，正常响应
- 离线（灰色）：Gateway 连接失败
- 忙碌（橙色）：正在处理请求

#### 2.3.3 Skills 浏览器

- 展示所有可用 Skills（从各 Gateway 加载）
- 每个 Skill 显示：名称、描述、触发关键词

#### 2.3.4 Plugins 管理

| 功能 | 描述 |
|------|------|
| 插件列表 | 展示所有已安装 Plugins |
| 启用/禁用 | 开关控制插件是否生效 |

#### 2.3.5 Models 选择

- 当前可用模型列表（从各 Gateway 加载）
- 显示模型名称、上下文窗口、状态

---

### 2.4 Tab3：我的

#### 2.4.1 Settings 设置

| 功能 | 描述 |
|------|------|
| 个人信息 | 修改用户名、头像 |
| 通知设置 | 推送开关、免打扰时段 |
| 多设备管理 | 查看已登录设备列表（设备名/登录时间），支持远程登出 |
| 主题设置 | 浅色/深色/跟随系统 |
| 清除缓存 | 清理本地消息缓存 |
| 关于 | 版本号、用户协议、隐私政策 |

#### 2.4.2 Usage 用量统计

| 指标 | 说明 |
|------|------|
| Token 使用 | 按模型分组显示 Token 消耗量 |
| 对话次数 | 累计发起对话数 |
| 成本估算 | 按模型单价估算费用（需配置单价） |

#### 2.4.3 Profiles 配置

- 多 Profile 支持（如：开发环境 / 生产环境 / 个人）
- 每个 Profile 包含：Gateway 地址、默认 Agent、主题偏好
- 快速切换 Profile

---

## 3. 不需要的功能（明确排除）

以下 hermes-web-ui 功能在一期 **不实现**：

| 功能 | 原因 |
|------|------|
| Terminal（终端） | 移动端不需要 |
| Channels（Telegram/Discord 集成） | 移动端直接交互 |
| Profiles 导入/导出 | 简化处理 |
| WeChat/WeCom/Feishu 平台集成 | 不需要 |
| Jobs 定时任务 | 后续版本考虑 |
| Kanban 看板 | 后续版本考虑 |
| Logs 日志 | 后续版本考虑 |
| Memory 记忆 | 后续版本考虑 |

---

## 4. 数据需求

### 4.1 数据库 Schema

#### users（用户表）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | TEXT PK | UUID |
| username | TEXT UNIQUE | 用户名 |
| password_hash | TEXT | bcrypt 加密密码 |
| created_at | INTEGER | 创建时间戳 |
| multi_device | BOOLEAN | 是否允许多设备，默认 False |

#### rooms（群聊房间）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | TEXT PK | UUID |
| name | TEXT | 群名 |
| avatar | TEXT | 头像 URL |
| owner_id | TEXT FK | 群主用户 ID |
| mode | TEXT | 协作模式：broadcast/mention |
| trigger_tokens | INTEGER | 触发 Context 压缩的 Token 数，默认 100000 |
| max_history_tokens | INTEGER | 压缩后最大 Token 数，默认 32000 |
| tail_message_count | INTEGER | 保留最近消息条数，默认 20 |
| invite_code | TEXT | 邀请码 |
| created_at | INTEGER | 创建时间戳 |

#### room_members（群成员）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | TEXT PK | UUID |
| room_id | TEXT FK | 房间 ID |
| user_id | TEXT FK | 用户 ID |
| role | TEXT | 角色：owner/admin/member |
| joined_at | INTEGER | 加入时间戳 |

#### messages（消息）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | TEXT PK | UUID |
| room_id | TEXT FK | 房间 ID |
| sender_id | TEXT | 发送者 ID（用户或 Agent） |
| sender_type | TEXT | user / agent |
| sender_name | TEXT | 发送者显示名 |
| content | TEXT | 消息内容 |
| content_type | TEXT | text / image / voice |
| extra | TEXT | JSON 扩展（图片 URL、语音转文字、tool_calls、thinking 等）|
| parent_id | TEXT | 父消息 ID（用于线程/协作链）|
| is_streaming | BOOLEAN | 是否正在流式输出 |
| is_aborted | BOOLEAN | 是否被中止 |
| created_at | INTEGER | 创建时间戳 |

#### gateways（Gateway 配置）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | TEXT PK | UUID |
| user_id | TEXT FK | 所属用户 ID |
| name | TEXT | Gateway 名称 |
| address | TEXT | 地址（IP:Port 或域名:Port）|
| status | TEXT | online/offline |
| last_seen | INTEGER | 最后在线时间戳 |
| created_at | INTEGER | 添加时间戳 |

#### agents（Agent 配置）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | TEXT PK | UUID |
| gateway_id | TEXT FK | 所属 Gateway ID |
| remote_id | TEXT | 在远程 Gateway 上的 ID |
| name | TEXT | Agent 名称 |
| description | TEXT | Agent 描述 |
| avatar | TEXT | 头像 URL |
| profile | TEXT | JSON profile data |
| status | TEXT | online/offline/busy |
| invited | BOOLEAN | 是否已邀请入群 |
| created_at | INTEGER | 创建时间戳 |

#### room_agents（群里的 Agent）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | TEXT PK | UUID |
| room_id | TEXT FK | 房间 ID |
| agent_id | TEXT FK | Agent ID |
| joined_at | INTEGER | 加入时间戳 |

#### message_summaries（压缩后的消息摘要）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | TEXT PK | UUID |
| room_id | TEXT FK | 房间 ID |
| start_message_id | TEXT | 摘要起始消息 ID |
| end_message_id | TEXT | 摘要结束消息 ID |
| summary | TEXT | LLM 生成的摘要 |
| token_count | INTEGER | 压缩的 token 数 |
| created_at | INTEGER | 创建时间戳 |

---

## 5. API 需求

### 5.1 认证接口

| 接口 | 方法 | 说明 |
|------|------|------|
| `/auth/register` | POST | 用户注册 |
| `/auth/login` | POST | 用户登录 |
| `/auth/refresh` | POST | 刷新 Token |
| `/auth/logout` | POST | 登出 |
| `/auth/me` | GET | 获取当前用户信息 |

### 5.2 房间接口

| 接口 | 方法 | 说明 |
|------|------|------|
| `/rooms` | GET | 获取用户的房间列表 |
| `/rooms` | POST | 创建房间 |
| `/rooms/{id}` | GET | 获取房间详情 |
| `/rooms/{id}` | PUT | 更新房间信息（仅群主/管理员）|
| `/rooms/{id}` | DELETE | 删除房间（仅群主）|
| `/rooms/{id}/join` | POST | 通过邀请码加入 |
| `/rooms/{id}/members` | GET | 获取成员列表 |
| `/rooms/{id}/members/{user_id}` | DELETE | 移除成员 |
| `/rooms/{id}/agents` | GET | 获取群的 Agent 列表 |
| `/rooms/{id}/agents` | POST | 添加 Agent 到群 |
| `/rooms/{id}/agents/{agent_id}` | DELETE | 从群移除 Agent |

### 5.3 消息接口

| 接口 | 方法 | 说明 |
|------|------|------|
| `/rooms/{id}/messages` | GET | 获取消息历史（分页）|
| `/rooms/{id}/messages` | POST | 发送消息（HTTP 备用）|
| `/ws/chat` | WebSocket | 实时聊天 WebSocket（含流式）|

### 5.4 Gateway 与 Agent 接口

| 接口 | 方法 | 说明 |
|------|------|------|
| `/gateways` | GET | 获取 Gateway 列表 |
| `/gateways` | POST | 添加 Gateway |
| `/gateways/{id}` | DELETE | 删除 Gateway |
| `/gateways/{id}/agents` | GET | 从 Gateway 发现 Agent 列表 |
| `/agents` | GET | 获取所有 Agent |
| `/agents/{id}` | GET | 获取 Agent 详情 |

### 5.5 其他接口

| 接口 | 方法 | 说明 |
|------|------|------|
| `/skills` | GET | 获取 Skills 列表 |
| `/plugins` | GET | 获取 Plugins 列表 |
| `/plugins/{id}` | PUT | 更新插件状态 |
| `/models` | GET | 获取可用模型列表 |
| `/usage` | GET | 获取用量统计 |

---

## 6. 非功能需求

### 6.1 性能需求

| 指标 | 目标值 |
|------|--------|
| App 冷启动时间 | < 3 秒 |
| 消息列表首次加载 | < 1 秒 |
| WebSocket 消息延迟 | < 500ms |
| API 响应时间（P99） | < 2 秒 |
| 图片压缩 | 最大 10MB，聊天中展示缩略图 |

### 6.2 兼容性需求

| 平台 | 最低版本 |
|------|---------|
| iOS | iOS 14.0 |
| Android | Android 8.0（API 26）|
| Flutter | 3.x |

### 6.3 安全需求

- 密码 bcrypt 加密存储
- JWT Token 不存储明文（仅 Access Token 存于内存，Refresh Token 存于安全存储）
- HTTPS 强制（生产环境）
- WebSocket 连接需携带有效 JWT
- 邀请码 6 位随机（62^6 组合）

---

## 7. 附录

### 7.1 术语表

| 术语 | 定义 |
|------|------|
| Hermes Gateway | Hermes Agent 的远程网关服务，负责暴露 Agent 能力 |
| Context Compression | 当对话历史超过阈值时，自动压缩旧消息保留关键上下文 |
| Room | 群聊房间，对应一个对话上下文 |
| Agent | 可被 @提及的 AI 助手实体，来自远程 Gateway |
| Tool Calls | Agent 执行工具时的中间过程展示 |
| Reasoning/Thinking | Agent 的思考过程，可折叠显示 |

### 7.2 参考竞品

- 微信（消息列表、群聊体验）
- Slack/Discord（多频道、@mention）
- Telegram（机器人、群组管理）
- ChatGPT（流式输出、Thinking 折叠）

### 7.3 后续版本规划（暂不定在本期）

- 智能路由模式
- 流水线模式（Agent A → B → C 串行处理）
- Whisper ASR 语音转文字
- 视频消息
- 消息已读状态
- 群文件管理
- Jobs 定时任务
- Kanban 看板
- Logs 日志
- Memory 记忆

---

**文档审批**

| 角色 | 姓名 | 日期 | 签字 |
|------|------|------|------|
| 产品负责人 | - | - | - |
| 技术负责人 | - | - | - |
| 设计负责人 | - | - | - |
