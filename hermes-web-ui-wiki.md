# Hermes Web UI Wiki

## 项目概述

Hermes Web UI 是 Hermes Agent 系统的 Web 管理面板，提供聊天界面、模型管理、平台通道配置、使用量监控、终端访问等功能。采用 monorepo 结构，包含三个核心包。

## 项目结构

```
hermes-web-ui/
├── packages/
│   ├── client/          # Vue 3 前端 SPA
│   ├── server/          # Koa.js 后端服务
│   ├── website/         # 营销/文档网站
│   └── skills/          # 可选技能包
├── bin/                 # CLI 入口
├── scripts/             # 构建和工具脚本
└── tests/               # 测试文件 (Vitest + Playwright)
```

## 技术栈

### 前端 (client)

| 类别 | 技术 |
|------|------|
| 框架 | Vue 3 + Composition API |
| UI 库 | Naive UI |
| 状态管理 | Pinia |
| 路由 | Vue Router (hash history) |
| 国际化 | Vue I18n |
| 构建工具 | Vite |
| 样式 | SCSS + CSS Variables 主题 |
| 实时通信 | Socket.IO Client |
| 代码编辑器 | Monaco Editor |
| 终端 | XTerm.js |
| Markdown | Markdown-it + 语法高亮 |

### 后端 (server)

| 类别 | 技术 |
|------|------|
| 运行时 | Node.js 23+ |
| Web 框架 | Koa.js |
| 数据库 | SQLite (Node < 22.5 降级为 JSON) |
| 实时通信 | Socket.IO + WebSocket |
| 认证 | Bearer Token |
| 终端模拟 | node-pty |
| 日志 | Pino |
| 任务队列 | 后台任务处理 |

## 前端架构 (client)

### 目录结构

```
packages/client/src/
├── components/
│   ├── hermes/       # 业务功能组件
│   └── layout/       # 布局组件
├── views/            # 页面级组件
├── composables/      # 可复用逻辑 (theme, keyboard 等)
├── stores/           # Pinia 状态管理
├── router/           # 路由配置
├── i18n/             # 国际化资源
├── assets/           # 静态资源
└── utils/            # 工具函数
```

### Pinia Stores

| Store | 文件 | 职责 |
|-------|------|------|
| app | `app.ts` | 全局状态、模型列表、健康检查 |
| chat | `chat.ts` | 聊天会话管理、消息流 |
| profiles | `profiles.ts` | Profile 管理和切换 |
| settings | `settings.ts` | 用户偏好设置 |

### 路由

使用 hash history 模式，确保兼容性。页面包括：
- 聊天界面（主页面）
- 模型管理
- 平台通道配置
- 使用量监控
- 终端
- 看板
- 技能管理
- 内存管理
- 定时任务

## 后端架构 (server)

### 目录结构

```
packages/server/src/
├── routes/           # 路由控制器
├── services/         # 业务逻辑层
├── db/               # 数据库层 (SQLite ORM)
├── middleware/        # Koa 中间件
├── utils/            # 工具函数
└── types/            # TypeScript 类型定义
```

### API 端点

| 路径 | 方法 | 说明 |
|------|------|------|
| `/health` | GET | 健康检查和版本信息 |
| `/api/hermes/*` | ALL | 主要 API 端点 |
| `/v1/*` | ALL | 代理到 LLM 提供商 |
| `/upload` | POST | 文件上传 |
| `/webhook` | POST | Webhook 接收 |

### WebSocket 端点

| 路径 | 用途 |
|------|------|
| `/chat-run` | 实时聊天流式响应 |
| `/terminal` | Web 终端访问 |
| `/kanban/events` | 看板板实时更新 |

### Socket.IO 事件

- **Chat 流式传输** — 带会话隔离的实时消息
- **Tool Call 进度** — 工具调用追踪
- **Usage 更新** — 使用量实时推送
- **Approval 工作流** — 审批请求/响应
- **Compression 事件** — 数据压缩

## 认证机制

- Bearer Token 系统，首次启动自动生成
- 客户端存储在 localStorage，服务端存储在文件系统
- 通过 `X-Hermes-Profile` Header 实现 Profile 路由
- 认证配置文件：`~/.hermes/auth.json`

## 核心功能

### 1. 聊天界面

- Socket.IO 实时流式响应
- 多会话管理，支持分组
- 文件上传/下载
- Markdown 渲染 + 代码块高亮
- Tool Call 可视化
- 会话搜索 (`Ctrl+K`)

### 2. 模型管理

- 从 `~/.hermes/auth.json` 自动发现模型
- 提供商管理，支持 OAuth
- 模型别名和可见性规则
- 动态模型切换

### 3. 平台通道 (8 个平台)

| 平台 | 标识 |
|------|------|
| Telegram | telegram |
| Discord | discord |
| Slack | slack |
| WhatsApp | whatsapp |
| Matrix | matrix |
| 飞书 (Lark) | feishu |
| 微信 | wechat |
| 企业微信 | wecom |

统一配置界面，在 `~/.hermes/config.yaml` 中管理。

### 4. 监控与分析

- Token 使用量追踪
- 费用估算
- 会话统计
- 模型使用分布
- 30 天趋势图

### 5. 高级功能

- **Web 终端** — 基于 node-pty 的完整终端
- **看板** — 任务管理界面
- **定时任务** — Cron 任务管理
- **内存管理** — Agent 记忆浏览
- **技能管理** — 自定义技能注入
- **多 Profile** — 环境隔离和切换

## Profile 架构

Profile 是 Hermes Web UI 的核心隔离机制：

- 每个 Profile 拥有独立的配置、会话、模型设置
- 通过 `X-Hermes-Profile` Header 路由请求
- 与 Hermes Agent 的 session 隔离
- 支持动态切换

## 配置文件

### 环境变量

```bash
# 服务配置
PORT=8648                         # 默认端口
BIND_HOST=0.0.0.0                 # 绑定地址
AUTH_TOKEN=your-token             # 认证 Token
HERMES_WEB_UI_HOME=~/.hermes-web-ui  # 数据目录

# 功能配置
PROFILE=default                   # 当前 Profile
GATEWAY_HOST=127.0.0.1            # Gateway 地址
MAX_DOWNLOAD_SIZE=209715200       # 最大下载 (200MB)
MAX_EDIT_SIZE=10485760            # 最大编辑 (10MB)
LOG_LEVEL=info                    # 日志级别
```

### Hermes 配置文件

| 文件 | 用途 |
|------|------|
| `~/.hermes/auth.json` | LLM 提供商凭证 |
| `~/.hermes/config.yaml` | 平台通道设置 |
| `~/.hermes/.env` | Gateway 环境变量 |

## 部署方式

### npm 全局安装

```bash
npm install -g hermes-web-ui
hermes-web-ui start
```

### Docker

```bash
docker-compose up -d
```

### 自定义构建

```bash
npm run build
npm run preview
```

## 开发命令

```bash
# 安装依赖
npm install

# 开发模式 (热重载)
npm run dev

# 构建
npm run build

# 测试
npm run test           # 单元测试 (Vitest)
npm run test:e2e       # E2E 测试 (Playwright)

# 预览
npm run preview
```

## 性能优化

- Vite chunk splitting + 懒加载
- 依赖预构建
- Node < 22.5 优雅降级 (SQLite → JSON)
- 响应式组件按需渲染

## 安全

- Token 认证
- CORS 配置
- 输入验证
- 文件大小限制 (下载 200MB, 编辑 10MB)

## 跨平台支持

- Windows / macOS / Linux / WSL
- Node.js 23+ (推荐), < 22.5 自动降级
