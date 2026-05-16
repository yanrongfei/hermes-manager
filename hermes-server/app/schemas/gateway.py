from pydantic import BaseModel, Field
from typing import Optional


class GatewayCreate(BaseModel):
    name: Optional[str] = None
    address: str = Field(..., description="Gateway address: IP:Port or hostname:Port")
    api_key: Optional[str] = Field(None, description="Gateway API key (optional)")


class GatewayUpdate(BaseModel):
    name: Optional[str] = None
    api_key: Optional[str] = None


class GatewayResponse(BaseModel):
    id: str
    name: Optional[str]
    address: str
    api_key: Optional[str]
    status: str
    last_seen: Optional[int]
    created_at: int
    profile_count: int = 0
    agent_count: int = 0

    class Config:
        from_attributes = True
