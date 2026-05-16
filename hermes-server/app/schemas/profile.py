from pydantic import BaseModel
from typing import Optional


class ProfileResponse(BaseModel):
    id: str
    gateway_id: str
    remote_name: str
    alias: Optional[str]
    model: Optional[str]
    provider: Optional[str]
    skills: int
    description: Optional[str]
    synced_at: Optional[int]
    created_at: int
    agent_count: int = 0

    class Config:
        from_attributes = True


class ProfileUpdate(BaseModel):
    alias: Optional[str] = None
