from pydantic import BaseModel
from typing import Optional, List

class MessageCreate(BaseModel):
    content: str
    content_type: str = "text"
    extra: Optional[str] = None

class MessageResponse(BaseModel):
    id: str
    room_id: str
    sender_id: Optional[str]
    sender_type: Optional[str]
    sender_name: Optional[str]
    content: str
    content_type: str
    extra: Optional[str]
    parent_id: Optional[str]
    created_at: int

    class Config:
        from_attributes = True

class MessageListResponse(BaseModel):
    messages: List[MessageResponse]
    has_more: bool