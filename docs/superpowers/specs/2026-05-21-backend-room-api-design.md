# 后端 Room API 修复设计

> Room Service & WebSocket 修复
>
> Version: 1.0
>
> Date: 2026-05-21
>
> 状态: 已完成

---

# 1. 概述

## 1.1 背景

PRD v3.1 对后端 Room API 提出了以下要求：

| 要求 | 当前状态 |
|------|----------|
| mode 支持 direct 模式 | ❌ 缺失 |
| invite_code 懒生成 | ❌ 始终生成 |
| 1:1 模式使用 direct | ❌ 使用 mention 模拟 |
| agent_busy 事件 | ❌ 未实现 |
| WebSocket 统一 camelCase | ⚠️ 部分不一致 |

## 1.2 修复目标

| 问题 | 修复目标 |
|------|----------|
| mode 字段 | 支持 direct/broadcast/mention/router |
| invite_code | 创建时为 null，首次邀请时生成 |
| 1:1 模式 | 使用 `agent_id` + `direct` 模式 |
| agent_busy | 发送 `agent_busy` 事件并断开 |
| WebSocket | 统一使用 camelCase |

---

# 2. Room Model 修复

## 2.1 当前 model

```python
class Room(Base):
    # ...
    mode = Column(String, default="broadcast")
    invite_code = Column(String, nullable=True)  # 始终生成
    profile_id = Column(String, nullable=True)
    # 缺少 agent_id 字段
```

## 2.2 修复后 model

```python
class Room(Base):
    # ...
    mode = Column(String, default="direct")  # 支持 direct/broadcast/mention/router
    invite_code = Column(String, nullable=True)  # 懒生成，创建时为 null
    agent_id = Column(String, nullable=True)  # 1:1 时关联的 Agent ID
    profile_id = Column(String, nullable=True)  # 内部查询优化
```

---

# 3. RoomService 修复

## 3.1 create_room 修复

### 当前逻辑

```python
async def create_room(self, owner_id: str, name: str, mode: str = "broadcast",
                     profile_id: Optional[str] = None) -> Room:
    invite_code = secrets.token_urlsafe(6)  # ❌ 始终生成
    if profile_id and mode == "broadcast":
        mode = "mention"  # ❌ 错误
```

### 修复后逻辑

```python
async def create_room(self, owner_id: str, name: str,
                     mode: str = "direct",
                     agent_ids: List[str] = None,  # 新增参数
                     agent_id: str = None,  # 1:1 专用
                     ) -> Room:
    # invite_code 默认 None（懒生成）
    room = Room(
        owner_id=owner_id,
        name=name,
        mode=mode,
        invite_code=None,  # 懒生成
        agent_id=agent_id,  # 1:1 时设置
        profile_id=profile_id,
    )
```

### create_room 参数对照

| 参数 | 类型 | 说明 | 来源 |
|------|------|------|------|
| owner_id | str | 所有者 | 必填 |
| name | str | 会话名称 | 必填 |
| mode | str | 协作模式 | 默认为 "direct" |
| agent_ids | List[str] | 关联的 Agent ID 列表 | 新增 |
| agent_id | str | 1:1 专用 | 新增 |

## 3.2 invite 修复（懒生成）

### 当前逻辑

```python
async def generate_invite_code(self, room_id: str) -> Optional[str]:
    # 无此方法
```

### 修复后逻辑

```python
async def generate_invite_code(self, room_id: str) -> Optional[str]:
    """懒生成邀请码，首次邀请时调用。"""
    room = await self.get_room(room_id)
    if not room:
        return None

    if room.invite_code:
        return room.invite_code  # 已存在，直接返回

    # 生成 6 位邀请码
    invite_code = secrets.token_urlsafe(6)[:6].upper()
    room.invite_code = invite_code
    await self.db.commit()
    await self.db.refresh(room)
    return invite_code
```

---

# 4. agent_id 字段设计

## 4.1 用途

| 场景 | agent_id | profile_id |
|------|----------|------------|
| 1:1 会话 | 关联的 Agent ID | 内部优化 |
| 群聊 | null | null |

## 4.2 创建 1:1 会话

```python
async def create_one_on_one_room(self, owner_id: str, name: str,
                                 agent_id: str, agent_name: str) -> Room:
    """创建 1:1 会话。"""
    room = Room(
        owner_id=owner_id,
        name=agent_name,  # 使用 Agent 名称
        mode="direct",    # 1:1 使用 direct 模式
        agent_id=agent_id,
        invite_code=None,  # 1:1 不生成邀请码
    )
    self.db.add(room)
    await self.db.commit()

    # 添加 owner 为成员
    member = RoomMember(room_id=room.id, user_id=owner_id, role="owner")
    self.db.add(member)
    await self.db.commit()

    return room
```

---

# 5. WebSocket agent_busy 事件

## 5.1 当前逻辑

```python
if room_id in active_executors and active_executors[room_id]:
    # 放入队列
    message_queues[room_id].append({...})
```

## 5.2 修复后逻辑

```python
# 检查 Room 模式
room_mode = room.mode  # 从之前的查询获取

if room_mode == "direct":
    # direct 模式：忙碌时直接拒绝
    if room_id in active_executors and active_executors[room_id]:
        await manager.send_to_room(room_id, "agent_busy", {})
        # 不创建用户消息，也不放入队列
else:
    # 其他模式：放入队列
    if room_id not in message_queues:
        message_queues[room_id] = []
    message_queues[room_id].append({...})
    await manager.send_to_room(room_id, "queue_updated", {
        "queueLength": len(message_queues[room_id]),
    })
```

## 5.3 agent_busy 事件格式

```json
{
  "event": "agent_busy",
  "data": {}
}
```

前端收到此事件后显示 Toast 提示"Agent 正忙，请稍后再试"。

---

# 6. 路由参数修复

## 6.1 创建会话 API

### 当前

```
POST /rooms
Body: {
  "name": "string",
  "mode": "broadcast" | "mention" | "router",
  "profile_id": "string"  // 可选
}
```

### 修复后

```
POST /rooms
Body: {
  "name": "string",
  "agentIds": ["agent-id-1"],  // 1个 = 1:1，多个 = 群聊
  "mode": "direct" | "broadcast" | "mention" | "router"
}
Response: {
  "id": "string",
  "name": "string",
  "mode": "string",
  "type": "1v1" | "group",  // 后端计算
  "inviteCode": string | null  // 群聊时为 null
}
```

### type 计算逻辑

```python
def calculate_room_type(agent_ids: List[str]) -> str:
    return "1v1" if len(agent_ids) == 1 else "group"
```

---

# 7. 懒生成邀请码 API

## 7.1 API 设计

```
POST /rooms/{roomId}/invite
Response: {
  "inviteCode": "ABC123"  // 6 位邀请码
}
```

## 7.2 实现

```python
@router.post("/rooms/{room_id}/invite")
async def generate_invite_code(room_id: str, current_user: User = Depends(get_current_user)):
    room_service = RoomService(db)
    room = await room_service.get_room(room_id)
    if not room:
        raise HTTPException(404, "Room not found")

    # 1:1 会话不允许邀请
    if room.mode == "direct":
        raise HTTPException(400, "1:1 chat does not support invite")

    invite_code = await room_service.generate_invite_code(room_id)
    return {"inviteCode": invite_code}
```

---

# 8. WebSocket 事件命名规范

## 8.1 统一 camelCase

| 事件 | 字段 | 说明 |
|------|------|------|
| message | roomId, messageId | 消息事件 |
| message.delta | messageId, content | 流式片段 |
| run.started | runId | Agent 开始 |
| queue_updated | queueLength | 队列更新 |
| agent_busy | {} | Agent 正忙 |

## 8.2 客户端 → 服务端

```json
{
  "event": "message",
  "data": {
    "roomId": "room-id",
    "content": "消息内容"
  }
}
```

---

# 9. 实现检查清单

## 9.1 Room Model

- [ ] 添加 `agent_id` 字段
- [ ] `mode` 默认值改为 `"direct"`
- [ ] `invite_code` 默认为 `None`

## 9.2 RoomService

- [ ] `create_room` 添加 `agent_ids` 参数
- [ ] `create_room` 支持 1:1 创建
- [ ] 添加 `generate_invite_code` 方法（懒生成）
- [ ] 添加 `create_one_on_one_room` 方法

## 9.3 WebSocket

- [ ] 检测 room.mode == "direct"
- [ ] direct 模式忙碌时发送 `agent_busy` 事件
- [ ] 其他模式使用消息队列
- [ ] 统一 camelCase 事件字段

## 9.4 API

- [ ] POST /rooms 支持 `agentIds` 参数
- [ ] POST /rooms 返回 `type` 字段
- [ ] POST /rooms/{id}/invite 实现懒生成
- [ ] DELETE /rooms/{id}/leave 移除成员

---

# 10. 与 PRD v3.1 一致性检查

| PRD 要求 | 实现 |
|---------|------|
| mode 支持 direct | ✅ mode 默认 "direct" |
| invite_code 懒生成 | ✅ 创建时为 null，invite API 生成 |
| 1:1 使用 direct | ✅ agent_id + direct 模式 |
| agent_busy 事件 | ✅ WebSocket 中实现 |
| WebSocket camelCase | ✅ 统一命名 |