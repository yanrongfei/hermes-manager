# Hermes Manager - 产品需求文档 (PRD)

## 1. 产品概述

**产品名称：** Hermes Manager
**产品类型：** 移动端 AI 聊天应用（H5 + Flutter Web）
**版本：** 1.0.0
**后端地址：** `http://62.234.25.205:3002`
**Web 地址：** `http://62.234.25.205:3003`
**一句话描述：** 支持多用户群聊、多 Agent 协作的移动 AI 助手

---

## 2. 页面结构

```
/ (SplashScreen)
    ├─ Token 有效 → /home
    └─ Token 无效/不存在 → /login

/login (LoginScreen)
    └─ 登录成功 → /home

/register (RegisterScreen)
    └─ 注册成功 → 自动登录 → /home

/home (HomeScreen)
    ├─ [0] ChatListTab — 聊天室列表
    ├─ [1] DiscoverTab — 发现（网关/Agent/技能/插件）
    └─ [2] ProfileTab — 个人设置

/chat/:roomId (ChatScreen)
    └─ 聊天室内实时对话

/push (额外页面)
/callback (额外页面)
```

---

## 3. 功能模块详细规格

---

### 3.1 认证模块

#### 3.1.1 登录页 `/login`

**UI 布局（垂直居中，单列）：**

| 元素 | 类型 | 说明 |
|------|------|------|
| Logo 图 | Image | `assets/images/hermesagent.png`，72×72，居中 |
| 产品名称 | Text | "Hermes Agent"，32px，bold，颜色 #ECECEC，居中 |
| 用户名输入框 | TextFormField | label="用户名"，prefixIcon=Icons.person_outline，颜色 #A0A0A0 |
| 密码输入框 | TextFormField | label="密码"，prefixIcon=Icons.lock_outline，后缀图标可切换显示/隐藏 |
| 登录按钮 | ElevatedButton | "登录"，背景色 #5856D6，full width，14px padding |
| 注册链接 | TextButton | "没有账号？去注册"，颜色 #A0A0A0 |

**交互逻辑：**

| 操作 | 行为 |
|------|------|
| 点击登录 | 调用 `/auth/login`，成功存 token → go('/home')，失败显示 Toast 错误 |
| 点击注册链接 | go('/register') |
| 用户名/密码空 | 点击登录按钮时，显示"请输入用户名"/"请输入密码" |

**API：**
```
POST /auth/login
Body: { "username": string, "password": string }
成功: { "access_token": string, "refresh_token": string }
失败: { "code": string, "msg": string }
```

---

#### 3.1.2 注册页 `/register`

**UI 布局：** 同登录页

| 元素 | 类型 | 说明 |
|------|------|------|
| 产品名称 | Text | "Hermes Agent"，32px，bold |
| 用户名输入框 | TextFormField | label="用户名"，prefixIcon=Icons.person_outline |
| 密码输入框 | TextFormField | label="密码"，prefixIcon=Icons.lock_outline，可切换显示 |
| 注册按钮 | ElevatedButton | "注册"，背景色 #5856D6，full width |
| 登录链接 | TextButton | "已有账号？去登录"，颜色 #A0A0A0 |

**交互逻辑：**

| 操作 | 行为 |
|------|------|
| 点击注册 | 调用 `/auth/register`，成功 → 自动调用 login → go('/home')，失败显示 Toast |
| 点击登录链接 | go('/login') |
| 用户名已存在 | 显示"用户名已被注册，请尝试其他用户名" |
| 密码为空/太短 | 显示"请输入密码" |

**API：**
```
POST /auth/register
Body: { "username": string, "password": string }
成功: { "id": string, "username": string }
失败: { "code": "AUTH_001", "msg": "用户名已被注册" }
```

---

### 3.2 首页 `/home`

#### 3.2.1 ChatListTab（对话 Tab）

**顶部栏：**
- 标题："对话"，颜色 #ECECEC
- 右下角 FAB：两个
  - 小 FAB（`heroTag='join'`）：背景色 #3A3A3A，图标 Icons.link，"加入群聊"
  - 大 FAB（`heroTag='create'`）：背景色 #5856D6，图标 Icons.add，"创建群聊"

**列表行为：**
| 状态 | 显示 |
|------|------|
| 有聊天室 | ListView，Card 样式，颜色 #2A2A2A，左侧圆形头像（首字母），聊天室名称，模式标签 |
| 空 | 居中图标（Icons.chat_bubble_outline，64px），文字"暂无群聊"，副文字"点击右下角创建群聊" |
| 加载中 | Center CircularProgressIndicator |
| 加载失败 | 居中图标（Icons.wifi_off，48px），文字"加载失败，请检查网络"，重试按钮 |

**聊天室 Card：**
- 左侧 CircleAvatar：首字母大写，背景色 #5856D6
- 标题：聊天室名称，颜色 #ECECEC
- 副标题：模式（broadcast="广播模式" / mention="指定模式"），颜色 #A0A0A0，12px
- 右侧：Icons.chevron_right，颜色 #A0A0A0
- onTap：context.push('/chat/${room.id}')

**创建群聊弹窗（showModalBottomSheet）：**
| 元素 | 说明 |
|------|------|
| 标题 | "创建群聊"，20px，bold |
| 群聊名称输入框 | TextField，label="群聊名称"，背景色 #343541 |
| 协作模式选择 | ChoiceChip，"广播模式"（默认选中）/ "指定模式"，选中颜色 #5856D6 |
| 创建按钮 | ElevatedButton，"创建"，full width，14px padding，背景色 #5856D6 |

**加入群聊弹窗：**
| 元素 | 说明 |
|------|------|
| 标题 | "加入群聊" |
| 邀请码输入框 | TextField，label="邀请码"，hint="输入6位邀请码" |
| 加入按钮 | ElevatedButton，"加入"，full width |

---

#### 3.2.2 DiscoverTab（发现 Tab）

**Section: 连接**
| 入口 | 图标 | 标题 | 副标题 | 点击行为 |
|------|------|------|--------|----------|
| Gateway 管理 | Icons.dns_outlined | Gateway 管理 | 管理远程 Gateway 连接 | Navigator.push(MachinesScreen) |
| Agent 管理 | Icons.smart_toy | Agent 管理 | 查看和管理可用 Agent | Navigator.push(MachinesScreen) |

**Section: AI 资源**
| 入口 | 图标 | 标题 | 副标题 | 点击行为 |
|------|------|------|--------|----------|
| 技能 | Icons.psychology_outlined | 技能 | 浏览可用 AI 技能 | Navigator.push(SkillsScreen) |
| 插件 | Icons.extension_outlined | 插件 | 管理插件扩展 | Navigator.push(PluginsScreen) |
| 模型 | Icons.model_training | 模型 | 查看可用 AI 模型 | Navigator.push(ModelsScreen) |

**Section: 工具（暂不可用，显示"即将推出"标签）**
| 入口 | 状态 |
|------|------|
| 定时任务 | 置灰 + "即将推出" |
| 看板 | 置灰 + "即将推出" |

---

#### 3.2.3 ProfileTab（我的 Tab）

| 元素 | 说明 |
|------|------|
| 用户名 | 显示当前登录用户名，center |
| 多设备状态 | "多设备模式: 是/否" |
| 清除缓存按钮 | AlertDialog 确认，清除后显示 Toast "缓存已清除" |
| 登出按钮 | AlertDialog 确认，调用 logout，go('/login') |

---

### 3.3 聊天页 `/chat/:roomId`

**顶部栏（AppBar）：**
- 返回按钮：Icons.arrow_back
- 聊天室名称：Text，颜色 #ECECEC
- 成员数：Text，"{count}人"
- 设置按钮：Icons.more_vert，PopupMenu（编辑群聊/删除群聊/退出群聊）

**消息列表（ListView.builder）：**
- 反向构建（stackFromBottom=true）
- 每条消息：MessageBubble 组件

**MessageBubble 组件：**
| 类型 | 样式 |
|------|------|
| 用户消息 | 右侧，背景色 #5856D6，文字白色 |
| Agent 消息 | 左侧，背景色 #2A2A2A，Agent 名称 + 头像 |
| 流式消息 | 实时更新 content，带光标闪烁 |
| 错误消息 | Text，橙色 #FF9500，SelectableText 可复制 |
| 已中止消息 | Text，"已中止"，橙色 #FF9500 |
| Token 统计 | Text，"输入 X / 输出 Y"，11px，灰色 |
| 工具调用状态 | 图标：started=转圈 / completed=绿色勾 / error=红色叉 |

**底部输入区：**
| 元素 | 说明 |
|------|------|
| TextField | 多行输入，hint="输入消息..."，背景色 #343541 |
| @按钮 | Icons.alternate_email，选择后插入 "@Agent名 " |
| 发送按钮 | Icons.send，颜色 #5856D6，disabled 时灰色 |

---

### 3.4 Gateway 管理 `/machines`（MachinesScreen）

**顶部栏：**
- 标题："Gateway 管理"
- 右下角 FAB：Icons.add，背景色 #5856D6

**扫描区域（_ScanSection）：**
- 扫描按钮：OutlinedButton，"扫描 Gateway"，图标 Icons.wifi_tethering
- 扫描中：CircularProgressIndicator + "扫描中..."
- 扫描结果：
  - 空：Text，"未发现 Gateway，请确保已启动 Gateway 服务"
  - 有：List，显示 address、profile_name、model、online 状态
  - 已添加：Text "已添加"，蓝色
  - 未添加：TextButton "添加"

**网关列表（machinesAsync.when）：**
| 状态 | 显示 |
|------|------|
| 加载中 | Center CircularProgressIndicator |
| 加载失败 | Center，图标 Icons.wifi_off，文字"加载失败，请检查网络"，重试按钮 |
| 空 | 居中，文字"暂无 Gateway"，副文字"点击上方「扫描」发现本机 Gateway" |
| 有数据 | Card ListTile，CircleAvatar，本地模式显示绿色"Local"标签 |

**MachineDetailScreen（点击网关进入）：**
- AppBar：显示网关名称，"Agent 列表"
- 右上角 PopupMenu：编辑 / 删除
- Agent 列表：
  - 空：居中，Icons.smart_toy_outlined，文字"暂无 Agent"
  - 有：ListView，CircleAvatar + 名称 + 描述 + invited 标记

**添加网关弹窗（showModalBottomSheet）：**
| 元素 | 类型 | 说明 |
|------|------|------|
| 名称 | TextFormField | label="名称（可选）" |
| 地址 | TextFormField | label="Gateway 地址"，hint="192.168.1.100:8642"，必填 |
| API Key | TextFormField | label="API Key（可选）"，密码样式 |
| 添加按钮 | ElevatedButton | "添加"，full width |

**API：**
```
GET  /machines                    → 列表
POST /machines                   → 创建
GET  /machines/{id}              → 详情
PUT  /machines/{id}              → 更新
DELETE /machines/{id}             → 删除
GET  /machines/{id}/agents       → Agent 列表
```

---

## 4. 表单验证规则

| 字段 | 规则 |
|------|------|
| 用户名 | 非空，最少 2 字符 |
| 密码 | 非空，最少 6 字符 |
| 群聊名称 | 非空 |
| 邀请码 | 6 位字符 |
| Gateway 地址 | 非空，格式 IP:Port 或 hostname:Port |

---

## 5. 错误处理

### 5.1 前端错误显示

| 场景 | 显示 |
|------|------|
| 网络断开 | Toast "网络异常，请检查网络连接"，颜色 #FF3B30 |
| Token 无效/过期 | Splash 阶段检测到 → 自动 logout → go('/login') |
| 401 Unauthorized | 在 HomeScreen initState 中检测 → context.go('/login') |
| 服务器内部错误 | Toast "服务器内部错误，请稍后重试" |
| 表单验证失败 | 输入框下方红色提示文字 |
| 加载失败 | 页面内重试按钮，不显示技术细节 |

### 5.2 后端错误码

| 错误码 | msg（用户看到的） |
|--------|-------------------|
| AUTH_001 | 用户名已被注册，请尝试其他用户名 |
| AUTH_002 | 用户名或密码错误，请检查后重试 |
| AUTH_003 | 登录已失效，请重新登录 |
| AUTH_004 | 登录已过期，请重新登录 |
| AUTH_005 | 请先登录后再操作 |
| VALID_001 | 请求参数不合法，请检查以下字段 |
| RES_001 | 请求的资源不存在 |
| RES_002 | 无权访问该资源 |
| RES_004 | 请求参数错误 |
| GW_001 | 无法连接到网关，请检查地址和网络 |
| SYS_001 | 服务器内部错误，错误编号: {id} |

---

## 6. 颜色规格

| 用途 | Hex |
|------|-----|
| 背景 | #212121 |
| 卡片/表面 | #2A2A2A |
| 输入框 | #343541 |
| 主色/强调 | #5856D6 |
| 主文字 | #ECECEC |
| 次要文字 | #A0A0A0 |
| 成功 | #34C759 |
| 错误/失败 | #FF3B30 |
| 警告/中止 | #FF9500 |
| 链接/引导 | #2AABEE |

---

## 7. 消息状态与样式

| 状态 | 颜色 | 样式 |
|------|------|------|
| 正常 | #ECECEC | 普通文本 |
| 流式传输中 | #ECECEC | 文本 + 光标闪烁 |
| 错误 | #FF9500 | SelectableText，可复制 |
| 已中止 | #FF9500 | Text "已中止" |
| 工具调用中 | #A0A0A0 | CircularProgressIndicator，12px |
| 工具成功 | #34C759 | Icons.check_circle，绿色 |
| 工具失败 | #FF3B30 | Icons.error，红色 |

---

## 8. API 端点汇总

### 认证
| 方法 | 路径 | 描述 |
|------|------|------|
| POST | /auth/register | 注册 |
| POST | /auth/login | 登录 |
| POST | /auth/refresh | 刷新 token |
| GET | /auth/me | 当前用户信息 |

### 聊天室
| 方法 | 路径 | 描述 |
|------|------|------|
| GET | /rooms | 列表 |
| POST | /rooms | 创建 |
| GET | /rooms/{id} | 详情 |
| PUT | /rooms/{id} | 更新 |
| DELETE | /rooms/{id}/leave | 离开 |
| GET | /rooms/{id}/members | 成员列表 |
| POST | /rooms/join | 邀请码加入 |

### 消息
| 方法 | 路径 | 描述 |
|------|------|------|
| GET | /rooms/{id}/messages | 消息列表（分页） |

### Gateway
| 方法 | 路径 | 描述 |
|------|------|------|
| GET | /machines | 列表 |
| POST | /machines | 创建 |
| GET | /machines/{id} | 详情 |
| PUT | /machines/{id} | 更新 |
| DELETE | /machines/{id} | 删除 |
| GET | /machines/{id}/agents | Agent 列表 |
| GET | /machines/discover | 扫描网关 |

### Agent
| 方法 | 路径 | 描述 |
|------|------|------|
| GET | /agents | 用户所有 Agent |
| POST | /agents | 创建 |
| GET | /agents/{id} | 详情 |
| PUT | /agents/{id} | 更新 |
| DELETE | /agents/{id} | 删除 |

### WebSocket
- 路径：`/ws/chat?token={access_token}`
- 参考本文档 5.x 节

---

## 9. WebSocket 协议

### 9.1 客户端 → 服务端

| 事件 | payload | 说明 |
|------|---------|------|
| join | `{ "room_id": string }` | 加入聊天室 |
| message | `{ "room_id": string, "content": string }` | 发送消息 |
| abort | `{ "room_id": string }` | 中止运行中的 Agent |
| typing | `{ "room_id": string }` | 正在输入 |
| stop_typing | `{ "room_id": string }` | 停止输入 |

### 9.2 服务端 → 客户端

| 事件 | payload | 说明 |
|------|---------|------|
| message.delta | `{ "message_id": string, "content": string }` | 消息片段（流式） |
| reasoning.delta | `{ "message_id": string, "content": string }` | 推理片段 |
| tool.started | `{ "tool": string, "arguments": object }` | 工具开始 |
| tool.completed | `{ "tool": string, "output": string, "duration": int }` | 工具完成 |
| tool.error | `{ "tool": string, "error": string }` | 工具失败 |
| run.started | `{ "run_id": string }` | Agent 开始运行 |
| run.completed | `{ "run_id": string }` | Agent 运行完成 |
| run.failed | `{ "run_id": string, "error": string }` | Agent 运行失败 |
| queue_updated | `{ "queue_length": int }` | 队列长度更新 |
| member_joined | `{ "user_id": string }` | 成员加入 |
| member_left | `{ "user_id": string }` | 成员离开 |
| abort.started | `{ "run_id": string }` | 中止开始 |
| abort.completed | `{ "run_id": string }` | 中止完成 |

---

## 10. 数据库模型

### users
| 字段 | 类型 | 说明 |
|------|------|------|
| id | VARCHAR(36) PK | UUID |
| username | VARCHAR UNIQUE | 用户名 |
| password_hash | VARCHAR | Argon2 加密 |
| created_at | INTEGER | Unix timestamp |
| multi_device | BOOLEAN | 多设备标记 |

### machines
| 字段 | 类型 | 说明 |
|------|------|------|
| id | VARCHAR(36) PK | UUID |
| user_id | VARCHAR(36) FK | 所属用户 |
| name | VARCHAR | 名称 |
| address | VARCHAR | 地址 |
| api_key | VARCHAR | API Key（可选） |
| mode | VARCHAR | "http" / "local" |
| profile_name | VARCHAR | 本地 profile 名称 |
| created_at | INTEGER | Unix timestamp |

### agents
| 字段 | 类型 | 说明 |
|------|------|------|
| id | VARCHAR(36) PK | UUID |
| machine_id | VARCHAR(36) FK | 所属机器 |
| remote_id | VARCHAR | Gateway 上的 ID |
| name | VARCHAR | 名称 |
| description | VARCHAR | 描述 |
| avatar | VARCHAR | 头像 URL |
| profile | VARCHAR | Profile 配置 |
| invited | BOOLEAN | 是否被邀请 |
| created_at | INTEGER | Unix timestamp |

### rooms
| 字段 | 类型 | 说明 |
|------|------|------|
| id | VARCHAR(36) PK | UUID |
| name | VARCHAR | 名称 |
| avatar | VARCHAR | 头像 URL |
| owner_id | VARCHAR(36) FK | 所有者 |
| mode | VARCHAR | broadcast/mention/router/pipeline |
| invite_code | VARCHAR | 6 位邀请码 |
| created_at | INTEGER | Unix timestamp |

### room_members
| 字段 | 类型 | 说明 |
|------|------|------|
| id | VARCHAR(36) PK | UUID |
| room_id | VARCHAR(36) FK | 聊天室 |
| user_id | VARCHAR(36) FK | 用户 |
| role | VARCHAR | owner/admin/member |
| joined_at | INTEGER | Unix timestamp |

### messages
| 字段 | 类型 | 说明 |
|------|------|------|
| id | VARCHAR(36) PK | UUID |
| room_id | VARCHAR(36) FK | 聊天室 |
| sender_id | VARCHAR | 发送者 ID |
| sender_type | VARCHAR | user/agent |
| sender_name | VARCHAR | 发送者名称 |
| content | TEXT | 消息内容 |
| content_type | VARCHAR | text/image/voice |
| extra | TEXT | JSON（tool_calls/reasoning 等） |
| parent_id | VARCHAR | 线程/管道父消息 ID |
| is_streaming | BOOLEAN | 是否在流式传输 |
| is_aborted | BOOLEAN | 是否被中止 |
| created_at | INTEGER | Unix timestamp |

---

## 11. 部署说明

### hermes-server
- 方式：Docker（docker-compose.prod.yml）
- 端口：3002
- 数据持久化：`/vol1/1000/nas1/docker/hermes-server:/app/data`
- DEBUG：通过 `docker-compose.prod.yml` 环境变量 `DEBUG=true`
- 本地调试：`restart-hermes-server-local.sh`（停掉 Docker，直接用 venv + uvicorn）

### hermes-app (H5)
- 构建：`cd hermes-app && flutter build web`
- 服务：`python3 -m http.server 3003`（在 build/web 目录）
- 日志：`hermes-app/logs/app.log`
- 本地脚本：`restart-hermes-app.sh`

### 重启脚本（项目根目录）
| 脚本 | 用途 |
|------|------|
| restart-hermes-server-local.sh | 本地调试模式（停 Docker，venv） |
| restart-hermes-server-docker.sh | Docker 部署模式 |
| restart-hermes-app.sh | 前端 H5 重启 |

---

## 12. 待优化/待开发功能

| 功能 | 优先级 | 状态 |
|------|--------|------|
| 语音消息 | P2 | 待开发 |
| 图片消息 | P2 | 待开发 |
| 消息搜索 | P2 | 待开发 |
| 深色/浅色主题切换 | P3 | 待开发 |
| 国际化 | P3 | 待开发 |
| Token 自动刷新 | P1 | 待实现 |
| 消息已读未读 | P3 | 待开发 |