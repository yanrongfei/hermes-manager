# 新建对话功能设计

## 概述

在 Agent 详情页添加"开始对话"按钮，实现与单个 Agent 的 1:1 对话功能。对话名称可编辑，可删除。

## 用户流程

1. 用户在 Discover/Gateways 页面找到 Agent
2. 点击 Agent 进入详情页
3. 点击"开始对话"按钮
4. 系统创建 1:1 Room（mode: mention），自动进入聊天页
5. 聊天页标题显示 Agent 名称和头像

## 功能详情

### 1. 开始对话（Agent 详情页）

- 在 `agent_detail_screen.dart` 添加"开始对话"按钮
- 点击后调用 API 创建 Room（mode: 'mention'）
- 创建成功后跳转到 `/chat/{roomId}`
- Room name 存储 Agent 名称

### 2. 聊天页标题栏

- `mode: 'mention'` 的 Room 显示 Agent 头像 + 名称
- `mode: 'broadcast'` 的 Room 保持现有"群聊"样式
- 点击名称弹出编辑对话框
- 右上角菜单包含"删除对话"选项

### 3. 编辑对话名称

- 聊天页标题栏点击名称
- 弹出对话框显示当前名称
- 用户可编辑后保存
- 调用 API 更新 Room 名称

### 4. 删除对话

- 聊天页右上角菜单选择"删除"
- 确认对话框防止误操作
- 删除后返回对话列表
- 调用 API 删除 Room

## 数据模型

### Room 模型（现有）

```dart
class Room {
  final String id;
  final String name;
  final String? avatar;
  final String ownerId;
  final String mode;  // 'broadcast' | 'mention'
  final String? inviteCode;
  final int createdAt;
}
```

- `mode: 'mention'` 表示 1:1 对话
- `mode: 'broadcast'` 表示群聊

## API 端点

- `POST /rooms` - 创建 Room
- `PUT /rooms/{id}` - 更新 Room（名称）
- `DELETE /rooms/{id}` - 删除 Room

## 涉及文件

| 文件 | 修改内容 |
|------|----------|
| `agent_detail_screen.dart` | 添加"开始对话"按钮 |
| `chat_screen.dart` | 动态标题、编辑名称、删除功能 |
| `chat_list_tab.dart` | 对话列表显示 Agent 头像、支持删除 |
| `room_provider.dart` | 添加 updateRoom、deleteRoom 方法 |

## 里程碑

1. Agent 详情页添加"开始对话"按钮
2. 创建 Room 并跳转聊天页
3. 聊天页显示 Agent 头像+名称
4. 编辑对话名称功能
5. 删除对话功能
