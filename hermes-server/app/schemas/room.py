from pydantic import BaseModel, Field
from typing import Optional, List

class RoomCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    avatar: Optional[str] = None
    agent_ids: List[str] = Field(default_factory=list)  # Agent IDs for the room
    mode: str = Field(default="direct")  # direct/broadcast/mention/route

class RoomUpdate(BaseModel):
    name: Optional[str] = None
    avatar: Optional[str] = None
    mode: Optional[str] = None
    agent_id: Optional[str] = None
    profile_id: Optional[str] = None

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
    agent_id: Optional[str] = None  # 1:1 关联的 Agent ID
    profile_id: Optional[str] = None  # 内部字段
    created_at: int
    type: str = "group"  # "1v1" | "group"
    member_count: int = 0
    online_count: int = 0
    last_message: Optional[str] = None
    updated_at: Optional[int] = None
    has_running_tasks: bool = False
    running_tasks_count: int = 0

    class Config:
        from_attributes = True

class RoomDetail(RoomResponse):
    members: List["MemberResponse"] = []

class RoomJoin(BaseModel):
    invite_code: str

class MemberResponse(BaseModel):
    id: str
    user_id: str
    username: str
    role: str
    joined_at: int

    class Config:
        from_attributes = True


# Rebuild model with forward references
RoomDetail.model_rebuild()