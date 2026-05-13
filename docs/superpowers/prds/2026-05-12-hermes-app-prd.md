# Hermes App 产品需求文档（PRD）

> **文档版本：** v1.0
> **编制日期：** 2026-05-12
> **状态：** 草稿
> **密级：** 内部

---

## 1. 产品概述

### 1.1 产品背景

用户在使用 hermes-web-ui（Web 版）时，希望有移动端 App 能随时与 AI Agent 对话和管理任务。hermes-web-ui 本身是桌面优先的 Web 应用，缺乏移动端体验。

本产品是完全独立的移动端应用，功能参考 hermes-web-ui，但针对移动场景重新设计交互体验，不依赖其现有服务。

### 1.2 产品定义

**一句话定位：** 移动端的 AI Agent 协作平台，支持多用户群聊、多 Agent 调度和 Agent 配置管理。

**核心价值：** 随时随地通过手机与 AI Agent 交互，灵活组建 Agent 协作群组，高效管理多台机器上的 Agent 资源。

### 1.3 目标用户

| 用户类型 | 场景描述 |
|---------|---------|
| AI 开发者 | 调试多 Agent 协作，实时查看对话效果 |
| 技术团队 | 多人共用 Agent 资源，按需调用 |
| AI 爱好者 | 体验多 Agent 群聊，探索 Agent 能力 |

### 1.4 成功指标

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

**语音消息**
- 发送原声录音
- 用户可在设置中开启"自动转文字"，发送时附上转写文本
- 录音时显示实时波形
- 播放时支持外放和耳机切换

**消息推送**
- WebSocket 持久连接，实时推送新消息
- App 在后台时通过系统推送通知（参考 iOS APNs / Android FCM）

**输入体验**
- 底部工具栏：语音入口（左）、输入框（中）、图片入口、更多"+"（右）
- 展开"更多"显示：图片、拍照、文件
- 快捷工具布局参考微信，但更简洁

#### 2.2.4 多 Agent 模式

创建群时可选择 Agent 协作模式：

| 模式 | 说明 | 触发条件 |
|------|------|---------|
| 广播模式 | 用户发消息，所有 Agent 都能看到并回复 | 默认模式 |
| 指定模式 | 用户用 @mention 指定某个 Agent 回复 | 消息含 @AgentName |
| 智能路由 | 系统自动判断该由哪个 Agent 处理 | 后续版本 |

**@Mention 路由**
- 用户/Agent 在消息中 @某个 Agent，被 @者处理
- Agent 也可以 @其他 Agent，形成协作链
- 界面显示 @ 提及时自动高亮并跳转至对应 Agent 卡片

#### 2.2.5 消息同步策略

- 登录时同步最近 7 天的消息（按时间倒序）
- 更早的消息上滑加载更多（每次加载20条）
- 增量同步：记录本地最后一条消息的时间戳，跳过已同步消息

#### 2.2.6 WebSocket 协议

**客户端发送事件**

```
join        → 加入群聊 Room
leave       → 离开群聊 Room
message     → 发送消息
mention     → @提及 Agent
typing      → 正在输入
stop_typing → 停止输入
```

**服务端推送事件**

```
message           → 新消息
member_joined     → 成员加入
member_left       → 成员离开
typing            → 成员正在输入
context_status    → Agent 处理状态（compressing/replying/ready）
message.processed → 消息已被 Agent 处理
```

**连接管理**
- WebSocket 连接建立时携带 JWT Token 进行认证
- 连接断开时自动重连（指数退避，最长30秒）
- 心跳 ping/pong 间隔 30 秒

---

### 2.3 Tab2：发现

#### 2.3.1 机器管理

| 功能 | 描述 |
|------|------|
| 添加机器 | 输入机器地址（IP:Port），为其命名 |
| 机器列表 | 显示已添加的机器，支持删除 |
| 连接测试 | 保存前测试连通性，显示在线/离线状态 |
| 加载 Agent | 从已连接的机器获取 Agent 列表 |

#### 2.3.2 Agent 管理

| 功能 | 描述 |
|------|------|
| Agent 列表 | 展示所有可用 Agent（按机器分组） |
| Agent 详情 | 名字、描述、头像、所属机器、在线状态 |
| 添加到群 | 从 Agent 列表选择，添加到指定群聊 |
| 头像编辑 | 预设头像池 + 自定义图片 URL |

**Agent 状态**
- 在线（绿色）：Gateway 可达，正常响应
- 离线（灰色）：Gateway 连接失败
- 忙碌（橙色）：正在处理请求

#### 2.3.3 Skills 浏览器

- 展示所有可用 Skills（从各机器加载）
- 每个 Skill 显示：名称、描述、触发关键词
- 点击可查看 Skill 详情（参数说明、使用示例）

#### 2.3.4 Plugins 管理

| 功能 | 描述 |
|------|------|
| 插件列表 | 展示所有已安装 Plugins |
| 启用/禁用 | 开关控制插件是否生效 |
| 插件详情 | 名称、版本、描述、配置参数 |

#### 2.3.5 Models 选择

- 当前可用模型列表（从各机器加载）
- 显示模型名称、上下文窗口、状态
- 选择当前会话使用的模型

#### 2.3.6 Jobs 定时任务

| 功能 | 描述 |
|------|------|
| 任务列表 | 显示所有定时任务 |
| 创建任务 | 选择目标 Agent、输入 prompt、设置 Cron 表达式 |
| 编辑任务 | 修改任务参数 |
| 启用/暂停 | 控制任务是否执行 |
| 执行记录 | 查看最近执行结果（成功/失败/输出摘要） |

#### 2.3.7 Kanban 看板

- 默认看板视图（参考 Trello）
- 列表：待办/进行中/已完成
- 卡片：标题、描述、负责人、截止日期
- 支持拖拽调整状态
- 与 Hermes Agent 任务同步（Agent 可自动创建/更新卡片）

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

#### 2.4.2 Logs 日志

- 系统日志列表（按时间倒序）
- 日志级别：DEBUG / INFO / WARNING / ERROR
- 支持按级别筛选
- 日志详情页：时间、级别、来源、内容

#### 2.4.3 Usage 用量统计

| 指标 | 说明 |
|------|------|
| Token 使用 | 按模型分组显示 Token 消耗量 |
| 对话次数 | 累计发起对话数 |
| 成本估算 | 按模型单价估算费用（需配置单价） |
| 趋势图 | 近7天/30天用量曲线 |

#### 2.4.4 Gateway 网关管理

- 展示已配置的 Hermes Gateway 列表
- 添加/编辑/删除 Gateway
- 显示每个 Gateway 的 Agent 数量和在线状态

#### 2.4.5 Profiles 配置

- 多 Profile 支持（如：开发环境 / 生产环境 / 个人）
- 每个 Profile 包含：Gateway 地址、默认 Agent、主题偏好
- 快速切换 Profile

#### 2.4.6 Memory 记忆

- 展示 Agent 的持久化记忆摘要
- 支持手动添加/编辑记忆条目
- 记忆类型：事实（Facts）、偏好（Preferences）、上下文（Context）

---

## 3. 数据需求

### 3.1 数据库 Schema

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
| mode | TEXT | 协作模式：broadcast/mention/router/pipeline |
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
| extra | TEXT | JSON 扩展（图片 URL、语音转文字等） |
| parent_id | TEXT | 父消息 ID（用于线程/流水线） |
| created_at | INTEGER | 创建时间戳 |

#### machines（机器配置）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | TEXT PK | UUID |
| user_id | TEXT FK | 所属用户 ID |
| name | TEXT | 机器名称 |
| address | TEXT | 地址（IP:Port） |
| created_at | INTEGER | 添加时间戳 |

#### agents（Agent 配置）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | TEXT PK | UUID |
| machine_id | TEXT FK | 所属机器 ID |
| remote_id | TEXT | 在 Hermes Gateway 上的 ID |
| name | TEXT | Agent 名称 |
| description | TEXT | Agent 描述 |
| avatar | TEXT | 头像 URL |
| profile | TEXT | 关联 Profile |
| invited | BOOLEAN | 是否已邀请入群 |
| created_at | INTEGER | 创建时间戳 |

#### room_agents（群里的 Agent）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | TEXT PK | UUID |
| room_id | TEXT FK | 房间 ID |
| agent_id | TEXT FK | Agent ID |
| joined_at | INTEGER | 加入时间戳 |

---

## 4. API 需求

### 4.1 认证接口

| 接口 | 方法 | 说明 |
|------|------|------|
| `/auth/register` | POST | 用户注册 |
| `/auth/login` | POST | 用户登录 |
| `/auth/refresh` | POST | 刷新 Token |
| `/auth/logout` | POST | 登出 |
| `/auth/me` | GET | 获取当前用户信息 |

### 4.2 房间接口

| 接口 | 方法 | 说明 |
|------|------|------|
| `/rooms` | GET | 获取用户的房间列表 |
| `/rooms` | POST | 创建房间 |
| `/rooms/{id}` | GET | 获取房间详情 |
| `/rooms/{id}` | PUT | 更新房间信息（仅群主/管理员） |
| `/rooms/{id}` | DELETE | 删除房间（仅群主） |
| `/rooms/{id}/join` | POST | 通过邀请码加入 |
| `/rooms/{id}/members` | GET | 获取成员列表 |
| `/rooms/{id}/members/{user_id}` | DELETE | 移除成员 |
| `/rooms/{id}/agents` | GET | 获取群的 Agent 列表 |
| `/rooms/{id}/agents` | POST | 添加 Agent 到群 |
| `/rooms/{id}/agents/{agent_id}` | DELETE | 从群移除 Agent |

### 4.3 消息接口

| 接口 | 方法 | 说明 |
|------|------|------|
| `/rooms/{id}/messages` | GET | 获取消息历史（分页） |
| `/rooms/{id}/messages` | POST | 发送消息（HTTP 备用） |
| `/ws/chat` | WebSocket | 实时聊天 WebSocket |

### 4.4 机器与 Agent 接口

| 接口 | 方法 | 说明 |
|------|------|------|
| `/machines` | GET | 获取机器列表 |
| `/machines` | POST | 添加机器 |
| `/machines/{id}` | DELETE | 删除机器 |
| `/machines/{id}/agents` | GET | 从机器加载 Agent 列表 |
| `/agents` | GET | 获取所有 Agent |
| `/agents/{id}` | GET | 获取 Agent 详情 |

### 4.5 其他接口

| 接口 | 方法 | 说明 |
|------|------|------|
| `/skills` | GET | 获取 Skills 列表 |
| `/plugins` | GET | 获取 Plugins 列表 |
| `/plugins/{id}` | PUT | 更新插件状态 |
| `/models` | GET | 获取可用模型列表 |
| `/jobs` | GET | 获取定时任务列表 |
| `/jobs` | POST | 创建定时任务 |
| `/jobs/{id}` | PUT | 更新定时任务 |
| `/jobs/{id}` | DELETE | 删除定时任务 |
| `/usage` | GET | 获取用量统计 |

---

## 5. 非功能需求

### 5.1 性能需求

| 指标 | 目标值 |
|------|--------|
| App 冷启动时间 | < 3 秒 |
| 消息列表首次加载 | < 1 秒 |
| WebSocket 消息延迟 | < 500ms |
| API 响应时间（P99） | < 2 秒 |
| 图片压缩 | 最大 10MB，聊天中展示缩略图 |

### 5.2 兼容性需求

| 平台 | 最低版本 |
|------|---------|
| iOS | iOS 14.0 |
| Android | Android 8.0（API 26） |
| Flutter | 3.x |

### 5.3 安全需求

- 密码 bcrypt 加密存储
- JWT Token 不存储明文（仅 Access Token 存于内存，Refresh Token 存于安全存储）
- HTTPS 强制（生产环境）
- WebSocket 连接需携带有效 JWT
- 邀请码 6 位随机（62^6 组合）

### 5.4 日志与监控

- Crash 日志上报（iOS Crashlytics / Android Firebase Crashlytics）
- 性能监控（APM）
- 关键事件埋点（注册、登录、创群、发消息）

---

## 6. 附录

### 6.1 术语表

| 术语 | 定义 |
|------|------|
| Hermes Gateway | Hermes Agent 的网关服务，负责暴露 Agent 能力 |
| Context Compression | 当对话历史超过阈值时，自动压缩旧消息保留关键上下文 |
| Room | 群聊房间，对应一个对话上下文 |
| Agent | 可被 @提及的 AI 助手实体 |

### 6.2 参考竞品

- 微信（消息列表、群聊体验）
- Slack/Discord（多频道、@mention）
- Telegram（机器人、群组管理）

### 6.3 后续版本规划（暂不定在本期）

- 智能路由模式
- 流水线模式（Agent A → B → C 串行处理）
- Whisper ASR 语音转文字
- 视频消息
- 消息已读状态
- 群文件管理

---

**文档审批**

| 角色 | 姓名 | 日期 | 签字 |
|------|------|------|------|
| 产品负责人 | - | - | - |
| 技术负责人 | - | - | - |
| 设计负责人 | - | - | - |
