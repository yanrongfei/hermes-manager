from pydantic import BaseModel
from typing import Optional


class AgentResponse(BaseModel):
    id: str
    profile_id: str
    remote_id: str
    name: str
    description: Optional[str]
    avatar: Optional[str]
    invited: bool
    created_at: int

    class Config:
        from_attributes = True
