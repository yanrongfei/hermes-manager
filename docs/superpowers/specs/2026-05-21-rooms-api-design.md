# rooms.py API 修复设计

> 后端 Room API Schema 修复
>
> Version: 1.0
>
> Date: 2026-05-21
>
> 状态: 已完成

---

# 1. 概述

## 1.1 背景

rooms.py API 当前实现与 PRD v3.1 存在以下不一致：
1. RoomCreate 缺少 agent_ids
2. RoomCreate mode 默认值错误（broadcast → direct）
3. RoomCreate profile_id 应为 agent_id
4. RoomResponse 缺少 type
5. RoomResponse 缺少 agent_id
6. RoomResponse 缺少成员统计

## 1.2 修复目标

| 问题 | 当前值 | 目标值 |
|------|--------|--------|
| agent_ids | 缺失 | 添加 |
| mode 默认值 | 'broadcast' | 'direct' |
| agent_id 字段 | profile_id | agent_id |
| type 字段 | 缺失 | 添加（计算字段） |
| 成员统计 | 缺失 | 添加 |

---

# 2. Schema 修复

## 2.1 RoomCreate

### 当前代码

```python
class RoomCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    avatar: Optional[str] = None
    mode: str = Field(default="broadcast")  # ❌
    profile_id: Optional[str] = None  # ❌
```

### 修复后

```python
class RoomCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    avatar: Optional[str] = None
    agent_ids: List[str] = Field(default_factory=list)  # ✅
    mode: str = Field(default="direct")  # ✅
```

## 2.2 RoomResponse

### 当前代码

```python
class RoomResponse(BaseModel):
    id: str
    name: str
    avatar: Optional[str]
    owner_id: str
    mode: str
    trigger_tokens: int
    max_history_tokens: int
    tail_message_count: int
    invite_code: Optional[str]
    profile_id: Optional[str]  # ❌
    created_at: int
    # ❌ 缺少 type
    # ❌ 缺少 agent_id
    # ❌ 缺少 member_count
    # ❌ 缺少 online_count
```

### 修复后

```python
class RoomResponse(BaseModel):
    id: str
    name: str
    avatar: Optional[str]
    owner_id: str
    mode: str
    trigger_tokens: int
    max_history_tokens: int
    tail_message_count: int
    invite_code: Optional[str]
    agent_id: Optional[str] = None  # ✅ 1:1 关联
    profile_id: Optional[str] = None  # 内部字段
    created_at: int

    # ✅ 新增字段
    type: str  # "1v1" | "group"
    member_count: int = 0
    online_count: int = 0
    last_message: Optional[str] = None
    updated_at: Optional[int] = None
    has_running_tasks: bool = False
    running_tasks_count: int = 0
```

---

# 3. type 计算逻辑

## 3.1 计算规则

```python
def calculate_room_type(agent_ids: List[str], mode: str) -> str:
    """
    根据 agent_ids 长度判断 room type
    """
    if len(agent_ids) == 1:
        return "1v1"
    return "group"
```

## 3.2 创建时计算

```python
# 在 RoomService.create_room 中
type = calculate_room_type(agent_ids, mode)
```

---

# 4. API 修复

## 4.1 POST /rooms

### 当前代码

```python
@router.post("", response_model=RoomResponse)
async def create_room(
    data: RoomCreate,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    service = RoomService(db)
    return await service.create_room(
        current_user.id, data.name, data.mode, data.profile_id
    )
```

### 修复后

```python
@router.post("", response_model=RoomResponse)
async def create_room(
    data: RoomCreate,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    service = RoomService(db)
    room = await service.create_room(
        owner_id=current_user.id,
        name=data.name,
        mode=data.mode,
        agent_ids=data.agent_ids,  # ✅
    )
    return room
```

## 4.2 GET /rooms

### 当前代码

```python
@router.get("", response_model=List[RoomResponse])
async def list_rooms(
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    service = RoomService(db)
    return await service.get_user_rooms(current_user.id)
```

### 修复后

```python
@router.get("", response_model=List[RoomResponse])
async def list_rooms(
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    service = RoomService(db)
    rooms = await service.get_user_rooms(current_user.id)

    # 为每个 room 添加统计信息
    result = []
    for room in rooms:
        stats = await service.get_room_stats(room.id)  # ✅
        result.append({
            **RoomResponse.model_validate(room).model_dump(),
            **stats
        })
    return result
```

## 4.3 GET /rooms/{room_id}

### 当前代码

```python
@router.get("/{room_id}", response_model=RoomDetail)
async def get_room(
    room_id: str,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # ... 验证逻辑
    return {
        **RoomResponse.model_validate(room).model_dump(),
        "members": [...]
    }
```

### 修复后

```python
@router.get("/{room_id}", response_model=RoomDetail)
async def get_room(
    room_id: str,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # ... 验证逻辑
    stats = await service.get_room_stats(room_id)  # ✅
    return {
        **RoomResponse.model_validate(room).model_dump(),
        **stats,
        "members": [...]
    }
```

---

# 5. RoomService 扩展

## 5.1 get_room_stats 方法

```python
async def get_room_stats(self, room_id: str) -> dict:
    """获取 room 的统计信息"""
    # 成员数量
    members = await self.get_room_members(room_id)
    member_count = len(members)

    # 在线数量（需要 gateway 连接状态）
    online_count = member_count  # 简化版，后续接入 gateway 状态

    # 运行中的任务（从 ws.py 的 active_executors 获取）
    from app.api.ws import active_executors
    running_count = len(active_executors.get(room_id, []))

    return {
        "member_count": member_count,
        "online_count": online_count,
        "has_running_tasks": running_count > 0,
        "running_tasks_count": running_count,
    }
```

## 5.2 create_room 修改

```python
async def create_room(
    self,
    owner_id: str,
    name: str,
    mode: str = "direct",
    agent_ids: List[str] = None,  # ✅
    agent_id: str = None,  # 1:1 专用
) -> Room:
    # 计算 type
    type = "1v1" if (len(agent_ids) == 1 if agent_ids else agent_id) else "group"

    # invite_code 懒生成，创建时为 None
    room = Room(
        owner_id=owner_id,
        name=name,
        mode=mode,
        agent_id=agent_id,
        invite_code=None,  # ✅ 懒生成
        # ... 其他字段
    )
    # ...
```

---

# 6. 懒生成邀请码 API

## 6.1 新增 API

```python
@router.post("/{room_id}/invite", response_model={"invite_code": str})
async def generate_invite_code(
    room_id: str,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    service = RoomService(db)
    room = await service.get_room(room_id)

    if not room:
        raise AppException(ErrorCode.RESOURCE_NOT_FOUND, "聊天室不存在", status_code=404)

    # 1:1 不允许邀请
    if room.mode == "direct":
        raise AppException(ErrorCode.RESOURCE_BAD_REQUEST, "1:1 聊天室不支持邀请", status_code=400)

    # 生成邀请码
    invite_code = await service.generate_invite_code(room_id)
    return {"invite_code": invite_code}
```

---

# 7. 完整 Schema 对照

## 7.1 RoomCreate

```python
class RoomCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    avatar: Optional[str] = None
    agent_ids: List[str] = Field(default_factory=list)  # ✅
    mode: str = Field(default="direct")  # ✅
```

## 7.2 RoomResponse

```python
class RoomResponse(BaseModel):
    id: str
    name: str
    avatar: Optional[str]
    owner_id: str
    mode: str
    trigger_tokens: int
    max_history_tokens: int
    tail_message_count: int
    invite_code: Optional[str]
    agent_id: Optional[str]  # ✅
    profile_id: Optional[str]
    created_at: int
    type: str  # ✅ "1v1" | "group"
    member_count: int  # ✅
    online_count: int  # ✅
    last_message: Optional[str]  # ✅
    updated_at: Optional[int]  # ✅
    has_running_tasks: bool  # ✅
    running_tasks_count: int  # ✅
```

---

# 8. 实现检查清单

- [ ] RoomCreate 添加 agent_ids 字段
- [ ] RoomCreate mode 默认值改为 'direct'
- [ ] RoomResponse 添加 agent_id 字段
- [ ] RoomResponse 添加 type 字段（计算）
- [ ] RoomResponse 添加成员统计字段
- [ ] POST /rooms 处理 agent_ids
- [ ] GET /rooms 返回统计信息
- [ ] GET /rooms/{id} 返回统计信息
- [ ] 添加 GET /rooms/{id}/invite API
- [ ] RoomService 添加 get_room_stats 方法
- [ ] RoomService.create_room 支持 agent_id

---

# 9. 与 PRD v3.1 一致性

| PRD 要求 | 实现 |
|---------|------|
| POST /rooms agentIds | ✅ RoomCreate.agent_ids |
| mode 默认 direct | ✅ |
| 1:1 agent_id | ✅ RoomResponse.agent_id |
| type 字段 | ✅ |
| invite_code 懒生成 | ✅ |
| 成员统计 | ✅ |