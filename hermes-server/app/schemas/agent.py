from pydantic import BaseModel
from typing import Optional

class AgentCreate(BaseModel):
    machine_id: str
    remote_id: str
    name: str
    description: Optional[str] = None
    avatar: Optional[str] = None
    profile: Optional[str] = None
    invited: bool = False

class AgentUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    avatar: Optional[str] = None
    profile: Optional[str] = None

class AgentResponse(BaseModel):
    id: str
    machine_id: str
    remote_id: str
    name: str
    description: Optional[str]
    avatar: Optional[str]
    profile: Optional[str]
    invited: bool
    created_at: int

    class Config:
        from_attributes = True
