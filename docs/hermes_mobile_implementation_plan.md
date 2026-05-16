# Hermes Mobile 架构重构实施计划

> 基于 Design System v2 的 Hermes Mobile 实现计划
>
> Version: 1.0
>
> Date: 2026-05-16

---

# 1. 概述

## 1.1 背景

Hermes Mobile 当前代码存在以下问题：
- 硬编码颜色值，无 token 化
- 目录结构不符合 design system 规范
- 组件实现与 design system 有偏差
- 缺少关键 UI 组件（FAB、Running Tasks Card）

## 1.2 目标

基于 `hermes_mobile_design_system_complete_v_2.md` 文档，完成移动端架构重构，使其符合 AI Native Multi-Agent Workspace 的产品定位。

## 1.3 范围

- Flutter iOS/Android 移动端
- Phase 1: 核心聊天体验
- 不包含：Voice、Image、Push Notification 等 Phase 3 功能

---

# 2. 实施阶段

## Phase 0: 准备（当前）

### 任务
- [ ] 创建计划文档
- [ ] 分析 design system 与当前代码差距

### 交付物
- `docs/hermes_mobile_implementation_plan.md`

---

## Phase 1: Theme System（优先级 P0）

### 任务
- [ ] 创建 `lib/core/theme/app_colors.dart` - 颜色 token
- [ ] 创建 `lib/core/theme/app_typography.dart` - 字体 token
- [ ] 创建 `lib/core/theme/app_spacing.dart` - 间距 token
- [ ] 创建 `lib/core/theme/app_radius.dart` - 圆角 token
- [ ] 创建 `lib/core/theme/app_motion.dart` - 动画 token
- [ ] 修改 `app.dart` 使用新的 theme system

### 设计系统对应

| Design System Token | 实现文件 |
|---------------------|----------|
| Spacing System (4dp base) | app_spacing.dart |
| Radius System | app_radius.dart |
| Typography Scale | app_typography.dart |
| Dark Theme Colors | app_colors.dart |
| Motion Duration/Curve | app_motion.dart |

### 颜色对照表

| Token | Design System | 当前值 | 新值 |
|-------|--------------|--------|------|
| background | #121212 | #212121 | #121212 |
| primary | #7C6CFF | #5856D6 | #7C6CFF |
| surface | #1E1E1E | #212121 | #1E1E1E |
| surface-2 | #262626 | - | #262626 |

### 交付物
- `lib/core/theme/app_colors.dart`
- `lib/core/theme/app_typography.dart`
- `lib/core/theme/app_spacing.dart`
- `lib/core/theme/app_radius.dart`
- `lib/core/theme/app_motion.dart`
- `lib/core/theme/hermes_theme.dart`（整合）
- 修改后的 `app.dart`

---

## Phase 2: MessageBubble 重构（优先级 P1）

### 任务
- [ ] 重写 `_BubbleContent` - 适配 22dp radius、72 chars maxWidth
- [ ] 实现 Tool Timeline 默认折叠 "使用了 3 个工具 >"
- [ ] 实现 Code Block Widget（Copy/Horizontal Scroll/Collapse/Syntax Highlight）
- [ ] 实现 Agent Message 展开态（Tool Timeline + Reasoning + Tokens）
- [ ] 添加 Streaming Cursor 动画（500ms linear）

### Design System 对照

| 组件 | Design System 要求 | 当前状态 |
|------|-------------------|----------|
| Message Bubble radius | 22dp (radius-xl) | 18dp |
| maxWidth | 72 chars (~300dp) | 72% |
| Tool Timeline default | 折叠 "使用了 3 个工具 >" | 直接展开 |
| Code Block | Copy/Horizontal/Collapse/Highlight | 无 |
| Streaming Cursor | linear 500ms | 600ms |

### 交付物
- `lib/shared/widgets/code_block.dart`
- 修改后的 `lib/presentation/widgets/message_bubble.dart`

---

## Phase 3: Bottom Navigation 重构（优先级 P2）

### 任务
- [ ] 将 Discover → Workflows
- [ ] 新增 Notifications Tab
- [ ] 修改 `home_screen.dart` 的 NavigationBar

### Design System 对照

| Design System | 当前实现 |
|---------------|----------|
| Chats | 对话 |
| Workflows | 发现（需改名） |
| Notifications | 缺失 |
| Profile | 我的 |

### 交付物
- 修改后的 `lib/presentation/screens/home_screen.dart`
- 新增 `lib/presentation/screens/workflows_tab.dart`
- 新增 `lib/presentation/screens/notifications_tab.dart`

---

## Phase 4: 新增核心组件（优先级 P3）

### 任务
- [ ] 实现 Room Card（streaming pulse、mode badge）
- [ ] 实现 Running Tasks Card
- [ ] 实现 FAB（新建会话/快速Agent/创建Workflow/加入房间）
- [ ] 实现 Input Area 展开选项（@Agent/Upload/Voice/Image/Workflow）

### 交付物
- `lib/shared/widgets/room_card.dart`
- `lib/shared/widgets/running_task_card.dart`
- `lib/shared/widgets/fab_menu.dart`
- `lib/shared/widgets/input_action_sheet.dart`

---

## Phase 5: 目录结构重构（优先级 P4）

### 目标结构

```
lib/
 ├─ core/
 │   ├─ theme/
 │   │   ├─ app_colors.dart
 │   │   ├─ app_typography.dart
 │   │   ├─ app_spacing.dart
 │   │   ├─ app_radius.dart
 │   │   ├─ app_motion.dart
 │   │   └─ hermes_theme.dart
 │   ├─ network/
 │   ├─ websocket/
 │   └─ utils/
 │
 ├─ features/
 │   ├─ auth/
 │   │   └─ screens/login_screen.dart, register_screen.dart
 │   ├─ chats/
 │   │   ├─ screens/chat_screen.dart, chat_list_tab.dart
 │   │   └─ providers/chat_provider.dart
 │   ├─ workflows/
 │   │   ├─ screens/workflows_tab.dart, workflow_detail_screen.dart
 │   │   └─ ...
 │   ├─ notifications/
 │   │   └─ screens/notifications_tab.dart
 │   └─ profile/
 │       └─ screens/profile_tab.dart, profile_detail_screen.dart
 │
 ├─ shared/
 │   ├─ widgets/
 │   │   ├─ room_card.dart
 │   │   ├─ running_task_card.dart
 │   │   ├─ message_bubble.dart
 │   │   ├─ code_block.dart
 │   │   ├─ fab_menu.dart
 │   │   └─ input_action_sheet.dart
 │   ├─ services/
 │   └─ models/
 │
 └─ main.dart
```

### 策略
- 保持现有文件位置不变，创建新的 target 目录
- 使用 Flutter 的 `export` 机制保持 API 兼容
- 分阶段迁移，不破坏现有功能

### 交付物
- 新目录结构
- 迁移脚本（如需要）

---

## Phase 6: Motion 动画补充（优先级 P5）

### 任务
- [ ] Timeline expand: easeOutCubic 220ms
- [ ] FAB: spring animation
- [ ] Page transition: fastOutSlowIn
- [ ] Tool/Reasoning collapse 动画

### 交付物
- `lib/shared/widgets/animations/` 目录

---

# 3. 验收标准

## Phase 1 验收

- [ ] 所有颜色使用 token（无硬编码 #RRGGBB）
- [ ] Typography 使用 TextTheme 定义
- [ ] Spacing 使用 AppSpacing 常量
- [ ] Radius 使用 AppRadius 常量

## Phase 2 验收

- [ ] Message Bubble radius = 22dp
- [ ] Tool Timeline 默认折叠
- [ ] Code Block 支持 Copy
- [ ] Streaming cursor 500ms linear

## Phase 3 验收

- [ ] Bottom Navigation 有 4 个 tab
- [ ] Workflows tab 可正常切换

## Phase 4 验收

- [ ] FAB 可展开/收起
- [ ] Running Task Card 显示进度
- [ ] Room Card 显示 streaming pulse

---

# 4. 技术约束

## 4.1 Flutter 版本
- Flutter SDK: >=3.0
- Dart SDK: >=3.0

## 4.2 依赖
- flutter_riverpod: 状态管理
- go_router: 路由
- flutter_markdown: Markdown 渲染（需优化）
- flutter_secure_storage: Token 存储（已使用）

## 4.3 性能要求
- Streaming 禁止每 token rebuild 全页面
- Timeline 使用 ListView.builder
- Markdown 延迟解析

---

# 5. 当前文件与 Design System 差距

## app.dart

```dart
// 当前
colorSchemeSeed: Color(0xFF5856D6)  // 应该是 #7C6CFF
scaffoldBackgroundColor: Color(0xFF212121)  // 应该是 #121212

// 设计系统
primary: #7C6CFF
background: #121212
```

## message_bubble.dart

| 问题 | 当前 | Design System |
|------|------|---------------|
| Bubble radius | 18dp | 22dp |
| maxWidth | 72% | 72 chars |
| Tool Timeline | 直接展开 | 折叠 |
| Code Block | 无 | Copy/Horizontal/Collapse |

## home_screen.dart

| 问题 | 当前 | Design System |
|------|------|---------------|
| Navigation | 3 tabs | 4 tabs |
| Tab Names | 对话/发现/我的 | Chats/Workflows/Notifications/Profile |

---

# 6. 里程碑

| 阶段 | 描述 | 状态 |
|------|------|------|
| Phase 0 | 准备 | [完成] |
| Phase 1 | Theme System | 待开始 |
| Phase 2 | MessageBubble | 待开始 |
| Phase 3 | Bottom Navigation | 待开始 |
| Phase 4 | 新增组件 | 待开始 |
| Phase 5 | 目录结构 | 待开始 |
| Phase 6 | Motion | 待开始 |

---

# 7. 参考文档

- `docs/hermes_mobile_design_system_complete_v_2.md` - 设计系统
- `docs/hermes_mobile_prd_v_3_complete.md` - 产品需求
- `docs/hermes_manager_mobile_wireframe_and_ui_spec.md` - 线框图