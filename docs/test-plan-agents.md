# Agents 功能测试计划

## 1. 功能概述

**功能名称：** Agents（Agent 目录）
**入口：** DiscoverTab → "Agents"
**后端 API：** `/agents`
**前端页面：** `AgentsDirectoryScreen`

## 2. 测试范围

### 2.1 页面加载测试

| 测试项 | 操作 | 预期结果 |
|--------|------|----------|
| 正常加载 | 进入 Agents 页面 | 显示加载动画 → Agent 列表 |
| 网络错误 | 断开网络后进入页面 | 显示错误状态 + 重试按钮 |
| 无 Agent 数据 | 后端返回空列表 | 显示空状态："暂无 Agent" + "请先添加并同步 Gateway" |

### 2.2 Agent 列表展示测试

| 测试项 | 操作 | 预期结果 |
|--------|------|----------|
| Agent 卡片内容 | 列表展示时 | 显示：头像（首字母）、名称、描述（最多2行省略）、状态标签 |
| 已邀请状态 | agent.invited = true | 显示绿色 ✓ 图标 + "已邀请" |
| 未邀请状态 | agent.invited = false | 显示蓝色 "邀请" 按钮 |
| 邀请按钮存在 | 未邀请的 Agent | 右上角显示 "邀请" TextButton |
| 下拉刷新 | 列表页下拉 | 重新请求 `/agents` 刷新列表 |

### 2.3 API 接口测试

| 测试项 | 方法 | 路径 | 预期结果 |
|--------|------|------|----------|
| 获取 Agent 列表 | GET | `/agents` | 返回 `List<AgentResponse>` |
| 邀请 Agent | POST | `/agents/{id}/invite` | 返回更新后的 Agent，invited=true |
| 删除 Agent | DELETE | `/agents/{id}` | 返回 204 No Content |

### 2.4 响应数据格式测试

```json
// GET /agents 响应
[
  {
    "id": "uuid-string",
    "profile_id": "profile-uuid",
    "remote_id": "remote-id",
    "name": "Agent 名称",
    "description": "Agent 描述",
    "avatar": "avatar_url_or_null",
    "invited": true,
    "created_at": 1234567890
  }
]
```

| 字段 | 类型 | 测试点 |
|------|------|--------|
| id | String | 非空，UUID 格式 |
| profile_id | String | 非空 |
| remote_id | String | 非空 |
| name | String | 非空，显示在卡片上 |
| description | String? | 可为空，2行显示后省略 |
| avatar | String? | 可为空，头像显示首字母 |
| invited | bool | 控制邀请按钮/已邀请状态显示 |
| created_at | int | Unix timestamp |

### 2.5 状态显示测试

| 状态 | UI 组件 | 样式 |
|------|---------|------|
| 加载中 | CircularProgressIndicator | 居中显示 |
| 加载失败 | Column + Icon + Text + TextButton | 图标 Icons.error_outline，文字 "加载失败，请稍后重试" |
| 空状态 | Column + Icon + Text | 图标 Icons.smart_toy_outlined (64px)，文字 "暂无 Agent" |
| 已邀请 | Row + Icon + Text | Icon: check_circle (#34C759)，Text: "已邀请" |
| 未邀请 | TextButton | Text: "邀请"，颜色 #2AABEE |

### 2.6 UI 样式测试

| 元素 | 样式 | 验证 |
|------|------|------|
| 页面背景 | #212121 | Scaffold backgroundColor |
| 卡片背景 | #2A2A2A | Card color |
| 标题文字 | #ECECEC | agent.name 颜色 |
| 描述文字 | #A0A0A0, 12px | description 颜色和字号 |
| 头像背景 | #5856D6 | CircleAvatar backgroundColor |
| 头像文字 | 白色 | 名称首字母大写 |

### 2.7 邀请功能测试（TODO）

| 测试项 | 操作 | 预期结果 |
|--------|------|----------|
| 点击邀请按钮 | 未邀请状态下点击 "邀请" | 当前显示 TODO，待实现 |
| 邀请成功 | 调用 POST /agents/{id}/invite | Agent 状态变为已邀请 |
| 邀请失败 | 网络错误 | 显示错误 Toast |

## 3. 测试数据准备

### 3.1 需要的测试数据

1. **已有 Agent**：创建 Profile 后同步 Gateway，获得 Agent 数据
2. **已邀请 Agent**：调用 `/agents/{id}/invite` 标记为已邀请
3. **未邀请 Agent**：新同步的 Agent 默认 invited=false

### 3.2 测试环境要求

- 后端服务运行在 `http://localhost:3002`
- 用户已登录并获取有效 token
- Gateway 已添加并同步（Profiles/Agents 已同步到数据库）

## 4. 测试执行方式

### 4.1 手动测试

```bash
# 1. 启动后端
bash restart-hermes-server-local.sh

# 2. 启动 Flutter App
cd hermes-app && flutter run

# 3. 登录后进入 DiscoverTab → Agents
```

### 4.2 API 测试

```bash
# 获取 token
TOKEN=$(curl -s http://localhost:3002/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}' \
  | jq -r '.access_token')

# 获取 Agent 列表
curl http://localhost:3002/agents \
  -H "Authorization: Bearer $TOKEN"

# 邀请 Agent
curl -X POST http://localhost:3002/agents/{agent_id}/invite \
  -H "Authorization: Bearer $TOKEN"
```

## 5. 测试用例清单

| 用例编号 | 类别 | 描述 | 优先级 |
|----------|------|------|--------|
| AGENT-001 | 加载 | 正常进入 Agents 页面显示列表 | P0 |
| AGENT-002 | 加载 | 网络错误显示错误状态 | P0 |
| AGENT-003 | 加载 | 无 Agent 时显示空状态 | P1 |
| AGENT-004 | 展示 | Agent 卡片显示完整信息 | P0 |
| AGENT-005 | 展示 | 已邀请 Agent 显示正确状态 | P0 |
| AGENT-006 | 展示 | 未邀请 Agent 显示邀请按钮 | P0 |
| AGENT-007 | 刷新 | 下拉刷新重新加载列表 | P1 |
| AGENT-008 | API | GET /agents 返回正确数据 | P0 |
| AGENT-009 | API | POST /agents/{id}/invite 成功 | P2 |
| AGENT-010 | API | DELETE /agents/{id} 成功 | P2 |
| AGENT-011 | 邀请 | 邀请按钮点击（TODO） | P3 |

## 6. 回归测试

每次代码修改后需要验证：

1. `flutter analyze` 无错误
2. `flutter build web` 构建成功
3. Agent 列表页面可正常访问
4. Agent 卡片显示正确
5. API 请求正常发送和接收