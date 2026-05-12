from pydantic import BaseModel, Field
from typing import Optional, List

class RoomCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    avatar: Optional[str] = None
    mode: str = Field(default="broadcast")

class RoomUpdate(BaseModel):
    name: Optional[str] = None
    avatar: Optional[str] = None
    mode: Optional[str] = None

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
    created_at: int

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